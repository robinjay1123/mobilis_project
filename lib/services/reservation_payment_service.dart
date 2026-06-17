import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReservationPaymentSettings {
  final double amount;
  final String qrUrl;
  final String accountName;
  final String instructions;

  const ReservationPaymentSettings({
    required this.amount,
    required this.qrUrl,
    required this.accountName,
    required this.instructions,
  });
}

class ReservationPaymentProof {
  final double amount;
  final String method;
  final String paymentType;
  final String referenceNumber;
  final String proofUrl;

  const ReservationPaymentProof({
    required this.amount,
    required this.method,
    required this.paymentType,
    required this.referenceNumber,
    required this.proofUrl,
  });
}

class ReservationPaymentService {
  static const amountKey = 'reservation_payment_amount';
  static const qrUrlKey = 'reservation_payment_qr_url';
  static const accountNameKey = 'reservation_payment_account_name';
  static const instructionsKey = 'reservation_payment_instructions';
  static const _bucket = 'reservation_receipts';

  static const defaultInstructions =
      'Pay the refundable reservation fee, upload the payment screenshot, and enter the 13-digit transaction reference number.';

  final SupabaseClient _supabase;

  ReservationPaymentService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<ReservationPaymentSettings> getSettings() async {
    try {
      final rows = await _supabase
          .from('app_settings')
          .select('key,value')
          .inFilter('key', [
            amountKey,
            qrUrlKey,
            accountNameKey,
            instructionsKey,
          ]);

      final values = {
        for (final row in List<Map<String, dynamic>>.from(rows))
          row['key']?.toString() ?? '': row['value']?.toString() ?? '',
      };

      return ReservationPaymentSettings(
        amount: double.tryParse(values[amountKey] ?? '') ?? 1000,
        qrUrl: values[qrUrlKey]?.trim() ?? '',
        accountName: values[accountNameKey]?.trim().isNotEmpty == true
            ? values[accountNameKey]!.trim()
            : 'PSDC',
        instructions: values[instructionsKey]?.trim().isNotEmpty == true
            ? values[instructionsKey]!.trim()
            : defaultInstructions,
      );
    } catch (e) {
      debugPrint('Unable to load reservation payment settings: $e');
      return const ReservationPaymentSettings(
        amount: 1000,
        qrUrl: '',
        accountName: 'PSDC',
        instructions: defaultInstructions,
      );
    }
  }

  Future<void> updateSettings({
    required double amount,
    required String qrUrl,
    required String accountName,
    required String instructions,
  }) async {
    if (amount <= 0) {
      throw Exception('Reservation amount must be greater than zero.');
    }

    final userId = _supabase.auth.currentUser?.id;
    final now = DateTime.now().toIso8601String();
    final rows = [
      {
        'key': amountKey,
        'value': amount.toStringAsFixed(0),
        'description':
            'Refundable reservation payment required before booking request creation.',
      },
      {
        'key': qrUrlKey,
        'value': qrUrl.trim(),
        'description':
            'Public image URL for the PSDC online banking QR code shown to renters.',
      },
      {
        'key': accountNameKey,
        'value': accountName.trim().isEmpty ? 'PSDC' : accountName.trim(),
        'description':
            'Payment account name shown beside the reservation QR code.',
      },
      {
        'key': instructionsKey,
        'value': instructions.trim().isEmpty
            ? defaultInstructions
            : instructions.trim(),
        'description': 'Instructions shown on the reservation payment screen.',
      },
    ].map((row) => {...row, 'updated_by': userId, 'updated_at': now}).toList();

    await _supabase.from('app_settings').upsert(rows, onConflict: 'key');
  }

  Future<String> uploadReceiptProof({
    required String userId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    final rawName = file.name.trim();
    final extension = rawName.contains('.')
        ? rawName.split('.').last.toLowerCase()
        : 'jpg';
    final objectPath =
        '$userId/reservation_${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _supabase.storage
        .from(_bucket)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _supabase.storage.from(_bucket).getPublicUrl(objectPath);
  }
}
