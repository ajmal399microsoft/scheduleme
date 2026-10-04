import 'package:flutter_test/flutter_test.dart';

import 'package:schedule_me/models/recurrence_rule.dart';

void main() {
  test('daily recurrence is due on each interval day', () {
    const rule =
        RecurrenceRule(frequency: RecurrenceFrequency.daily, interval: 2);
    final anchor = DateTime(2026, 1, 1);

    expect(rule.isDueOn(DateTime(2026, 1, 1), anchor), isTrue);
    expect(rule.isDueOn(DateTime(2026, 1, 2), anchor), isFalse);
    expect(rule.isDueOn(DateTime(2026, 1, 3), anchor), isTrue);
  });

  test('weekly recurrence respects selected weekdays', () {
    const rule =
        RecurrenceRule(frequency: RecurrenceFrequency.weekly, weekdays: [1, 3]);
    final anchor = DateTime(2026, 1, 5);

    expect(rule.isDueOn(DateTime(2026, 1, 5), anchor), isTrue);
    expect(rule.isDueOn(DateTime(2026, 1, 6), anchor), isFalse);
  });

  test('one-time recurrence is due only on its chosen date', () {
    const rule = RecurrenceRule(frequency: RecurrenceFrequency.once);
    final anchor = DateTime(2026, 4, 12, 14, 30);

    expect(rule.isDueOn(DateTime(2026, 4, 12), anchor), isTrue);
    expect(rule.isDueOn(DateTime(2026, 4, 13), anchor), isFalse);
  });

  test('custom daily interval and end date are respected', () {
    final rule = RecurrenceRule(
      frequency: RecurrenceFrequency.daily,
      interval: 3,
      endDate: DateTime(2026, 4, 18),
    );
    final anchor = DateTime(2026, 4, 12, 8);

    expect(rule.isDueOn(DateTime(2026, 4, 15), anchor), isTrue);
    expect(rule.isDueOn(DateTime(2026, 4, 16), anchor), isFalse);
    expect(rule.isDueOn(DateTime(2026, 4, 21), anchor), isFalse);
  });

  test('weekly intervals are counted by calendar week', () {
    const rule = RecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      interval: 2,
      weekdays: [1],
    );
    final anchor = DateTime(2026, 1, 5);

    expect(rule.isDueOn(DateTime(2026, 1, 5), anchor), isTrue);
    expect(rule.isDueOn(DateTime(2026, 1, 12), anchor), isFalse);
    expect(rule.isDueOn(DateTime(2026, 1, 19), anchor), isTrue);
  });

  test('a task logged yesterday can next recur two weeks later', () {
    const rule =
        RecurrenceRule(frequency: RecurrenceFrequency.weekly, interval: 2);
    final completedYesterday = DateTime(2026, 1, 5, 18, 30);

    expect(rule.isDueOn(DateTime(2026, 1, 5), completedYesterday), isTrue);
    expect(rule.isDueOn(DateTime(2026, 1, 12), completedYesterday), isFalse);
    expect(rule.isDueOn(DateTime(2026, 1, 19), completedYesterday), isTrue);
  });

  test('yearly recurrence stays on the anniversary', () {
    const rule = RecurrenceRule(frequency: RecurrenceFrequency.yearly);
    final anchor = DateTime(2026, 6, 20, 9);

    expect(rule.isDueOn(DateTime(2027, 6, 20), anchor), isTrue);
    expect(rule.isDueOn(DateTime(2027, 6, 21), anchor), isFalse);
  });

  test('monthly recurrence clamps to the last day of shorter months', () {
    const rule = RecurrenceRule(frequency: RecurrenceFrequency.monthly);
    final anchor = DateTime(2026, 1, 31);

    expect(rule.isDueOn(DateTime(2026, 2, 28), anchor), isTrue);
    expect(rule.isDueOn(DateTime(2026, 2, 27), anchor), isFalse);
  });

  test('weekly recurrence defaults to the anchor weekday when none selected',
      () {
    const rule = RecurrenceRule(frequency: RecurrenceFrequency.weekly);
    final anchor = DateTime(2026, 1, 7);

    expect(rule.isDueOn(DateTime(2026, 1, 14), anchor), isTrue);
    expect(rule.isDueOn(DateTime(2026, 1, 15), anchor), isFalse);
  });
}
