/// The IANA zone to send as `?tz=` with the notifications list, so a time in a sentence ("Mon, 19 Oct, 11:00 am")
/// reads on the phone's clock, as the website sends the browser's (`viewerTimeZone`, `frontend/src/lib/datetime.ts`;
/// the API reads it with `safeTimeZone` and answers on the Indian clock when it is absent or unknown).
///
/// Dart only knows the phone's offset and an abbreviation, not the zone's name, so this names the zone of the
/// markets ICR serves that sits on that offset, and an `Etc/GMT±N` zone for any other whole-hour offset. Null for an
/// offset no zone name fits (the API then reads the Indian clock, as it did before). A zone that changes its clock
/// twice a year reads one hour off after the change until the list is next read; the website's name is exact.
String? viewerTimeZone([Duration? offset]) {
  final minutes = (offset ?? DateTime.now().timeZoneOffset).inMinutes;
  final named = _named[minutes];
  if (named != null) return named;
  if (minutes % 60 != 0) return null;
  final hours = minutes ~/ 60;
  if (hours == 0) return 'UTC';
  if (hours > 14 || hours < -12) return null;
  // POSIX sign: "Etc/GMT-4" is four hours AHEAD of UTC.
  return 'Etc/GMT${hours > 0 ? '-' : '+'}${hours.abs()}';
}

const _named = <int, String>{
  330: 'Asia/Kolkata',
  345: 'Asia/Kathmandu',
  240: 'Asia/Dubai',
  180: 'Asia/Riyadh',
  480: 'Asia/Singapore',
  300: 'Asia/Karachi',
  360: 'Asia/Dhaka',
};
