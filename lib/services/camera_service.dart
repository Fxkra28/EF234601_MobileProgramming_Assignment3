import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class CapturedImage {
  CapturedImage({
    required this.bytes,
    required this.mediaType,
    required this.filePath,
  });
  final Uint8List bytes;
  final String mediaType;
  final String filePath;
}

class CameraService {
  final ImagePicker _picker = ImagePicker();

  Future<bool> ensureCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> ensurePhotosPermission() async {
    final status = await Permission.photos.request();
    return status.isGranted || status.isLimited;
  }

  Future<CapturedImage?> takePhoto() async {
    if (!await ensureCameraPermission()) return null;
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null) return null;
    return _toCaptured(file);
  }

  Future<CapturedImage?> pickFromGallery() async {
    if (!await ensurePhotosPermission()) return null;
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null) return null;
    return _toCaptured(file);
  }

  Future<CapturedImage> _toCaptured(XFile file) async {
    final bytes = await File(file.path).readAsBytes();
    final mime = _mimeFromPath(file.path);
    return CapturedImage(bytes: bytes, mediaType: mime, filePath: file.path);
  }

  String _mimeFromPath(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
