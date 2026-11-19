// Thai national ID (SPEC §5, §7.3): stored as 13 digits, shown and typed as
// 3-XXXX-XXXXX-XX-X.

/// The message the form shows for a bad checksum (SPEC §7.3).
const invalidNationalIdMessage =
    "This national ID isn't valid. Check the 13 digits.";

/// 13 digits whose last digit is the SPEC §5 checksum:
/// sum = Σ dᵢ × (14 − i) for i = 1…12; check = (11 − sum mod 11) mod 10.
bool isValidNationalId(String digits) {
  if (!RegExp(r'^[0-9]{13}$').hasMatch(digits)) return false;
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += (digits.codeUnitAt(i) - 0x30) * (13 - i);
  }
  return (11 - sum % 11) % 10 == digits.codeUnitAt(12) - 0x30;
}

/// Formats up to 13 digits as 3-XXXX-XXXXX-XX-X. A shorter input is
/// formatted as far as it goes (for typing); non-digits are dropped.
String formatNationalId(String input) {
  final d = nationalIdDigits(input);
  const groups = [1, 4, 5, 2, 1];
  final parts = <String>[];
  var start = 0;
  for (final len in groups) {
    if (start >= d.length) break;
    final end = start + len < d.length ? start + len : d.length;
    parts.add(d.substring(start, end));
    start = end;
  }
  return parts.join('-');
}

/// The digits of [input] (dashes and spaces dropped), at most 13.
String nationalIdDigits(String input) {
  final d = input.replaceAll(RegExp(r'[^0-9]'), '');
  return d.length > 13 ? d.substring(0, 13) : d;
}

/// The 13 stored digits for a typed ID, or null if it isn't 13 digits.
/// It does not check the checksum: use [isValidNationalId].
String? parseNationalId(String input) {
  final d = input.replaceAll(RegExp(r'[\s-]'), '');
  return RegExp(r'^[0-9]{13}$').hasMatch(d) ? d : null;
}
