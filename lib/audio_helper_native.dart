import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String?> saveBytesToTempFile(Uint8List bytes, String ext) async {
  final dir  = await getTemporaryDirectory();
  final file = File('${dir.path}/highlight_audio.$ext');
  await file.writeAsBytes(bytes);
  return file.path;
}
