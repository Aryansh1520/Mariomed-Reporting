import '../core/utils/formatters.dart';
import '../models/contact.dart';
import '../models/report.dart';
import '../models/visit.dart';
import '../core/utils/business_time.dart';
import 'api_service.dart';
import 'contact_service.dart';
import 'plan_service.dart';
import 'visit_service.dart';

/// Builds the full report behind each home card from the endpoints the app already uses.
/// The server has already decided which reports the caller may open.
class ReportService {
  ReportService(this._api)
    : _visits = VisitService(_api),
      _plans = PlanService(_api),
      _contacts = ContactService(_api);

  final ApiService _api;
  final VisitService _visits;
  final PlanService _plans;
  final ContactService _contacts;

  Future<ReportData> load(ReportKind kind) => switch (kind) {
    ReportKind.today => _todayReport(),
    ReportKind.month => _month(),
    ReportKind.coverage => _coverage(),
    ReportKind.missed => _missed(),
    ReportKind.calls => _calls(),
    ReportKind.nextUp => _nextUp(),
    ReportKind.joint => _joint(),
    ReportKind.team => _team(),
  };

  static DateTime get _todayDate => indiaToday();

  static String _time(String visitTime) => visitTime.substring(0, 5);

  Future<ReportData> _todayReport() async {
    final today = _todayDate;
    final visits = await _visits.listVisits(from: today, to: today);
    final days = await _visits.listDays(from: today, to: today);
    final plans = await _plans.listPlans(from: today, to: today);
    final planned = [for (final day in plans) ...day.items];
    final status = days.isEmpty
        ? 'Not reported'
        : days.first.isLeave
        ? 'On leave'
        : days.first.isEnded
        ? 'Ended'
        : 'Open';
    return ReportData(
      figures: [
        ReportFigure(
          label: 'Calls',
          value: '${visits.length}',
          tone: RowTone.good,
        ),
        ReportFigure(label: 'Planned', value: '${planned.length}'),
        ReportFigure(label: 'Day', value: status),
      ],
      sections: [
        ReportSection(
          title: 'Calls',
          emptyText: 'No calls recorded today.',
          rows: [for (final visit in visits) _visitRow(visit)],
        ),
        ReportSection(
          title: 'Planned',
          emptyText: 'Nothing planned for today.',
          rows: [
            for (final item in planned)
              ReportRow(
                title: item.contactName,
                subtitle: '${item.categoryName}  ·  ${item.subzoneName}',
                trailing: _planLabel(item.status),
                tone: _planTone(item.status),
              ),
          ],
        ),
      ],
    );
  }

  Future<ReportData> _month() async {
    final start = DateTime(_todayDate.year, _todayDate.month);
    final visits = await _visits.listVisits(from: start, to: _todayDate);
    final days = await _visits.listDays(from: start, to: _todayDate);
    final reported = days.where((day) => day.isEnded).length;
    final visitsByDay = <DateTime, int>{};
    for (final visit in visits) {
      visitsByDay[visit.visitDate] = (visitsByDay[visit.visitDate] ?? 0) + 1;
    }
    final ordered = [...days]
      ..sort((a, b) => b.visitDate.compareTo(a.visitDate));
    return ReportData(
      figures: [
        ReportFigure(label: 'Calls', value: '${visits.length}'),
        ReportFigure(
          label: 'Contacts visited',
          value: '${visits.map((visit) => visit.contactId).toSet().length}',
        ),
        ReportFigure(
          label: 'Days reported',
          value: '$reported',
          tone: RowTone.good,
        ),
      ],
      sections: [
        ReportSection(
          title: 'Days this month',
          emptyText: 'No days reported this month yet.',
          rows: [
            for (final day in ordered)
              ReportRow(
                title: formatDay(day.visitDate),
                subtitle:
                    '${visitsByDay[day.visitDate] ?? 0} ${(visitsByDay[day.visitDate] ?? 0) == 1 ? 'call' : 'calls'}',
                trailing: day.isLeave
                    ? 'Leave'
                    : (day.isEnded ? 'Ended' : 'Open'),
                tone: day.isEnded
                    ? RowTone.good
                    : (day.isLeave ? RowTone.muted : RowTone.warning),
              ),
          ],
        ),
      ],
    );
  }

  /// Every active contact the caller can see, split by whether they were visited this month.
  Future<ReportData> _coverage() async {
    final contacts = await _allContacts();
    final start = DateTime(_todayDate.year, _todayDate.month);
    final visited = (await _visits.listVisits(
      from: start,
      to: _todayDate,
    )).map((visit) => visit.contactId).toSet();
    final covered = [
      for (final contact in contacts)
        if (visited.contains(contact.id)) contact,
    ];
    final uncovered = [
      for (final contact in contacts)
        if (!visited.contains(contact.id)) contact,
    ];
    final total = contacts.length;
    final percent = total == 0 ? 0 : (covered.length * 100 / total).round();
    return ReportData(
      figures: [
        ReportFigure(
          label: 'Covered',
          value: '${covered.length}',
          tone: RowTone.good,
        ),
        ReportFigure(
          label: 'Not yet',
          value: '${uncovered.length}',
          tone: uncovered.isEmpty ? RowTone.normal : RowTone.warning,
        ),
        ReportFigure(label: 'Coverage', value: '$percent%'),
      ],
      sections: [
        ReportSection(
          title: 'Covered this month',
          emptyText: 'No contact covered yet this month.',
          rows: [
            for (final contact in covered) _contactRow(contact, RowTone.good),
          ],
        ),
        ReportSection(
          title: 'Not covered yet',
          emptyText: 'Every contact has been covered this month.',
          rows: [
            for (final contact in uncovered)
              _contactRow(contact, RowTone.warning),
          ],
        ),
      ],
      footnote: 'Covered means at least one call this month.',
    );
  }

  /// The contacts the caller can visit that were not visited this month, grouped by category.
  Future<ReportData> _missed() async {
    final contacts = await _allContacts();
    final start = DateTime(_todayDate.year, _todayDate.month);
    final visited = (await _visits.listVisits(
      from: start,
      to: _todayDate,
    )).map((visit) => visit.contactId).toSet();
    final missed = [
      for (final contact in contacts)
        if (!visited.contains(contact.id)) contact,
    ];
    missed.sort(
      (a, b) => a.categoryName == b.categoryName
          ? a.name.compareTo(b.name)
          : a.categoryName.compareTo(b.categoryName),
    );
    final categories = {for (final contact in missed) contact.categoryName};
    return ReportData(
      figures: [
        ReportFigure(
          label: 'Not visited',
          value: '${missed.length}',
          tone: missed.isEmpty ? RowTone.good : RowTone.alert,
        ),
        ReportFigure(label: 'Categories', value: '${categories.length}'),
      ],
      sections: [
        for (final category in categories)
          ReportSection(
            title: category,
            emptyText: '',
            rows: [
              for (final contact in missed)
                if (contact.categoryName == category)
                  _contactRow(contact, RowTone.alert),
            ],
          ),
        if (missed.isEmpty)
          const ReportSection(
            title: 'Missed',
            emptyText: 'Every contact has been visited this month.',
            rows: [],
          ),
      ],
      footnote: 'Contacts you can visit that have had no call this month.',
    );
  }

  /// Each of the last 14 days with its calls.
  Future<ReportData> _calls() async {
    final start = _todayDate.subtract(const Duration(days: 13));
    final visits = await _visits.listVisits(from: start, to: _todayDate);
    final byDay = <DateTime, List<VisitRecord>>{};
    for (final visit in visits) {
      byDay.putIfAbsent(visit.visitDate, () => []).add(visit);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return ReportData(
      figures: [
        ReportFigure(label: 'Calls', value: '${visits.length}'),
        ReportFigure(label: 'Days with calls', value: '${days.length}'),
      ],
      sections: [
        for (final day in days)
          ReportSection(
            title: formatDay(day),
            emptyText: '',
            rows: [for (final visit in byDay[day]!) _visitRow(visit)],
          ),
        if (days.isEmpty)
          const ReportSection(
            title: 'Calls',
            emptyText: 'No calls in the last 14 days.',
            rows: [],
          ),
      ],
    );
  }

  Future<ReportData> _nextUp() async {
    final plans = await _plans.listPlans(
      from: _todayDate.add(const Duration(days: 1)),
      to: _todayDate.add(const Duration(days: 7)),
    );
    final count = plans.fold<int>(0, (sum, day) => sum + day.items.length);
    return ReportData(
      figures: [ReportFigure(label: 'Planned calls', value: '$count')],
      sections: [
        for (final day in plans)
          ReportSection(
            title: formatDay(day.planDate),
            emptyText: '',
            rows: [
              for (final item in day.items)
                ReportRow(
                  title: item.contactName,
                  subtitle:
                      '${item.categoryName}  ·  ${item.zoneName} › ${item.subzoneName}',
                  trailing: _planLabel(item.status),
                  tone: _planTone(item.status),
                ),
            ],
          ),
        if (plans.isEmpty)
          const ReportSection(
            title: 'Planned',
            emptyText: 'Nothing planned for the next 7 days.',
            rows: [],
          ),
      ],
      footnote: 'Plan the coming days in Tasks.',
    );
  }

  Future<ReportData> _joint() async {
    final requests = await _visits.listJointRequests();
    final waiting = requests.where((request) => request.canRespond).toList();
    final answered = requests.where((request) => !request.canRespond).toList();
    return ReportData(
      figures: [
        ReportFigure(
          label: 'Waiting',
          value: '${waiting.length}',
          tone: waiting.isEmpty ? RowTone.normal : RowTone.warning,
        ),
        ReportFigure(label: 'Answered', value: '${answered.length}'),
      ],
      sections: [
        ReportSection(
          title: 'Waiting for your answer',
          emptyText: 'No joint call is waiting for you.',
          rows: [for (final request in waiting) _jointRow(request)],
        ),
        ReportSection(
          title: 'Answered',
          emptyText: 'No joint call answered yet.',
          rows: [for (final request in answered) _jointRow(request)],
        ),
      ],
      footnote: 'Accept or dispute a joint call in Tasks, on Complete Day.',
    );
  }

  Future<ReportData> _team() async {
    final page = await _api.getData<List<ReportRow>>('/users?page_size=100', (
      data,
    ) {
      final items = ApiService.asJsonMap(data)['items'] as List<Object?>;
      return [
        for (final item in items)
          () {
            final user = ApiService.asJsonMap(item);
            final active = user['is_active'] as bool;
            return ReportRow(
              title: user['full_name'] as String,
              subtitle: '${user['role_name']}  ·  ${user['email']}',
              trailing: active ? 'Active' : 'Inactive',
              tone: active ? RowTone.good : RowTone.muted,
            );
          }(),
      ];
    });
    final active = page.where((row) => row.tone == RowTone.good).length;
    return ReportData(
      figures: [
        ReportFigure(label: 'Active', value: '$active', tone: RowTone.good),
        ReportFigure(
          label: 'Inactive',
          value: '${page.length - active}',
          tone: RowTone.muted,
        ),
      ],
      sections: [
        ReportSection(
          title: 'People',
          emptyText: 'No one in the team yet.',
          rows: page,
        ),
      ],
    );
  }

  Future<List<Contact>> _allContacts() async {
    final collected = <Contact>[];
    var page = 1;
    while (true) {
      final result = await _contacts.listContacts(page: page);
      collected.addAll(result.items);
      if (result.items.isEmpty || collected.length >= result.total) break;
      page++;
    }
    return [
      for (final contact in collected)
        if (contact.isActive) contact,
    ];
  }

  static ReportRow _visitRow(VisitRecord visit) => ReportRow(
    title: visit.contactName,
    subtitle:
        '${_time(visit.visitTime)}  ·  ${visit.repName}  ·  ${visit.products.map((product) => product.name).join(', ')}',
    trailing: visit.categoryName,
  );

  static ReportRow _contactRow(Contact contact, RowTone tone) => ReportRow(
    title: contact.name,
    subtitle:
        '${contact.categoryName}  ·  ${contact.zoneName} › ${contact.subzoneName}',
    tone: tone,
    contactId: contact.id,
  );

  static ReportRow _jointRow(JointRequest request) => ReportRow(
    title: request.contactName,
    subtitle: '${formatDay(request.visitDate)}  ·  ${request.subzoneName}',
    trailing: request.canRespond
        ? 'Waiting'
        : (request.status == 'accepted' ? 'Accepted' : 'Disputed'),
    tone: request.canRespond
        ? RowTone.warning
        : (request.status == 'accepted' ? RowTone.good : RowTone.alert),
  );

  static String _planLabel(String status) => switch (status) {
    'achieved' => 'Achieved',
    'open' => 'Open',
    'missed' => 'Missed',
    _ => 'Planned',
  };

  static RowTone _planTone(String status) => switch (status) {
    'achieved' => RowTone.good,
    'open' => RowTone.warning,
    'missed' => RowTone.alert,
    _ => RowTone.normal,
  };
}
