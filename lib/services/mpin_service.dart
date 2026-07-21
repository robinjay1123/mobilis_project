import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
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

  Future<void> configure(String mpin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(mpin)) {
      throw const FormatException('MPIN must contain exactly 6 digits.');
    }

    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('No signed-in user found.');

    final salt = _newSalt();
    await _supabase.auth.updateUser(
      UserAttributes(
        data: {
          ...?user.userMetadata,
          'mpin_enabled': true,
          'mpin_salt': salt,
          'mpin_hash': _hash(mpin, salt),
          'mpin_updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      ),
    );
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
