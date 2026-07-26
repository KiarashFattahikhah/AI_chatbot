import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ChatbotModel {
  int? id;
  String message;
  String sender;
  String? imagePath;

  ChatbotModel({
    this.id,
    required this.message,
    required this.sender,
    this.imagePath,
  });
}

class Chatbot {
  final String apiKey;
  Chatbot(this.apiKey);

  Future<String> sendMessage(String message, {File? image}) async {
    final String apiUrl =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=$apiKey";

    // Build the parts list: text is always included, image is added if present
    final List<Map<String, dynamic>> parts = [];

    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = _mimeTypeFromPath(image.path);

      parts.add({
        "inline_data": {
          "mime_type": mimeType,
          "data": base64Image,
        }
      });
    }

    // Always include text, even if empty, so Gemini has a prompt to act on
    parts.add({"text": message.isEmpty ? "Describe this image." : message});

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {"parts": parts}
        ],
        "generationConfig": {
          "temperature": 0.5,
          "maxOutputTokens": 2000,
        }
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      var finalResponse =
          jsonResponse['candidates'][0]['content']['parts'][0]['text'].toString();
      return finalResponse;
    } else {
      print("API Error: ${response.body}");
      throw Exception('API Error: ${response.body}');
    }
  }

  String _mimeTypeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}