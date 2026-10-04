enum RecurrenceFrequency { once, daily, weekly, monthly, yearly }

class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.weekdays = const <int>[],
    this.repeatAfterCompletion = false,
    this.endDate,
  });

  final RecurrenceFrequency frequency;
  final int interval;
  final List<int> weekdays;
  final bool repeatAfterCompletion;
  final DateTime? endDate;

  bool isDueOn(DateTime date, DateTime anchor) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedAnchor = DateTime(anchor.year, anchor.month, anchor.day);
    final difference = normalizedDate.difference(normalizedAnchor).inDays;
    if (difference < 0) return false;

    if (endDate != null && normalizedDate.isAfter(DateTime(
      endDate!.year,
      endDate!.month,
      endDate!.day,
    ))) {
      return false;
    }

    switch (frequency) {
      case RecurrenceFrequency.once:
        return normalizedDate == normalizedAnchor;
      case RecurrenceFrequency.daily:
        return difference % interval == 0;
      case RecurrenceFrequency.weekly:
        final selectedWeekdays = weekdays.isEmpty
            ? <int>{normalizedAnchor.weekday}
            : weekdays.toSet();
        return selectedWeekdays.contains(normalizedDate.weekday) &&
            difference ~/ 7 % interval == 0;
      case RecurrenceFrequency.monthly:
        final months =
          (normalizedDate.year - normalizedAnchor.year) * 12 +
            normalizedDate.month -
            normalizedAnchor.month;
        final lastDay = DateTime(
            normalizedDate.year, normalizedDate.month + 1, 0)
          .day;
        final day = normalizedAnchor.day.clamp(1, lastDay);
        return months >= 0 &&
          months % interval == 0 &&
          normalizedDate.day == day;
      case RecurrenceFrequency.yearly:
        return normalizedDate.month == normalizedAnchor.month &&
            normalizedDate.day == normalizedAnchor.day &&
            ((normalizedDate.year - normalizedAnchor.year) >= 0) &&
            ((normalizedDate.year - normalizedAnchor.year) % interval == 0);
    }
  }
}
