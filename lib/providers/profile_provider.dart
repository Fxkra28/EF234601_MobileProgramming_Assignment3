import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../services/firestore_service.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider(this._uid) {
    if (_uid != null) {
      _bootstrap();
    }
  }

  final String? _uid;
  final FirestoreService _cloud = FirestoreService.instance;
  StreamSubscription<UserProfile?>? _sub;
  UserProfile? _profile;
  String? _bootstrapError;

  UserProfile? get profile => _profile;
  String? get bootstrapError => _bootstrapError;

  Future<void> retry() => _bootstrap();

  Future<void> _bootstrap() async {
    _bootstrapError = null;
    notifyListeners();
    try {
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      _profile = await _cloud.ensureProfile(uid: _uid!, email: email);
      debugPrint('[ProfileProvider] ensured profile for $_uid');
    } catch (e) {
      _bootstrapError = e.toString();
      debugPrint('[ProfileProvider] ensureProfile failed: $e');
    }
    notifyListeners();
    _subscribe();
  }

  void _subscribe() {
    _sub = _cloud.watchProfile(_uid!).listen((p) {
      _profile = p ?? _profile;
      notifyListeners();
    });
  }

  Future<void> updateDisplayName(String name) async {
    if (_profile == null) return;
    await _cloud.updateProfile(_profile!.copyWith(displayName: name));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
