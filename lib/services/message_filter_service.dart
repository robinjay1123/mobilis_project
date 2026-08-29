import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_restriction_service.dart';

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

    // Social media / off-platform contact
    'facebook',
    'fb',
    'messenger',
    'instagram',
    'ig',
    'viber',
    'tiktok',
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
      final existing = await supabase
          .from('message_flags')
          .select()
          .eq('message_id', messageId)
          .maybeSingle();
      if (existing != null) {
        return {
          'success': true,
          'flagged': true,
          'reason': existing['flag_reason']?.toString() ?? flagReason,
          'data': existing,
        };
      }

      final analysis = await analyzeMessageWithFilters(messageContent);

      // Create flag record with status pending_review
      final response = await supabase
          .from('message_flags')
          .insert({
            'message_id': messageId,
            'conversation_id': conversationId,
            'sender_id': senderId,
            'flag_reason': flagReason,
            'message_content': messageContent,
            'risk_score': analysis['risk_score'],
            'risk_level': analysis['risk_level'],
            'status': 'pending_review',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

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

  /// Check if a message is an automated system audit, booking summary, or checklist notice
  static bool isSystemOrAuditMessage(String messageContent) {
    final trimmed = messageContent.trim();
    final lower = trimmed.toLowerCase();
    return trimmed.startsWith('[System]') ||
        lower.startsWith('booking confirmed') ||
        lower.startsWith('booking request created') ||
        lower.startsWith('booking details') ||
        lower.startsWith('booking approved') ||
        lower.startsWith('pre-trip checklist') ||
        lower.startsWith('return checklist') ||
        (lower.contains('booking id:') &&
            (lower.contains('plate number:') ||
                lower.contains('schedule:') ||
                lower.contains('vehicle:'))) ||
        lower.contains('use this conversation for booking coordination') ||
        lower.contains('checklist submitted') ||
        lower.contains('gps coordinates:') ||
        lower.contains('pre-trip inspection completed') ||
        lower.contains('return inspection completed') ||
        (lower.contains('renter:') && lower.contains('partner/owner:'));
  }

  /// Analyze message for off-platform transaction attempts
  static Map<String, dynamic> analyzeMessage(String messageContent) {
    if (isSystemOrAuditMessage(messageContent)) {
      return {
        'is_suspicious': false,
        'risk_score': 0.0,
        'risk_level': 'none',
        'found_keywords': <String>[],
        'should_flag': false,
      };
    }

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

    // Check for phone number patterns (including Philippine numbers e.g. 09306288261)
    if (RegExp(r'\b(?:\+?63|0)9\d{9}\b').hasMatch(messageContent) ||
        RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b').hasMatch(messageContent) ||
        RegExp(r'\b09\d{9}\b').hasMatch(messageContent) ||
        RegExp(r'\b\d{10,11}\b').hasMatch(messageContent)) {
      foundKeywords.add('phone_number');
      riskScore += 0.35;
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
      'is_suspicious': foundKeywords.isNotEmpty,
      'risk_score': riskScore,
      'risk_level': riskLevel,
      'found_keywords': foundKeywords,
      'should_flag': foundKeywords.isNotEmpty,
    };
  }

  /// Analyze built-in safety patterns together with words managed by admins.
  static Future<Map<String, dynamic>> analyzeMessageWithFilters(
    String messageContent,
  ) async {
    final analysis = Map<String, dynamic>.from(analyzeMessage(messageContent));
    final filterCheck = await checkMessageAgainstFilterWords(messageContent);
    final customWords = List<String>.from(
      filterCheck['found_words'] as List? ?? const <String>[],
    );
    final keywords = List<String>.from(
      analysis['found_keywords'] as List? ?? const <String>[],
    );

    for (final word in customWords) {
      if (!keywords.contains(word)) keywords.add(word);
    }

    var riskScore = (analysis['risk_score'] as num?)?.toDouble() ?? 0;
    if (customWords.isNotEmpty) riskScore += 0.5;
    if (riskScore > 1) riskScore = 1;

    final riskLevel = riskScore >= 0.5
        ? 'high'
        : riskScore >= 0.25
        ? 'medium'
        : 'low';

    return {
      'is_suspicious': keywords.isNotEmpty,
      'risk_score': riskScore,
      'risk_level': riskLevel,
      'found_keywords': keywords,
      'should_flag': keywords.isNotEmpty,
    };
  }

  /// Load message flags for the moderation queue, including sender details.
  static Future<List<Map<String, dynamic>>> getFlags({String? status}) async {
    var query = supabase
        .from('message_flags')
        .select(
          'id, message_id, conversation_id, sender_id, flag_reason, '
          'message_content, risk_score, risk_level, status, admin_notes, '
          'created_at, reviewed_at, '
          'sender:users!message_flags_sender_id_fkey('
          'id, name, full_name, email, role, off_platform_flag_count, is_blocked)',
        );
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
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
      if (!{'approve', 'dismiss', 'block_user'}.contains(action)) {
        return {'success': false, 'error': 'Unsupported review action'};
      }

      final response = await supabase
          .from('message_flags')
          .update({
            'status': (action == 'approve' || action == 'confirm' || action == 'block_user') ? 'confirmed' : 'dismissed',
            'admin_notes': adminNotes,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', flagId)
          .select()
          .single();

      final senderId = response['sender_id']?.toString() ?? '';
      if ((action == 'approve' || action == 'confirm' || action == 'block_user') && senderId.isNotEmpty) {
        await _incrementUserFlagCount(senderId);
      }

      if (action == 'block_user' && senderId.isNotEmpty) {
        await supabase
            .from('users')
            .update({'is_blocked': true})
            .eq('id', senderId);
      }

      return {'success': true, 'data': response};
    } catch (e) {
      return {'success': false, 'error': 'Failed to review flag: $e'};
    }
  }

  /// Load users who have message flags, elevated flag count, or have been blocked/suspended for message violations.
  static Future<List<Map<String, dynamic>>> getViolatingUsers() async {
    try {
      // First process any expired restrictions across the platform to auto-unban users whose time is up
      await UserRestrictionService().processExpiredRestrictions();

      final flagsResponse = await supabase
          .from('message_flags')
          .select(
            'id, sender_id, flag_reason, message_content, risk_level, status, created_at',
          )
          .order('created_at', ascending: false);

      final flagsList = List<Map<String, dynamic>>.from(flagsResponse);
      final flaggedUserIds = flagsList
          .map((f) => f['sender_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet();

      final usersQuery = await supabase
          .from('users')
          .select(
            'id, name, full_name, email, role, avatar_url, profile_picture_url, off_platform_flag_count, is_blocked, is_active, suspension_reason, suspended_at, chat_restricted_until, account_restricted_until, restriction_level, restriction_reason',
          )
          .or('off_platform_flag_count.gt.0,is_blocked.eq.true,is_active.eq.false,account_restricted_until.not.is.null,chat_restricted_until.not.is.null');

      final usersList = List<Map<String, dynamic>>.from(usersQuery);
      final userMap = <String, Map<String, dynamic>>{};

      for (final user in usersList) {
        final id = user['id']?.toString();
        if (id != null && id.isNotEmpty) {
          userMap[id] = user;
        }
      }

      final missingUserIds = flaggedUserIds
          .where((id) => !userMap.containsKey(id))
          .toList();
      if (missingUserIds.isNotEmpty) {
        final missingUsers = await supabase
            .from('users')
            .select(
              'id, name, full_name, email, role, avatar_url, profile_picture_url, off_platform_flag_count, is_blocked, is_active, suspension_reason, suspended_at, chat_restricted_until, account_restricted_until, restriction_level, restriction_reason',
            )
            .inFilter('id', missingUserIds);
        for (final user in List<Map<String, dynamic>>.from(missingUsers)) {
          final id = user['id']?.toString();
          if (id != null && id.isNotEmpty) {
            userMap[id] = user;
          }
        }
      }

      final now = DateTime.now();
      final result = <Map<String, dynamic>>[];
      for (final entry in userMap.entries) {
        final userId = entry.key;
        final user = Map<String, dynamic>.from(entry.value);
        final userFlags = flagsList
            .where((f) => f['sender_id']?.toString() == userId)
            .toList();

        final accountUntil = DateTime.tryParse(
          user['account_restricted_until']?.toString() ?? '',
        );
        final chatUntil = DateTime.tryParse(
          user['chat_restricted_until']?.toString() ?? '',
        );
        final level = user['restriction_level']?.toString().trim() ?? '';
        final isPermanent =
            level == 'third_attempt_blocked' ||
            level == 'matched_blocked_identity';
        final isExpired =
            !isPermanent &&
            ((accountUntil != null && accountUntil.isBefore(now)) ||
                (chatUntil != null && chatUntil.isBefore(now)));

        if (isExpired) {
          user['is_blocked'] = false;
          user['is_active'] = true;
        }

        user['user_flags'] = userFlags;
        user['flag_count'] =
            userFlags.length > ((user['off_platform_flag_count'] as num?)?.toInt() ?? 0)
                ? userFlags.length
                : ((user['off_platform_flag_count'] as num?)?.toInt() ?? 0);

        if (userFlags.isNotEmpty) {
          final first = userFlags.first;
          final reason = first['flag_reason']?.toString().trim();
          final content = first['message_content']?.toString().trim();
          user['latest_reason'] = (reason != null && reason.isNotEmpty)
              ? reason
              : (content ?? 'Flagged message violation');
          user['latest_flag_date'] = first['created_at'];
        }

        result.add(user);
      }

      result.sort((a, b) {
        final aRestricted =
            (a['is_blocked'] == true || a['is_active'] == false) ? 1 : 0;
        final bRestricted =
            (b['is_blocked'] == true || b['is_active'] == false) ? 1 : 0;
        if (aRestricted != bRestricted) return bRestricted.compareTo(aRestricted);
        final aCount = (a['flag_count'] as int? ?? 0);
        final bCount = (b['flag_count'] as int? ?? 0);
        return bCount.compareTo(aCount);
      });

      return result;
    } catch (e) {
      debugPrint('Error loading violating users: $e');
      return [];
    }
  }

  /// Unban/unblock user and completely reset all restriction blocks and message violation flags
  static Future<Map<String, dynamic>> unbanUser(String userId) {
    return UserRestrictionService().unbanUser(userId);
  }

  /// Set restriction duration or permanent ban on a user
  static Future<Map<String, dynamic>> setCustomRestriction({
    required String userId,
    required Duration? duration,
    required String reason,
    String? adminNotes,
  }) {
    return UserRestrictionService().setCustomRestriction(
      userId: userId,
      duration: duration,
      reason: reason,
      adminNotes: adminNotes,
    );
  }
}
