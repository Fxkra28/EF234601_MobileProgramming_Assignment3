import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String? displayName;
  final DateTime? createdAt;

  UserProfile copyWith({String? displayName}) => UserProfile(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'createdAt':
            createdAt == null ? Timestamp.now() : Timestamp.fromDate(createdAt!),
      };

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    final created = map['createdAt'];
    return UserProfile(
      uid: uid,
      email: (map['email'] ?? '') as String,
      displayName: map['displayName'] as String?,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
