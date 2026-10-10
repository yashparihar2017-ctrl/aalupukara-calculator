import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'secret_chat_screen.dart';

class SecretLogin extends StatefulWidget {
  const SecretLogin({super.key});

  @override
  State<SecretLogin> createState() => _SecretLoginState();
}

class _SecretLoginState extends State<SecretLogin> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  void loginUser() async {
    String id = _idController.text.trim();
    String pass = _passController.text.trim();
    String peer = "";

    // Hardcoded 2 IDs (No Sign Up)
    if (id == "Yash" && pass == "1111") {
      peer = "Partner";
    } else if (id == "Partner" && pass == "2222") {
      peer = "Yash";
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Wrong ID or Password!")));
      return;
    }

    // Login hote hi Firebase mein online status set karo
    await FirebaseFirestore.instance.collection('users').doc(id).set({
      'isOnline': true,
      'isTyping': false,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Chat screen par bhejo
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              SecretChatScreen(currentUser: id, peerUser: peer),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Vault Login", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _idController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Vault ID",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Passcode",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
              ),
              onPressed: loginUser,
              child: const Text(
                "ACCESS VAULT",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
