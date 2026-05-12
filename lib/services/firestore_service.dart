import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../models/user_profile.dart';

class FirestoreService {
  static final FirestoreService instance = FirestoreService._();
  FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _conversations(String uid) =>
      _userDoc(uid).collection('conversations');

  CollectionReference<Map<String, dynamic>> _messages(
          String uid, String conversationId) =>
      _conversations(uid).doc(conversationId).collection('messages');

  // Profile operations.

  Future<UserProfile> ensureProfile({
    required String uid,
    required String email,
  }) async {
    final ref = _userDoc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      final profile =
          UserProfile(uid: uid, email: email, createdAt: DateTime.now());
      await ref.set(profile.toMap());
      return profile;
    }
    final data = snap.data() ?? const {};
    return UserProfile.fromMap(uid, {...data, 'email': data['email'] ?? email});
  }

  Stream<UserProfile?> watchProfile(String uid) =>
      _userDoc(uid).snapshots().map((s) {
        if (!s.exists) return null;
        return UserProfile.fromMap(uid, s.data() ?? const {});
      });

  Future<void> updateProfile(UserProfile profile) async {
    await _userDoc(profile.uid).set(profile.toMap(), SetOptions(merge: true));
  }

  // Conversation operations.

  Stream<List<Conversation>> watchConversations(String uid) =>
      _conversations(uid)
          .orderBy('lastMessageAt', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map((d) => Conversation.fromMap(d.id, d.data()))
              .toList());

  Future<Conversation> createConversation({
    required String uid,
    String title = 'New chat',
  }) async {
    final now = DateTime.now();
    final doc = _conversations(uid).doc();
    final conv = Conversation(
      id: doc.id,
      title: title,
      createdAt: now,
      lastMessageAt: now,
    );
    await doc.set(conv.toMap());
    return conv;
  }

  Future<void> renameConversation({
    required String uid,
    required String conversationId,
    required String title,
  }) async {
    await _conversations(uid).doc(conversationId).update({'title': title});
  }

  Future<void> deleteConversation({
    required String uid,
    required String conversationId,
  }) async {
    final messages = await _messages(uid, conversationId).get();
    final batch = _db.batch();
    for (final d in messages.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_conversations(uid).doc(conversationId));
    await batch.commit();
  }

  Future<void> _touchConversation({
    required String uid,
    required String conversationId,
    required String preview,
  }) async {
    await _conversations(uid).doc(conversationId).update({
      'lastMessageAt': Timestamp.fromDate(DateTime.now()),
      'lastMessagePreview': preview,
    });
  }

  // Message operations within a single conversation.

  Stream<List<ChatMessage>> watchMessages({
    required String uid,
    required String conversationId,
  }) =>
      _messages(uid, conversationId)
          .orderBy('createdAt')
          .snapshots()
          .map((s) =>
              s.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList());

  Future<ChatMessage> addMessage({
    required String uid,
    required String conversationId,
    required MessageRole role,
    required String text,
  }) async {
    final doc = _messages(uid, conversationId).doc();
    final msg = ChatMessage(
      id: doc.id,
      role: role,
      text: text,
      createdAt: DateTime.now(),
    );
    await doc.set(msg.toMap());
    await _touchConversation(
      uid: uid,
      conversationId: conversationId,
      preview: text.length > 80 ? '${text.substring(0, 80)}…' : text,
    );
    return msg;
  }
}
