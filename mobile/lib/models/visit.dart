import 'package:flutter/material.dart';

import 'contact.dart';

/// A product a visit promoted.
class ProductRef {
  const ProductRef({required this.id, required this.name});

  factory ProductRef.fromJson(Map<String, Object?> json) =>
      ProductRef(id: json['id'] as int, name: json['name'] as String);

  final int id;
  final String name;
}

/// One recorded call, as the server returns it. Reads the caller's own calls and the joint calls they were part of.
class VisitRecord {
  const VisitRecord({
    required this.id,
    required this.userId,
    required this.repName,
    required this.visitDate,
    required this.visitTime,
    required this.status,
    required this.remarks,
    required this.contactId,
    required this.contactName,
    required this.categoryName,
    this.typeName,
    required this.zoneId,
    required this.zoneName,
    required this.subzoneId,
    required this.subzoneName,
    required this.products,
    required this.partnerUserId,
    required this.partnerStatus,
    required this.isEditable,
  });

  factory VisitRecord.fromJson(Map<String, Object?> json) => VisitRecord(
    id: json['id'] as int,
    userId: json['user_id'] as int,
    repName: json['rep_name'] as String,
    visitDate: DateTime.parse(json['visit_date'] as String),
    visitTime: json['visit_time'] as String,
    status: json['status'] as String,
    remarks: json['remarks'] as String,
    contactId: json['contact_id'] as int,
    contactName: json['contact_name'] as String,
    categoryName: json['category_name'] as String,
    typeName: json['type_name'] as String?,
    zoneId: json['zone_id'] as int,
    zoneName: json['zone_name'] as String,
    subzoneId: json['subzone_id'] as int,
    subzoneName: json['subzone_name'] as String,
    products: [
      for (final item in json['products'] as List<Object?>)
        ProductRef.fromJson((item as Map).cast()),
    ],
    partnerUserId: json['partner_user_id'] as int?,
    partnerStatus: json['partner_status'] as String?,
    isEditable: json['is_editable'] as bool,
  );

  final int id;
  final int userId;
  final String repName;
  final DateTime visitDate;

  /// The time as the server sends it, "HH:MM:SS".
  final String visitTime;

  /// open until the day ends, then completed; disputed when a joint call was refused.
  final String status;
  final String remarks;
  final int contactId;
  final String contactName;
  final String categoryName;
  final String? typeName;
  final int zoneId;
  final String zoneName;
  final int subzoneId;
  final String subzoneName;
  final List<ProductRef> products;
  final int? partnerUserId;

  /// The joint partner's answer as this rep sees it: pending, accepted or disputed. Null when there is no partner.
  final String? partnerStatus;
  final bool isEditable;

  TimeOfDay get time {
    final parts = visitTime.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Contact get contact => Contact(
    id: contactId,
    name: contactName,
    categoryName: categoryName,
    typeName: typeName,
    zoneId: zoneId,
    zoneName: zoneName,
    subzoneId: subzoneId,
    subzoneName: subzoneName,
    isActive: true,
  );
}

/// A rep's report for one date. Missing days are not on the server; the screen treats them as not reported.
class VisitDay {
  const VisitDay({
    required this.id,
    required this.userId,
    required this.visitDate,
    required this.status,
    required this.endedAt,
  });

  factory VisitDay.fromJson(Map<String, Object?> json) => VisitDay(
    id: json['id'] as int,
    userId: json['user_id'] as int,
    visitDate: DateTime.parse(json['visit_date'] as String),
    status: json['status'] as String,
    endedAt: json['ended_at'] == null
        ? null
        : DateTime.parse(json['ended_at'] as String),
  );

  final int id;
  final int userId;
  final DateTime visitDate;

  /// open while the rep can still change the day, ended once it is closed for good.
  final String status;
  final DateTime? endedAt;

  bool get isEnded => status == 'ended';

  bool get isLeave => status == 'leave';
}

/// A joint call another rep recorded with this rep. The rep accepts it or disputes it.
class JointRequest {
  const JointRequest({
    required this.visitId,
    required this.initiatorUserId,
    required this.visitDate,
    required this.visitTime,
    required this.contactName,
    required this.categoryName,
    this.typeName,
    required this.zoneName,
    required this.subzoneName,
    required this.remarks,
    required this.products,
    required this.status,
    required this.canRespond,
  });

  factory JointRequest.fromJson(Map<String, Object?> json) => JointRequest(
    visitId: json['visit_id'] as int,
    initiatorUserId: json['initiator_user_id'] as int,
    visitDate: DateTime.parse(json['visit_date'] as String),
    visitTime: json['visit_time'] as String,
    contactName: json['contact_name'] as String,
    categoryName: json['category_name'] as String,
    typeName: json['type_name'] as String?,
    zoneName: json['zone_name'] as String,
    subzoneName: json['subzone_name'] as String,
    remarks: json['remarks'] as String,
    products: [
      for (final item in json['products'] as List<Object?>)
        ProductRef.fromJson((item as Map).cast()),
    ],
    status: json['status'] as String,
    canRespond: json['can_respond'] as bool,
  );

  final int visitId;
  final int initiatorUserId;
  final DateTime visitDate;
  final String visitTime;
  final String contactName;
  final String categoryName;
  final String? typeName;
  final String zoneName;
  final String subzoneName;
  final String remarks;
  final List<ProductRef> products;

  /// pending until answered; accepted or disputed after.
  final String status;
  final bool canRespond;
}
