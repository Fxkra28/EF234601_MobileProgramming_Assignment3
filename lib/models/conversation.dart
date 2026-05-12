import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastMessageAt,
    this.lastMessagePreview,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final String? lastMessagePreview;

  Map<String, dynamic> toMap() => {
        'title': title,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastMessageAt': Timestamp.fromDate(lastMessageAt),
        'lastMessagePreview': lastMessagePreview,
      };

  factory Conversation.fromMap(String id, Map<String, dynamic> m) {
    return Conversation(
      id: id,
      title: (m['title'] ?? 'New chat') as String,
      createdAt: (m['createdAt'] is Timestamp)
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastMessageAt: (m['lastMessageAt'] is Timestamp)
          ? (m['lastMessageAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastMessagePreview: m['lastMessagePreview'] as String?,
    );
  }
}
