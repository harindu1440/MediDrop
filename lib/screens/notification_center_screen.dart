import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../services/notifications_service.dart';
import '../firebase_operations.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final List<Map<String, dynamic>> notifications = [];
  StreamSubscription<DatabaseEvent>? _notificationsSubscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupNotificationsListener();
  }

  /// Set up real-time listener for notification database changes
  void _setupNotificationsListener() {
    try {
      final ref = FirebaseDatabase.instance.ref('notifications');
      _notificationsSubscription = ref.onValue.listen((event) {
        // On any change to notifications, reload the list
        _loadNotifications();
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error setting up notifications listener: $e');
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await FirebaseOperations.readData('notifications');
      notifications.clear();
      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            notifications.add({
              'dbId': key,
              'title': value['title'] ?? '',
              'message': value['message'] ?? '',
              'time': value['timestamp'] ?? '',
              'localId': value['localId'],
            });
          }
        });
        // sort by timestamp desc when possible
        notifications.sort((a, b) {
          final ta =
              DateTime.tryParse(a['time'] ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final tb =
              DateTime.tryParse(b['time'] ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return tb.compareTo(ta);
        });
      }
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      // ignore: avoid_print
      print('Error loading notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(icon: const Icon(Icons.clear_all), onPressed: _clearAll),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 18),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: notifications.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return _buildNotificationCard(notif);
              },
            ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: notif['read'] ? Colors.white : Colors.blue.shade50,
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              notif['title'].split(' ')[0],
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Text(
          notif['title'],
          style: TextStyle(
            fontWeight: (notif['read'] ?? false)
                ? FontWeight.normal
                : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notif['message']),
            const SizedBox(height: 4),
            Text(
              notif['time'],
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmAndRemove(notif),
        ),
      ),
    );
  }

  Future<void> _confirmAndRemove(Map<String, dynamic> notif) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Notification'),
        content: const Text('Remove this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      final dbId = notif['dbId']?.toString();
      final localId = notif['localId'] is num
          ? (notif['localId'] as num).toInt()
          : null;
      if (dbId != null) {
        await _removeNotificationByDbId(dbId, localId: localId);
      } else {
        // fallback: remove by title/message match
        if (!mounted) return;
        setState(() {
          notifications.remove(notif);
        });
      }
    }
  }

  Future<void> _removeNotificationByDbId(String dbId, {int? localId}) async {
    try {
      await NotificationsService().clearNotification(dbId, localId: localId);
    } catch (e) {
      // ignore: avoid_print
      print('Error clearing notification $dbId: $e');
    }

    if (!mounted) return;
    setState(() {
      notifications.removeWhere((n) => n['dbId'] == dbId);
    });
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Cancel all local notifications and delete DB notifications
              try {
                await NotificationsService().cancelAllNotifications();
                await FirebaseOperations.deleteData('notifications');
              } catch (e) {
                // ignore: avoid_print
                print('Error clearing all notifications: $e');
              }

              if (mounted) setState(() => notifications.clear());
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
