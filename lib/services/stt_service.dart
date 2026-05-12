import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/constants.dart';

class SttService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _ready = false;

  bool get isListening => _speech.isListening;
  bool get hasError => !_ready;

  Future<bool> init() async {
    if (_ready) return true;
    _ready = await _speech.initialize(
      onError: (e) => _ready = false,
      onStatus: (_) {},
    );
    return _ready;
  }

  Future<void> start({
    String? localeId,
    required void Function(String partial) onPartial,
    required void Function(String finalText) onFinal,
    Duration silenceTimeout = const Duration(
        seconds: AppConstants.silenceTimeoutSeconds),
  }) async {
    if (!_ready && !await init()) return;
    await _speech.listen(
      localeId: localeId ?? AppConstants.defaultSttLocale,
      pauseFor: silenceTimeout,
      listenFor: const Duration(seconds: 60),
      onResult: (result) {
        if (result.finalResult) {
          onFinal(result.recognizedWords);
        } else {
          onPartial(result.recognizedWords);
        }
      },
    );
  }

  Future<void> stop() => _speech.stop();
  Future<void> cancel() => _speech.cancel();
}
