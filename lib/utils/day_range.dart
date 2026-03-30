import 'package:boy_barbershop/utils/shop_time.dart';

List<String> daysBetweenInclusive(String startDay, String endDay) {
  final start = parseYyyyMmDd(startDay);
  final end = parseYyyyMmDd(endDay);
  if (start == null || end == null) return const <String>[];
  final out = <String>[];
  var cursor = DateTime(start.year, start.month, start.day);
  final last = DateTime(end.year, end.month, end.day);
  while (!cursor.isAfter(last)) {
    out.add(yyyyMmDd(cursor));
    cursor = cursor.add(const Duration(days: 1));
  }
  return out;
}

