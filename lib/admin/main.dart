import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../theme.dart';
import 'admin_gate.dart';

/// The admin panel (web): `flutter build web -t lib/admin/main.dart`.
/// Shares the question model with the app but none of its services.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  runApp(
    MaterialApp(
      title: 'Amore Admin',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      themeMode: ThemeMode.dark,
      home: const AdminGate(),
    ),
  );
}
