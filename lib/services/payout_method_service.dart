import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PayoutMethod {
  final String id;
  final String provider; // 'GCash', 'Maya', 'MariBank', 'GoTyme'
  final String accountName;
  final String accountNumber; // 11 digits
  final String? qrCodeUrl;
  final bool isDefault;
  final DateTime createdAt;

  const PayoutMethod({
    required this.id,
    required this.provider,
    required this.accountName,
    required this.accountNumber,
    this.qrCodeUrl,
    this.isDefault = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider,
        'account_name': accountName,
        'account_number': accountNumber,
        'qr_code_url': qrCodeUrl,
        'is_default': isDefault,
        'created_at': createdAt.toIso8601String(),
      };

  factory PayoutMethod.fromJson(Map<String, dynamic> json) => PayoutMethod(
        id: json['id']?.toString() ?? '',
        provider: json['provider']?.toString() ?? 'GCash',
        accountName: json['account_name']?.toString() ?? '',
        accountNumber: json['account_number']?.toString() ?? '',
        qrCodeUrl: json['qr_code_url']?.toString(),
        isDefault: json['is_default'] == true,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );

  PayoutMethod copyWith({
    String? id,
    String? provider,
    String? accountName,
    String? accountNumber,
    String? qrCodeUrl,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return PayoutMethod(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      accountName: accountName ?? this.accountName,
      accountNumber: accountNumber ?? this.accountNumber,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class PayoutMethodService {
  static final PayoutMethodService _instance = PayoutMethodService._internal();

  factory PayoutMethodService() {
    return _instance;
  }

  PayoutMethodService._internal();

  static const List<String> allowedProviders = [
    'GCash',
    'Maya',
    'MariBank',
    'GoTyme',
  ];

  final _supabase = Supabase.instance.client;

  String _localKey(String userId) => 'payout_methods_$userId';

  /// Fetch all linked payout methods for a user
  Future<List<PayoutMethod>> getPayoutMethods(String userId) async {
    if (userId.isEmpty) return [];

    try {
      // 1. Try reading from Supabase auth user_metadata if current user matches
      final user = _supabase.auth.currentUser;
      if (user != null && user.id == userId) {
        final meta = user.userMetadata?['payout_methods'];
        if (meta is List && meta.isNotEmpty) {
          final list = meta
              .map((e) => PayoutMethod.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          await _saveToLocalCache(userId, list);
          return list;
        }
      }

      // 2. Try reading from public.users table raw_user_meta_data
      final userRow = await _supabase
          .from('users')
          .select('raw_user_meta_data')
          .eq('id', userId)
          .maybeSingle();

      if (userRow != null && userRow['raw_user_meta_data'] != null) {
        final rawMeta = userRow['raw_user_meta_data'];
        if (rawMeta is Map && rawMeta['payout_methods'] is List) {
          final list = (rawMeta['payout_methods'] as List)
              .map((e) => PayoutMethod.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          await _saveToLocalCache(userId, list);
          return list;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching payout methods from cloud users table: $e');
    }

    // 3. Check storage bucket & table fallback for direct QR Code image
    final cached = await _getFromLocalCache(userId);
    if (cached.isNotEmpty) return cached;

    final discoveredQrUrl = await getRenterQrCodeUrl(userId);
    if (discoveredQrUrl != null && discoveredQrUrl.isNotEmpty) {
      return [
        PayoutMethod(
          id: 'payout_discovered_${userId.substring(0, 4)}',
          provider: 'GCash',
          accountName: 'Linked Account',
          accountNumber: '',
          qrCodeUrl: discoveredQrUrl,
          isDefault: true,
          createdAt: DateTime.now(),
        ),
      ];
    }

    return cached;
  }

  /// Get direct uploaded QR Code URL for a user from storage or metadata tables
  Future<String?> getRenterQrCodeUrl(String userId, {String provider = 'GCash'}) async {
    if (userId.isEmpty) return null;

    // A. Check cloud storage buckets for uploaded QR code file
    const buckets = [
      'partner_documents',
      'driver_documents',
      'documents',
      'avatars',
      'vehicle_images',
      'reservation_qr_codes',
    ];

    for (final bucket in buckets) {
      try {
        final files = await _supabase.storage.from(bucket).list(path: 'payout_qrs/$userId');
        if (files.isNotEmpty) {
          final qrFile = files.firstWhere(
            (f) =>
                f.name.toLowerCase().endsWith('.png') ||
                f.name.toLowerCase().endsWith('.jpg') ||
                f.name.toLowerCase().endsWith('.jpeg') ||
                f.name.toLowerCase().endsWith('.webp'),
            orElse: () => files.first,
          );
          final path = 'payout_qrs/$userId/${qrFile.name}';
          final publicUrl = _supabase.storage.from(bucket).getPublicUrl(path);
          if (publicUrl.isNotEmpty) return publicUrl;
        }
      } catch (_) {}
    }

    // B. Check public.users table raw_user_meta_data
    try {
      final userRow = await _supabase
          .from('users')
          .select('raw_user_meta_data')
          .eq('id', userId)
          .maybeSingle();

      final meta = userRow?['raw_user_meta_data'];
      if (meta is Map) {
        final qr = meta['qr_code_url'] ??
            meta['gcash_qr_url'] ??
            meta['payout_qr_url'] ??
            meta['qr_url'];
        if (qr != null && qr.toString().trim().isNotEmpty) {
          return qr.toString().trim();
        }
      }
    } catch (_) {}

    // C. Check renters & user_verifications tables
    try {
      final renterRow = await _supabase
          .from('renters')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();
      if (renterRow != null) {
        final qr = renterRow['qr_code_url'] ??
            renterRow['gcash_qr_url'] ??
            renterRow['payout_qr_url'] ??
            renterRow['qr_url'];
        if (qr != null && qr.toString().trim().isNotEmpty) {
          return qr.toString().trim();
        }
      }
    } catch (_) {}

    try {
      final verRow = await _supabase
          .from('user_verifications')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();
      if (verRow != null) {
        final qr = verRow['qr_code_url'] ??
            verRow['gcash_qr_url'] ??
            verRow['payment_qr_url'] ??
            verRow['payout_qr_url'];
        if (qr != null && qr.toString().trim().isNotEmpty) {
          return qr.toString().trim();
        }
      }
    } catch (_) {}

    return null;
  }

  /// Add or update a payout method
  Future<List<PayoutMethod>> savePayoutMethod({
    required String userId,
    required String provider,
    required String accountName,
    required String accountNumber,
    String? qrCodeUrl,
    bool isDefault = false,
  }) async {
    final cleanProvider = provider.trim();
    if (!allowedProviders.contains(cleanProvider)) {
      throw Exception('Invalid payment provider. Allowed: ${allowedProviders.join(', ')}');
    }

    final cleanName = accountName.trim();
    if (cleanName.isEmpty) {
      throw Exception('Please enter the account name.');
    }

    final cleanNumber = accountNumber.replaceAll(RegExp(r'\D'), '').trim();
    if (cleanNumber.length != 11) {
      throw Exception('Account number must be exactly 11 digits (e.g. 09171234567).');
    }

    final existing = await getPayoutMethods(userId);
    final shouldBeDefault = isDefault || existing.isEmpty;

    final newMethod = PayoutMethod(
      id: 'payout_${DateTime.now().millisecondsSinceEpoch}',
      provider: cleanProvider,
      accountName: cleanName,
      accountNumber: cleanNumber,
      qrCodeUrl: qrCodeUrl?.trim(),
      isDefault: shouldBeDefault,
      createdAt: DateTime.now(),
    );

    final updated = existing.map((m) {
      if (shouldBeDefault) {
        return m.copyWith(isDefault: false);
      }
      return m;
    }).toList();

    updated.insert(0, newMethod);

    await _persistMethods(userId, updated);
    return updated;
  }

  /// Delete a linked payout method
  Future<List<PayoutMethod>> deletePayoutMethod(String userId, String methodId) async {
    final existing = await getPayoutMethods(userId);
    final filtered = existing.where((m) => m.id != methodId).toList();

    // If we deleted the default, set the first remaining as default
    if (filtered.isNotEmpty && !filtered.any((m) => m.isDefault)) {
      filtered[0] = filtered[0].copyWith(isDefault: true);
    }

    await _persistMethods(userId, filtered);
    return filtered;
  }

  /// Set a payout method as default
  Future<List<PayoutMethod>> setDefault(String userId, String methodId) async {
    final existing = await getPayoutMethods(userId);
    final updated = existing.map((m) {
      return m.copyWith(isDefault: m.id == methodId);
    }).toList();

    await _persistMethods(userId, updated);
    return updated;
  }

  /// Upload QR Code image to Supabase Storage
  Future<String> uploadQrCode({
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final filename = 'payout_qr_${userId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final path = 'payout_qrs/$userId/$filename';

    const buckets = [
      'partner_documents',
      'driver_documents',
      'documents',
      'avatars',
      'vehicle_images',
    ];

    for (final bucket in buckets) {
      try {
        await _supabase.storage.from(bucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: 'image/$extension',
                upsert: true,
              ),
            );
        return _supabase.storage.from(bucket).getPublicUrl(path);
      } catch (e) {
        debugPrint('ℹ️ Payout QR upload tried $bucket: $e');
      }
    }

    throw Exception('Failed to upload QR code to cloud storage. Please check your internet connection or try again.');
  }

  Future<void> _persistMethods(String userId, List<PayoutMethod> methods) async {
    // 1. Save to local cache
    await _saveToLocalCache(userId, methods);

    final jsonList = methods.map((m) => m.toJson()).toList();

    // 2. Save to auth user metadata if updating self
    try {
      final user = _supabase.auth.currentUser;
      if (user != null && user.id == userId) {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {'payout_methods': jsonList},
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error updating user metadata payout methods: $e');
    }

    // 3. Sync to public.users raw_user_meta_data so operators/admins/drivers can query it
    try {
      final userRow = await _supabase
          .from('users')
          .select('raw_user_meta_data')
          .eq('id', userId)
          .maybeSingle();

      Map<String, dynamic> currentMeta = {};
      if (userRow != null && userRow['raw_user_meta_data'] is Map) {
        currentMeta = Map<String, dynamic>.from(userRow['raw_user_meta_data'] as Map);
      }
      currentMeta['payout_methods'] = jsonList;

      final defaultMethod = methods.firstWhere(
        (m) => m.isDefault && m.qrCodeUrl != null && m.qrCodeUrl!.trim().isNotEmpty,
        orElse: () => methods.firstWhere(
          (m) => m.qrCodeUrl != null && m.qrCodeUrl!.trim().isNotEmpty,
          orElse: () => methods.first,
        ),
      );
      if (defaultMethod.qrCodeUrl != null && defaultMethod.qrCodeUrl!.trim().isNotEmpty) {
        currentMeta['qr_code_url'] = defaultMethod.qrCodeUrl;
        currentMeta['gcash_qr_url'] = defaultMethod.qrCodeUrl;
      }

      await _supabase
          .from('users')
          .update({'raw_user_meta_data': currentMeta})
          .eq('id', userId);
    } catch (e) {
      debugPrint('⚠️ Error updating public.users raw_user_meta_data: $e');
    }

    // 4. Sync to public.renters table
    try {
      final defaultMethod = methods.firstWhere(
        (m) => m.isDefault && m.qrCodeUrl != null && m.qrCodeUrl!.trim().isNotEmpty,
        orElse: () => methods.firstWhere(
          (m) => m.qrCodeUrl != null && m.qrCodeUrl!.trim().isNotEmpty,
          orElse: () => methods.first,
        ),
      );
      if (defaultMethod.qrCodeUrl != null && defaultMethod.qrCodeUrl!.trim().isNotEmpty) {
        await _supabase
            .from('renters')
            .update({
              'qr_code_url': defaultMethod.qrCodeUrl,
              'gcash_qr_url': defaultMethod.qrCodeUrl,
            })
            .eq('user_id', userId);
      }
    } catch (_) {}
  }

  Future<void> _saveToLocalCache(String userId, List<PayoutMethod> methods) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(methods.map((m) => m.toJson()).toList());
      await prefs.setString(_localKey(userId), jsonStr);
    } catch (e) {
      debugPrint('⚠️ Error saving payout methods cache: $e');
    }
  }

  Future<List<PayoutMethod>> _getFromLocalCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_localKey(userId));
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List;
        return decoded
            .map((e) => PayoutMethod.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ Error reading payout methods cache: $e');
    }
    return [];
  }

  /// Fetch all refund and disbursement history for a user based on their role
  Future<List<Map<String, dynamic>>> getRefundAndDisbursementHistory({
    required String userId,
    required String role,
  }) async {
    if (userId.isEmpty) return [];

    final normalizedRole = role.toLowerCase().trim();
    final records = <Map<String, dynamic>>[];

    try {
      if (normalizedRole == 'renter') {
        // 1. Fetch renter's bookings with refunds or security deposit refunds
        final response = await _supabase
            .from('bookings')
            .select('''
              id,
              booking_reference,
              start_date,
              end_date,
              total_cost,
              status,
              security_deposit_status,
              security_deposit_refunded,
              security_deposit_refund_amount,
              security_deposit_refund_deduction,
              security_deposit_refund_notes,
              security_deposit_refund_method,
              security_deposit_refund_ref,
              security_deposit_refund_receipt_url,
              security_deposit_refunded_at,
              refund_completed,
              refund_amount,
              refund_method,
              refund_ref,
              refund_reference,
              refund_receipt_url,
              refund_reason,
              refunded_at,
              created_at,
              vehicles:vehicle_id (
                id, brand, model, year, plate_number,
                vehicle_images (image_url, display_order)
              )
            ''')
            .eq('renter_id', userId)
            .order('created_at', ascending: false);

        for (final b in List<Map<String, dynamic>>.from(response)) {
          final veh = b['vehicles'] as Map<String, dynamic>?;
          final vehicleName = '${veh?['brand'] ?? ''} ${veh?['model'] ?? ''}'.trim();
          final bookingId = b['id']?.toString() ?? '';

          // A: Security deposit refund
          if (b['security_deposit_refunded'] == true ||
              ((b['security_deposit_refund_amount'] as num?)?.toDouble() ?? 0) > 0) {
            final amt = (b['security_deposit_refund_amount'] as num?)?.toDouble() ?? 0.0;
            final ded = (b['security_deposit_refund_deduction'] as num?)?.toDouble() ?? 0.0;
            records.add({
              'id': 'sec_dep_$bookingId',
              'booking_id': bookingId,
              'booking_reference': b['booking_reference'] ?? (bookingId.isNotEmpty ? bookingId.substring(0, bookingId.length > 8 ? 8 : bookingId.length) : '—'),
              'category': 'security_deposit',
              'title': 'Security Deposit Refund',
              'amount': amt,
              'deduction': ded,
              'deduction_notes': b['security_deposit_refund_notes']?.toString(),
              'method': b['security_deposit_refund_method']?.toString() ?? 'GCash',
              'reference_number': b['security_deposit_refund_ref']?.toString() ?? '—',
              'receipt_url': b['security_deposit_refund_receipt_url']?.toString(),
              'date': b['security_deposit_refunded_at'] ?? b['created_at'],
              'vehicle_name': vehicleName.isNotEmpty ? vehicleName : 'Rental Vehicle',
              'plate_number': veh?['plate_number']?.toString() ?? '',
              'status': 'Completed',
            });
          }

          // B: General / cancellation refund
          if (b['refund_completed'] == true ||
              ((b['refund_amount'] as num?)?.toDouble() ?? 0) > 0) {
            final amt = (b['refund_amount'] as num?)?.toDouble() ?? 0.0;
            records.add({
              'id': 'booking_refund_$bookingId',
              'booking_id': bookingId,
              'booking_reference': b['booking_reference'] ?? (bookingId.isNotEmpty ? bookingId.substring(0, bookingId.length > 8 ? 8 : bookingId.length) : '—'),
              'category': 'booking_refund',
              'title': 'Booking Cancellation Refund',
              'amount': amt,
              'deduction': 0.0,
              'deduction_notes': b['refund_reason']?.toString(),
              'method': b['refund_method']?.toString() ?? 'GCash',
              'reference_number': b['refund_ref']?.toString() ?? b['refund_reference']?.toString() ?? '—',
              'receipt_url': b['refund_receipt_url']?.toString(),
              'date': b['refunded_at'] ?? b['created_at'],
              'vehicle_name': vehicleName.isNotEmpty ? vehicleName : 'Rental Vehicle',
              'plate_number': veh?['plate_number']?.toString() ?? '',
              'status': 'Completed',
            });
          }
        }
      } else if (normalizedRole == 'partner') {
        // Partner payouts from booking_payouts table
        try {
          final payoutsRes = await _supabase
              .from('booking_payouts')
              .select('''
                *,
                bookings:booking_id (
                  id,
                  booking_reference,
                  vehicles:vehicle_id (
                    id, brand, model, year, plate_number
                  )
                )
              ''')
              .eq('recipient_user_id', userId)
              .order('released_at', ascending: false);

          for (final p in List<Map<String, dynamic>>.from(payoutsRes)) {
            final b = p['bookings'] as Map<String, dynamic>?;
            final veh = b?['vehicles'] as Map<String, dynamic>?;
            final vehicleName = '${veh?['brand'] ?? ''} ${veh?['model'] ?? ''}'.trim();
            final meta = p['metadata'] as Map<String, dynamic>? ?? {};
            final bid = p['booking_id']?.toString() ?? '';

            records.add({
              'id': p['id']?.toString() ?? '',
              'booking_id': bid,
              'booking_reference': b?['booking_reference'] ?? (bid.isNotEmpty ? bid.substring(0, bid.length > 8 ? 8 : bid.length) : '—'),
              'category': 'partner_payout',
              'title': 'Vehicle Commission Payout',
              'amount': (p['net_amount'] as num?)?.toDouble() ?? 0.0,
              'gross_amount': (p['gross_amount'] as num?)?.toDouble() ?? 0.0,
              'deduction': (p['deductions'] as num?)?.toDouble() ?? 0.0,
              'method': meta['payment_method']?.toString() ?? 'GCash',
              'reference_number': meta['reference_number']?.toString() ?? '—',
              'receipt_url': meta['receipt_url']?.toString(),
              'date': p['released_at'] ?? p['created_at'],
              'vehicle_name': vehicleName.isNotEmpty ? vehicleName : (meta['vehicle_title']?.toString() ?? 'Partner Vehicle'),
              'plate_number': veh?['plate_number']?.toString() ?? '',
              'status': p['status']?.toString() == 'released' ? 'Completed' : (p['status']?.toString() ?? 'Completed'),
            });
          }
        } catch (_) {}

        // Fallback: check bookings directly
        if (records.isEmpty) {
          try {
            final vehRes = await _supabase
                .from('vehicles')
                .select('id, brand, model, plate_number')
                .or('owner_id.eq.$userId,partner_id.eq.$userId');
            final vehList = List<Map<String, dynamic>>.from(vehRes);
            final vMap = {for (final v in vehList) v['id']?.toString() ?? '': v};
            final vIds = vMap.keys.where((k) => k.isNotEmpty).toList();

            if (vIds.isNotEmpty) {
              final bRes = await _supabase
                  .from('bookings')
                  .select('*')
                  .inFilter('vehicle_id', vIds)
                  .eq('partner_payout_disbursed', true)
                  .order('partner_payout_disbursed_at', ascending: false);

              for (final b in List<Map<String, dynamic>>.from(bRes)) {
                final vid = b['vehicle_id']?.toString() ?? '';
                final veh = vMap[vid];
                final vehicleName = '${veh?['brand'] ?? ''} ${veh?['model'] ?? ''}'.trim();
                final bookingId = b['id']?.toString() ?? '';
                records.add({
                  'id': 'partner_booking_$bookingId',
                  'booking_id': bookingId,
                  'booking_reference': b['booking_reference'] ?? (bookingId.isNotEmpty ? bookingId.substring(0, bookingId.length > 8 ? 8 : bookingId.length) : '—'),
                  'category': 'partner_payout',
                  'title': 'Vehicle Commission Payout',
                  'amount': (b['partner_payout_amount'] as num?)?.toDouble() ?? 0.0,
                  'deduction': (b['partner_payout_commission'] as num?)?.toDouble() ?? 0.0,
                  'method': b['partner_payout_method']?.toString() ?? 'GCash',
                  'reference_number': b['partner_payout_ref']?.toString() ?? '—',
                  'receipt_url': b['partner_payout_receipt_url']?.toString(),
                  'date': b['partner_payout_disbursed_at'] ?? b['updated_at'] ?? b['created_at'],
                  'vehicle_name': vehicleName.isNotEmpty ? vehicleName : 'Partner Vehicle',
                  'plate_number': veh?['plate_number']?.toString() ?? '',
                  'status': 'Completed',
                });
              }
            }
          } catch (_) {}
        }
      } else if (normalizedRole == 'driver') {
        // Driver earnings from driver_earnings table
        try {
          final earningsRes = await _supabase
              .from('driver_earnings')
              .select('''
                *,
                bookings:booking_id (
                  id,
                  booking_reference,
                  vehicles:vehicle_id (
                    id, brand, model, year, plate_number
                  )
                )
              ''')
              .eq('driver_id', userId)
              .order('paid_at', ascending: false);

          for (final e in List<Map<String, dynamic>>.from(earningsRes)) {
            final b = e['bookings'] as Map<String, dynamic>?;
            final veh = b?['vehicles'] as Map<String, dynamic>?;
            final vehicleName = '${veh?['brand'] ?? ''} ${veh?['model'] ?? ''}'.trim();
            final bookingId = e['booking_id']?.toString() ?? '';

            records.add({
              'id': e['id']?.toString() ?? '',
              'booking_id': bookingId,
              'booking_reference': b?['booking_reference'] ?? (bookingId.isNotEmpty ? bookingId.substring(0, bookingId.length > 8 ? 8 : bookingId.length) : '—'),
              'category': 'driver_payout',
              'title': 'Driver Trip Fee Payout',
              'amount': (e['net_earnings'] as num?)?.toDouble() ?? 0.0,
              'gross_amount': (e['trip_fee'] as num?)?.toDouble() ?? 0.0,
              'deduction': (e['commission_amount'] as num?)?.toDouble() ?? 0.0,
              'method': e['payout_method']?.toString() ?? 'GCash',
              'reference_number': e['payout_ref']?.toString() ?? '—',
              'receipt_url': e['payout_receipt_url']?.toString(),
              'date': e['paid_at'] ?? e['created_at'],
              'vehicle_name': vehicleName.isNotEmpty ? vehicleName : 'Trip Vehicle',
              'plate_number': veh?['plate_number']?.toString() ?? '',
              'status': e['payout_status']?.toString() == 'paid' ? 'Completed' : (e['payout_status']?.toString() ?? 'Completed'),
            });
          }
        } catch (_) {}

        // Fallback: check bookings directly
        if (records.isEmpty) {
          try {
            final bRes = await _supabase
                .from('bookings')
                .select('''
                  id,
                  booking_reference,
                  driver_payout_disbursed,
                  driver_payout_amount,
                  driver_payout_method,
                  driver_payout_ref,
                  driver_payout_receipt_url,
                  driver_payout_disbursed_at,
                  updated_at,
                  created_at,
                  vehicles:vehicle_id (
                    id, brand, model, year, plate_number
                  )
                ''')
                .or('driver_id.eq.$userId,assigned_driver_id.eq.$userId')
                .eq('driver_payout_disbursed', true)
                .order('driver_payout_disbursed_at', ascending: false);

            for (final b in List<Map<String, dynamic>>.from(bRes)) {
              final veh = b['vehicles'] as Map<String, dynamic>?;
              final vehicleName = '${veh?['brand'] ?? ''} ${veh?['model'] ?? ''}'.trim();
              final bookingId = b['id']?.toString() ?? '';
              records.add({
                'id': 'driver_booking_$bookingId',
                'booking_id': bookingId,
                'booking_reference': b['booking_reference'] ?? (bookingId.isNotEmpty ? bookingId.substring(0, bookingId.length > 8 ? 8 : bookingId.length) : '—'),
                'category': 'driver_payout',
                'title': 'Driver Trip Fee Payout',
                'amount': (b['driver_payout_amount'] as num?)?.toDouble() ?? 0.0,
                'method': b['driver_payout_method']?.toString() ?? 'GCash',
                'reference_number': b['driver_payout_ref']?.toString() ?? '—',
                'receipt_url': b['driver_payout_receipt_url']?.toString(),
                'date': b['driver_payout_disbursed_at'] ?? b['updated_at'] ?? b['created_at'],
                'vehicle_name': vehicleName.isNotEmpty ? vehicleName : 'Trip Vehicle',
                'plate_number': veh?['plate_number']?.toString() ?? '',
                'status': 'Completed',
              });
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error loading refund and disbursement history: $e');
    }

    // Sort all records descending by date
    records.sort((a, b) {
      final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(1970);
      final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(1970);
      return db.compareTo(da);
    });

    return records;
  }
}
