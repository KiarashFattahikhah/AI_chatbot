import "package:ai_chatbot/api_service.dart";
import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:permission_handler/permission_handler.dart";
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:ai_chatbot/db/chat_database.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ai_chatbot/auth/auth_service.dart';
import 'package:ai_chatbot/pages/sign_in_page.dart';
import 'package:ai_chatbot/pages/sign_up_page.dart';


class ChatbotScreen extends StatefulWidget {
  // 1. Add parameters to accept the theme state and callback
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;

  const ChatbotScreen({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  // In a real app, replace `apiKey` with your actual key.
  final Chatbot _chatbot = Chatbot('Enter your apiKey');
  final TextEditingController chatController = TextEditingController();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;

  List<ChatbotModel> chatList = [];

  bool isLoading = false;

  int? _currentChatId;
  List<Map<String, dynamic>> _chatHistory = [];

  final ImagePicker _picker = ImagePicker();
  File? _pickedImage;

  String _currentUsername = '';
  String _currentEmail = '';

  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initApp();
  }

  Future<void> _initApp() async {
    await _loadCurrentUser();
    await _loadOrCreateChat();
  }

  Future<void> _loadCurrentUser() async {
    final userId = await AuthService.getCurrentUserId();
    if (userId == null) return;

    final user = await ChatDatabase.instance.getUserById(userId);
    if (user != null) {
      setState(() {
        _currentUserId = userId;
        _currentUsername = user['username'] as String;
        _currentEmail = user['email'] as String;
      });
    }
  }

  Future<void> _loadOrCreateChat() async {
    if (_currentUserId == null) return;

    final chats = await ChatDatabase.instance.getAllChats(_currentUserId!);
    setState(() => _chatHistory = chats);

    if (chats.isNotEmpty) {
      await _openChat(chats.first['id'] as int);
    } else {
      await _startNewChat();
    }
  }

  Future<void> _startNewChat() async {
    if (_currentUserId == null) return;

    final id = await ChatDatabase.instance.createChat('New chat', _currentUserId!);
    final chats = await ChatDatabase.instance.getAllChats(_currentUserId!);
    setState(() {
      _currentChatId = id;
      chatList = [];
      _chatHistory = chats;
    });
  }

  Future<void> _openChat(int chatId) async {
    final rows = await ChatDatabase.instance.getMessages(chatId);
    setState(() {
      _currentChatId = chatId;
      chatList = rows
          .map((r) => ChatbotModel(
                id: r['id'] as int,
                message: r['message'] as String,
                sender: r['sender'] as String,
                imagePath: r['imagePath'] as String?, 
              ))
          .toList();
    });
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );

    if (file == null) return;

    // Copy into permanent app storage so it survives cache clears
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/chat_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final savedImage = await File(file.path).copy('${imagesDir.path}/$fileName');

    setState(() => _pickedImage = savedImage);
  }

  Future<void> _openChatSearch() async {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> results = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // lets it grow with keyboard open
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search chats and messages...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (query) async {
                        if (query.trim().isEmpty) {
                          setModalState(() => results = []);
                          return;
                        }
                        final found = await ChatDatabase.instance.searchChats(query.trim(), _currentUserId!);
                        setModalState(() => results = found);
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: results.isEmpty
                          ? Center(
                              child: Text(
                                searchController.text.isEmpty
                                    ? 'Start typing to search'
                                    : 'No results found',
                                style: Theme.of(ctx).textTheme.bodyMedium,
                              ),
                            )
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (context, index) {
                                final chat = results[index];
                                return ListTile(
                                  leading: const Icon(Icons.chat_bubble_outline),
                                  title: Text(chat['title'] as String),
                                  subtitle: Text(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      chat['createdAt'] as int,
                                    ).toString(),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    await _openChat(chat['id'] as int);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _initSpeech() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
  
    if (!status.isGranted) {
      debugPrint('Microphone permission denied');
      setState(() => _speechAvailable = false);
      return;
    }
  
    _speechAvailable = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status: $status'),
      onError: (error) => debugPrint('Speech error: ${error.errorMsg}'),
    );
    setState(() {});
  }

  void _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          chatController.text = result.recognizedWords;
          chatController.selection = TextSelection.fromPosition(
            TextPosition(offset: chatController.text.length),
          );
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    chatController.dispose();
    super.dispose();
  }

  // Re-creating the logo color definitions for easier use within the state
  static const Color kDarkNavy = Color(0xFF0D1B2A);
  static const Color kTextGrey = Color(0xFF7F8C8D);
  static const LinearGradient kBotBubbleGradient = LinearGradient(
    colors: [Color(0xFF4A90E2), Color(0xFFF5A623)],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  void send(String message) async {
    if (message.trim().isEmpty && _pickedImage == null) return;
    if (_currentChatId == null) return;

    final imageToSend = _pickedImage;
    chatController.clear();
    isLoading = true;
    setState(() {
      chatList.add(ChatbotModel(
        message: message,
        sender: 'User',
        imagePath: imageToSend?.path,
      ));
      _pickedImage = null; // clear preview immediately
    });

    await ChatDatabase.instance.insertMessage(
      chatId: _currentChatId!,
      message: message,
      sender: 'User',
      imagePath: imageToSend?.path,
    );

    if (chatList.length == 1) {
      final title = message.isNotEmpty
          ? (message.length > 30 ? '${message.substring(0, 30)}…' : message)
          : 'Image chat';
      await ChatDatabase.instance.renameChat(_currentChatId!, title);
      final chats = await ChatDatabase.instance.getAllChats(_currentUserId!);
      setState(() => _chatHistory = chats);
    }

    final response = await _chatbot.sendMessage(message, image: imageToSend);

    setState(() {
      isLoading = false;
      chatList.add(ChatbotModel(message: response, sender: 'Bot'));
    });

    await ChatDatabase.instance.insertMessage(
      chatId: _currentChatId!,
      message: response,
      sender: 'Bot',
    );
  }

  void _openImageGallery() async {
    final images = await ChatDatabase.instance.getAllImages(_currentUserId!);
  
    if (!mounted) return;
  
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Images (${images.length})',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: images.isEmpty
                    ? const Center(child: Text('No images sent yet'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(8.0),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          final img = images[index];
                          final path = img['imagePath'] as String;
                          final chatId = img['chatId'] as int;
  
                          return GestureDetector(
                            onTap: () async {
                              Navigator.pop(ctx);
                              await _openChat(chatId); // jump to that conversation
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(path),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel, style: TextStyle(color: isDestructive ? Colors.red : null)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 2. Access the current theme data
    final themeData = Theme.of(context);
    final isDarkMode = themeData.brightness == Brightness.dark;

    return SafeArea(
      child: Scaffold(
        backgroundColor: themeData.colorScheme.background,
        appBar: AppBar(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(12.0))),
          title: Text('AURA CHAT'),
          centerTitle: true,
          actions: [
            // 3. Add the Theme Toggle Button to actions:[]
            IconButton(
              icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () {
                widget.onThemeChanged(!widget.isDark);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: chatList.isEmpty ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Icon(Icons.chat_bubble_outline, size: 60.0, color: themeData.colorScheme.primary),
                  Text('Empty!', style: themeData.textTheme.titleMedium,),
                ],) :
                Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: chatList.length,
                        itemBuilder: (context, index) {
                          final chatItem = chatList[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(12.0),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: chatItem.message.trim())).then((value){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied')));});
                            },
                            child: Container(
                              margin: EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.0),
                                
                                // 4. Apply BRANDED colors to chat bubbles
                                color: chatItem.sender == 'User'
                                  // User bubble: light/dark variant surface
                                  ? themeData.colorScheme.surfaceVariant
                                  : null, // We handle the bot bubble with a gradient below

                                gradient: chatItem.sender == 'Bot'
                                  // Bot bubble: UNIQUE Translucent Gradient from logo
                                  ? kBotBubbleGradient.mapGradient((color) => color.withOpacity(0.8))
                                  : null,
                              ),
                              child: ListTile(
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (chatItem.imagePath != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 6.0),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(File(chatItem.imagePath!), fit: BoxFit.cover),
                                        ),
                                      ),
                                    SelectableText(chatItem.message.trim()),
                                  ],
                                ),
                                leading: chatItem.sender == 'User'
                                    ? Icon(Icons.person, color: isDarkMode ? Colors.white70 : kDarkNavy)
                                    : Icon(Icons.bolt_rounded, color: isDarkMode ? Colors.white : kBotBubbleGradient.colors[0]),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    isLoading ? Container(
                      margin: EdgeInsets.only(bottom: 16.0),
                      child: CupertinoActivityIndicator(color: themeData.colorScheme.primary)
                    ) : SizedBox(),
                  ],
                ),
              ),

              if (_pickedImage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_pickedImage!, width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: IconButton(
                            icon: const Icon(Icons.cancel, size: 20),
                            onPressed: () => setState(() => _pickedImage = null),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  onSubmitted: send,
                  controller: chatController,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    icon: IconButton(
                      onPressed: _toggleListening,
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.keyboard_voice,
                        color: _isListening
                            ? Colors.redAccent
                            : (isDarkMode ? Colors.white70 : kTextGrey),
                      ),
                    ),
                    prefixIcon: IconButton(
                      onPressed: _pickImage,
                      icon: Icon(Icons.add, color: themeData.colorScheme.primary),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        send(chatController.text);
                      }, 
                      icon: Icon(Icons.send),
                      color: isDarkMode ? Colors.white : kBotBubbleGradient.colors[0],
                    ),
                    hintText: 'Type your message here ...'
                  ),
                ),
              ),
            ],
          ),
        ),
        drawer: Drawer(
          child: ListView(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[900] : kDarkNavy,
                ),
                child: UserAccountsDrawerHeader(
                  currentAccountPictureSize: Size.square(50.0),
                  currentAccountPicture: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: CircleAvatar(
                      backgroundColor: isDarkMode ? Color(0xFF1A1A1A) : Colors.white,
                      child: Text(
                        _currentUsername.isNotEmpty ? _currentUsername[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 20, color: isDarkMode ? Colors.white : kDarkNavy),
                      ),
                    ),
                  ),
                  decoration: BoxDecoration(color: Colors.transparent),
                  accountName: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      _currentUsername,
                      style: TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  ),
                  accountEmail: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      _currentEmail,
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.chat, color: isDarkMode ? Colors.white70 : kDarkNavy),
                title: Text('New chat'),
                onTap: () async {
                  Navigator.pop(context); // close drawer
                  await _startNewChat();
                },
              ),
              ListTile(
                leading: Icon(Icons.search, color: isDarkMode ? Colors.white70 : kDarkNavy),
                title: Text('Search chats'),
                onTap: () {
                  Navigator.pop(context); // close drawer first
                  _openChatSearch();
                },
              ),
              ListTile(
                leading: Icon(Icons.history, color: isDarkMode ? Colors.white70 : kDarkNavy),
                title: Text('Chat history'),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    builder: (ctx) => ListView(
                      children: _chatHistory.map((c) {
                        return ListTile(
                          title: Text(c['title'] as String),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await ChatDatabase.instance.deleteChat(c['id'] as int);
                              final chats = await ChatDatabase.instance.getAllChats(_currentUserId!);
                              setState(() => _chatHistory = chats);
                              Navigator.pop(ctx);
                            },
                          ),
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _openChat(c['id'] as int);
                          },
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.image, color: isDarkMode ? Colors.white70 : kDarkNavy),
                title: Text('Images'),
                onTap: () {
                  Navigator.pop(context);
                  _openImageGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.logout, color: isDarkMode ? Colors.white70 : kDarkNavy),
                title: Text('Log out'),
                onTap: () async {
                  final confirmed = await _showConfirmDialog(
                    title: 'Log out?',
                    message: 'Are you sure you want to log out?',
                    confirmLabel: 'Log out',
                  );
                  if (confirmed == true) {
                    await AuthService.clearSession();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => SignInPage(isDark: widget.isDark, onThemeChanged: widget.onThemeChanged),
                      ),
                      (route) => false,
                    );
                  }
                },
              ),
              TextButton(
                onPressed: () async {
                  final confirmed = await _showConfirmDialog(
                    title: 'Delete account?',
                    message: 'This will permanently delete your account. This cannot be undone.',
                    confirmLabel: 'Delete',
                    isDestructive: true,
                  );
                  if (confirmed == true) {
                    final userId = await AuthService.getCurrentUserId();
                    if (userId != null) {
                      await ChatDatabase.instance.deleteAllChatsForUser(userId); 
                      await ChatDatabase.instance.deleteUser(userId);
                    }
                    await AuthService.clearSession();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => SignUpPage(isDark: widget.isDark, onThemeChanged: widget.onThemeChanged),
                      ),
                      (route) => false,
                    );
                  }
                },
                child: Text('Delete account', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper extension to make defining gradients with opacity easier
extension LinearGradientExtension on LinearGradient {
  LinearGradient mapGradient(Color Function(Color) colorMapper) {
    return LinearGradient(
      colors: colors.map(colorMapper).toList(),
      stops: stops,
      begin: begin,
      end: end,
    );
  }
}