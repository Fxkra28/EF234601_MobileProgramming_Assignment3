import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageRole { user, assistant }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final MessageRole role;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'role': role.name,
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory ChatMessage.fromMap(String id, Map<String, dynamic> m) => ChatMessage(
        id: id,
        role: (m['role'] == 'assistant')
            ? MessageRole.assistant
            : MessageRole.user,
        text: (m['text'] ?? '') as String,
        createdAt: (m['createdAt'] is Timestamp)
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
}

/// The result returned by Claude after a grammar review. The Grammar
/// screen and the Vision screen both surface this shape: a cleaned-up
/// version of the source text and a list of itemized changes the user
/// can study individually.
class GrammarCorrection {
  GrammarCorrection({
    required this.correctedText,
    required this.changes,
  });

  final String correctedText;
  final List<GrammarChange> changes;
}

class GrammarChange {
  GrammarChange({
    required this.original,
    required this.corrected,
    required this.explanation,
    required this.category,
  });

  final String original;
  final String corrected;
  final String explanation;
  // One of: grammar, punctuation, tone, structure, spelling, fact. The
  // category drives the icon and color used in the correction card so
  // the user can scan a long list at a glance.
  final String category;

  factory GrammarChange.fromMap(Map<String, dynamic> m) => GrammarChange(
        original: (m['original'] ?? '') as String,
        corrected: (m['corrected'] ?? '') as String,
        explanation: (m['explanation'] ?? '') as String,
        category: (m['category'] ?? 'grammar') as String,
      );
}

/// The result returned by Claude after analyzing a captured image. It
/// contains a short summary of what the photo shows, a list of specific
/// observations, and any context-aware corrections — for example, typos
/// in a sign or mislabeled items on a menu.
class VisionAnalysis {
  VisionAnalysis({
    required this.summary,
    required this.observations,
    required this.corrections,
  });

  final String summary;
  final List<String> observations;
  final List<GrammarChange> corrections;
}
