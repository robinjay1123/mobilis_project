import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageFilterService {
  static final supabase = Supabase.instance.client;

  // Keywords/patterns that indicate off-platform transaction attempts
  static const offPlatformKeywords = [
    // Direct contact
    'whatsapp',
    'telegram',
    'phone',
    'call me',
    'text me',
    'dm me',
    'message me on',
    'contact me on',
    'direct message',

    // Bank details
    'bank account',
    'bank transfer',
    'wire transfer',
    'swift',
    'iban',
    'routing number',

    // Payment avoidance
    'pay outside',
    'skip payment',
    'avoid commission',
    'no commission',
    'cheaper if',
    'save money by',
    'directly to me',
    'cash payment',
    'cash only',

    // Escrow/meeting outside
    'meet at',
    'meet me',
    'in person only',
    'pickup from',
    'pickup at',
    'drop off at home',
    'my place',

    // Personal info sharing
    'email:',
    'email me',
    '@gmail',
    '@yahoo',
    'my email',
    'send email',
  ];

  /// Flag a message as potentially suspicious
  static Future<Map<String, dynamic>> flagMessageForReview({
    required String messageId,
    required String conversationId,
    required String senderId,
    required String flagReason,
    required String messageContent,
  }) async {
    try {
      // Create flag record
      final response = await supabase
          .from('message_flags')
          .insert({
            'message_id': messageId,
            'conversation_id': conversationId,
            'sender_id': senderId,
            'flag_reason': flagReason,
            'message_content': messageContent,
            'status': 'pending_review',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // Increment user flag count
      await _incrementUserFlagCount(senderId);

      return {
        'success': true,
        'flagged': true,
        'reason': flagReason,
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'flagged': false,
        'error': 'Failed to flag message: $e',
      };
    }
  }

  /// Analyze message for off-platform transaction attempts
  static Map<String, dynamic> analyzeMessage(String messageContent) {
    final lowerContent = messageContent.toLowerCase();
    final foundKeywords = <String>[];
    double riskScore = 0.0;

    // Check for keywords
    for (final keyword in offPlatformKeywords) {
      if (lowerContent.contains(keyword)) {
        foundKeywords.add(keyword);
        riskScore += 0.15;
      }
    }

    // Check for phone number patterns
    if (RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b').hasMatch(messageContent)) {
      foundKeywords.add('phone_number');
      riskScore += 0.25;
    }

    // Check for email patterns
    if (RegExp(
      r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    ).hasMatch(messageContent)) {
      foundKeywords.add('email_address');
      riskScore += 0.20;
    }

    // Check for URL patterns
    if (RegExp(r'https?://').hasMatch(messageContent)) {
      foundKeywords.add('url');
      riskScore += 0.15;
    }

    // Cap risk score
    riskScore = riskScore > 1.0 ? 1.0 : riskScore;

    final riskLevel = riskScore >= 0.5
        ? 'high'
        : riskScore >= 0.25
        ? 'medium'
        : 'low';

    return {
      'is_suspicious': riskScore >= 0.5,
      'risk_score': riskScore,
      'risk_level': riskLevel,
      'found_keywords': foundKeywords,
      'should_flag': riskScore >= 0.5,
    };
  }

  /// Get user's flag history
  static Future<List<Map<String, dynamic>>> getUserFlagHistory(
    String userId,
  ) async {
    try {
      return await supabase
          .from('message_flags')
          .select()
          .eq('sender_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
    } catch (e) {
      return [];
    }
  }

  /// Get user's flag count
  static Future<int> getUserFlagCount(String userId) async {
    try {
      final response = await supabase
          .from('users')
          .select('off_platform_flag_count')
          .eq('id', userId)
          .single();

      return response['off_platform_flag_count'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Increment user flag count
  static Future<void> _incrementUserFlagCount(String userId) async {
    try {
      final currentCount = await getUserFlagCount(userId);

      await supabase
          .from('users')
          .update({'off_platform_flag_count': currentCount + 1})
          .eq('id', userId);

      // Block user if too many flags
      if (currentCount + 1 >= 3) {
        await supabase
            .from('users')
            .update({'is_blocked': true})
            .eq('id', userId);
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// Load all admin-defined filter words from database
  static Future<List<String>> loadFilterWords() async {
    try {
      final response = await supabase
          .from('filter_words')
          .select('word')
          .order('created_at', ascending: false);

      return (response as List).map((item) => item['word'] as String).toList();
    } catch (e) {
      debugPrint('Error loading filter words: $e');
      return [];
    }
  }

  /// Check if message contains any admin-defined filter words
  static Future<Map<String, dynamic>> checkMessageAgainstFilterWords(
    String messageContent, {
    List<String>? filterWords,
  }) async {
    try {
      // Load filter words if not provided
      final wordsToCheck = filterWords ?? await loadFilterWords();

      if (wordsToCheck.isEmpty) {
        return {'contains_filter_words': false, 'found_words': <String>[]};
      }

      final lowerContent = messageContent.toLowerCase();
      final foundWords = <String>[];

      for (final word in wordsToCheck) {
        if (lowerContent.contains(word.toLowerCase())) {
          foundWords.add(word);
        }
      }

      return {
        'contains_filter_words': foundWords.isNotEmpty,
        'found_words': foundWords,
      };
    } catch (e) {
      debugPrint('Error checking filter words: $e');
      return {
        'contains_filter_words': false,
        'found_words': <String>[],
        'error': e.toString(),
      };
    }
  }

  /// Auto-flag message if it contains filter words
  static Future<Map<String, dynamic>> autoFlagMessageIfNeeded({
    required String messageId,
    required String conversationId,
    required String senderId,
    required String messageContent,
  }) async {
    try {
      // Check against filter words
      final filterCheck = await checkMessageAgainstFilterWords(messageContent);

      if (filterCheck['contains_filter_words'] == true) {
        final foundWords = filterCheck['found_words'] as List<String>;
        final reason = 'Contains flagged word(s): ${foundWords.join(", ")}';

        // Auto-flag the message
        return await flagMessageForReview(
          messageId: messageId,
          conversationId: conversationId,
          senderId: senderId,
          flagReason: reason,
          messageContent: messageContent,
        );
      }

      return {
        'success': true,
        'flagged': false,
        'reason': 'No filter words detected',
      };
    } catch (e) {
      return {
        'success': false,
        'flagged': false,
        'error': 'Error auto-flagging message: $e',
      };
    }
  }

  /// Admin review flagged messages
  static Future<Map<String, dynamic>> reviewFlaggedMessage({
    required String flagId,
    required String action, // 'approve', 'dismiss', 'block_user'
    required String adminNotes,
  }) async {
    try {
      final response = await supabase
          .from('message_flags')
          .update({
            'status': action == 'approve' ? 'confirmed' : 'dismissed',
            'admin_notes': adminNotes,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', flagId)
          .select()
          .single();

      if (action == 'block_user') {
        await supabase
            .from('users')
            .update({'is_blocked': true})
            .eq('id', response['sender_id']);
      }

      return {'success': true, 'data': response};
    } catch (e) {
      return {'success': false, 'error': 'Failed to review flag: $e'};
    }
  }
}
