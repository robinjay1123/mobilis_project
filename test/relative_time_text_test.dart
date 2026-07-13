import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/mobile_ui/widgets/relative_time_text.dart';

void main() {
  test('parses correctly stored UTC message timestamps', () {
    final sentAt = DateTime.now().toUtc().subtract(const Duration(hours: 1));

    final parsed = parseMessageTimestamp(sentAt.toIso8601String());

    expect(parsed, isNotNull);
    expect(
      parsed!.difference(sentAt.toLocal()).inSeconds.abs(),
      lessThanOrEqualTo(1),
    );
  });

  test('recovers legacy local wall-clock timestamps stored as UTC', () {
    final localSentAt = DateTime.now().subtract(const Duration(hours: 1));
    final legacyStoredAt = DateTime.utc(
      localSentAt.year,
      localSentAt.month,
      localSentAt.day,
      localSentAt.hour,
      localSentAt.minute,
      localSentAt.second,
    );

    final parsed = parseMessageTimestamp(legacyStoredAt.toIso8601String());

    expect(parsed, isNotNull);
    expect(parsed!.year, localSentAt.year);
    expect(parsed.month, localSentAt.month);
    expect(parsed.day, localSentAt.day);
    expect(parsed.hour, localSentAt.hour);
    expect(parsed.minute, localSentAt.minute);
  });

  testWidgets('relative message time displays elapsed hours', (tester) async {
    final sentAt = DateTime.now().toUtc().subtract(
      const Duration(hours: 1, minutes: 5),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RelativeTimeText(
          value: sentAt.toIso8601String(),
          style: const TextStyle(),
        ),
      ),
    );

    expect(find.text('1h ago'), findsOneWidget);
  });
}
