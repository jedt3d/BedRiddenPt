// Display text for the Detail screen (SPEC §7.4, Figma frames 17–18).
// Dates are in the Buddhist era (Gregorian + 543), e.g. "Born 2493 (age 76)".

import '../../data/patient.dart';

/// The current time. Replaceable in tests so ages don't depend on the clock.
DateTime Function() detailClock = DateTime.now;

/// "2493 (age 76)" for a patient born 1950, in 2026.
String bornText(Patient p, {int? year}) =>
    '${p.birthYearBE} (age ${p.ageIn(year ?? detailClock().year)})';

/// "063-759-2951" for a 10-digit phone; anything else is shown as stored.
String formatPhone(String phone) => RegExp(r'^[0-9]{10}$').hasMatch(phone)
    ? '${phone.substring(0, 3)}-${phone.substring(3, 6)}-${phone.substring(6)}'
    : phone;

/// "13.730103, 100.498575".
String coordinatesText(double lat, double lng) =>
    '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

/// "±5 m", or "Not recorded" (bootstrap data has no accuracy).
String gpsAccuracyText(double? metres) =>
    metres == null ? 'Not recorded' : '±${metres.round()} m';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "19 Nov 2569, 09:00" for an ISO 8601 timestamp, in local time and the
/// Buddhist era. An empty or unreadable value is shown as "—".
String timestampText(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '—';
  final t = parsed.isUtc ? parsed.toLocal() : parsed;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.day} ${_months[t.month - 1]} ${t.year + 543}, '
      '${two(t.hour)}:${two(t.minute)}';
}
