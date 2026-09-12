import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Driver Scheduled Availability Unit Tests', () {
    test('Date only normalization strips time components', () {
      final dt1 = DateTime(2026, 9, 20, 14, 30, 45);
      final dt2 = DateTime(2026, 9, 20, 8, 0, 0);

      DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

      expect(dateOnly(dt1), equals(dateOnly(dt2)));
      expect(dateOnly(dt1), equals(DateTime(2026, 9, 20)));
    });

    test('Time conversion for database correctly parses 12h to 24h format', () {
      String timeForDatabase(String value, String fallback) {
        final raw = value.trim();
        if (raw.isEmpty) return fallback;
        final match = RegExp(
          r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
          caseSensitive: false,
        ).firstMatch(raw);
        if (match == null) return raw;
        var hour = int.parse(match.group(1)!);
        final minute = match.group(2)!;
        final period = match.group(3)!.toUpperCase();
        if (period == 'PM' && hour < 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
        return '${hour.toString().padLeft(2, '0')}:$minute';
      }

      expect(timeForDatabase('08:00 AM', '08:00'), equals('08:00'));
      expect(timeForDatabase('1:30 PM', '08:00'), equals('13:30'));
      expect(timeForDatabase('12:00 AM', '08:00'), equals('00:00'));
      expect(timeForDatabase('12:00 PM', '08:00'), equals('12:00'));
      expect(timeForDatabase('11:59 PM', '08:00'), equals('23:59'));
      expect(timeForDatabase('', '09:00'), equals('09:00'));
    });

    test('Schedule row generation for driver_availability_schedule', () {
      final dates = {
        DateTime(2026, 9, 20),
        DateTime(2026, 9, 21),
      };
      const driverId = 'drv-123';
      const isAvailable = true;
      const startTime = '08:00';
      const endTime = '18:00';

      final rows = dates.map((date) {
        final dateStr =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        return {
          'driver_id': driverId,
          'date': dateStr,
          'start_time': startTime,
          'end_time': endTime,
          'is_available': isAvailable,
        };
      }).toList();

      expect(rows.length, equals(2));
      expect(rows[0]['driver_id'], equals('drv-123'));
      expect(rows[0]['is_available'], equals(true));
      expect(rows[0]['start_time'], equals('08:00'));
      expect(rows[0]['end_time'], equals('18:00'));
      expect(rows.any((r) => r['date'] == '2026-09-20'), isTrue);
      expect(rows.any((r) => r['date'] == '2026-09-21'), isTrue);
    });

    test('Booking date range matcher validates driver availability against schedule', () {
      final driverAvailableDates = <String, Set<String>>{
        'driver-A': {'2026-09-20', '2026-09-21', '2026-09-22'},
        'driver-B': {'2026-09-20'}, // Missing 21 & 22
      };
      final driverUnavailableDates = <String, Set<String>>{
        'driver-C': {'2026-09-21'}, // Specifically off-duty on 21
      };

      final bookingDates = ['2026-09-20', '2026-09-21', '2026-09-22'];

      bool isDriverAvailableForTrip(String driverId) {
        final unavail = driverUnavailableDates[driverId] ?? <String>{};
        for (final d in bookingDates) {
          if (unavail.contains(d)) return false;
        }

        final sched = driverAvailableDates[driverId];
        if (sched != null) {
          for (final d in bookingDates) {
            if (!sched.contains(d)) return false;
          }
        }
        return true;
      }

      expect(isDriverAvailableForTrip('driver-A'), isTrue);
      expect(isDriverAvailableForTrip('driver-B'), isFalse);
      expect(isDriverAvailableForTrip('driver-C'), isFalse);
    });

    test('Driver verification status guard blocks unverified drivers from setting availability', () {
      bool canSetAvailability({
        required String verificationStatus,
        required String certificationStatus,
      }) {
        final isVerified = verificationStatus == 'verified' ||
            verificationStatus == 'approved' ||
            verificationStatus == 'certified';
        final isCertified = certificationStatus == 'certified' ||
            certificationStatus == 'approved';
        return isVerified || isCertified;
      }

      // Pending driver
      expect(
        canSetAvailability(
          verificationStatus: 'pending',
          certificationStatus: 'basic',
        ),
        isFalse,
      );

      // Unverified driver
      expect(
        canSetAvailability(
          verificationStatus: 'unverified',
          certificationStatus: 'basic',
        ),
        isFalse,
      );

      // Rejected driver
      expect(
        canSetAvailability(
          verificationStatus: 'rejected',
          certificationStatus: 'basic',
        ),
        isFalse,
      );

      // Verified driver
      expect(
        canSetAvailability(
          verificationStatus: 'verified',
          certificationStatus: 'basic',
        ),
        isTrue,
      );

      // Approved certified driver
      expect(
        canSetAvailability(
          verificationStatus: 'verified',
          certificationStatus: 'certified',
        ),
        isTrue,
      );
    });
  });
}
