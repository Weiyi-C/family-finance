String formatMoney(int cents) {
  return '¥${(cents / 100).toStringAsFixed(2)}';
}

String formatMoneyShort(int cents) {
  final yuan = cents / 100;
  if (yuan >= 10000) return '¥${(yuan / 10000).toStringAsFixed(1)}万';
  if (yuan >= 1000) return '¥${(yuan / 1000).toStringAsFixed(1)}千';
  return '¥${yuan.toStringAsFixed(2)}';
}

String formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String formatDateTime(DateTime date) {
  return '${formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
