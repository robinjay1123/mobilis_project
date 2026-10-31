import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'loyalty_service.dart';

class VoucherModel {
  final String id;
  final String code;
  final String title;
  final String description;
  final double discountPercent;
  final double discountAmount;
  final bool isPercent;
  final int minTripsRequired;
  final double minSpend;
  final DateTime? expiresAt;
  final bool isActive;
  final int? maxUses;
  final int usedCount;
  final String category; // 'seasonal', 'loyalty_milestone', 'promo'
  final DateTime createdAt;
  final DateTime updatedAt;

  const VoucherModel({
    required this.id,
    required this.code,
    required this.title,
    this.description = '',
    this.discountPercent = 0.0,
    this.discountAmount = 0.0,
    this.isPercent = true,
    this.minTripsRequired = 0,
    this.minSpend = 0.0,
    this.expiresAt,
    this.isActive = true,
    this.maxUses,
    this.usedCount = 0,
    this.category = 'seasonal',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get isAvailable =>
      isActive && !isExpired && (maxUses == null || usedCount < maxUses!);

  String get formattedDiscount {
    if (isPercent) {
      final isInt = discountPercent.truncateToDouble() == discountPercent;
      return '${isInt ? discountPercent.toInt() : discountPercent.toStringAsFixed(1)}% OFF';
    } else {
      final isInt = discountAmount.truncateToDouble() == discountAmount;
      return '₱${isInt ? discountAmount.toInt() : discountAmount.toStringAsFixed(2)} OFF';
    }
  }

  String get formattedCategory {
    switch (category) {
      case 'seasonal':
        return 'Seasonal Promo';
      case 'loyalty_milestone':
        return 'Loyalty Milestone';
      case 'promo':
      default:
        return 'Special Promo';
    }
  }

  double calculateDiscount(double subtotal) {
    if (subtotal <= 0) return 0.0;
    if (minSpend > 0 && subtotal < minSpend) return 0.0;

    double discount = 0.0;
    if (isPercent) {
      discount = subtotal * (discountPercent / 100.0);
    } else {
      discount = discountAmount;
    }
    return discount > subtotal ? subtotal : discount;
  }

  LoyaltyVoucher toLoyaltyVoucher() {
    return LoyaltyVoucher(
      id: id,
      code: code,
      title: title,
      description: description,
      discountPercent: discountPercent,
      discountAmount: discountAmount,
      isPercent: isPercent,
      minTripsRequired: minTripsRequired,
      minSpend: minSpend,
      expiresAt: expiresAt,
      isActive: isActive,
      category: category,
    );
  }

  factory VoucherModel.fromLoyaltyVoucher(
    LoyaltyVoucher v, {
    String? id,
    int? maxUses,
    int usedCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return VoucherModel(
      id: id ?? v.id ?? v.code,
      code: v.code.toUpperCase(),
      title: v.title,
      description: v.description,
      discountPercent: v.discountPercent,
      discountAmount: v.discountAmount,
      isPercent: v.isPercent,
      minTripsRequired: v.minTripsRequired,
      minSpend: v.minSpend,
      expiresAt: v.expiresAt,
      isActive: v.isActive,
      maxUses: maxUses,
      usedCount: usedCount,
      category: v.category,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    DateTime? parseDateTime(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString())?.toLocal();
    }

    return VoucherModel(
      id: json['id']?.toString() ?? '',
      code: (json['code']?.toString() ?? '').trim().toUpperCase(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      discountPercent:
          (json['discount_percent'] as num?)?.toDouble() ?? 0.0,
      discountAmount:
          (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      isPercent: json['is_percent'] as bool? ?? true,
      minTripsRequired:
          (json['min_trips_required'] as num?)?.toInt() ?? 0,
      minSpend: (json['min_spend'] as num?)?.toDouble() ?? 0.0,
      expiresAt: parseDateTime(json['expires_at']),
      isActive: json['is_active'] as bool? ?? true,
      maxUses: (json['max_uses'] as num?)?.toInt(),
      usedCount: (json['used_count'] as num?)?.toInt() ?? 0,
      category: json['category']?.toString() ?? 'seasonal',
      createdAt: parseDateTime(json['created_at']) ?? now,
      updatedAt: parseDateTime(json['updated_at']) ?? now,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'code': code.trim().toUpperCase(),
      'title': title.trim(),
      'description': description.trim(),
      'discount_percent': discountPercent,
      'discount_amount': discountAmount,
      'is_percent': isPercent,
      'min_trips_required': minTripsRequired,
      'min_spend': minSpend,
      'expires_at': expiresAt?.toUtc().toIso8601String(),
      'is_active': isActive,
      'max_uses': maxUses,
      'used_count': usedCount,
      'category': category,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  VoucherModel copyWith({
    String? id,
    String? code,
    String? title,
    String? description,
    double? discountPercent,
    double? discountAmount,
    bool? isPercent,
    int? minTripsRequired,
    double? minSpend,
    DateTime? expiresAt,
    bool? clearExpiresAt,
    bool? isActive,
    int? maxUses,
    bool? clearMaxUses,
    int? usedCount,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VoucherModel(
      id: id ?? this.id,
      code: code ?? this.code,
      title: title ?? this.title,
      description: description ?? this.description,
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      isPercent: isPercent ?? this.isPercent,
      minTripsRequired: minTripsRequired ?? this.minTripsRequired,
      minSpend: minSpend ?? this.minSpend,
      expiresAt: clearExpiresAt == true ? null : (expiresAt ?? this.expiresAt),
      isActive: isActive ?? this.isActive,
      maxUses: clearMaxUses == true ? null : (maxUses ?? this.maxUses),
      usedCount: usedCount ?? this.usedCount,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class VoucherValidationResult {
  final bool isValid;
  final String? errorMessage;
  final VoucherModel? voucher;

  const VoucherValidationResult({
    required this.isValid,
    this.errorMessage,
    this.voucher,
  });

  factory VoucherValidationResult.success(VoucherModel voucher) =>
      VoucherValidationResult(isValid: true, voucher: voucher);

  factory VoucherValidationResult.failure(String message) =>
      VoucherValidationResult(isValid: false, errorMessage: message);
}

class VoucherService {
  static final VoucherService _instance = VoucherService._internal();
  factory VoucherService() => _instance;
  VoucherService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Default fallback vouchers in memory (including seasonal summer code)
  static final List<VoucherModel> _defaultFallbackVouchers = [
    VoucherModel(
      id: 'fallback-summer-2026',
      code: 'SUMMER2026',
      title: 'Summer Getaway 15% OFF',
      description: 'Enjoy 15% off your next summer rental trip with PSDC!',
      discountPercent: 15.0,
      discountAmount: 0.0,
      isPercent: true,
      minTripsRequired: 0,
      minSpend: 1000.0,
      expiresAt: DateTime.now().add(const Duration(days: 90)),
      isActive: true,
      category: 'seasonal',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    VoucherModel(
      id: 'fallback-welcome-100',
      code: 'WELCOME100',
      title: 'Welcome to PSDC ₱100 OFF',
      description: '₱100 off your next trip with PSDC!',
      discountPercent: 0.0,
      discountAmount: 100.0,
      isPercent: false,
      minTripsRequired: 0,
      minSpend: 500.0,
      expiresAt: DateTime.now().add(const Duration(days: 180)),
      isActive: true,
      category: 'promo',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    VoucherModel(
      id: 'fallback-psdc-3trips',
      code: 'PSDC3TRIPS10',
      title: '10% OFF Frequent Renter Voucher',
      description: 'Unlocked after 3 completed trips with PSDC!',
      discountPercent: 10.0,
      discountAmount: 0.0,
      isPercent: true,
      minTripsRequired: 3,
      minSpend: 0.0,
      isActive: true,
      category: 'loyalty_milestone',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    VoucherModel(
      id: 'fallback-psdc-5trips',
      code: 'PSDC5TRIPS500',
      title: '₱500 OFF PSDC Loyal Renter Reward',
      description: 'Unlocked after 5 completed trips with PSDC!',
      discountPercent: 0.0,
      discountAmount: 500.0,
      isPercent: false,
      minTripsRequired: 5,
      minSpend: 0.0,
      isActive: true,
      category: 'loyalty_milestone',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    VoucherModel(
      id: 'fallback-psdc-vip',
      code: 'PSDCVIP20',
      title: '20% OFF PSDC VIP Renter Voucher',
      description: 'Unlocked after 10 completed trips with PSDC!',
      discountPercent: 20.0,
      discountAmount: 0.0,
      isPercent: true,
      minTripsRequired: 10,
      minSpend: 0.0,
      isActive: true,
      category: 'loyalty_milestone',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  List<VoucherModel> _memoryVouchers = List.from(_defaultFallbackVouchers);

  /// Fetch all vouchers with optional active filter and category filter
  Future<List<VoucherModel>> getVouchers({
    bool activeOnly = false,
    String? category,
  }) async {
    try {
      var query = _supabase.from('vouchers').select();
      if (activeOnly) {
        query = query.eq('is_active', true);
      }
      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }

      final response = await query.order('created_at', ascending: false);
      final list = (response as List)
          .map((item) => VoucherModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      if (list.isNotEmpty) {
        _memoryVouchers = list;
        return list;
      }
    } catch (e) {
      debugPrint('VoucherService: Using fallback/cached vouchers: $e');
    }

    // Fallback to local memory vouchers
    var result = List<VoucherModel>.from(_memoryVouchers);
    if (activeOnly) {
      result = result.where((v) => v.isActive && !v.isExpired).toList();
    }
    if (category != null && category.isNotEmpty) {
      result = result.where((v) => v.category == category).toList();
    }
    return result;
  }

  /// Get active vouchers applicable to a specific renter based on completed trips
  Future<List<VoucherModel>> getAvailableForRenter({
    required int completedTrips,
    double? subtotal,
  }) async {
    final all = await getVouchers(activeOnly: true);
    return all.where((v) {
      if (v.isExpired) return false;
      if (v.minTripsRequired > completedTrips) return false;
      if (subtotal != null && v.minSpend > 0 && subtotal < v.minSpend) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Find voucher by exact code (case-insensitive)
  Future<VoucherModel?> findByCode(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return null;

    try {
      final response = await _supabase
          .from('vouchers')
          .select()
          .ilike('code', clean)
          .maybeSingle();

      if (response != null) {
        return VoucherModel.fromJson(Map<String, dynamic>.from(response));
      }
    } catch (e) {
      debugPrint('VoucherService: Error querying voucher by code: $e');
    }

    // Check memory list
    return _memoryVouchers.cast<VoucherModel?>().firstWhere(
      (v) => v?.code.toUpperCase() == clean,
      orElse: () => null,
    );
  }

  /// Validate a voucher or promo code entered by a renter
  Future<VoucherValidationResult> validateVoucherCode(
    String rawCode, {
    int completedTrips = 0,
    double subtotal = 0.0,
  }) async {
    final clean = rawCode.trim().toUpperCase();
    if (clean.isEmpty) {
      return VoucherValidationResult.failure('Please enter a voucher code.');
    }

    final voucher = await findByCode(clean);
    if (voucher == null) {
      return VoucherValidationResult.failure(
        'Invalid voucher code. Please check and try again.',
      );
    }

    if (!voucher.isActive) {
      return VoucherValidationResult.failure(
        'This voucher code is currently inactive.',
      );
    }

    if (voucher.isExpired) {
      final expiryStr = voucher.expiresAt != null
          ? DateFormat('MMM d, yyyy').format(voucher.expiresAt!)
          : 'recently';
      return VoucherValidationResult.failure(
        'This voucher code has expired on $expiryStr.',
      );
    }

    if (voucher.maxUses != null && voucher.usedCount >= voucher.maxUses!) {
      return VoucherValidationResult.failure(
        'This promotional voucher has reached its redemption limit.',
      );
    }

    if (completedTrips < voucher.minTripsRequired) {
      return VoucherValidationResult.failure(
        '${voucher.title} requires ${voucher.minTripsRequired} completed trip(s) on your PSDC Loyalty Card. You have $completedTrips trip(s).',
      );
    }

    if (subtotal > 0 && voucher.minSpend > 0 && subtotal < voucher.minSpend) {
      final minSpendStr = NumberFormat('#,##0.00').format(voucher.minSpend);
      return VoucherValidationResult.failure(
        'A minimum rental subtotal of ₱$minSpendStr is required to apply ${voucher.code}.',
      );
    }

    return VoucherValidationResult.success(voucher);
  }

  /// Create a new voucher (Admin)
  Future<VoucherModel> createVoucher(VoucherModel voucher) async {
    final cleanCode = voucher.code.trim().toUpperCase();
    final data = voucher.toJson(includeId: false);
    data['code'] = cleanCode;
    data['created_at'] = DateTime.now().toUtc().toIso8601String();

    try {
      final response =
          await _supabase.from('vouchers').insert(data).select().single();
      final created =
          VoucherModel.fromJson(Map<String, dynamic>.from(response));
      _memoryVouchers.removeWhere((v) => v.code == cleanCode);
      _memoryVouchers.insert(0, created);
      return created;
    } catch (e) {
      debugPrint('VoucherService: Error inserting voucher: $e');
      final fallbackCreated = voucher.copyWith(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        code: cleanCode,
      );
      _memoryVouchers.removeWhere((v) => v.code == cleanCode);
      _memoryVouchers.insert(0, fallbackCreated);
      return fallbackCreated;
    }
  }

  /// Update an existing voucher (Admin)
  Future<VoucherModel> updateVoucher(VoucherModel voucher) async {
    final data = voucher.toJson(includeId: false);

    try {
      final response = await _supabase
          .from('vouchers')
          .update(data)
          .eq('id', voucher.id)
          .select()
          .single();
      final updated =
          VoucherModel.fromJson(Map<String, dynamic>.from(response));
      final idx = _memoryVouchers.indexWhere((v) => v.id == voucher.id);
      if (idx != -1) {
        _memoryVouchers[idx] = updated;
      }
      return updated;
    } catch (e) {
      debugPrint('VoucherService: Error updating voucher: $e');
      final idx = _memoryVouchers.indexWhere((v) => v.id == voucher.id);
      if (idx != -1) {
        _memoryVouchers[idx] = voucher;
      }
      return voucher;
    }
  }

  /// Toggle active/inactive status (Admin)
  Future<void> toggleVoucherStatus(String id, bool isActive) async {
    try {
      await _supabase
          .from('vouchers')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      debugPrint('VoucherService: Error toggling status: $e');
    }
    final idx = _memoryVouchers.indexWhere((v) => v.id == id);
    if (idx != -1) {
      _memoryVouchers[idx] = _memoryVouchers[idx].copyWith(isActive: isActive);
    }
  }

  /// Delete a voucher (Admin)
  Future<void> deleteVoucher(String id) async {
    try {
      await _supabase.from('vouchers').delete().eq('id', id);
    } catch (e) {
      debugPrint('VoucherService: Error deleting voucher: $e');
    }
    _memoryVouchers.removeWhere((v) => v.id == id);
  }

  /// Increment voucher usage counter when a booking is confirmed
  Future<void> recordVoucherUsage(String codeOrId) async {
    final clean = codeOrId.trim();
    if (clean.isEmpty) return;

    try {
      final voucher = await findByCode(clean);
      if (voucher != null) {
        final newCount = voucher.usedCount + 1;
        await _supabase
            .from('vouchers')
            .update({
              'used_count': newCount,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', voucher.id);

        final idx = _memoryVouchers.indexWhere((v) => v.id == voucher.id);
        if (idx != -1) {
          _memoryVouchers[idx] =
              _memoryVouchers[idx].copyWith(usedCount: newCount);
        }
      }
    } catch (e) {
      debugPrint('VoucherService: Error recording usage: $e');
    }
  }
}

