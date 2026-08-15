import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_optimization_service.dart';

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
  final String? proofStoragePath;
  final String? senderPhone;

  const ReservationPaymentProof({
    required this.amount,
    required this.method,
    required this.paymentType,
    required this.referenceNumber,
    required this.proofUrl,
    this.proofStoragePath,
    this.senderPhone,
  });
}

class ReservationPaymentService {
  static const amountKey = 'reservation_payment_amount';
  static const qrUrlKey = 'reservation_payment_qr_url';
  static const accountNameKey = 'reservation_payment_account_name';
  static const instructionsKey = 'reservation_payment_instructions';
  static const _receiptBucket = 'reservation_receipts';
  static const _qrBucket = 'reservation_qr_codes';
  static const _senderNumbersPrefix = 'renter_payment_sender_numbers_';

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

  Future<String> uploadQrCode({required XFile file}) async {
    final originalBytes = await file.readAsBytes();
    final extension = _fileExtension(file.name, fallback: 'png');
    final objectPath =
        'psdc/payment_qr_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final bytes = await ImageOptimizationService.optimizeForUpload(
      originalBytes,
      fileName: objectPath,
      preset: UploadImagePreset.sensitiveDocument,
    );

    await _supabase.storage
        .from(_qrBucket)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            cacheControl: '31536000',
          ),
        );

    return _supabase.storage.from(_qrBucket).getPublicUrl(objectPath);
  }

  Future<void> deleteQrCode(String qrUrl) async {
    final objectPath = _storagePathFromPublicUrl(qrUrl, bucket: _qrBucket);
    if (objectPath == null || objectPath.isEmpty) return;
    await _supabase.storage.from(_qrBucket).remove([objectPath]);
  }

  Future<ReservationReceiptUpload> uploadReceiptProof({
    required String userId,
    required XFile file,
  }) async {
    final originalBytes = await file.readAsBytes();
    final extension = _fileExtension(file.name, fallback: 'jpg');
    final objectPath =
        '$userId/reservation_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final bytes = await ImageOptimizationService.optimizeForUpload(
      originalBytes,
      fileName: objectPath,
      preset: UploadImagePreset.sensitiveDocument,
    );

    await _supabase.storage
        .from(_receiptBucket)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            cacheControl: '31536000',
          ),
        );

    return ReservationReceiptUpload(
      publicUrl: _supabase.storage
          .from(_receiptBucket)
          .getPublicUrl(objectPath),
      storagePath: objectPath,
    );
  }

  Future<void> createReceiptRecord({
    required String bookingId,
    required String renterId,
    required ReservationPaymentProof proof,
  }) async {
    final payload = <String, dynamic>{
      'booking_id': bookingId,
      'renter_id': renterId,
      'amount': proof.amount,
      'payment_method': proof.method,
      'payment_type': proof.paymentType,
      'reference_number': proof.referenceNumber,
      'proof_url': proof.proofUrl,
      'proof_storage_path': proof.proofStoragePath,
      'status': 'pending_review',
      'submitted_at': DateTime.now().toIso8601String(),
    };
    if (proof.senderPhone != null && proof.senderPhone!.trim().isNotEmpty) {
      payload['sender_phone'] = proof.senderPhone!.trim();
    }
    await _supabase.from('reservation_payment_receipts').insert(payload);
  }

  /// Get saved sender/GCash phone numbers for this renter that have been used 2+ times.
  static Future<List<String>> getSavedSenderNumbers(String userId) async {
    if (userId.trim().isEmpty) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_senderNumbersPrefix$userId';
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];

      final Map<String, dynamic> decoded = jsonDecode(raw);
      final List<String> frequent = [];
      decoded.forEach((number, count) {
        if (count is num && count >= 2 && number.toString().trim().isNotEmpty) {
          frequent.add(number.toString().trim());
        }
      });
      return frequent;
    } catch (e) {
      debugPrint('Error getting saved sender numbers: $e');
      return [];
    }
  }

  /// Get all previous sender numbers for this renter regardless of count.
  static Future<Map<String, int>> getAllSenderNumberUsage(String userId) async {
    if (userId.trim().isEmpty) return {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_senderNumbersPrefix$userId';
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return {};
      final Map<String, dynamic> decoded = jsonDecode(raw);
      return decoded.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    } catch (e) {
      return {};
    }
  }

  /// Records usage of a sender/GCash phone number.
  /// When used twice or more, it will automatically appear in the saved numbers dropdown on subsequent bookings.
  static Future<void> recordSenderNumberUsage(
    String userId,
    String phoneNumber,
  ) async {
    final cleanPhone = phoneNumber.trim();
    if (cleanPhone.isEmpty || userId.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_senderNumbersPrefix$userId';
      final currentMap = await getAllSenderNumberUsage(userId);
      final count = (currentMap[cleanPhone] ?? 0) + 1;
      currentMap[cleanPhone] = count;

      await prefs.setString(key, jsonEncode(currentMap));
      debugPrint(
        'Recorded payment sender number $cleanPhone usage count: $count for user $userId',
      );
    } catch (e) {
      debugPrint('Error recording sender number usage: $e');
    }
  }

  String _fileExtension(String rawName, {required String fallback}) {
    final cleanName = rawName.trim();
    if (!cleanName.contains('.')) return fallback;
    final extension = cleanName.split('.').last.toLowerCase();
    return extension.isEmpty ? fallback : extension;
  }

  String? _storagePathFromPublicUrl(
    String publicUrl, {
    required String bucket,
  }) {
    final uri = Uri.tryParse(publicUrl.trim());
    if (uri == null) return null;
    final marker = '/object/public/$bucket/';
    final index = uri.path.indexOf(marker);
    if (index < 0) return null;
    return Uri.decodeComponent(uri.path.substring(index + marker.length));
  }
}

class ReservationReceiptUpload {
  final String publicUrl;
  final String storagePath;

  const ReservationReceiptUpload({
    required this.publicUrl,
    required this.storagePath,
  });
}
