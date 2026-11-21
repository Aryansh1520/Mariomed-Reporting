import 'contact.dart';

/// A doctor or chemist a rep met that is not on the contact list. Kept per patch, and flagged once converted.
class UnlistedContact {
  const UnlistedContact({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.zoneId,
    required this.zoneName,
    required this.subzoneId,
    required this.subzoneName,
    required this.status,
    required this.addedBy,
    required this.addedAt,
    required this.convertedBy,
    required this.convertedAt,
  });

  factory UnlistedContact.fromJson(Map<String, Object?> json) =>
      UnlistedContact(
        id: json['id'] as int,
        name: json['name'] as String,
        categoryId: json['category_id'] as int,
        categoryName: json['category_name'] as String,
        zoneId: json['zone_id'] as int,
        zoneName: json['zone_name'] as String,
        subzoneId: json['subzone_id'] as int,
        subzoneName: json['subzone_name'] as String,
        status: json['status'] as String,
        addedBy: json['added_by'] as String?,
        addedAt: DateTime.parse(json['added_at'] as String),
        convertedBy: json['converted_by'] as String?,
        convertedAt: json['converted_at'] == null
            ? null
            : DateTime.parse(json['converted_at'] as String),
      );

  final int id;
  final String name;
  final int categoryId;
  final String categoryName;
  final int zoneId;
  final String zoneName;
  final int subzoneId;
  final String subzoneName;

  /// unlisted while it is still in use; converted once the admin has flagged it.
  final String status;

  /// Who added the contact, and when. The name is null when that user no longer exists.
  final String? addedBy;
  final DateTime addedAt;

  /// Who flagged the contact as converted, and when. Null until it is converted.
  final String? convertedBy;
  final DateTime? convertedAt;

  bool get isConverted => status == 'converted';

  /// The unlisted contact in the shape the record screen takes, so a call is recorded on it the same way.
  Contact toContact() => Contact(
    id: id,
    name: name,
    categoryName: categoryName,
    categoryId: categoryId,
    zoneId: zoneId,
    zoneName: zoneName,
    subzoneId: subzoneId,
    subzoneName: subzoneName,
    isActive: true,
    isUnlisted: true,
  );
}

/// The unlisted doctors and chemists of one patch for a period: how many are open, how many converted, and the calls on them.
class UnlistedPatch {
  const UnlistedPatch({
    required this.subzoneId,
    required this.subzoneName,
    required this.zoneName,
    required this.unlisted,
    required this.converted,
    required this.calls,
    required this.reps,
    required this.categories,
  });

  factory UnlistedPatch.fromJson(Map<String, Object?> json) => UnlistedPatch(
    subzoneId: json['subzone_id'] as int,
    subzoneName: json['subzone_name'] as String,
    zoneName: json['zone_name'] as String,
    unlisted: json['unlisted'] as int,
    converted: json['converted'] as int,
    calls: json['calls'] as int,
    reps: json['reps'] as int,
    categories: [
      for (final item in json['categories'] as List<Object?>)
        UnlistedCategory.fromJson((item as Map).cast()),
    ],
  );

  final int subzoneId;
  final String subzoneName;
  final String zoneName;
  final int unlisted;
  final int converted;
  final int calls;
  final int reps;
  final List<UnlistedCategory> categories;
}

/// The calls on one kind of unlisted contact within a patch.
class UnlistedCategory {
  const UnlistedCategory({
    required this.categoryName,
    required this.calls,
    required this.contacts,
  });

  factory UnlistedCategory.fromJson(Map<String, Object?> json) =>
      UnlistedCategory(
        categoryName: json['category_name'] as String,
        calls: json['calls'] as int,
        contacts: json['contacts'] as int,
      );

  final String categoryName;
  final int calls;
  final int contacts;
}

/// One unlisted doctor or chemist in a patch, with the calls made on them in the period.
class UnlistedContactStat {
  const UnlistedContactStat({
    required this.unlistedId,
    required this.name,
    required this.categoryName,
    required this.status,
    required this.calls,
    required this.reps,
    required this.lastVisit,
  });

  factory UnlistedContactStat.fromJson(Map<String, Object?> json) =>
      UnlistedContactStat(
        unlistedId: json['unlisted_id'] as int,
        name: json['name'] as String,
        categoryName: json['category_name'] as String,
        status: json['status'] as String,
        calls: json['calls'] as int,
        reps: json['reps'] as int,
        lastVisit: json['last_visit'] == null
            ? null
            : DateTime.parse(json['last_visit'] as String),
      );

  final int unlistedId;
  final String name;
  final String categoryName;
  final String status;
  final int calls;
  final int reps;
  final DateTime? lastVisit;

  bool get isConverted => status == 'converted';
}

/// One unlisted contact in full: the contact, its totals, and the calls made on it, newest first.
class UnlistedDetail {
  const UnlistedDetail({
    required this.unlisted,
    required this.callsTotal,
    required this.reps,
    required this.lastVisit,
    required this.calls,
  });

  factory UnlistedDetail.fromJson(Map<String, Object?> json) => UnlistedDetail(
    unlisted: UnlistedContact.fromJson(
      (json['unlisted'] as Map).cast<String, Object?>(),
    ),
    callsTotal: json['calls_total'] as int,
    reps: json['reps'] as int,
    lastVisit: json['last_visit'] == null
        ? null
        : DateTime.parse(json['last_visit'] as String),
    calls: [
      for (final item in json['calls'] as List<Object?>)
        UnlistedCallLine.fromJson((item as Map).cast()),
    ],
  );

  final UnlistedContact unlisted;
  final int callsTotal;
  final int reps;
  final DateTime? lastVisit;
  final List<UnlistedCallLine> calls;
}

/// One call on an unlisted contact.
class UnlistedCallLine {
  const UnlistedCallLine({
    required this.visitId,
    required this.visitDate,
    this.visitTime,
    required this.dayPart,
    required this.repName,
    required this.status,
    required this.products,
    required this.remarks,
  });

  factory UnlistedCallLine.fromJson(Map<String, Object?> json) =>
      UnlistedCallLine(
        visitId: json['visit_id'] as int,
        visitDate: DateTime.parse(json['visit_date'] as String),
        visitTime: json['visit_time'] as String?,
        dayPart: json['day_part'] as String,
        repName: json['rep_name'] as String,
        status: json['status'] as String,
        products: [
          for (final name in json['products'] as List<Object?>) name as String,
        ],
        remarks: json['remarks'] as String,
      );

  final int visitId;
  final DateTime visitDate;
  final String? visitTime;
  final String dayPart;
  final String repName;
  final String status;
  final List<String> products;
  final String remarks;
}
