import 'package:flutter/material.dart';

import 'calculator_logic.dart';
import 'updater_service.dart';
import 'secret_login.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'secret_chat_screen.dart';

import 'dart:async'; // StreamSubscription ke liye add kiya

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
  String _history = '';
  final CalculatorLogic _logic = CalculatorLogic();

  // Notification Engine Setup
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Naye variables: Taaki double-double notification na aaye
  StreamSubscription<QuerySnapshot>? _messageSubscription;
  StreamSubscription<DocumentSnapshot>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
    _initStealthNotifications();
  }

  void _checkForUpdates() async {
    await UpdaterService.checkForUpdate(context);
  }

  // Khufiya Notification Engine!
  void _initStealthNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(settings: initSettings);

    // Android 13+ Notification Permission
    _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? myId = prefs.getString('my_id');
    String? peerId = prefs.getString('peer_id');

    if (myId != null && peerId != null) {
      // Purane background processes ko band karo (taaki double notification na aaye)
      _messageSubscription?.cancel();
      _statusSubscription?.cancel();

      // 1. Message Listener (Fake "Calculator Update" Alert)
      _messageSubscription = FirebaseFirestore.instance
          .collection('secret_messages')
          .where('sender', isEqualTo: peerId)
          .where('isSeen', isEqualTo: false)
          .snapshots()
          .listen((snapshot) async {
            if (snapshot.docs.isNotEmpty && !SecretChatScreen.isChatOpen) {
              var userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(myId)
                  .get();
              if (userDoc.exists &&
                  userDoc.data()?['notificationsEnabled'] == true) {
                for (var change in snapshot.docChanges) {
                  if (change.type == DocumentChangeType.added) {
                    _showStealthNotification(
                      "Calculator Update",
                      "New mathematical features available. Tap to apply.",
                    );
                    break;
                  }
                }
              }
            }
          });

      // 2. Online Status Listener (Fake "Performance Optimization" Alert)
      _statusSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(peerId)
          .snapshots()
          .listen((snapshot) async {
            if (snapshot.exists && !SecretChatScreen.isChatOpen) {
              var data = snapshot.data() as Map<String, dynamic>;
              bool isOnline = data['isOnline'] ?? false;
              bool wasOnline =
                  prefs.getBool('peer_was_online_$peerId') ?? false;

              if (isOnline && !wasOnline) {
                var userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(myId)
                    .get();
                if (userDoc.exists &&
                    userDoc.data()?['notificationsEnabled'] == true) {
                  _showStealthNotification(
                    "Performance Optimization",
                    "Calculator algorithms are running faster.",
                  );
                }
              }
              prefs.setBool('peer_was_online_$peerId', isOnline);
            }
          });
    }
  }

  // Asli Notification Dikhanewala function
  Future<void> _showStealthNotification(String title, String body) async {
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

    await _flutterLocalNotificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }

  void _onButtonPressed(String buttonText) {
    setState(() {
      if (buttonText == 'C') {
        _display = '0';
        _history = '';
      } else if (buttonText == '⌫') {
        _display = _display.length > 1
            ? _display.substring(0, _display.length - 1)
            : '0';
      } else if (buttonText == '=') {
        if (_display == '8055') {
          _display = '0';
          // Khufiya Chat khulne ka Code!
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SecretLogin()),
          ).then((_) {
            // FIX: Chat se bahar aane ke baad notification engine wapas chalu hoga
            _initStealthNotifications();
          });
        } else {
          _history = _display;
          _display = _logic.processInput('=', _display, _history);
        }
      } else if (buttonText == '( )') {
        if (_display == '0') {
          _display = '(';
        } else {
          _display += '(';
        }
      } else {
        if (_display == '0' && buttonText != '.') {
          _display = buttonText;
        } else {
          _display += buttonText;
        }
      }
    });
  }

  Widget _buildButton(
    String text, {
    Color textColor = Colors.white,
    Color? bgColor,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: () => _onButtonPressed(text),
          customBorder: const CircleBorder(),
          child: Ink(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor ?? const Color(0xFF1E1E1E),
            ),
            child: Center(
              child: text == '⌫'
                  ? Icon(Icons.backspace_outlined, color: textColor, size: 24)
                  : Text(
                      text,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 28,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _history,
                      style: const TextStyle(color: Colors.grey, fontSize: 24),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _display,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildButton('C', textColor: Colors.redAccent),
                      _buildButton('⌫', textColor: Colors.redAccent),
                      _buildButton('%'),
                      _buildButton('÷'),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('7'),
                      _buildButton('8'),
                      _buildButton('9'),
                      _buildButton('×'),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('4'),
                      _buildButton('5'),
                      _buildButton('6'),
                      _buildButton('-'),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('1'),
                      _buildButton('2'),
                      _buildButton('3'),
                      _buildButton('+'),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('( )'),
                      _buildButton('0'),
                      _buildButton('.'),
                      _buildButton('=', bgColor: const Color(0xFF007A5E)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
