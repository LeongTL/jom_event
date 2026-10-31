// Money is whole sen everywhere; this is the only place it becomes text: Free, RM 45, RM 45.50.
String formatMoney(int sen) {
  if (sen < 0) {
    throw ArgumentError.value(
      sen,
      'sen',
      'an amount of money cannot be negative',
    );
  }
  if (sen == 0) return 'Free';
  final ringgit = sen ~/ 100;
  final cents = sen % 100;
  return cents == 0
      ? 'RM $ringgit'
      : 'RM $ringgit.${cents.toString().padLeft(2, '0')}';
}
