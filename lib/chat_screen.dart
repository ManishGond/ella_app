import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:toast/toast.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool isServerOnline = false;
  bool isLoading = false;
  File? _image;
  String _response = '';

  Future _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
        _handleSubmitted('image'); // Add the image path as user message
        uploadImage();
      }
    });
  }

  Future uploadImage() async {
    if (_image == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Error"),
          content: const Text("Please select an image first."),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }
    var request = http.MultipartRequest(
        'POST', Uri.parse('http://192.168.40.60:5000/upload')); // Updated URL

    request.files.add(await http.MultipartFile.fromPath('file', _image!.path));

    try {
      var response = await request.send();
      var responseData = await response.stream.toBytes();
      var responseString = utf8.decode(responseData);
      setState(() {
        _response = responseString;
        _handleSubmitted(_response);
      });
    } catch (e) {
      print(e.toString());
      setState(() {
        _response = 'Error: $e';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkServerStatus();
    });
  }

  Future<void> _checkServerStatus() async {
    try {
      final response = await http
          .get(
            Uri.parse('http://192.168.40.60:5000/status'), //TODO
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
  int currentImageIndex = 1;

  @override
  Widget build(BuildContext context) {
    ToastContext().init(context);
    return Scaffold(
      appBar: AppBar(
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
                    onPressed: _pickImage,
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
      Toast.show("Text field is empty", duration: 2, gravity: Toast.bottom);
      return;
    }

    _textController.clear();
    ChatMessage message;

    // Check if the text is valid JSON
    if (_isValidJson(text)) {
      _simulateChatbotResponse(text);
      return;
    } else {
      // If it's not valid JSON, treat it as a regular user message
      message = ChatMessage(
        text: text,
        isUser: true,
        image: text == 'image' ? _image : null,
      );
    }

    setState(() {
      _messages.insert(0, message);
    });

    if (text == 'image') {
      // Don't call _simulateChatbotResponse for image messages
      return;
    }
    _simulateChatbotResponse(text);
  }

  bool _isValidJson(String text) {
    try {
      jsonDecode(text);
      return true;
    } catch (_) {
      return false;
    }
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

      String apiResponse;

      // Check if userMessage is a JSON string
      try {
        final decodedJson = json.decode(userMessage);
        apiResponse = decodedJson['response'] as String;
      } catch (e) {
        // If parsing fails, get the actual chatbot response
        apiResponse = await getChatbotResponse(userMessage);
      }

      // Remove the typing indicator and add the real response
      setState(() {
        _messages.removeAt(0);
        ChatMessage imageMessage = ChatMessage(
          text: apiResponse,
          isUser: false,
        );
        _messages.insert(0, imageMessage);
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
        Uri.parse('http://192.168.40.60:5000/chat'), //TODO
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)["response"];
      } else {
        throw Exception('Sorry, I don\'t understand.');
      }
    } catch (e) {
      throw Exception('An error occurred: $e');
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
  final File? image;

  const ChatMessage(
      {Key? key, required this.text, required this.isUser, this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          if (image != null) // Render the image if available
            Image.file(
              image!,
              height: 150.0,
              width: 150.0,
              fit: BoxFit.cover,
            ),
          if (text.isNotEmpty && text != 'image')
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
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                ),
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
}
