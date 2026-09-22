/// Pure date/label helpers for the HRD placeholder.
///
/// Deliberately hand-written Indonesian month names instead of
/// `DateFormat(..., 'id_ID')`: that would require
/// `initializeDateFormatting` at startup, and keeping this file free of
/// Flutter/intl imports lets the payroll engine and its tests run as
/// plain Dart.
library;

const List<String> _monthsLong = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const List<String> _monthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String _pad2(int n) => n.toString().padLeft(2, '0');

/// Parses `yyyy-MM-dd` as a UTC date (UTC on purpose: no DST/timezone
/// drift when adding days for week ranges).
DateTime parseIsoDate(String iso) {
  return DateTime.utc(
    int.parse(iso.substring(0, 4)),
    int.parse(iso.substring(5, 7)),
    int.parse(iso.substring(8, 10)),
  );
}

/// Formats a date as `yyyy-MM-dd` using its own y/m/d fields (no timezone
/// conversion — pass either a UTC date from [parseIsoDate] or a local
/// date from a date picker).
String formatIsoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_pad2(d.month)}-${_pad2(d.day)}';

/// `2026-09-11` -> `11 September 2026`.
String formatDateLong(String iso) {
  final d = parseIsoDate(iso);
  return '${d.day} ${_monthsLong[d.month - 1]} ${d.year}';
}

/// `2026-09-11` -> `11 Sep`.
String formatDateShort(String iso) {
  final d = parseIsoDate(iso);
  return '${d.day} ${_monthsShort[d.month - 1]}';
}

/// `2026-09` -> `September 2026`.
String monthLabel(String yyyyMm) {
  final year = int.parse(yyyyMm.substring(0, 4));
  final month = int.parse(yyyyMm.substring(5, 7));
  return '${_monthsLong[month - 1]} $year';
}

/// Tenure ("lama bekerja") ALWAYS computed from the start date — never an
/// input field. `2026-01-12` as of `2026-09-11` -> `7 bulan 30 hari`.
String tenureLabel(String startDateIso, String asOfIso) {
  final start = parseIsoDate(startDateIso);
  final asOf = parseIsoDate(asOfIso);
  var months = (asOf.year - start.year) * 12 + (asOf.month - start.month);
  var days = asOf.day - start.day;
  if (days < 0) {
    months -= 1;
    // Day 0 of a month == last day of the previous month.
    final daysInPreviousMonth = DateTime.utc(asOf.year, asOf.month, 0).day;
    days += daysInPreviousMonth;
  }
  if (months < 0) return '0 hari';
  final parts = <String>[];
  if (months > 0) parts.add('$months bulan');
  parts.add('$days hari');
  return parts.join(' ');
}

/// `HH:mm` (or `H:mm`) -> minutes since midnight.
int timeToMinutes(String t) {
  final parts = t.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// Normalises user-typed time to zero-padded `HH:mm`, or null when it is
/// not a valid 24h time (`9:5`, `25:00`, `abc` -> null).
String? normalizeTimeInput(String raw) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
  if (match == null) return null;
  final h = int.parse(match.group(1)!);
  final m = int.parse(match.group(2)!);
  if (h > 23 || m > 59) return null;
  return '${_pad2(h)}:${_pad2(m)}';
}
