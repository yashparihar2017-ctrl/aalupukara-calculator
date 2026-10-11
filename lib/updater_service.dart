import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:io';

class UpdaterService {
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('app_info')
          .doc('update_data')
          .get();

      if (!snapshot.exists) {
        return;
      }

      String latestVersionOnCloud = snapshot['latest_version'];
      String apkDownloadUrl = snapshot['apk_url'];

      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      if (currentVersion != latestVersionOnCloud) {
        if (!context.mounted) {
          return;
        }
        _showUpdatePopup(context, apkDownloadUrl);
      }
    } catch (e) {
      debugPrint("Update error: $e");
    }
  }

  static void _showUpdatePopup(BuildContext context, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      // Renamed context to dialogContext to avoid shadowing
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text("New VIP Update!"),
        content: const Text(
          "App ka naya version aa gaya hai. Abhi update karein.",
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(dialogContext);
              _downloadAndInstall(context, downloadUrl);
            },
            child: const Text(
              "Update Now",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadAndInstall(
    BuildContext context,
    String url,
  ) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Update link missing!")));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Downloading update... Please wait.")),
    );

    try {
      Directory tempDir = await getTemporaryDirectory();
      String savePath = "${tempDir.path}/update.apk";

      Dio dio = Dio();
      await dio.download(url, savePath);

      OpenFilex.open(savePath);
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Download failed: $e")));
    }
  }
}
