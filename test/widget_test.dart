// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:schedule_me/models/recurrence_rule.dart';

void main() {
  test('monthly recurrence stays on the selected day', () {
    const rule = RecurrenceRule(frequency: RecurrenceFrequency.monthly);
    final anchor = DateTime(2026, 1, 15, 9, 30);

    expect(rule.isDueOn(DateTime(2026, 2, 15), anchor), isTrue);
    expect(rule.isDueOn(DateTime(2026, 2, 14), anchor), isFalse);
  });
}
