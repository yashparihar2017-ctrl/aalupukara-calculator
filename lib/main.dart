import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'calculator_ui.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  if (message.data['stealth_trigger'] == 'true') {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(settings: initSettings);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'stealth_calc_updates',
          'System Updates',
          channelDescription: 'Updates for calculator features',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: "Calculator Update",
      body: "New mathematical features available. Tap to apply.",
      notificationDetails: platformDetails,
    );
  }
}

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

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
