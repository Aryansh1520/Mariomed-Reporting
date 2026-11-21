import 'business_time.dart';

/// "contacts.read" becomes "Contacts: read". Codes that do not match the pattern pass through unchanged.
String permissionLabel(String code) {
  final parts = code.split('.');
  if (parts.length != 2) return code;
  return '${_capitalise(parts[0].replaceAll('_', ' '))}: ${parts[1]}';
}

/// The plain words for a permission scope.
String scopeLabel(String scope) => switch (scope) {
  'all' => 'All records',
  'self' => 'Only you',
  'assigned' => 'Assigned to you',
  _ => scope,
};

/// A greeting from the first name, or a plain welcome when the name is missing.
String greetingFor(String? fullName) {
  final first = fullName?.trim().split(' ').first;
  return first == null || first.isEmpty ? 'Welcome' : 'Hello, $first';
}

String _capitalise(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

/// The greeting for the time of day: morning before noon, afternoon before five, evening after.
String timeOfDayGreeting(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A day as it reads on a form, such as "28 Oct 2026".
String formatDay(DateTime day) =>
    '${day.day} ${_monthNames[day.month - 1]} ${day.year}';

/// A moment as it reads on a form, such as "28 Oct 2026, 20:55", in India time.
String formatMoment(DateTime moment) {
  final local = indiaTime(moment);
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${formatDay(local)}, $hour:$minute';
}

/// The name of the day of the week, such as "Saturday".
String weekdayName(DateTime day) => const [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
][day.weekday - 1];

/// A date as the API takes it in a query or a path: yyyy-mm-dd.
String apiDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

/// The parts of the day a call can be placed in, in the order they fall in a day.
const dayPartOptions = ['morning', 'afternoon', 'evening'];

String dayPartLabel(String dayPart) => _capitalise(dayPart);

/// A call's time as lists show it: the clock time for a call logged with one, otherwise its part of the day.
String callTimeLabel(String dayPart, String? visitTime) =>
    visitTime == null ? dayPartLabel(dayPart) : visitTime.substring(0, 5);

/// Orders calls within a day: by part of the day, then by clock time for calls logged with one.
int compareCallTimes(
  String aDayPart,
  String? aVisitTime,
  String bDayPart,
  String? bVisitTime,
) {
  final byPart = dayPartOptions
      .indexOf(aDayPart)
      .compareTo(dayPartOptions.indexOf(bDayPart));
  return byPart != 0 ? byPart : (aVisitTime ?? '').compareTo(bVisitTime ?? '');
}
