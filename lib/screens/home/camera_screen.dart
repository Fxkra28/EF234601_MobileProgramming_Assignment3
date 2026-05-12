import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../providers/camera_provider.dart';
import '../../widgets/correction_card.dart';
import '../../widgets/dismiss_keyboard.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final TextEditingController _hint = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hint.addListener(() {
      context.read<CameraProvider>().setHint(_hint.text);
    });
  }

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  void _reset() {
    _hint.clear();
    context.read<CameraProvider>().reset();
  }

  @override
  Widget build(BuildContext context) {
    final cam = context.watch<CameraProvider>();
    final hasContent = cam.image != null || cam.result != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera'),
        actions: [
          if (hasContent)
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('New'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: DismissKeyboard(
        child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Hint(),
            const SizedBox(height: 12),
            if (cam.image == null)
              _Capture(
                onTake: () => context.read<CameraProvider>().takePhoto(),
                onPick: () =>
                    context.read<CameraProvider>().pickFromGallery(),
              )
            else
              _Preview(
                path: cam.image!.filePath,
                onRetake: _reset,
              ),
            if (cam.permissionMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _PermissionCallout(message: cam.permissionMessage!),
              ),
            const SizedBox(height: 12),
            if (cam.image != null) ...[
              TextField(
                controller: _hint,
                decoration: const InputDecoration(
                  labelText:
                      'Optional context (e.g. "this is a restaurant menu")',
                  isDense: true,
                ),
                maxLines: 2,
                minLines: 1,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: cam.analyzing
                    ? null
                    : () => context.read<CameraProvider>().analyze(),
                icon: cam.analyzing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome),
                label: const Text('Analyze image'),
              ),
            ],
            const SizedBox(height: 16),
            if (cam.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child:
                    Text(cam.error!, style: const TextStyle(color: Colors.red)),
              ),
            if (cam.result != null) Expanded(child: _ResultView(result: cam.result!)),
          ],
        ),
      ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.camera_alt_outlined, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Snap a sign, menu, document, or form — Personal Buddy will flag '
            'typos, mislabels, and contextual errors.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _Capture extends StatelessWidget {
  const _Capture({required this.onTake, required this.onPick});
  final VoidCallback onTake;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined,
              size: 48, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onTake,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take photo'),
              ),
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('From gallery'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.path, required this.onRetake});
  final String path;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            height: 240,
            width: double.infinity,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Retake',
              onPressed: onRetake,
            ),
          ),
        ),
      ],
    );
  }
}

class _PermissionCallout extends StatelessWidget {
  const _PermissionCallout({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          TextButton(
              onPressed: openAppSettings, child: const Text('Settings')),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});
  final dynamic result;

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if ((result.summary as String).isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(result.summary as String)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if ((result.observations as List).isNotEmpty) ...[
          Text('What I see', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          ...(result.observations as List<String>).map(
            (o) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(o)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if ((result.corrections as List).isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              border: Border.all(color: Colors.green.shade200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: const [
                Icon(Icons.thumb_up_off_alt, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                    child: Text('No issues spotted in the image.',
                        style: TextStyle(fontWeight: FontWeight.w500))),
              ],
            ),
          )
        else ...[
          Text('Corrections (${(result.corrections as List).length})',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          ...(result.corrections as List)
              .map((c) => CorrectionCard(change: c)),
        ],
      ],
    );
  }
}
