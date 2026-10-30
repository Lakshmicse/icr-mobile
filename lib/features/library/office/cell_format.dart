/// How a spreadsheet number is worded: a plain figure, a percentage, or a date, from the cell's number
/// format (a built-in format id, or a custom format code). Shared by the Excel 2007 and Excel 97 readers.
class CellFormat {
  const CellFormat({this.date = false, this.time = false, this.percent = false});

  final bool date;
  final bool time;
  final bool percent;

  static const general = CellFormat();

  /// The format a built-in id (0 to 49, the ones the file does not spell out) stands for.
  static CellFormat builtIn(int id) {
    if ((id >= 14 && id <= 17) || id == 27 || (id >= 30 && id <= 31) || id == 36 || (id >= 50 && id <= 58)) {
      return const CellFormat(date: true);
    }
    if (id == 22) return const CellFormat(date: true, time: true);
    if ((id >= 18 && id <= 21) || (id >= 45 && id <= 47)) return const CellFormat(time: true);
    if (id == 9 || id == 10) return const CellFormat(percent: true);
    return general;
  }

  /// The format a custom format code stands for ("dd-mmm-yy", "0.0%", "[$-409]h:mm AM/PM").
  static CellFormat fromCode(String code) {
    // Quoted text, escaped characters, colours and conditions are not part of the number's shape.
    final shape = code
        .replaceAll(RegExp(r'"[^"]*"'), '')
        .replaceAll(RegExp(r'\\.'), '')
        .replaceAll(RegExp(r'_.'), '')
        .replaceAll(RegExp(r'\*.'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .toLowerCase();
    if (shape.isEmpty || shape == 'general') return general;
    final hasDay = RegExp(r'd').hasMatch(shape);
    final hasYear = RegExp(r'y').hasMatch(shape);
    final hasHour = RegExp(r'h').hasMatch(shape) || shape.contains('am/pm') || shape.contains('a/p');
    final hasSecond = RegExp(r's').hasMatch(shape);
    // "m" alone is a month or a minute; with a day or year it is a month.
    final hasMonth = RegExp(r'm').hasMatch(shape) && (hasDay || hasYear || !hasHour);
    final date = hasDay || hasYear || (hasMonth && !hasHour);
    final time = hasHour || (hasSecond && !date);
    if (date || time) return CellFormat(date: date, time: time);
    if (shape.contains('%')) return const CellFormat(percent: true);
    return general;
  }

  /// [value] as a cell shows it. [date1904] is the workbook's date system.
  String format(double value, {bool date1904 = false}) {
    if (value.isNaN || value.isInfinite) return value.toString();
    if (date || time) {
      final text = _moment(value, date1904: date1904);
      if (text != null) return text;
    }
    if (percent) return '${plainNumber(value * 100)}%';
    return plainNumber(value);
  }

  String? _moment(double serial, {required bool date1904}) {
    if (serial < 0 || serial > 2958465) return null; // before 1900 or after the year 9999
    final days = serial.floor();
    var seconds = ((serial - days) * 86400).round();
    var day = days;
    if (seconds >= 86400) {
      seconds -= 86400;
      day += 1;
    }
    // Excel counts 1900 as a leap year; its day 1 is 1 January 1900, and from 1 March 1900 on the serial is
    // one day ahead of the calendar, so the epoch is 30 December 1899. The 1904 system starts on 1 January 1904.
    final epoch = date1904 ? DateTime.utc(1904) : DateTime.utc(1899, 12, 30);
    final when = epoch.add(Duration(days: day, seconds: seconds));
    final hh = when.hour.toString().padLeft(2, '0');
    final mm = when.minute.toString().padLeft(2, '0');
    final clock = '$hh:$mm${when.second == 0 ? '' : ':${when.second.toString().padLeft(2, '0')}'}';
    if (!date) return clock;
    final dayText = '${when.day.toString().padLeft(2, '0')} ${_months[when.month - 1]} ${when.year}';
    if (!time && seconds == 0) return dayText;
    return '$dayText $clock';
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
}

/// A number without the noise of binary fractions: whole numbers without ".0", others to 12 significant digits.
String plainNumber(double value) {
  if (value == value.truncateToDouble() && value.abs() < 1e15) return value.toInt().toString();
  var text = value.toStringAsPrecision(12);
  if (text.contains('e')) return text;
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}
