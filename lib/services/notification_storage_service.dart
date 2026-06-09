import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalNotificationModel {
  final String id;
  final String title;
  final String body;
  final String timestamp;
  final String? imageUrl;
  final Map<String, dynamic> payload;

  LocalNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.imageUrl,
    required this.payload,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'timestamp': timestamp,
    'imageUrl': imageUrl,
    'payload': payload,
  };

  factory LocalNotificationModel.fromJson(Map<String, dynamic> json) =>
      LocalNotificationModel(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        timestamp: json['timestamp'] ?? '',
        imageUrl: json['imageUrl'],
        payload: json['payload'] ?? {},
      );
}

class NotificationStorageService {
  static const String _storageKey = 'saved_notifications_list';

  // Save incoming RemoteMessage into Local Storage
  static Future<void> saveNotification(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> existingData = prefs.getStringList(_storageKey) ?? [];

    String? imageUrl = message.notification?.android?.imageUrl ??
        message.notification?.apple?.imageUrl ??
        message.data['image'];

    final newNotification = LocalNotificationModel(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? 'အကြောင်းကြားစာ',
      body: message.notification?.body ?? '',
      timestamp: DateTime.now().toIso8601String(),
      imageUrl: imageUrl,
      payload: message.data,
    );

    existingData.insert(0, jsonEncode(newNotification.toJson())); // Newest first
    await prefs.setStringList(_storageKey, existingData);
  }

  // Fetch all stored notifications
  static Future<List<LocalNotificationModel>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> cachedList = prefs.getStringList(_storageKey) ?? [];

    return cachedList.map((item) {
      return LocalNotificationModel.fromJson(jsonDecode(item));
    }).toList();
  }

  // Clear all history
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}