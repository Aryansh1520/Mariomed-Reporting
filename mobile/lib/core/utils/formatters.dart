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
