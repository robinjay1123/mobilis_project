import 'dart:convert';
import 'dart:typed_data';
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
      // 1. Try reading from Supabase user_metadata or partners table
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

      // 2. Try reading from users table
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
      debugPrint('⚠️ Error fetching payout methods from cloud: $e');
    }

    // 3. Fallback to local cache
    return _getFromLocalCache(userId);
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

    // 2. Save to user metadata
    try {
      final jsonList = methods.map((m) => m.toJson()).toList();
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {'payout_methods': jsonList},
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Error updating user metadata payout methods: $e');
    }
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
}
