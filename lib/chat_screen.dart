import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:ella_app/config.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:toast/toast.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  List<Map<String, dynamic>> pdfData = [];
  bool isServerOnline = false;
  bool isCheckingServer = false;
  FilePickerResult? result;
  PlatformFile? pickedFile;
  bool isLoading = false;

  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  File? fileToDisplay;
  final DatabaseReference _databaseReference =
      // ignore: deprecated_member_use
      FirebaseDatabase.instance.reference().child('messages');

  void _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif'],
      type: FileType.custom,
    );

    if (result == null) return;

    final file = result.files.first;

    // Upload the file to Firebase Cloud Storage
    String downloadUrl = await _uploadFile(file);

    // Add the file message to the chat
    String message = 'File Uploaded: $downloadUrl';
    _handleSubmitted(message);

    await _firebaseFirestore.collection("imgs").add({
      "name": _getFileName(downloadUrl),
      "url": downloadUrl,
    });
  }

  Future<String> _uploadFile(PlatformFile file) async {
    try {
      final Reference storageReference =
          FirebaseStorage.instance.ref().child('images/${file.name}');

      final UploadTask uploadTask = storageReference.putFile(File(file.path!));

      // Rest of the code remains the same...

      TaskSnapshot taskSnapshot = await uploadTask;

      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      await _sendToFlaskAPI(downloadUrl);

      return downloadUrl;

      // Rest of the code remains the same...
    } catch (e) {
      // Handle errors and show a toast message if needed
      Toast.show("Error uploading file: $e",
          duration: 5, gravity: Toast.bottom);
      return 'Error uploading file: $e';
    }
  }

  Future<void> _sendToFlaskAPI(String imageUrl) async {
    try {
      final response = await http.post(
        Uri.parse('YOUR_FLASK_API_URL'), // Replace with your Flask API URL
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'imageUrl': imageUrl}),
      );

      if (response.statusCode == 200) {
        // Handle success if needed
      } else {
        // Handle error if needed
        print('Error in Flask API response: ${response.body}');
      }
    } catch (e) {
      // Handle errors if needed
      print('Error sending to Flask API: $e');
    }
  }

// Function to handle file upload and show toast message
  void _handleFileUpload(String downloadUrl) {
    // Display a toast message for the filename
    Toast.show("File Uploaded: ${_getFileName(downloadUrl)}",
        duration: 5, gravity: Toast.bottom);
  }

// Function to extract filename from the URL
  String _getFileName(String downloadUrl) {
    Uri uri = Uri.parse(downloadUrl);
    return uri.pathSegments.last;
  }

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkServerStatus();
    });
    _databaseReference.onChildAdded.listen((event) {
      Map<String, dynamic> data =
          Map<String, dynamic>.from(event.snapshot.value as Map);
      String text = data['text'];
      bool isUser = data['isUser'];

      ChatMessage message = ChatMessage(
        text: text,
        isUser: isUser,
      );

      setState(() {
        _messages.insert(0, message);
      });
    });
  }

  Future<void> _checkServerStatus() async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.serverUrl}/status'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          isServerOnline = true;
        });
      } else {
        setState(() {
          isServerOnline = false;
        });
      }
    } catch (e) {
      setState(() {
        isServerOnline = false;
      });
    }
  }

  List<String> backgroundImages = [
    'images/background1.png',
    'images/background2.png',
    'images/background3.png',
    'images/background4.png',
    'images/background5.png',
    'images/background6.png',
  ];
  int currentImageIndex = 3;

  @override
  Widget build(BuildContext context) {
    ToastContext().init(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'ELLA',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8.0),
            Container(
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: isServerOnline ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                isServerOnline ? 'Online' : 'Offline',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.0,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.image_search),
            onPressed: _changeBackgroundImage,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(backgroundImages[currentImageIndex]),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _messages[index];
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(
                      Icons.add,
                      color: Colors.pink,
                    ),
                    onPressed: _pickFile, // Handle file upload
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0),
                        child: TextField(
                          controller: _textController,
                          decoration: const InputDecoration(
                            hintText: 'Ask me anything...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.pink),
                    onPressed: () {
                      _handleSubmitted(_textController.text);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  final ScrollController _scrollController = ScrollController();

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) {
      Toast.show("Text field is empty 😂", duration: 2, gravity: Toast.bottom);
      return;
    }

    _textController.clear();
    ChatMessage message = ChatMessage(
      text: text,
      isUser: true,
    );
    setState(() {
      _messages.insert(0, message);
    });

    _simulateChatbotResponse(text);
    _scrollController.animateTo(
      0.0,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _simulateChatbotResponse(String userMessage) async {
    try {
      // Show a typing indicator or loading state
      ChatMessage typingIndicator = const ChatMessage(
        text: 'Thinking....',
        isUser: false,
      );

      setState(() {
        _messages.insert(0, typingIndicator);
      });

      // Simulate a delay or loading time (you can adjust the duration)
      await Future.delayed(const Duration(seconds: 3));

      // Get the actual chatbot response
      String apiResponse = await getChatbotResponse(userMessage);

      // Remove the typing indicator and add the real response
      setState(() {
        _messages.removeAt(0);
        ChatMessage message = ChatMessage(
          text: apiResponse,
          isUser: false,
        );
        _messages.insert(0, message);
      });

      _scrollController.animateTo(
        0.0,
        curve: Curves.easeOut,
        duration: const Duration(milliseconds: 300),
      );
    } catch (e) {
      // Handle errors
      if (kDebugMode) {
        print('Error in chatbot API response: $e');
      }
      ChatMessage errorMessage = const ChatMessage(
        text: 'Ella is sleeping at the moment Zzzz',
        isUser: false,
      );

      setState(() {
        _messages.removeAt(0);
        _messages.insert(0, errorMessage);
      });

      _scrollController.animateTo(
        0.0,
        curve: Curves.easeOut,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  Future<String> getChatbotResponse(String message) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)["response"];
      } else {
        throw Exception('Sorry I dont understand :(');
      }
    } catch (e) {
      throw Exception('');
    }
  }

  void _changeBackgroundImage() {
    setState(() {
      currentImageIndex = (currentImageIndex + 1) % backgroundImages.length;
    });
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatMessage({super.key, required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8.0),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            decoration: BoxDecoration(
              color: isUser ? Colors.blue : Colors.red.shade300,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isUser ? 12.0 : 0.0),
                topRight: Radius.circular(isUser ? 0.0 : 12.0),
                bottomLeft: const Radius.circular(12.0),
                bottomRight: const Radius.circular(12.0),
              ),
            ),
            child: Column(
              children: [
                if (text.startsWith(
                    'File Uploaded:')) // Check if it's a file message
                  _buildFileMessage(text),
                if (!text.startsWith('File Uploaded:'))
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            isUser ? 'You' : 'Ella',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileMessage(String text) {
    // Parse the download URL from the message
    String downloadUrl = text.substring('File Uploaded: '.length);

    // Use Uri class to parse the download URL
    Uri uri = Uri.parse(downloadUrl);

    // Extract filename from the URL
    String fileName = uri.pathSegments.last;

    if (fileName.startsWith('imgs/')) {
      fileName = fileName.substring('imgs/'.length);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () async {
            openBrowserURL(url: uri, inApp: true);
          },
          child: Container(
            height: 100, // Adjust the height as needed
            width: 100, // Adjust the width as needed
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'images/imageIcon.png'), // Replace with your PDF thumbnail
                fit: BoxFit.fill,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          fileName, // Display the filename
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.0,
          ),
        ),
        // Display a toast message for successful upload
        const SizedBox(height: 8.0),
      ],
    );
  }

  Future openBrowserURL({required Uri url, bool inApp = false}) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
      );
    }
  }
}
