String formatCurrency(int amountCents) {
  final absoluteCents = amountCents.abs();
  final dollars = absoluteCents ~/ 100;
  final cents = (absoluteCents % 100).toString().padLeft(2, '0');
  return '\$$dollars.$cents';
}

int? parseCurrencyToCents(String value) {
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(value.trim());
  if (match == null) return null;

  final dollars = int.tryParse(match.group(1)!);
  if (dollars == null) return null;

  final fraction = match.group(2) ?? '';
  final cents = fraction.isEmpty ? 0 : int.parse(fraction.padRight(2, '0'));
  return dollars * 100 + cents;
}

String formatSignedCurrency(int amountCents) {
  if (amountCents > 0) return '+${formatCurrency(amountCents)}';
  if (amountCents < 0) return '-${formatCurrency(amountCents)}';
  return formatCurrency(0);
}

int? parseSignedCurrencyToCents(String value) {
  final trimmed = value.trim();
  final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d{1,2}))?$').firstMatch(trimmed);
  if (match == null) return null;

  final dollars = int.tryParse(match.group(2)!);
  if (dollars == null) return null;

  final fraction = match.group(3) ?? '';
  final cents = fraction.isEmpty ? 0 : int.parse(fraction.padRight(2, '0'));
  final amount = dollars * 100 + cents;
  return match.group(1) == '-' ? -amount : amount;
}
