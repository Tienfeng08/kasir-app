import 'package:intl/intl.dart';

final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final dateFormatter = DateFormat('dd/MM/yyyy');
final dateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm');
final qtyFormatter = NumberFormat('#,##0.##', 'id_ID');

String formatCurrency(num value) => currencyFormatter.format(value);
String formatDate(DateTime date) => dateFormatter.format(date);
String formatDateTime(DateTime date) => dateTimeFormatter.format(date);
String formatQty(num value) => qtyFormatter.format(value);
