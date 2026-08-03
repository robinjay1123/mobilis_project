import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'notification_permission_service.dart';
import 'notification_service.dart';

class RenterPromoPrompt {
  final String title;
  final String message;
  final String locationTag;
  final String iconEmoji;

  const RenterPromoPrompt({
    required this.title,
    required this.message,
    required this.locationTag,
    required this.iconEmoji,
  });
}

class RenterMarketingNotificationService {
  static final RenterMarketingNotificationService _instance =
      RenterMarketingNotificationService._internal();

  factory RenterMarketingNotificationService() => _instance;

  RenterMarketingNotificationService._internal();

  static const String _lastSentDateKey = 'renter_marketing_last_sent_date';
  static const String _lastPromptIndexKey = 'renter_marketing_last_prompt_index';

  final List<RenterPromoPrompt> _prompts = const [
    RenterPromoPrompt(
      title: 'Patar Golden Sunset Calling! 🌅🏖️',
      message:
          'Ready for a beach road trip? Rent a comfortable vehicle with Mobilis today and head to Bolinao’s Patar Beach & Enchanted Cave!',
      locationTag: 'Bolinao',
      iconEmoji: '🏖️',
    ),
    RenterPromoPrompt(
      title: 'Island Hopping Adventure! 🏝️⛵',
      message:
          'Pack your bags! Book your ride on Mobilis now and explore the world-famous Hundred Islands in Alaminos City.',
      locationTag: 'Alaminos',
      iconEmoji: '🏝️',
    ),
    RenterPromoPrompt(
      title: 'Pilgrimage & Food Trip Day! ⛩️🐟',
      message:
          'Time for a spiritual drive & seafood feast! Visit Manaoag Basilica and grab fresh Dagupan bangus with a Mobilis car.',
      locationTag: 'Manaoag & Dagupan',
      iconEmoji: '🐟',
    ),
    RenterPromoPrompt(
      title: 'Escape to Cool Baguio Mountain Breezes! 🌲⛰️',
      message:
          'Beat the heat! Rent a smooth SUV on Mobilis for a scenic drive up to Baguio City, Burnham Park, and Strawberry Farm.',
      locationTag: 'Baguio',
      iconEmoji: '🌲',
    ),
    RenterPromoPrompt(
      title: 'Surf, Sunsets & Good Vibes in Elyu! 🏄‍♂️🌊',
      message:
          'Weekend beach trip! Grab a rental car from Mobilis and cruise down to San Juan, La Union for surf and coastal dining.',
      locationTag: 'La Union',
      iconEmoji: '🏄‍♂️',
    ),
    RenterPromoPrompt(
      title: 'Discover Hidden Paradise in Dasol! 🏖️✨',
      message:
          'Unwind at Tambobong White Sand Beach & Colibra Island. Rent a reliable ride on Mobilis and start your coastal journey!',
      locationTag: 'Dasol',
      iconEmoji: '🏖️',
    ),
    RenterPromoPrompt(
      title: 'Breathtaking Cape Bolinao Views! 🗼🌊',
      message:
          'Marvel at the ocean horizon from Cape Bolinao Lighthouse! Easy hourly and daily rentals available on Mobilis.',
      locationTag: 'Bolinao',
      iconEmoji: '🗼',
    ),
    RenterPromoPrompt(
      title: 'Coastal Breeze & Sunset Walk in Lingayen! 🏛️🌅',
      message:
          'Take a relaxed afternoon drive to Lingayen Capitol Beach Park. Find your ideal ride on Mobilis today!',
      locationTag: 'Lingayen',
      iconEmoji: '🌅',
    ),
    RenterPromoPrompt(
      title: 'Pangasinan Food Crawl Road Trip! 🍲😋',
      message:
          'Hungry for an adventure? Drive to Calasiao for fresh puto and Mangaldan for authentic tupig with Mobilis!',
      locationTag: 'Calasiao & Mangaldan',
      iconEmoji: '🍲',
    ),
    RenterPromoPrompt(
      title: 'Quick Beach Escape to San Fabian! 🌊🚴',
      message:
          'Looking for a breezy day out? Rent a stylish car on Mobilis and cruise along San Fabian’s coastal roads.',
      locationTag: 'San Fabian',
      iconEmoji: '🚴',
    ),
    RenterPromoPrompt(
      title: 'Family Road Trip Time! 🚌👨‍👩‍👧‍👦',
      message:
          'Gather the crew! Rent a spacious van on Mobilis for a fun-filled tour around North Luzon’s top destinations.',
      locationTag: 'Pangasinan',
      iconEmoji: '🚌',
    ),
    RenterPromoPrompt(
      title: 'Zambales Coastal Road Trip! 🚗🏖️',
      message:
          'Feel the wanderlust? Book an affordable daily rental on Mobilis and explore the scenic coastlines of Zambales!',
      locationTag: 'Zambales',
      iconEmoji: '🚘',
    ),
    RenterPromoPrompt(
      title: 'Explore Eastern Pangasinan Eco Parks! 🌿🏞️',
      message:
          'Discover nature & heritage parks in Binalonan and Tayug. Drive with comfort & peace of mind using Mobilis!',
      locationTag: 'Binalonan',
      iconEmoji: '🌿',
    ),
    RenterPromoPrompt(
      title: 'Scenic Harbor & Bay Drive in Sual! 🛳️🌄',
      message:
          'Catch panoramic sea views at Sual & Cabalitian Island. Book a vehicle on Mobilis for a memorable weekend drive!',
      locationTag: 'Sual',
      iconEmoji: '🛳️',
    ),
    RenterPromoPrompt(
      title: 'Where to Next? Your Road Trip Awaits! 🚘✨',
      message:
          'The open road is calling! Rent a car on Mobilis today with transparent 24-hour daily rates and flexible hourly excess!',
      locationTag: 'Mobilis Drive',
      iconEmoji: '✨',
    ),
  ];

  List<RenterPromoPrompt> get allPrompts => _prompts;

  /// Checks if current hour is daytime (8:00 AM to 6:00 PM)
  bool _isDaytime(DateTime now) {
    return now.hour >= 8 && now.hour < 18;
  }

  /// Calculates a randomized daytime target time for the given date.
  /// Uses a deterministic seed so target time for today is fixed.
  DateTime _getDaytimeTargetTimeForDate(DateTime date) {
    final seed = date.year * 10000 + date.month * 100 + date.day;
    final random = Random(seed);
    final targetHour = 8 + random.nextInt(10); // 8 AM to 5 PM (17:xx)
    final targetMinute = random.nextInt(60);
    return DateTime(date.year, date.month, date.day, targetHour, targetMinute);
  }

  /// Checks if a marketing notification should be sent today, and sends it if eligible.
  Future<bool> checkAndTriggerDailyRenterNotification({
    bool force = false,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      // Ensure user is a renter (renters only!)
      final role = await AuthService().getUserRole();
      if (role != 'renter') {
        debugPrint(
          'Skipping marketing notification: user role is $role (renters only)',
        );
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final lastSentDate = prefs.getString(_lastSentDateKey);

      if (!force) {
        // 1. Check if already sent today
        if (lastSentDate == todayStr) {
          debugPrint('Daily renter promo already sent today ($todayStr)');
          return false;
        }

        // 2. Check if current time is daytime (8:00 AM to 6:00 PM)
        if (!_isDaytime(now)) {
          debugPrint(
            'Skipping marketing notification: current hour ${now.hour} is outside daytime window (8 AM - 6 PM)',
          );
          return false;
        }

        // 3. Check if current time reached today's target time slot
        final targetTime = _getDaytimeTargetTimeForDate(now);
        if (now.isBefore(targetTime)) {
          debugPrint(
            'Marketing notification scheduled for later today at ${targetTime.hour}:${targetTime.minute.toString().padLeft(2, '0')}',
          );
          return false;
        }
      }

      // Select a dynamic prompt that changes every time
      final lastIndex = prefs.getInt(_lastPromptIndexKey) ?? -1;

      final seed = now.year * 365 + now.month * 31 + now.day;
      final rng = Random(seed);
      int nextIndex = rng.nextInt(_prompts.length);
      if (nextIndex == lastIndex && _prompts.length > 1) {
        nextIndex = (nextIndex + 1) % _prompts.length;
      }

      final prompt = _prompts[nextIndex];

      debugPrint(
        '🚀 Triggering daily renter marketing notification: ${prompt.title}',
      );

      // Create notification record in Supabase database (PushNotificationService handles system popup)
      await NotificationService().createNotification(
        userId: user.id,
        title: prompt.title,
        message: prompt.message,
        type: 'marketing_promotion',
        data: {
          'promo_type': 'daily_renter_encouragement',
          'location_tag': prompt.locationTag,
          'action_route': '/vehicle-search',
          'event': 'renter_promo',
        },
      );

      // Save history to preferences
      await prefs.setString(_lastSentDateKey, todayStr);
      await prefs.setInt(_lastPromptIndexKey, nextIndex);

      return true;
    } catch (e) {
      debugPrint('Error triggering daily renter marketing notification: $e');
      return false;
    }
  }

  /// Helper to get today's promo message without sending it (e.g. for previews)
  RenterPromoPrompt getTodayPromoPrompt() {
    final now = DateTime.now();
    final seed = now.year * 365 + now.month * 31 + now.day;
    final rng = Random(seed);
    final index = rng.nextInt(_prompts.length);
    return _prompts[index];
  }
}
