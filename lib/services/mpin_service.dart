import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MpinState {
  const MpinState({
    required this.enabled,
    required this.hash,
    required this.salt,
  });

  final bool enabled;
  final String hash;
  final String salt;

  bool get isConfigured => enabled && hash.isNotEmpty && salt.isNotEmpty;
}

class MpinVerificationResult {
  final bool success;
  final String? operatorId;
  final String? operatorName;
  final String? operatorEmail;
  final String? errorMessage;

  const MpinVerificationResult({
    required this.success,
    this.operatorId,
    this.operatorName,
    this.operatorEmail,
    this.errorMessage,
  });
}

class MpinService {
  MpinService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  MpinState currentState() {
    final metadata = _supabase.auth.currentUser?.userMetadata;
    return MpinState(
      enabled: metadata?['mpin_enabled'] == true,
      hash: metadata?['mpin_hash']?.toString() ?? '',
      salt: metadata?['mpin_salt']?.toString() ?? '',
    );
  }

  bool verify(String mpin) {
    final state = currentState();
    if (!state.isConfigured || !RegExp(r'^\d{6}$').hasMatch(mpin)) {
      return false;
    }
    return _hash(mpin, state.salt) == state.hash;
  }

  /// Verifies if the provided 6-digit MPIN belongs to ANY registered operator or admin.
  /// Used for authorizing PSDC desk counter payments and high-security operator actions.
  /// Automatically records an audit trail in `admin_audit_logs` tracking who authorized the payment.
  Future<MpinVerificationResult> verifyOperatorMpin(
    String mpin, {
    String? bookingId,
    num? amount,
    String? contextDescription,
  }) async {
    final cleanMpin = mpin.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(cleanMpin)) {
      return const MpinVerificationResult(
        success: false,
        errorMessage: 'MPIN must be exactly 6 digits.',
      );
    }

    try {
      // 1. Check if the currently signed-in user is an operator/admin and matches
      final currentUser = _supabase.auth.currentUser;
      final currentMetadata = currentUser?.userMetadata;
      final currentRole = currentMetadata?['role']?.toString().toLowerCase().trim();
      final currentMpinEnabled = currentMetadata?['mpin_enabled'] == true;
      final currentSalt = currentMetadata?['mpin_salt']?.toString() ?? '';
      final currentHash = currentMetadata?['mpin_hash']?.toString() ?? '';

      if ((currentRole == 'operator' || currentRole == 'admin') &&
          currentMpinEnabled &&
          currentSalt.isNotEmpty &&
          currentHash.isNotEmpty) {
        if (_hash(cleanMpin, currentSalt) == currentHash) {
          final name = currentMetadata?['full_name']?.toString().trim() ??
              currentUser?.email?.split('@').first ??
              'Desk Operator';
          final email = currentUser?.email ?? '';

          await _logMpinAuthorization(
            operatorId: currentUser?.id ?? '',
            operatorName: name,
            operatorEmail: email,
            bookingId: bookingId,
            amount: amount,
            contextDescription: contextDescription,
          );

          return MpinVerificationResult(
            success: true,
            operatorId: currentUser?.id,
            operatorName: name,
            operatorEmail: email,
          );
        }
      }

      // 2. Query ALL registered operators and admins from users table
      final response = await _supabase
          .from('users')
          .select('id, full_name, email, role, user_metadata')
          .inFilter('role', ['operator', 'admin'])
          .timeout(const Duration(seconds: 5));

      final users = response as List<dynamic>? ?? [];
      for (final u in users) {
        final userData = u as Map<String, dynamic>;
        final metadata = userData['user_metadata'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(userData['user_metadata'] as Map)
            : null;

        final enabled = metadata?['mpin_enabled'] == true ||
            userData['mpin_enabled'] == true;
        final salt = (metadata?['mpin_salt'] ?? userData['mpin_salt'])?.toString() ?? '';
        final hash = (metadata?['mpin_hash'] ?? userData['mpin_hash'])?.toString() ?? '';

        if (enabled && salt.isNotEmpty && hash.isNotEmpty) {
          if (_hash(cleanMpin, salt) == hash) {
            final opId = userData['id']?.toString() ?? '';
            final name = userData['full_name']?.toString().trim() ??
                userData['email']?.toString().split('@').first ??
                'Desk Operator';
            final email = userData['email']?.toString() ?? '';

            await _logMpinAuthorization(
              operatorId: opId,
              operatorName: name,
              operatorEmail: email,
              bookingId: bookingId,
              amount: amount,
              contextDescription: contextDescription,
            );

            return MpinVerificationResult(
              success: true,
              operatorId: opId,
              operatorName: name,
              operatorEmail: email,
            );
          }
        }
      }

      return const MpinVerificationResult(
        success: false,
        errorMessage: 'Invalid Operator MPIN. Please try again.',
      );
    } catch (e) {
      debugPrint('Error verifying operator MPIN: $e');
      return MpinVerificationResult(
        success: false,
        errorMessage: 'Verification error: $e',
      );
    }
  }

  Future<void> _logMpinAuthorization({
    required String operatorId,
    required String operatorName,
    required String operatorEmail,
    String? bookingId,
    num? amount,
    String? contextDescription,
  }) async {
    try {
      final shortId = bookingId != null && bookingId.isNotEmpty
          ? (bookingId.length > 8 ? '#${bookingId.substring(0, 8).toUpperCase()}' : '#$bookingId')
          : '';
      final amtStr = amount != null ? ' of PHP ${amount.toStringAsFixed(2)}' : '';

      await _supabase.from('admin_audit_logs').insert({
        'entity_id': operatorId,
        'entity_type': 'operator_activity',
        'action': 'desk_payment_authorized',
        'notes': 'Operator $operatorName authorized in-person PSDC Desk payment$amtStr${shortId.isNotEmpty ? " for Booking $shortId" : ""}',
        'booking_id': bookingId,
        'created_at': DateTime.now().toIso8601String(),
        'metadata': {
          'operator_id': operatorId,
          'operator_name': operatorName,
          'operator_email': operatorEmail,
          'amount': amount,
          'method': 'psdc_desk_counter',
          'action': 'desk_payment_authorized',
          'context': contextDescription ?? 'PSDC Desk Payment Approval',
          'authorized_at': DateTime.now().toIso8601String(),
        },
      });
    } catch (e) {
      debugPrint('Audit log entry for desk payment authorization note: $e');
    }
  }

  Future<void> configure(String mpin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(mpin)) {
      throw const FormatException('MPIN must contain exactly 6 digits.');
    }

    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('No signed-in user found.');

    final salt = _newSalt();
    final hash = _hash(mpin, salt);
    final updatedAt = DateTime.now().toUtc().toIso8601String();

    final updatedMetadata = {
      ...?user.userMetadata,
      'mpin_enabled': true,
      'mpin_salt': salt,
      'mpin_hash': hash,
      'mpin_updated_at': updatedAt,
    };

    await _supabase.auth.updateUser(
      UserAttributes(
        data: updatedMetadata,
      ),
    );

    // Also sync to users table metadata if available
    try {
      await _supabase
          .from('users')
          .update({'user_metadata': updatedMetadata})
          .eq('id', user.id);
    } catch (e) {
      debugPrint('Syncing MPIN metadata to users table note: $e');
    }

    // Log MPIN configuration in audit trail
    try {
      final name = user.userMetadata?['full_name']?.toString().trim().isNotEmpty == true
          ? user.userMetadata!['full_name'].toString().trim()
          : (user.email ?? 'Operator');
      await _supabase.from('admin_audit_logs').insert({
        'entity_id': user.id,
        'entity_type': 'operator_activity',
        'action': 'operator_mpin_configured',
        'notes': 'Operator $name updated Desk Authorization MPIN',
        'created_at': DateTime.now().toIso8601String(),
        'metadata': {
          'operator_id': user.id,
          'operator_name': name,
          'operator_email': user.email ?? '',
          'action': 'operator_mpin_configured',
          'updated_at': updatedAt,
        },
      });
    } catch (e) {
      debugPrint('Audit logging for MPIN config note: $e');
    }
  }

  String _hash(String mpin, String salt) {
    return sha256.convert(utf8.encode('$salt:$mpin')).toString();
  }

  String _newSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}

