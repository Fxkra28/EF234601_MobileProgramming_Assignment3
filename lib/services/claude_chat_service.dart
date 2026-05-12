import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/env.dart';
import '../models/message.dart';

class ClaudeChatService {
  ClaudeChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final Uri _endpoint = Uri.parse('https://api.anthropic.com/v1/messages');
  static const _apiVersion = '2023-06-01';
  static const _maxTokens = 1024;

  /// Sends a multi-turn conversation to Claude in the assistant persona
  /// and returns the plain-text reply. This is what powers the main Chat
  /// tab — short, friendly, day-to-day-helpful replies without grammar
  /// coaching mixed in.
  Future<String> assistantChat({required List<ChatMessage> history}) async {
    final trimmed = _truncate(history, AppConstants.maxChatHistoryTurns);
    final messages = trimmed
        .map((m) => {
              'role': m.role == MessageRole.user ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    final body = {
      'model': Env.anthropicModel,
      'max_tokens': _maxTokens,
      'system': [
        {
          'type': 'text',
          'text': _assistantSystemPrompt,
          'cache_control': {'type': 'ephemeral'},
        }
      ],
      'messages': messages,
    };

    final res = await _post(body);
    return _extractFirstText(res);
  }

  /// Runs a one-shot grammar review on the given text. Claude is forced
  /// to call the `return_grammar_correction` tool so the response always
  /// arrives as validated JSON: a corrected version of the text plus a
  /// list of categorized changes the UI can render as individual cards.
  Future<GrammarCorrection> grammarCheck(String input) async {
    final body = {
      'model': Env.anthropicModel,
      'max_tokens': _maxTokens,
      'system': _grammarSystemPrompt,
      'tools': [_grammarTool],
      'tool_choice': {'type': 'tool', 'name': 'return_grammar_correction'},
      'messages': [
        {
          'role': 'user',
          'content':
              'Review the following text and return the corrected version plus a list of changes you made.\n\n---\n$input\n---',
        }
      ],
    };

    final res = await _post(body);
    final tool = _extractToolInput(res);
    final corrected = (tool['correctedText'] ?? input) as String;
    final changes = (tool['changes'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => GrammarChange.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    return GrammarCorrection(correctedText: corrected, changes: changes);
  }

  /// Sends a captured image to Claude's vision endpoint along with an
  /// optional context hint from the user. The model returns a short
  /// summary, a list of observations, and any corrections it can spot
  /// — typos in signs, mislabeled items, factual inconsistencies, etc.
  Future<VisionAnalysis> analyzeImage({
    required Uint8List imageBytes,
    required String mediaType,
    String? userHint,
  }) async {
    final base64Image = base64Encode(imageBytes);
    final body = {
      'model': Env.anthropicModel,
      'max_tokens': _maxTokens,
      'system': _visionSystemPrompt,
      'tools': [_visionTool],
      'tool_choice': {'type': 'tool', 'name': 'return_image_analysis'},
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaType,
                'data': base64Image,
              }
            },
            {
              'type': 'text',
              'text': userHint?.isNotEmpty == true
                  ? 'Context from the user: $userHint\n\nAnalyze the image and flag any errors or corrections needed.'
                  : 'Analyze the image and flag any errors or corrections needed in the text or content visible.',
            },
          ],
        }
      ],
    };

    final res = await _post(body);
    final tool = _extractToolInput(res);
    final summary = (tool['summary'] ?? '') as String;
    final observations = (tool['observations'] as List? ?? const [])
        .whereType<String>()
        .toList();
    final corrections = (tool['corrections'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => GrammarChange.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    return VisionAnalysis(
      summary: summary,
      observations: observations,
      corrections: corrections,
    );
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final res = await _client.post(
      _endpoint,
      headers: {
        'content-type': 'application/json',
        'x-api-key': Env.anthropicApiKey,
        'anthropic-version': _apiVersion,
      },
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ClaudeApiException(res.statusCode, res.body);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  String _extractFirstText(Map<String, dynamic> response) {
    final content = (response['content'] as List?) ?? const [];
    for (final block in content) {
      if (block is Map && block['type'] == 'text') {
        return (block['text'] ?? '') as String;
      }
    }
    return '';
  }

  Map<String, dynamic> _extractToolInput(Map<String, dynamic> response) {
    final content = (response['content'] as List?) ?? const [];
    for (final block in content) {
      if (block is Map && block['type'] == 'tool_use') {
        return Map<String, dynamic>.from(block['input'] as Map);
      }
    }
    throw const ClaudeApiException(0, 'No tool_use block in Claude response');
  }

  List<ChatMessage> _truncate(List<ChatMessage> history, int maxTurns) {
    if (history.length <= maxTurns * 2) return history;
    return history.sublist(history.length - maxTurns * 2);
  }

  static const _assistantSystemPrompt = '''
You are Personal Buddy — a friendly, concise, and helpful personal assistant for day-to-day life.

Style:
- Conversational and natural — like a smart friend, not a corporate bot.
- Keep replies short by default (1-3 sentences) unless the user asks for detail.
- Ask a clarifying question only when truly needed.
- No emojis unless the user uses them first.

Capabilities you can help with:
- Answering questions, giving recommendations, brainstorming ideas.
- Helping plan tasks, schedules, errands, decisions.
- Casual conversation when the user wants to chat.

Avoid:
- Long disclaimers, hedging, or repeating the user's question back.
- Pretending to have memory across separate sessions (the user can re-share context).
- Grammar correction or proofreading — those go to a separate "Grammar" mode the user can switch to.
''';

  static const _grammarSystemPrompt = '''
You are the grammar coach inside Personal Buddy. The user will give you a piece of text. Return:
1. The cleanly corrected text.
2. A list of distinct changes you made, each with a brief one-line explanation of why.

Categories for each change:
- "grammar": grammar, agreement, tense, conjugation
- "punctuation": missing or wrong punctuation
- "structure": sentence structure, word order, run-on / fragment fixes
- "tone": improving clarity, formality, conciseness, word choice
- "spelling": typos / misspellings

Rules:
- Preserve the user's voice and meaning. Don't rewrite for style unless tone is clearly off.
- If the original text is already correct, return it unchanged with an empty changes list.
- Never editorialize beyond the explanation field.
- Always call the return_grammar_correction tool.
''';

  static const _visionSystemPrompt = '''
You are the vision reviewer inside Personal Buddy. The user shows you an image — often a photo of a sign, document, label, menu, or piece of text.

Your job:
1. Briefly summarize what's in the image (one sentence).
2. List 1-5 concrete observations about the content (what text/labels/items are visible).
3. Flag any errors visible: spelling, grammar, punctuation, factually wrong labels, inconsistent units, mislabeled items, etc. Each correction includes the original phrase, the suggested correction, and a brief why.

Be specific — if there's no error to flag, return an empty corrections list. Do not invent issues. Always call the return_image_analysis tool.
''';

  static final Map<String, dynamic> _grammarTool = {
    'name': 'return_grammar_correction',
    'description':
        'Return the corrected text and the list of changes that were made.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'correctedText': {
          'type': 'string',
          'description': 'The full corrected version of the user\'s text.',
        },
        'changes': {
          'type': 'array',
          'description': 'Distinct changes made to the original.',
          'items': {
            'type': 'object',
            'properties': {
              'original': {'type': 'string'},
              'corrected': {'type': 'string'},
              'explanation': {'type': 'string'},
              'category': {
                'type': 'string',
                'enum': ['grammar', 'punctuation', 'structure', 'tone', 'spelling'],
              },
            },
            'required': ['original', 'corrected', 'explanation', 'category'],
          },
        },
      },
      'required': ['correctedText', 'changes'],
    },
  };

  static final Map<String, dynamic> _visionTool = {
    'name': 'return_image_analysis',
    'description':
        'Return a summary, observations, and any contextual corrections '
            'found in the image.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'summary': {
          'type': 'string',
          'description': 'One-sentence summary of what\'s in the image.',
        },
        'observations': {
          'type': 'array',
          'description': 'Specific text/labels/items visible in the image.',
          'items': {'type': 'string'},
        },
        'corrections': {
          'type': 'array',
          'description':
              'Errors or improvements found — spelling, grammar, '
                  'factual mistakes, mislabels, etc.',
          'items': {
            'type': 'object',
            'properties': {
              'original': {'type': 'string'},
              'corrected': {'type': 'string'},
              'explanation': {'type': 'string'},
              'category': {
                'type': 'string',
                'enum': [
                  'grammar',
                  'punctuation',
                  'structure',
                  'tone',
                  'spelling',
                  'fact',
                ],
              },
            },
            'required': ['original', 'corrected', 'explanation', 'category'],
          },
        },
      },
      'required': ['summary', 'observations', 'corrections'],
    },
  };

  void dispose() => _client.close();
}

class ClaudeApiException implements Exception {
  const ClaudeApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() => 'ClaudeApiException($statusCode): $body';
}
