import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/documents_store.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => DocumentsStore()..load(),
      child: const ScoreSnapApp(),
    ),
  );
}
