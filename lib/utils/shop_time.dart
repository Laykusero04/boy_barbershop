String yyyyMmDd(DateTime d) {
  final yyyy = d.year.toString().padLeft(4, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}

bool isValidYyyyMmDd(String value) {
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value.trim());
}

DateTime? parseYyyyMmDd(String raw) {
  final trimmed = raw.trim();
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
  if (m == null) return null;
  final yyyy = int.tryParse(m.group(1)!);
  final mm = int.tryParse(m.group(2)!);
  final dd = int.tryParse(m.group(3)!);
  if (yyyy == null || mm == null || dd == null) return null;
  return DateTime(yyyy, mm, dd);
}

/// "Shop time" helper for Asia/Manila (UTC+8, no DST).
DateTime nowManila() => DateTime.now().toUtc().add(const Duration(hours: 8));

String todayManilaDay() => yyyyMmDd(nowManila());

/// Converts an instant to Asia/Manila local time (UTC+8, no DST).
///
/// Important: Firestore `Timestamp.toDate()` represents an instant; to get
/// Manila-clock hour/day correctly across devices, normalize to UTC first.
DateTime manilaFromInstant(DateTime instant) {
  return instant.toUtc().add(const Duration(hours: 8));
}

int manilaHourOfInstant(DateTime instant) => manilaFromInstant(instant).hour;

/// Builds a UTC DateTime from a date + time that are interpreted as Asia/Manila.
DateTime utcFromManilaParts({
  required int year,
  required int month,
  required int day,
  required int hour,
  required int minute,
}) {
  // Convert Manila (UTC+8) -> UTC by subtracting 8 hours.
  return DateTime.utc(year, month, day, hour - 8, minute);
}

DateTime utcStartOfManilaDay(String dayYyyyMmDd) {
  final d = parseYyyyMmDd(dayYyyyMmDd) ?? nowManila();
  return utcFromManilaParts(
    year: d.year,
    month: d.month,
    day: d.day,
    hour: 0,
    minute: 0,
  );
}

DateTime utcExclusiveEndOfManilaDay(String dayYyyyMmDd) {
  final d = parseYyyyMmDd(dayYyyyMmDd) ?? nowManila();
  final next = DateTime(d.year, d.month, d.day).add(const Duration(days: 1));
  return utcFromManilaParts(
    year: next.year,
    month: next.month,
    day: next.day,
    hour: 0,
    minute: 0,
  );
}

String formatMoney(double value) {
  final fixed = value.toStringAsFixed(2);
  if (fixed.endsWith('.00')) return fixed.substring(0, fixed.length - 3);
  return fixed;
}

const _monthNamesEn = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Human-readable Manila calendar day, e.g. "April 2, 2026".
String formatManilaDayForDisplay(String dayYyyyMmDd) {
  final d = parseYyyyMmDd(dayYyyyMmDd) ?? nowManila();
  return '${_monthNamesEn[d.month - 1]} ${d.day}, ${d.year}';
}

/// Month and year for headings, e.g. "April 2026".
String formatManilaMonthYearForDisplay(String dayYyyyMmDd) {
  final d = parseYyyyMmDd(dayYyyyMmDd) ?? nowManila();
  return '${_monthNamesEn[d.month - 1]} ${d.year}';
}

