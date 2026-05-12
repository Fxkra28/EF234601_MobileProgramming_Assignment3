import 'package:flutter/foundation.dart';

import '../models/message.dart';
import '../services/camera_service.dart';
import '../services/claude_chat_service.dart';

class CameraProvider extends ChangeNotifier {
  final CameraService _camera = CameraService();
  final ClaudeChatService _claude = ClaudeChatService();

  CapturedImage? _image;
  String _hint = '';
  VisionAnalysis? _result;
  bool _analyzing = false;
  String? _error;
  String? _permissionMessage;

  CapturedImage? get image => _image;
  String get hint => _hint;
  VisionAnalysis? get result => _result;
  bool get analyzing => _analyzing;
  String? get error => _error;
  String? get permissionMessage => _permissionMessage;

  void setHint(String h) {
    _hint = h;
  }

  Future<void> takePhoto() async {
    _permissionMessage = null;
    final img = await _camera.takePhoto();
    if (img == null) {
      _permissionMessage =
          'Camera permission is required. Enable it in Settings to use this feature.';
      notifyListeners();
      return;
    }
    _image = img;
    _result = null;
    _error = null;
    notifyListeners();
  }

  Future<void> pickFromGallery() async {
    _permissionMessage = null;
    final img = await _camera.pickFromGallery();
    if (img == null) {
      _permissionMessage =
          'Photo library permission is required. Enable it in Settings to use this feature.';
      notifyListeners();
      return;
    }
    _image = img;
    _result = null;
    _error = null;
    notifyListeners();
  }

  Future<void> analyze() async {
    final img = _image;
    if (img == null) return;
    _analyzing = true;
    _error = null;
    _result = null;
    notifyListeners();
    try {
      _result = await _claude.analyzeImage(
        imageBytes: img.bytes,
        mediaType: img.mediaType,
        userHint: _hint,
      );
    } catch (e) {
      _error = _humanize(e);
    } finally {
      _analyzing = false;
      notifyListeners();
    }
  }

  void reset() {
    _image = null;
    _result = null;
    _hint = '';
    _error = null;
    _permissionMessage = null;
    notifyListeners();
  }

  String _humanize(Object e) {
    if (e is ClaudeApiException) {
      if (e.statusCode == 401) return 'Invalid Anthropic API key.';
      if (e.statusCode == 429) return 'Rate limit hit — try again in a moment.';
      return 'Claude API error (${e.statusCode}).';
    }
    return 'Something went wrong: $e';
  }

  @override
  void dispose() {
    _claude.dispose();
    super.dispose();
  }
}
