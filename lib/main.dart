import 'package:flutter/material.dart';
import 'reader_page.dart';

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Color(0xFF6B0000), useMaterial3: true),
      home: ReaderPage(),
    ));
