import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@immutable
class SupportFaq {
  final String key;
  final String question;
  final String answer;

  const SupportFaq({
    required this.key,
    required this.question,
    required this.answer,
  });

  SupportFaq copyWith({String? answer}) =>
      SupportFaq(key: key, question: question, answer: answer ?? this.answer);
}

class SupportFaqService {
  static const _roles = ['renter', 'partner', 'driver'];

  final SupabaseClient _supabase;

  SupportFaqService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  static List<SupportFaq> defaultsForRole(String role) {
    switch (_normalizeRole(role)) {
      case 'partner':
        return const [
          SupportFaq(
            key: 'required_documents',
            question: 'What documents are needed to become a partner?',
            answer:
                'Complete identity verification and submit the requested business and vehicle ownership records. Vehicle applications normally require clear OR/CR files, ownership or authorization proof, and complete vehicle photos. The review screen will show any additional required document.',
          ),
          SupportFaq(
            key: 'add_vehicle',
            question: 'How do I add a vehicle to Mobilis?',
            answer:
                'Open Manage Vehicles, start a vehicle application, complete every vehicle detail, and upload all required photos and documents. The vehicle stays under review until an admin approves it.',
          ),
          SupportFaq(
            key: 'price_change',
            question: 'How can I change my vehicle rental price?',
            answer:
                'Partners cannot directly finalize a price change. Use Customer Service to request the new price. The admin will review it and pass the approved change to the operator.',
          ),
          SupportFaq(
            key: 'availability_tracking',
            question: 'How do availability and active-rental tracking work?',
            answer:
                'Set available dates from Manage Vehicles. An unavailable vehicle cannot be booked. During an active approved rental, use the booking Track action to view the latest authorized vehicle location.',
          ),
        ];
      case 'driver':
        return const [
          SupportFaq(
            key: 'driver_application',
            question: 'How do I apply as a Mobilis certified driver?',
            answer:
                'Open Application, complete all application steps, review your information, and submit it. Your account remains a basic driver until the application is approved.',
          ),
          SupportFaq(
            key: 'driver_documents',
            question: 'What documents are required for a driver application?',
            answer:
                'Prepare your valid driver license front and back, license number and expiry date, face selfie, selfie holding your ID, NBI clearance, digital signature, and professional driving information.',
          ),
          SupportFaq(
            key: 'work_availability',
            question: 'How do I set my work availability?',
            answer:
                'Open Availability, turn your availability on, and select every date you are available to accept trips. Operators can only assign you for eligible available dates.',
          ),
          SupportFaq(
            key: 'trip_updates',
            question: 'Where can I see assigned trips and application updates?',
            answer:
                'Assigned trips appear in My Bookings. Application decisions, assignments, document renewal reminders, and trip updates are also sent to Notifications.',
          ),
        ];
      default:
        return const [
          SupportFaq(
            key: 'rent_vehicle',
            question: 'How do I rent a vehicle?',
            answer:
                'Verify your account, choose a vehicle, select available dates and service options, complete the required traveler and safety information, then submit the booking and payment details for review.',
          ),
          SupportFaq(
            key: 'booking_requirements',
            question: 'What information is required before booking?',
            answer:
                'You need valid identity verification, the required booking documents, a digital signature, emergency contact details, and complete co-traveler information. A driver license is also required when applicable.',
          ),
          SupportFaq(
            key: 'delivery_fee',
            question: 'How is the vehicle delivery fee calculated?',
            answer:
                'Vehicle delivery costs PHP 75 per kilometer. The booking summary shows the delivery distance, the PHP 75 rate, and the calculated total before confirmation.',
          ),
          SupportFaq(
            key: 'cancellation_refunds',
            question: 'How do cancellation and refunds work?',
            answer:
                'Open the booking details and use Cancel Request when cancellation is still allowed. The applicable refund depends on the booking status, payment stage, and cancellation rules shown before you confirm.',
          ),
        ];
    }
  }

  Future<List<SupportFaq>> getFaqs(String role) async {
    final normalizedRole = _normalizeRole(role);
    final defaults = defaultsForRole(normalizedRole);
    final keys = defaults.map((faq) => _settingKey(normalizedRole, faq.key));
    try {
      final rows = await _supabase
          .from('app_settings')
          .select('key,value')
          .inFilter('key', keys.toList());
      final values = {
        for (final row in List<Map<String, dynamic>>.from(rows))
          row['key']?.toString() ?? '': row['value']?.toString() ?? '',
      };
      return defaults
          .map(
            (faq) => faq.copyWith(
              answer:
                  values[_settingKey(normalizedRole, faq.key)]
                          ?.trim()
                          .isNotEmpty ==
                      true
                  ? values[_settingKey(normalizedRole, faq.key)]!.trim()
                  : faq.answer,
            ),
          )
          .toList();
    } catch (error) {
      debugPrint('Unable to load support FAQs, using defaults: $error');
      return defaults;
    }
  }

  Future<Map<String, List<SupportFaq>>> getAllFaqs() async {
    final entries = await Future.wait(
      _roles.map((role) async => MapEntry(role, await getFaqs(role))),
    );
    return Map.fromEntries(entries);
  }

  Future<void> updateFaqs(String role, List<SupportFaq> faqs) async {
    final normalizedRole = _normalizeRole(role);
    final userId = _supabase.auth.currentUser?.id;
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = faqs.map((faq) {
      final answer = faq.answer.trim();
      if (answer.isEmpty) {
        throw Exception('FAQ answers cannot be empty.');
      }
      return {
        'key': _settingKey(normalizedRole, faq.key),
        'value': answer,
        'description': 'Customer support auto-reply for ${faq.question}',
        'updated_by': userId,
        'updated_at': now,
      };
    }).toList();
    await _supabase.from('app_settings').upsert(rows, onConflict: 'key');
  }

  static String _normalizeRole(String role) {
    final normalized = role.trim().toLowerCase();
    return _roles.contains(normalized) ? normalized : 'renter';
  }

  static String _settingKey(String role, String faqKey) =>
      'support_faq_${role}_$faqKey';
}
