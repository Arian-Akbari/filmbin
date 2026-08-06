/// Persian-facing number and date formatting.
///
/// The whole UI is Persian (section 8.2), so digits are converted at the edge:
/// models keep real numbers, widgets only ever show what comes out of here.
library;

class Formatters {
  const Formatters._();

  static const _persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  static const _thousandsSeparator = '٬';

  /// Rewrites ASCII digits as Persian ones, leaving everything else alone.
  static String digits(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0x30 && rune <= 0x39) {
        buffer.write(_persian[rune - 0x30]);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  static String count(int value) {
    final raw = value.abs().toString();
    final grouped = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) grouped.write(_thousandsSeparator);
      grouped.write(raw[i]);
    }
    return digits('${value < 0 ? '-' : ''}$grouped');
  }

  /// Short form for badges: 2_600_000 → ۲.۶M.
  static String compact(int value) {
    if (value >= 1000000) {
      final millions = (value / 1000000).toStringAsFixed(1);
      return '${digits(millions.endsWith('.0') ? millions.substring(0, millions.length - 2) : millions)}M';
    }
    if (value >= 1000) {
      final thousands = (value / 1000).toStringAsFixed(1);
      return '${digits(thousands.endsWith('.0') ? thousands.substring(0, thousands.length - 2) : thousands)}K';
    }
    return digits(value.toString());
  }

  static String rating(double? value) => value == null ? '—' : digits(value.toStringAsFixed(1));

  static String percent(int value) => '${digits(value.toString())}٪';

  static String? duration(int? minutes) {
    if (minutes == null || minutes <= 0) return null;
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '${digits('$rest')} دقیقه';
    if (rest == 0) return '${digits('$hours')} ساعت';
    return '${digits('$hours')} ساعت و ${digits('$rest')} دقیقه';
  }

  static String hours(double value) {
    final rounded = value.roundToDouble() == value
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return '${digits(rounded)} ساعت';
  }

  static String? airDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return null;
    return digits(isoDate.replaceAll('-', '/'));
  }

  static String relativeDate(DateTime moment) {
    final delta = DateTime.now().difference(moment);
    if (delta.inMinutes < 5) return 'چند لحظه پیش';
    if (delta.inMinutes < 60) return '${digits('${delta.inMinutes}')} دقیقه پیش';
    if (delta.inHours < 24) return '${digits('${delta.inHours}')} ساعت پیش';
    if (delta.inDays < 30) return '${digits('${delta.inDays}')} روز پیش';
    return digits(
      '${moment.year}/${moment.month.toString().padLeft(2, '0')}/'
      '${moment.day.toString().padLeft(2, '0')}',
    );
  }
}
