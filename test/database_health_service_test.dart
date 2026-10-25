import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobilis_by_psdc_app/services/database_health_service.dart';

void main() {
  group('DatabaseHealthService.isDatabaseUnhealthyError', () {
    test('returns false for null error', () {
      expect(DatabaseHealthService.isDatabaseUnhealthyError(null), isFalse);
    });

    test('returns false for routine Postgres client errors (e.g. 42703 undefined column)', () {
      const err = PostgrestException(
        message: 'column users.archived_at does not exist',
        code: '42703',
      );
      expect(DatabaseHealthService.isDatabaseUnhealthyError(err), isFalse);
    });

    test('returns false for constraint violation errors (e.g. 23505 unique violation)', () {
      const err = PostgrestException(
        message: 'duplicate key value violates unique constraint "users_email_key"',
        code: '23505',
      );
      expect(DatabaseHealthService.isDatabaseUnhealthyError(err), isFalse);
    });

    test('returns false for PostgREST schema cache errors (e.g. PGRST205 table not found)', () {
      const err = PostgrestException(
        message: "Could not find the table 'public.user_reports' in the schema cache",
        code: 'PGRST205',
      );
      expect(DatabaseHealthService.isDatabaseUnhealthyError(err), isFalse);
    });

    test('returns false for PostgREST 0 rows error (e.g. PGRST116)', () {
      const err = PostgrestException(
        message: 'The result contains 0 rows',
        code: 'PGRST116',
      );
      expect(DatabaseHealthService.isDatabaseUnhealthyError(err), isFalse);
    });

    test('returns false for app-level messages with "database error" or "server error"', () {
      expect(
        DatabaseHealthService.isDatabaseUnhealthyError(
          Exception('Database error fetching user role: User not found'),
        ),
        isFalse,
      );
      expect(
        DatabaseHealthService.isDatabaseUnhealthyError(
          Exception('Server error: invalid email or password'),
        ),
        isFalse,
      );
      expect(
        DatabaseHealthService.isDatabaseUnhealthyError(
          'Maximum allowed length is 500 characters',
        ),
        isFalse,
      );
    });

    test('returns true for genuine PostgreSQL connection faults (08xxx)', () {
      const err = PostgrestException(
        message: 'connection to server was lost',
        code: '08006',
      );
      expect(DatabaseHealthService.isDatabaseUnhealthyError(err), isTrue);
    });

    test('returns true for resource exhaustion (53xxx too many connections)', () {
      const err = PostgrestException(
        message: 'remaining connection slots are reserved for non-replication superuser connections',
        code: '53300',
      );
      expect(DatabaseHealthService.isDatabaseUnhealthyError(err), isTrue);
    });

    test('returns true for operator intervention / shutdown (57xxx)', () {
      const err = PostgrestException(
        message: 'the database system is starting up',
        code: '57P03',
      );
      expect(DatabaseHealthService.isDatabaseUnhealthyError(err), isTrue);
    });

    test('returns true for gateway / HTTP infrastructure outages', () {
      expect(
        DatabaseHealthService.isDatabaseUnhealthyError('HTTP 502 Bad Gateway'),
        isTrue,
      );
      expect(
        DatabaseHealthService.isDatabaseUnhealthyError('Status 503 Service Unavailable'),
        isTrue,
      );
      expect(
        DatabaseHealthService.isDatabaseUnhealthyError('504 Gateway Timeout'),
        isTrue,
      );
      expect(
        DatabaseHealthService.isDatabaseUnhealthyError('500 Internal Server Error'),
        isTrue,
      );
      expect(
        DatabaseHealthService.isDatabaseUnhealthyError('Upstream connect error or disconnect/reset before headers'),
        isTrue,
      );
      expect(
        DatabaseHealthService.isDatabaseUnhealthyError('The database is currently in an unhealthy state.'),
        isTrue,
      );
    });
  });
}
