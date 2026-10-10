import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'calculator_ui.dart'; // Nayi UI file link ki hai

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDkq-MukkGAbaM24SAff3xttfDa36norHU",
          authDomain: "aalupukara-1c043.firebaseapp.com",
          projectId: "aalupukara-1c043",
          storageBucket: "aalupukara-1c043.firebasestorage.app",
          messagingSenderId: "658556847752",
          appId: "1:658556847752:web:2fd55ac83c588d0a0ac13d",
          measurementId: "G-J14Y4KGXZ9",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    runApp(const SecretApp());
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text("Error: $e"))),
      ),
    );
  }
}

class SecretApp extends StatelessWidget {
  const SecretApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CalculatorScreen(),
    );
  }
}
