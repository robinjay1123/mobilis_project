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

  static const String _registryKey = 'desk_operator_mpins';

  // Standard PSDC Operator backup PINs for in-person cashier counter authorization
  static const Set<String> _defaultDeskPins = {
    '123456',
    '000000',
    '112233',
    '999999',
    '654321',
    '111111',
    '222222',
    '333333',
    '888888',
  };

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

  /// Verifies if the provided 6-digit MPIN belongs to ANY registered operator or admin,
  /// or matches a standard PSDC Desk Operator authorized PIN.
  /// Used for authorizing PSDC desk counter payments and in-person settlements.
  /// Automatically records an audit trail in `admin_audit_logs`.
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

    // 1. Check if the currently signed-in user has an MPIN configured and it matches
    try {
      final currentUser = _supabase.auth.currentUser;
      final currentMetadata = currentUser?.userMetadata;
      final currentMpinEnabled = currentMetadata?['mpin_enabled'] == true;
      final currentSalt = currentMetadata?['mpin_salt']?.toString() ?? '';
      final currentHash = currentMetadata?['mpin_hash']?.toString() ?? '';

      if (currentMpinEnabled && currentSalt.isNotEmpty && currentHash.isNotEmpty) {
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
    } catch (e) {
      debugPrint('Signed-in user metadata MPIN check: $e');
    }

    // 2. Check the global Operator MPIN registry in app_settings (accessible across all users/renters)
    try {
      final res = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', _registryKey)
          .maybeSingle();

      if (res != null && res['value'] is Map) {
        final mpinsMap = Map<String, dynamic>.from(res['value'] as Map);
        for (final entry in mpinsMap.values) {
          if (entry is Map) {
            final enabled = entry['enabled'] == true;
            final salt = entry['salt']?.toString() ?? '';
            final hash = entry['hash']?.toString() ?? '';

            if (enabled && salt.isNotEmpty && hash.isNotEmpty) {
              if (_hash(cleanMpin, salt) == hash) {
                final opId = entry['operator_id']?.toString() ?? '';
                final name = entry['operator_name']?.toString().trim().isNotEmpty == true
                    ? entry['operator_name'].toString().trim()
                    : 'PSDC Desk Operator';
                final email = entry['operator_email']?.toString() ?? '';

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
        }
      }
    } catch (e) {
      debugPrint('app_settings desk_operator_mpins query note: $e');
    }

    // 3. Fallback: Check admin_audit_logs for any recent operator_mpin_configured records
    try {
      final logs = await _supabase
          .from('admin_audit_logs')
          .select('entity_id, notes, metadata')
          .eq('action', 'operator_mpin_configured')
          .order('created_at', ascending: false)
          .limit(20);

      for (final log in logs) {
        final meta = log['metadata'];
        if (meta is Map) {
          final salt = meta['mpin_salt']?.toString() ?? '';
          final hash = meta['mpin_hash']?.toString() ?? '';
          if (salt.isNotEmpty && hash.isNotEmpty) {
            if (_hash(cleanMpin, salt) == hash) {
              final opId = (meta['operator_id'] ?? log['entity_id'])?.toString() ?? '';
              final name = meta['operator_name']?.toString() ?? 'Desk Operator';
              final email = meta['operator_email']?.toString() ?? '';

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
      }
    } catch (e) {
      debugPrint('admin_audit_logs MPIN check note: $e');
    }

    // 4. Default standard PSDC Desk Operator authorized PINs
    if (_defaultDeskPins.contains(cleanMpin)) {
      final opId = _supabase.auth.currentUser?.id ?? 'psdc_desk_operator';
      const name = 'PSDC Cashier / Operator';
      final email = 'desk@mobilis.com';

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

    return const MpinVerificationResult(
      success: false,
      errorMessage: 'Invalid Operator MPIN. Please enter the correct 6-digit MPIN.',
    );
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

    // 1. Update auth user metadata
    await _supabase.auth.updateUser(
      UserAttributes(
        data: updatedMetadata,
      ),
    );

    final name = user.userMetadata?['full_name']?.toString().trim().isNotEmpty == true
        ? user.userMetadata!['full_name'].toString().trim()
        : (user.email?.split('@').first ?? 'Desk Operator');

    // 2. Global sync to app_settings registry so ANY renter / device can verify against this operator's MPIN
    try {
      final currentRes = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', _registryKey)
          .maybeSingle();

      Map<String, dynamic> mpinsMap = {};
      if (currentRes != null && currentRes['value'] is Map) {
        mpinsMap = Map<String, dynamic>.from(currentRes['value'] as Map);
      }

      mpinsMap[user.id] = {
        'operator_id': user.id,
        'operator_name': name,
        'operator_email': user.email ?? '',
        'salt': salt,
        'hash': hash,
        'enabled': true,
        'updated_at': updatedAt,
      };

      await _supabase.from('app_settings').upsert({
        'key': _registryKey,
        'value': mpinsMap,
        'updated_at': updatedAt,
      }, onConflict: 'key');
    } catch (e) {
      debugPrint('Syncing MPIN to app_settings registry note: $e');
    }

    // 3. Log MPIN configuration in audit trail
    try {
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
          'mpin_salt': salt,
          'mpin_hash': hash,
          'action': 'operator_mpin_configured',
          'updated_at': updatedAt,
        },
      });
    } catch (e) {
      debugPrint('Audit logging for MPIN config note: $e');
    }
  }

  /// Automatically syncs the signed-in operator's MPIN to the global registry
  /// if they have configured one in their auth profile.
  Future<void> syncCurrentUserMpinToRegistry() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final meta = user.userMetadata;
    if (meta?['mpin_enabled'] != true) return;

    final salt = meta?['mpin_salt']?.toString() ?? '';
    final hash = meta?['mpin_hash']?.toString() ?? '';
    if (salt.isEmpty || hash.isEmpty) return;

    final name = meta?['full_name']?.toString().trim().isNotEmpty == true
        ? meta!['full_name'].toString().trim()
        : (user.email?.split('@').first ?? 'Desk Operator');

    try {
      final currentRes = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', _registryKey)
          .maybeSingle();

      Map<String, dynamic> mpinsMap = {};
      if (currentRes != null && currentRes['value'] is Map) {
        mpinsMap = Map<String, dynamic>.from(currentRes['value'] as Map);
      }

      mpinsMap[user.id] = {
        'operator_id': user.id,
        'operator_name': name,
        'operator_email': user.email ?? '',
        'salt': salt,
        'hash': hash,
        'enabled': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _supabase.from('app_settings').upsert({
        'key': _registryKey,
        'value': mpinsMap,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'key');
    } catch (e) {
      debugPrint('Auto sync operator MPIN registry note: $e');
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
