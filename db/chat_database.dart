import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'dart:convert';
import 'package:crypto/crypto.dart';

String hashPassword(String password) {
  return sha256.convert(utf8.encode(password)).toString();
}

class ChatDatabase {
  static final ChatDatabase instance = ChatDatabase._internal();
  ChatDatabase._internal();

  Database? _db;

  // ---------- Search ----------

  Future<List<Map<String, dynamic>>> searchChats(String query, int userId) async {
    final db = await database;
    final likeQuery = '%$query%';

    return db.rawQuery('''
      SELECT DISTINCT chats.id, chats.title, chats.createdAt
      FROM chats
      LEFT JOIN messages ON messages.chatId = chats.id
      WHERE chats.userId = ?
        AND (chats.title LIKE ? OR messages.message LIKE ?)
      ORDER BY chats.createdAt DESC
    ''', [userId, likeQuery, likeQuery]);
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'aura_chat.db');

    return openDatabase(
      path,
      version: 4, // bumped from 3
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE chats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId INTEGER NOT NULL,
            title TEXT NOT NULL,
            createdAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chatId INTEGER NOT NULL,
            message TEXT NOT NULL,
            sender TEXT NOT NULL,
            imagePath TEXT,
            timestamp INTEGER NOT NULL,
            FOREIGN KEY (chatId) REFERENCES chats (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            email TEXT UNIQUE NOT NULL,
            passwordHash TEXT NOT NULL,
            createdAt INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE messages ADD COLUMN imagePath TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              username TEXT UNIQUE NOT NULL,
              email TEXT UNIQUE NOT NULL,
              passwordHash TEXT NOT NULL,
              createdAt INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          // Add userId, defaulting existing rows to 0 (orphaned/pre-auth data)
          await db.execute('ALTER TABLE chats ADD COLUMN userId INTEGER NOT NULL DEFAULT 0');
        }
      },
    );
  }

  // ---------- Chats ----------

  Future<int> createChat(String title, int userId) async {
    final db = await database;
    return db.insert('chats', {
      'userId': userId,
      'title': title,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getAllChats(int userId) async {
    final db = await database;
    return db.query('chats', where: 'userId = ?', whereArgs: [userId], orderBy: 'createdAt DESC');
  }

  Future<void> deleteChat(int chatId) async {
    final db = await database;
    await db.delete('chats', where: 'id = ?', whereArgs: [chatId]);
    await db.delete('messages', where: 'chatId = ?', whereArgs: [chatId]);
  }

  Future<void> renameChat(int chatId, String newTitle) async {
    final db = await database;
    await db.update('chats', {'title': newTitle},
        where: 'id = ?', whereArgs: [chatId]);
  }

  // ---------- Messages ----------

  Future<int> insertMessage({
    required int chatId,
    required String message,
    required String sender,
    String? imagePath,
  }) async {
    final db = await database;
    return db.insert('messages', {
      'chatId': chatId,
      'message': message,
      'sender': sender,
      'imagePath': imagePath,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getMessages(int chatId) async {
    final db = await database;
    return db.query(
      'messages',
      where: 'chatId = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );
  }

  // ---------- Images ----------

  Future<List<Map<String, dynamic>>> getAllImages(int userId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT messages.* FROM messages
      INNER JOIN chats ON chats.id = messages.chatId
      WHERE chats.userId = ? AND messages.imagePath IS NOT NULL
      ORDER BY messages.timestamp DESC
    ''', [userId]);
  }

  // ---------- Users ----------

  Future<bool> usernameExists(String username) async {
    final db = await database;
    final rows = await db.query('users', where: 'username = ?', whereArgs: [username]);
    return rows.isNotEmpty;
  }

  Future<bool> emailExists(String email) async {
    final db = await database;
    final rows = await db.query('users', where: 'email = ?', whereArgs: [email]);
    return rows.isNotEmpty;
  }

  Future<int> createUser(String username, String email, String password) async {
    final db = await database;
    return db.insert('users', {
      'username': username,
      'email': email,
      'passwordHash': hashPassword(password),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<Map<String, dynamic>?> validateLogin(String usernameOrEmail, String password) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'username = ? OR email = ?',
      whereArgs: [usernameOrEmail, usernameOrEmail],
    );
    if (rows.isEmpty) return null;
    final user = rows.first;
    return user['passwordHash'] == hashPassword(password) ? user : null;
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<void> deleteUser(int userId) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }

  Future<void> deleteAllChatsForUser(int userId) async {
    final db = await database;
    // Get all chat ids for this user first
    final chats = await db.query('chats', where: 'userId = ?', whereArgs: [userId]);
    for (final chat in chats) {
      await db.delete('messages', where: 'chatId = ?', whereArgs: [chat['id']]);
    }
    await db.delete('chats', where: 'userId = ?', whereArgs: [userId]);
  }
}

