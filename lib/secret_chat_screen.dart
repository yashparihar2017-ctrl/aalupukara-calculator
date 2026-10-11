import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

class SecretChatScreen extends StatefulWidget {
  static bool isChatOpen = false;

  final String currentUser;
  final String peerUser;

  const SecretChatScreen({
    super.key,
    required this.currentUser,
    required this.peerUser,
  });

  @override
  State<SecretChatScreen> createState() => _SecretChatScreenState();
}

class _SecretChatScreenState extends State<SecretChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _msgController = TextEditingController();
  String? _editingDocId;
  Map<String, dynamic>? _replyingTo;

  int _selectedAutoDeleteTime = 0;
  final List<int> _timeOptions = [0, 5, 10, 30, 60];

  bool _isPickingImage = false;
  final ImagePicker _picker = ImagePicker();

  StreamSubscription<QuerySnapshot>? _seenSubscription;
  StreamSubscription<DocumentSnapshot>? _settingsSubscription;
  final Map<String, Timer> _bombTimers = {};

  bool _isNotificationOn = false;
  String _customDisplayName = "";

  String get _roomId {
    List<String> users = [widget.currentUser, widget.peerUser];
    users.sort();
    return users.join('_');
  }

  @override
  void initState() {
    super.initState();
    SecretChatScreen.isChatOpen = true;

    WidgetsBinding.instance.addObserver(this);

    _customDisplayName = widget.peerUser;

    _setUserOnline(true);
    _startSeenListener();
    _loadCloudPreferences();

    _settingsSubscription = FirebaseFirestore.instance
        .collection('chat_settings')
        .doc(_roomId)
        .snapshots()
        .listen((doc) {
          if (doc.exists && context.mounted) {
            setState(() {
              _selectedAutoDeleteTime = doc.data()?['autoDeleteTime'] ?? 0;
            });
          }
        });
  }

  Future<void> _loadCloudPreferences() async {
    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUser)
        .get();

    // FIX: Strictly using context.mounted to avoid async gap warnings
    if (!context.mounted) {
      return;
    }

    if (doc.exists) {
      var data = doc.data()!;
      setState(() {
        _isNotificationOn = data['notificationsEnabled'] ?? false;
        _customDisplayName = data['savedContactName'] ?? widget.peerUser;
      });
    }
  }

  void _editDisplayName() {
    TextEditingController nameController = TextEditingController(
      text: _customDisplayName,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text("Edit Name", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter new name...",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              String newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.currentUser)
                    .set({
                      'savedContactName': newName,
                    }, SetOptions(merge: true));

                // FIX: Strictly using context.mounted here as well
                if (!context.mounted) {
                  return;
                }

                setState(() {
                  _customDisplayName = newName;
                });
                Navigator.pop(context);
              }
            },
            child: const Text(
              "Save to Cloud",
              style: TextStyle(color: Colors.greenAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleNotification() async {
    bool newState = !_isNotificationOn;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUser)
        .set({'notificationsEnabled': newState}, SetOptions(merge: true));

    // FIX: Strictly using context.mounted
    if (!context.mounted) {
      return;
    }

    setState(() {
      _isNotificationOn = newState;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isNotificationOn
              ? "Ghost Notifications ON 👻"
              : "Notifications OFF 🔕",
        ),
        backgroundColor: _isNotificationOn ? Colors.green : Colors.redAccent,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    SecretChatScreen.isChatOpen = false;

    WidgetsBinding.instance.removeObserver(this);
    _setUserOnline(false);

    _seenSubscription?.cancel();
    _settingsSubscription?.cancel();
    for (var timer in _bombTimers.values) {
      timer.cancel();
    }
    _bombTimers.clear();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserOnline(true);
      _startSeenListener();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!_isPickingImage) {
        _setUserOnline(false);
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _setUserOnline(bool isOnline) {
    FirebaseFirestore.instance.collection('users').doc(widget.currentUser).set({
      'isOnline': isOnline,
      'isTyping': false,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _updateTypingStatus(String text) {
    FirebaseFirestore.instance.collection('users').doc(widget.currentUser).set({
      'isTyping': text.isNotEmpty,
    }, SetOptions(merge: true));
  }

  void _startSeenListener() {
    _seenSubscription?.cancel();

    _seenSubscription = FirebaseFirestore.instance
        .collection('secret_messages')
        .where('sender', isEqualTo: widget.peerUser)
        .where('isSeen', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.update({
              'isSeen': true,
              'seenAt': FieldValue.serverTimestamp(),
            });
          }
        });
  }

  void _clearEntireChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text("Clear Chat?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This will delete all messages. Are you sure?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              var snapshots = await FirebaseFirestore.instance
                  .collection('secret_messages')
                  .get();
              for (var doc in snapshots.docs) {
                await doc.reference.delete();
              }
            },
            child: const Text(
              "Clear",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    setState(() => _isPickingImage = true);

    XFile? image;
    try {
      image = await _picker.pickImage(
        source: source,
        imageQuality: 25,
        maxWidth: 800,
      );
    } catch (e) {
      // Ignore
    }

    // FIX: Using context.mounted for all async gaps in this method
    if (!context.mounted) {
      return;
    }
    setState(() => _isPickingImage = false);

    if (image == null) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Sending photo...")));

    try {
      List<int> imageBytes = await image.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      if (!context.mounted) {
        return;
      }

      if (base64Image.length > 1000000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Photo is too large, try another one.")),
        );
        return;
      }

      FirebaseFirestore.instance.collection('secret_messages').add({
        'text': '📸 Photo',
        'imageBase64': base64Image,
        'sender': widget.currentUser,
        'timestamp': FieldValue.serverTimestamp(),
        'isSeen': false,
        'isEdited': false,
        'replyText': _replyingTo != null ? _replyingTo!['text'] : null,
        'autoDeleteTime': _selectedAutoDeleteTime,
      });
      setState(() => _replyingTo = null);
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to send photo: $e")));
    }
  }

  void _showImageSourceMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: Colors.greenAccent,
                ),
                title: const Text(
                  "Camera",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Colors.blueAccent,
                ),
                title: const Text(
                  "Gallery",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void sendMessage() {
    if (_msgController.text.trim().isEmpty) {
      return;
    }

    if (_editingDocId != null) {
      FirebaseFirestore.instance
          .collection('secret_messages')
          .doc(_editingDocId)
          .update({'text': _msgController.text.trim(), 'isEdited': true});
      _editingDocId = null;
    } else {
      FirebaseFirestore.instance.collection('secret_messages').add({
        'text': _msgController.text.trim(),
        'sender': widget.currentUser,
        'timestamp': FieldValue.serverTimestamp(),
        'isSeen': false,
        'isEdited': false,
        'replyText': _replyingTo != null ? _replyingTo!['text'] : null,
        'autoDeleteTime': _selectedAutoDeleteTime,
      });
      setState(() => _replyingTo = null);
    }

    _msgController.clear();
    _updateTypingStatus("");
  }

  void _showMessageMenu(
    BuildContext context,
    Offset offset,
    String docId,
    String currentText,
    bool isMe,
  ) async {
    double left = offset.dx;
    double top = offset.dy;

    var action = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(left, top, left + 1, top + 1),
      color: const Color(0xFF2C2C2C),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        const PopupMenuItem(
          value: 'reply',
          child: Row(
            children: [
              Icon(Icons.reply, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text("Reply", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        if (isMe)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                SizedBox(width: 10),
                Text("Edit", style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        if (isMe)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                SizedBox(width: 10),
                Text("Delete", style: TextStyle(color: Colors.redAccent)),
              ],
            ),
          ),
      ],
    );

    if (action == 'reply') {
      setState(() => _replyingTo = {'id': docId, 'text': currentText});
    } else if (action == 'edit') {
      setState(() {
        _msgController.text = currentText;
        _editingDocId = docId;
      });
    } else if (action == 'delete') {
      FirebaseFirestore.instance
          .collection('secret_messages')
          .doc(docId)
          .delete();
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return "";
    }
    return DateFormat('hh:mm a').format(timestamp.toDate());
  }

  void _changeTimer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) {
        return ListView.builder(
          shrinkWrap: true,
          itemCount: _timeOptions.length,
          itemBuilder: (context, index) {
            int time = _timeOptions[index];
            String label = time == 0 ? "Off" : "$time Seconds";
            return ListTile(
              title: Text(
                label,
                style: TextStyle(
                  color: _selectedAutoDeleteTime == time
                      ? Colors.greenAccent
                      : Colors.white,
                ),
              ),
              trailing: _selectedAutoDeleteTime == time
                  ? const Icon(Icons.check, color: Colors.greenAccent)
                  : null,
              onTap: () {
                FirebaseFirestore.instance
                    .collection('chat_settings')
                    .doc(_roomId)
                    .set({'autoDeleteTime': time});
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  Future<bool> _onWillPop() async {
    if (_isNotificationOn) {
      bool? confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber),
              SizedBox(width: 10),
              Text("Warning", style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            "Ghost Notifications are ON!\n\nIf you get a message, a fake 'Calculator Update' notification will appear. Are you sure you want to leave them ON?",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _toggleNotification();
                Navigator.of(context).pop(true);
              },
              child: const Text(
                "Turn OFF & Exit",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                "Keep ON",
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),
          ],
        ),
      );
      if (confirm == true) {
        _setUserOnline(false);
        return true;
      }
      return false;
    }

    _setUserOnline(false);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }

        final bool shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          elevation: 10,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () async {
              bool canPop = await _onWillPop();
              if (canPop && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: GestureDetector(
            onTap: _editDisplayName,
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.peerUser)
                  .snapshots(),
              builder: (context, snapshot) {
                String status = "Offline";
                bool isTyping = false;
                if (snapshot.hasData && snapshot.data!.exists) {
                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  if (data['isTyping'] == true) {
                    status = "typing ";
                    isTyping = true;
                  } else if (data['isOnline'] == true) {
                    status = "Online";
                  } else {
                    Timestamp? lastSeen = data['lastSeen'];
                    status = lastSeen != null
                        ? "Last seen at ${_formatTimestamp(lastSeen)}"
                        : "Offline";
                  }
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _customDisplayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    isTyping
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "typing ",
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              TypingIndicator(),
                            ],
                          )
                        : Text(
                            status,
                            style: TextStyle(
                              color: status == "Online"
                                  ? Colors.greenAccent
                                  : Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                  ],
                );
              },
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isNotificationOn
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: _isNotificationOn ? Colors.amber : Colors.white54,
              ),
              onPressed: _toggleNotification,
            ),
            IconButton(
              icon: Icon(
                _selectedAutoDeleteTime > 0
                    ? Icons.timer
                    : Icons.timer_off_outlined,
                color: _selectedAutoDeleteTime > 0
                    ? Colors.greenAccent
                    : Colors.white70,
              ),
              onPressed: _changeTimer,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              onPressed: _clearEntireChat,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('secret_messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.greenAccent,
                        ),
                      );

                    var messages = snapshot.data!.docs;
                    return ListView.builder(
                      reverse: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        var msg = messages[index];
                        var docId = msg.id;
                        var data = msg.data() as Map<String, dynamic>;

                        bool isMe = data['sender'] == widget.currentUser;
                        bool isSeen = data['isSeen'] ?? false;
                        bool isEdited = data['isEdited'] ?? false;
                        String? replyText = data['replyText'];
                        String? imageBase64 = data['imageBase64'];
                        int autoDelete = data['autoDeleteTime'] ?? 0;
                        Timestamp? seenAt = data['seenAt'];

                        String time = _formatTimestamp(
                          data['timestamp'] as Timestamp?,
                        );

                        if (isSeen && autoDelete > 0 && seenAt != null) {
                          DateTime seenTime = seenAt.toDate();
                          DateTime deleteTime = seenTime.add(
                            Duration(seconds: autoDelete),
                          );

                          if (DateTime.now().isAfter(deleteTime)) {
                            msg.reference.delete();
                          } else if (!_bombTimers.containsKey(docId)) {
                            Duration remaining = deleteTime.difference(
                              DateTime.now(),
                            );
                            _bombTimers[docId] = Timer(remaining, () {
                              msg.reference.delete();
                              _bombTimers.remove(docId);
                            });
                          }
                        }

                        return GestureDetector(
                          onLongPressStart: (details) => _showMessageMenu(
                            context,
                            details.globalPosition,
                            docId,
                            data['text'],
                            isMe,
                          ),
                          child: Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 14,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isMe
                                      ? [
                                          const Color(0xFF007A5E),
                                          const Color(0xFF005944),
                                        ]
                                      : [
                                          const Color(0xFF2C2C2C),
                                          const Color(0xFF1E1E1E),
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isMe
                                      ? const Radius.circular(16)
                                      : const Radius.circular(4),
                                  bottomRight: isMe
                                      ? const Radius.circular(4)
                                      : const Radius.circular(16),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x4D000000),
                                    blurRadius: 4,
                                    offset: Offset(1, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (replyText != null)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black38,
                                        borderRadius: BorderRadius.circular(8),
                                        border: const Border(
                                          left: BorderSide(
                                            color: Colors.greenAccent,
                                            width: 4,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        replyText,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),

                                  if (imageBase64 != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.memory(
                                          base64Decode(imageBase64),
                                          width: 200,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),

                                  if (data['text'] != '📸 Photo')
                                    Text(
                                      data['text'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),

                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (autoDelete > 0)
                                        const Icon(
                                          Icons.timer,
                                          color: Colors.redAccent,
                                          size: 10,
                                        ),
                                      if (autoDelete > 0)
                                        const SizedBox(width: 4),
                                      if (isEdited)
                                        const Text(
                                          "Edited • ",
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      Text(
                                        time,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10,
                                        ),
                                      ),
                                      if (isMe) const SizedBox(width: 4),
                                      if (isMe)
                                        Icon(
                                          isSeen ? Icons.done_all : Icons.check,
                                          size: 14,
                                          color: isSeen
                                              ? Colors.lightBlueAccent
                                              : Colors.white54,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              if (_replyingTo != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: const Color(0xFF1A1A1A),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.reply,
                        color: Colors.greenAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Replying to: ${_replyingTo!['text']}",
                          style: const TextStyle(color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _replyingTo = null),
                      ),
                    ],
                  ),
                ),

              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: const BoxDecoration(color: Color(0xFF1A1A1A)),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white54,
                      ),
                      onPressed: _showImageSourceMenu,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        onChanged: _updateTypingStatus,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (value) => sendMessage(),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _editingDocId != null
                              ? "Edit message..."
                              : "Message...",
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF2C2C2C),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFF007A5E),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _editingDocId != null ? Icons.check : Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double val = (_controller.value * 2 * math.pi) - (index * 1.0);
            double y = (math.sin(val) * 3).clamp(-3.0, 3.0);
            return Transform.translate(
              offset: Offset(0, y),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.circle, color: Colors.greenAccent, size: 5),
              ),
            );
          },
        );
      }),
    );
  }
}
