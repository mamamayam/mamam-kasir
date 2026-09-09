import 'package:intl/intl.dart';

final _rupiahFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

/// Formats an integer Rupiah amount, e.g. 2450000 -> "Rp2.450.000".
/// NOTE: per architecture doc, money must stay integer/exact-decimal
/// throughout the domain layer — this formatter is presentation-only.
String formatRupiah(int amount) => _rupiahFormat.format(amount);
