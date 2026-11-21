import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../models/contact.dart';
import '../../models/team_dashboard.dart';

/// One call in full, for the modal that opens from any call listing on the admin side.
class CallDetail {
  const CallDetail({
    required this.contactName,
    required this.kind,
    required this.status,
    required this.visitDate,
    required this.timeLabel,
    required this.products,
    required this.remarks,
    this.repName,
    this.zoneName,
    this.isUnlisted = false,
  });

  factory CallDetail.fromTeamLine(TeamCallLine call) => CallDetail(
    contactName: call.contactName,
    kind: contactKind(call.categoryName, call.typeName),
    status: call.status,
    visitDate: call.visitDate,
    timeLabel: callTimeLabel(call.dayPart, call.visitTime),
    products: call.products,
    remarks: call.remarks,
    repName: call.repName,
    zoneName: call.zoneName,
    isUnlisted: call.isUnlisted,
  );

  final String contactName;
  final String kind;
  final String status;
  final DateTime visitDate;
  final String timeLabel;
  final List<String> products;
  final String remarks;
  final String? repName;
  final String? zoneName;
  final bool isUnlisted;
}

/// Opens one call's detail as a modal.
Future<void> showCallDetail(BuildContext context, CallDetail detail) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CallDetailSheet(detail: detail),
    );

/// The label on an unlisted doctor or chemist: a small amber tag beside the name.
class UnlistedTag extends StatelessWidget {
  const UnlistedTag({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s, vertical: 2),
      decoration: BoxDecoration(color: p.warning, borderRadius: AppRadius.sm),
      child: Text(
        'UNLISTED',
        style: text.labelSmall?.copyWith(
          color: p.onAccent,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// A label over a value, used for each line of a call's detail.
class DetailLine extends StatelessWidget {
  const DetailLine({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodySmall?.copyWith(color: p.inkMuted)),
          const SizedBox(height: AppSpace.xs),
          Text(value, style: text.bodyMedium?.copyWith(color: p.ink)),
        ],
      ),
    );
  }
}

/// The label and colours for a call's status.
(String, Color, Color) callStatusStyle(AppPalette p, String status) =>
    switch (status) {
      'completed' => ('Reported', p.go.withValues(alpha: 0.14), p.go),
      'disputed' => ('Disputed', p.alert.withValues(alpha: 0.14), p.alert),
      _ => ('Open', p.primary.withValues(alpha: 0.14), p.primary),
    };

class _CallDetailSheet extends StatelessWidget {
  const _CallDetailSheet({required this.detail});

  final CallDetail detail;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final status = callStatusStyle(p, detail.status);
    final remarks = detail.remarks.trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        0,
        AppSpace.xl,
        AppSpace.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.contactName,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s,
                  vertical: AppSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: status.$2,
                  borderRadius: AppRadius.sm,
                ),
                child: Text(
                  status.$1,
                  style: text.labelMedium?.copyWith(
                    color: status.$3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.kind,
                  style: text.bodyMedium?.copyWith(color: p.inkMuted),
                ),
              ),
              if (detail.isUnlisted) const UnlistedTag(),
            ],
          ),
          const SizedBox(height: AppSpace.l),
          DetailLine(
            label: 'Date',
            value:
                '${formatDay(detail.visitDate)}  ·  ${weekdayName(detail.visitDate)}',
          ),
          DetailLine(label: 'Time', value: detail.timeLabel),
          if (detail.repName != null)
            DetailLine(label: 'Rep', value: detail.repName!),
          if (detail.zoneName != null)
            DetailLine(label: 'Zone', value: detail.zoneName!),
          DetailLine(
            label: 'Products',
            value: detail.products.isEmpty
                ? 'None recorded'
                : detail.products.join(', '),
          ),
          DetailLine(
            label: 'Remarks',
            value: remarks.isEmpty ? 'No remarks' : remarks,
          ),
        ],
      ),
    );
  }
}
