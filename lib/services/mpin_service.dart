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
  final String? errorMessage;

  const MpinVerificationResult({
    required this.success,
    this.operatorId,
    this.operatorName,
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

  /// Verifies if the provided 6-digit MPIN belongs to any registered operator or admin.
  /// Used for authorizing PSDC desk counter payments and high-security operator actions.
  Future<MpinVerificationResult> verifyOperatorMpin(String mpin) async {
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
          return MpinVerificationResult(
            success: true,
            operatorId: currentUser?.id,
            operatorName: name,
          );
        }
      }

      // 2. Query operators and admins from users table
      final response = await _supabase
          .from('users')
          .select('id, full_name, email, role, user_metadata')
          .inFilter('role', ['operator', 'admin'])
          .timeout(const Duration(seconds: 5));

      final users = response as List<dynamic>? ?? [];
      for (final u in users) {
        final userData = u as Map<String, dynamic>;
        final metadata = userData['user_metadata'] as Map<String, dynamic>?;
        final enabled = metadata?['mpin_enabled'] == true;
        final salt = metadata?['mpin_salt']?.toString() ?? '';
        final hash = metadata?['mpin_hash']?.toString() ?? '';

        if (enabled && salt.isNotEmpty && hash.isNotEmpty) {
          if (_hash(cleanMpin, salt) == hash) {
            final name = userData['full_name']?.toString().trim() ??
                userData['email']?.toString().split('@').first ??
                'Desk Operator';
            return MpinVerificationResult(
              success: true,
              operatorId: userData['id']?.toString(),
              operatorName: name,
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

