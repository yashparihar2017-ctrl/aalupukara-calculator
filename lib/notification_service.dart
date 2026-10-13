import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  // DHYAN DEIN: Yahan apna Firebase ka asli JSON paste karein
  static const String _serviceAccountJsonString = '''
  {
    "type": "service_account",
    "project_id": "aalupukara-1c043",
    "private_key_id": "YOUR_KEY_ID",
    "private_key": "YOUR_PRIVATE_KEY",
    "client_email": "YOUR_CLIENT_EMAIL",
    "client_id": "YOUR_CLIENT_ID",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "YOUR_CERT_URL"
  }
  ''';

  static Future<void> sendStealthNotification(String targetFcmToken) async {
    try {
      final accountCredentials = ServiceAccountCredentials.fromJson(
        _serviceAccountJsonString,
      );
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

      final authClient = await clientViaServiceAccount(
        accountCredentials,
        scopes,
      );
      final String projectId =
          accountCredentials.projectId ?? "aalupukara-1c043";
      final String url =
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final Map<String, dynamic> payload = {
        'message': {
          'token': targetFcmToken,
          'data': {'stealth_trigger': 'true'},
          // YE NAYI 3 LINES ADD KARNI HAIN
          'android': {'priority': 'high'},
        },
      };

      final response = await authClient.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      debugPrint('Ghost Message Fired! Status: ${response.statusCode}');
      authClient.close();
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }
}
