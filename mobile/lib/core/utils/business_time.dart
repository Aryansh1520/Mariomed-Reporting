/// The business clock: India Standard Time, whatever the device's own time zone is.
/// India has no daylight saving, so a fixed offset from UTC gives the same date as the server on every device.
const _indiaOffset = Duration(hours: 5, minutes: 30);

/// The current moment in India.
DateTime indiaNow() => DateTime.now().toUtc().add(_indiaOffset);

/// Today's date in India, with the time left out.
DateTime indiaToday() {
  final now = indiaNow();
  return DateTime(now.year, now.month, now.day);
}

/// Sunday is a leave day for everyone: no calls are recorded or planned on it.
bool isSunday(DateTime day) => day.weekday == DateTime.sunday;
