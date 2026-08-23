import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_restriction_service.dart';

class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Submit a user safety report from a chat conversation or booking
  Future<Map<String, dynamic>> submitUserReport({
    required String reporterId,
    required String reportedUserId,
    String? bookingId,
    String? conversationId,
    required String category,
    required String description,
    String? evidenceUrl,
    String? reporterRole,
    String? reportedRole,
  }) async {
    final now = DateTime.now().toIso8601String();
    final payload = {
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'booking_id': bookingId,
      'conversation_id': conversationId,
      'category': category,
      'description': description,
      'evidence_url': evidenceUrl,
      'reporter_role': reporterRole,
      'reported_role': reportedRole,
      'status': 'pending',
      'created_at': now,
      'updated_at': now,
    };

    try {
      final inserted = await _supabase
          .from('user_reports')
          .insert(payload)
          .select()
          .maybeSingle();

      // Send alert notification to all admin accounts
      try {
        final admins = await _supabase
            .from('users')
            .select('id')
            .eq('role', 'admin');

        for (final admin in List<Map<String, dynamic>>.from(admins)) {
          final adminId = admin['id']?.toString();
          if (adminId != null && adminId.isNotEmpty) {
            await _supabase.from('notifications').insert({
              'user_id': adminId,
              'title': '🚨 New User Report: $category',
              'message':
                  'A participant in conversation $conversationId was reported for: $category.',
              'type': 'safety_report',
              'data': {
                'report_id': inserted?['id'],
                'reported_user_id': reportedUserId,
                'reporter_id': reporterId,
                'booking_id': bookingId,
                'category': category,
              },
              'created_at': now,
            });
          }
        }
      } catch (e) {
        debugPrint('Could not notify admins of report: $e');
      }

      return inserted ?? payload;
    } catch (e) {
      debugPrint('Error inserting into user_reports: $e. Falling back to notifications.');
      // If table doesn't exist yet, insert into support_tickets / notifications fallback
      try {
        await _supabase.from('notifications').insert({
          'user_id': reportedUserId,
          'title': 'Safety Report Logged',
          'message': 'Report submitted against user: $category. $description',
          'type': 'safety_incident',
          'data': payload,
          'created_at': now,
        });
      } catch (inner) {
        debugPrint('Fallback notification log error: $inner');
      }
      return payload;
    }
  }

  /// Get pending reports for Admin review
  Future<List<Map<String, dynamic>>> getPendingReports() async {
    try {
      final rows = await _supabase
          .from('user_reports')
          .select('''
            *,
            reporter:reporter_id (id, full_name, email, phone, role, avatar_url),
            reported_user:reported_user_id (id, full_name, email, phone, role, avatar_url, is_active, is_blocked)
          ''')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching user_reports: $e');
      return [];
    }
  }

  /// Resolve a report without banning
  Future<void> resolveReport({
    required String reportId,
    required String resolutionNotes,
    required String adminId,
  }) async {
    final now = DateTime.now().toIso8601String();
    try {
      await _supabase.from('user_reports').update({
        'status': 'resolved',
        'resolution_notes': resolutionNotes,
        'resolved_by': adminId,
        'resolved_at': now,
        'updated_at': now,
      }).eq('id', reportId);
    } catch (e) {
      debugPrint('Error resolving report: $e');
    }
  }

  /// Ban the reported user immediately and update the report status
  Future<void> banReportedUser({
    required String reportId,
    required String reportedUserId,
    required String banReason,
    required String adminId,
  }) async {
    final now = DateTime.now().toIso8601String();

    // 1. Block the user permanently in Supabase
    await UserRestrictionService().blockUserPermanently(
      reportedUserId,
      banReason,
    );

    // 2. Mark user as inactive in users table
    try {
      await _supabase.from('users').update({
        'is_active': false,
        'is_blocked': true,
        'restriction_reason': banReason,
        'suspension_reason': banReason,
        'suspended_at': now,
        'updated_at': now,
      }).eq('id', reportedUserId);
    } catch (e) {
      debugPrint('Error updating user active status: $e');
    }

    // 3. Mark the report as action_taken_banned
    try {
      await _supabase.from('user_reports').update({
        'status': 'banned',
        'resolution_notes': 'User banned permanently: $banReason',
        'resolved_by': adminId,
        'resolved_at': now,
        'updated_at': now,
      }).eq('id', reportId);
    } catch (e) {
      debugPrint('Error updating report status: $e');
    }

    // 4. Send notification to the banned user
    try {
      await _supabase.from('notifications').insert({
        'user_id': reportedUserId,
        'title': 'Account Suspended / Banned',
        'message':
            'Your account has been permanently suspended due to severe platform policy violation: $banReason.',
        'type': 'account_banned',
        'data': {
          'reason': banReason,
          'banned_at': now,
        },
        'created_at': now,
      });
    } catch (e) {
      debugPrint('Could not send ban notification to user: $e');
    }
  }
}
