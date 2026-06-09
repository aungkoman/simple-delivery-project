import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';


import '../services/notification_storage_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<LocalNotificationModel> _notifications = [];
  int _unreadCount = 0;

  List<LocalNotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  // Initialize and load historical entries from storage
  Future<void> loadNotifications() async {
    _notifications = await NotificationStorageService.getNotifications();
    // Assuming you have an 'isRead' tracker or calculating based on unread session count.
    // For a clean start, we can manage unread counts via a local counter variable or storage key.
    notifyListeners();
  }

  // Handle a newly arrived notification
  Future<void> handleNewNotification(RemoteMessage message) async {
    await NotificationStorageService.saveNotification(message);
    _unreadCount++;
    await loadNotifications(); // Refresh the list array
  }

  // Reset the unread counter when the user opens the list view hub
  void clearUnreadCount() {
    _unreadCount = 0;
    notifyListeners();
  }

  // Clear everything out completely
  Future<void> clearAllNotifications() async {
    await NotificationStorageService.clearAll();
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }
}