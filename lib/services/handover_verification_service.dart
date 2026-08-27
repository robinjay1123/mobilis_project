import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HandoverVerificationService {
  HandoverVerificationService._internal();
  static final HandoverVerificationService _instance =
      HandoverVerificationService._internal();
  factory HandoverVerificationService() => _instance;

  SupabaseClient get supabase => Supabase.instance.client;

  /// Generates a deterministic 6-digit security PIN based on booking ID and renter ID
  String generateHandoverPin(String bookingId, String renterId) {
    final rawKey = '${bookingId}_${renterId}_mobilis_handover_salt_2026';
    final bytes = utf8.encode(rawKey);
    final digest = sha256.convert(bytes);
    final hashNum = int.parse(digest.toString().substring(0, 8), radix: 16);
    final pinInt = (hashNum % 900000) + 100000;
    return pinInt.toString();
  }

  /// Encodes QR Code payload JSON string
  String generateQrPayload({
    required String bookingId,
    required String renterId,
    required String vehicleId,
    String? vehicleName,
  }) {
    final pin = generateHandoverPin(bookingId, renterId);
    final payload = {
      'app': 'MOBILIS_PSDC',
      'type': 'VEHICLE_HANDOVER_PASS',
      'booking_id': bookingId,
      'renter_id': renterId,
      'vehicle_id': vehicleId,
      'vehicle_name': vehicleName ?? 'Vehicle',
      'pin': pin,
      'generated_at': DateTime.now().toIso8601String(),
    };
    return jsonEncode(payload);
  }

  /// Verifies renter PIN or QR code payload for a booking
  Future<bool> verifyHandoverPass({
    required String bookingId,
    required String enteredPin,
    required String verifierId,
    required String verifierRole,
  }) async {
    try {
      final booking = await supabase
          .from('bookings')
          .select('id, user_id, handover_verified_at, handover_verified_by')
          .eq('id', bookingId)
          .maybeSingle();

      if (booking == null) {
        throw Exception('Booking not found');
      }

      final renterId = booking['user_id']?.toString() ?? '';
      final expectedPin = generateHandoverPin(bookingId, renterId);

      if (enteredPin.trim() != expectedPin) {
        return false;
      }

      // Record handover verification timestamp
      final now = DateTime.now().toIso8601String();
      await supabase.from('bookings').update({
        'handover_verified_at': now,
        'handover_verified_by': verifierId,
        'handover_verifier_role': verifierRole,
        'updated_at': now,
      }).eq('id', bookingId);

      debugPrint('Handover pass verified successfully for booking $bookingId by $verifierId ($verifierRole)');
      return true;
    } catch (e) {
      debugPrint('Error verifying handover pass: $e');
      rethrow;
    }
  }

  /// Verifies vehicle return pass PIN
  Future<bool> verifyReturnPass({
    required String bookingId,
    required String enteredPin,
    required String verifierId,
    required String verifierRole,
  }) async {
    try {
      final booking = await supabase
          .from('bookings')
          .select('id, user_id')
          .eq('id', bookingId)
          .maybeSingle();

      if (booking == null) {
        throw Exception('Booking not found');
      }

      final renterId = booking['user_id']?.toString() ?? '';
      final expectedPin = generateHandoverPin(bookingId, renterId);

      if (enteredPin.trim() != expectedPin) {
        return false;
      }

      final now = DateTime.now().toIso8601String();
      await supabase.from('bookings').update({
        'return_verified_at': now,
        'return_verified_by': verifierId,
        'return_verifier_role': verifierRole,
        'updated_at': now,
      }).eq('id', bookingId);

      debugPrint('Return pass verified successfully for booking $bookingId by $verifierId ($verifierRole)');
      return true;
    } catch (e) {
      debugPrint('Error verifying return pass: $e');
      rethrow;
    }
  }

  /// Parses QR Code JSON payload into booking ID and PIN
  Map<String, String>? parseQrPayload(String rawPayload) {
    try {
      final trimmed = rawPayload.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final decoded = jsonDecode(trimmed) as Map<String, dynamic>;
        final bookingId = decoded['booking_id']?.toString();
        final pin = decoded['pin']?.toString();
        if (bookingId != null && pin != null) {
          return {'booking_id': bookingId, 'pin': pin};
        }
      } else if (trimmed.length == 6 && RegExp(r'^\d{6}$').hasMatch(trimmed)) {
        return {'pin': trimmed};
      }
    } catch (e) {
      debugPrint('Error parsing QR payload: $e');
    }
    return null;
  }

  /// Check if handover or return has been verified for a booking
  Future<Map<String, dynamic>?> getHandoverStatus(String bookingId) async {
    try {
      final response = await supabase
          .from('bookings')
          .select('handover_verified_at, handover_verified_by, handover_verifier_role, return_verified_at, return_verified_by, return_verifier_role')
          .eq('id', bookingId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error getting handover status: $e');
      return null;
    }
  }
}
