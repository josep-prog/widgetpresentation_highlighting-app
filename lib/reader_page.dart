import 'dart:convert';
import 'dart:typed_data';

import 'audio_helper.dart' if (dart.library.io) 'audio_helper_native.dart';
import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key});
  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  List<String> _words = [];
  String? _docName;

  List<List<int>> _sentences  = [];
  Map<int, int>   _wordToSent = {};

  int      _currentWord      = -1;
  int      _currentSent      = -1;
  Set<int> _currentSentWords = {};

  List<GlobalKey> _keys = [];

  final _player  = AudioPlayer();
  bool _hasAudio = false;
  bool _playing  = false;

  List<double> _wordStarts = [];

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    _player.onPositionChanged.listen((pos) {
      if (!_playing || _wordStarts.isEmpty) return;
      final sec = pos.inMilliseconds / 1000.0;
      int idx = 0;
      for (int i = 1; i < _wordStarts.length; i++) {
        if (_wordStarts[i] > sec) break;
        idx = i;
      }
      if (idx != _currentWord) _highlight(idx);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playing = false; _clearHighlight(); });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _highlight(int wordIdx) {
    if (wordIdx < 0 || wordIdx >= _words.length) return;
    final sentIdx     = _wordToSent[wordIdx] ?? -1;
    final sentChanged = sentIdx != _currentSent;

    setState(() {
      _currentWord = wordIdx;
      if (sentChanged) {
        _currentSent      = sentIdx;
        _currentSentWords = sentIdx >= 0 ? _sentences[sentIdx].toSet() : {};
      }
    });

    if (wordIdx < _keys.length) {
      final ctx = _keys[wordIdx].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.35,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    }
  }

  void _clearHighlight() {
    _currentWord      = -1;
    _currentSent      = -1;
    _currentSentWords = {};
  }

  void _tokenise(String text) {
    _words = [];
    final starts = <int>[];
    int pos = 0;

    for (final token in text.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final s = text.indexOf(token, pos);
      starts.add(s);
      _words.add(token);
      pos = s + token.length;
    }

    _keys = List.generate(_words.length, (_) => GlobalKey());
    _buildSentences();
  }

  void _buildSentences() {
    _sentences  = [];
    _wordToSent = {};
    var current = <int>[];
    for (int i = 0; i < _words.length; i++) {
      current.add(i);
      final w      = _words[i];
      final isLast = i == _words.length - 1;
      if (w.endsWith('.') || w.endsWith('!') || w.endsWith('?') || isLast) {
        final sIdx = _sentences.length;
        _sentences.add(List.from(current));
        for (final wi in current) { _wordToSent[wi] = sIdx; }
        current.clear();
      }
    }
    if (current.isNotEmpty) {
      final sIdx = _sentences.length;
      _sentences.add(List.from(current));
      for (final wi in current) { _wordToSent[wi] = sIdx; }
    }
  }

  List<double> _buildWeightedTimings(Duration audioDuration) {
    final total   = audioDuration.inMilliseconds / 1000.0;
    final weights = _words.map((w) {
      double wt = w.length.toDouble();
      if (w.endsWith('.') || w.endsWith('!') || w.endsWith('?')) { wt += 5; }
      else if (w.endsWith(',') || w.endsWith(';') || w.endsWith(':')) { wt += 2; }
      return wt;
    }).toList();
    final totalWt = weights.fold(0.0, (a, b) => a + b);
    double cum = 0;
    return weights.map((wt) {
      final start = cum;
      cum += (wt / totalWt) * total;
      return start;
    }).toList();
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'pdf', 'docx'],
      withData: true,
    );
    if (result == null) return;

    final picked = result.files.single;
    final bytes  = picked.bytes;
    if (bytes == null) { _snack('Could not read file bytes'); return; }

    try {
      final text = _extractText(bytes, picked.extension ?? '');
      await _player.stop();
      setState(() {
        _docName  = picked.name;
        _playing  = false;
        _hasAudio = false;
        _wordStarts.clear();
        _clearHighlight();
        _tokenise(text.trim());
      });
    } catch (e) {
      _snack('Could not read "${picked.name}": $e');
    }
  }

  Future<void> _pickAudio() async {
    if (_words.isEmpty) { _snack('Open a document first'); return; }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result == null) return;

    final bytes = result.files.single.bytes;
    if (bytes == null) { _snack('Could not read audio bytes'); return; }

    await _player.stop();

    final ext      = result.files.single.extension ?? 'mp3';
    final tempPath = await saveBytesToTempFile(bytes, ext);
    if (tempPath != null) {
      await _player.setSource(DeviceFileSource(tempPath));
    } else {
      await _player.setSource(BytesSource(bytes));
    }
    final dur = await _player.getDuration();

    setState(() {
      _hasAudio   = true;
      _playing    = false;
      _wordStarts = dur != null ? _buildWeightedTimings(dur) : [];
      _clearHighlight();
    });
  }

  String _extractText(Uint8List bytes, String ext) {
    switch (ext.toLowerCase()) {
      case 'txt':
        return utf8.decode(bytes);
      case 'pdf':
        final doc  = PdfDocument(inputBytes: bytes);
        final text = PdfTextExtractor(doc).extractText();
        doc.dispose();
        return text;
      case 'docx':
        final archive = ZipDecoder().decodeBytes(bytes);
        final docXml  = archive.findFile('word/document.xml');
        if (docXml == null) throw Exception('Invalid DOCX — no document.xml');
        final xmlStr  = utf8.decode(docXml.content as List<int>);
        final xmlDoc  = XmlDocument.parse(xmlStr);
        return xmlDoc.findAllElements('w:p').map((para) {
          return para.findAllElements('w:t').map((t) => t.innerText).join('');
        }).where((s) => s.isNotEmpty).join('\n');
      default:
        throw UnsupportedError('Unsupported format: .$ext');
    }
  }

  Future<void> _togglePlay() async {
    if (_words.isEmpty) return;
    if (!_hasAudio) { _snack('Load an audio file first'); return; }

    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
    } else {
      setState(() => _playing = true);
      await _player.resume();
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6B0000),
        foregroundColor: Colors.white,
        title: Text(_docName ?? 'Highlight Reader',
            style: const TextStyle(fontSize: 16)),
        actions: const [],
      ),
      body: _words.isEmpty ? _emptyState() : _textView(),
      bottomNavigationBar: _controls(),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Open a document to begin',
                style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 6),
            Text('TXT  ·  PDF  ·  DOCX',
                style: TextStyle(fontSize: 13, color: Colors.grey[400])),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickDocument,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Open Document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B0000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );

  Widget _textView() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 19, color: Colors.black, height: 1.75),
            children: List.generate(_words.length, (i) {
              final inSent  = _currentSentWords.contains(i);
              final bgColor = inSent ? const Color(0xFFFFE066) : null;

              return WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Container(
                  key: _keys[i],
                  decoration: bgColor != null
                      ? BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(2),
                        )
                      : null,
                  padding: bgColor != null
                      ? const EdgeInsets.symmetric(horizontal: 1)
                      : EdgeInsets.zero,
                  child: Text(
                    '${_words[i]} ',
                    style: const TextStyle(fontSize: 19, height: 1.75),
                  ),
                ),
              );
            }),
          ),
        ),
      );

  Widget _controls() => Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: SafeArea(
          child: Row(
            children: [
              _FileBtn(
                icon: Icons.upload_file_rounded,
                label: _docName != null ? 'Change Doc' : 'Document',
                onTap: _pickDocument,
                active: _docName != null,
              ),
              const SizedBox(width: 24),
              _FileBtn(
                icon: Icons.audio_file_rounded,
                label: _hasAudio ? 'Audio ✓' : 'Audio',
                onTap: _pickAudio,
                active: _hasAudio,
              ),
              const Spacer(),
              GestureDetector(
                onTap: _togglePlay,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _words.isEmpty
                        ? Colors.grey[300]
                        : const Color(0xFF6B0000),
                    shape: BoxShape.circle,
                    boxShadow: _words.isEmpty
                        ? []
                        : [
                            BoxShadow(
                              color: const Color(0xFF6B0000).withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                  ),
                  child: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _FileBtn extends StatelessWidget {
  const _FileBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF6B0000) : Colors.grey[500]!;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
        ],
      ),
    );
  }
}
