import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../models/unlisted.dart';
import '../../services/api_service.dart';
import '../../services/app_exception.dart';
import '../../services/unlisted_service.dart';
import '../admin/call_detail_sheet.dart';

/// Opens one unlisted doctor or chemist in full: who added it and when, its conversion, its patch, and its calls.
/// Every list that shows unlisted contacts opens this.
Future<void> showUnlistedDetail(BuildContext context, int unlistedId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _UnlistedDetailSheet(unlistedId: unlistedId),
    );

class _UnlistedDetailSheet extends StatefulWidget {
  const _UnlistedDetailSheet({required this.unlistedId});

  final int unlistedId;

  @override
  State<_UnlistedDetailSheet> createState() => _UnlistedDetailSheetState();
}

class _UnlistedDetailSheetState extends State<_UnlistedDetailSheet> {
  late final Future<UnlistedDetail> _detail = UnlistedService(
    Get.find<ApiService>(),
  ).detail(widget.unlistedId);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return FutureBuilder<UnlistedDetail>(
      future: _detail,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(AppSpace.xxl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final error = snapshot.error;
        if (error != null) {
          return Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Text(
              error is AppException ? error.message : 'Try again in a moment.',
              style: text.bodyMedium?.copyWith(color: p.alert),
            ),
          );
        }
        return _UnlistedDetailBody(detail: snapshot.data!);
      },
    );
  }
}

class _UnlistedDetailBody extends StatelessWidget {
  const _UnlistedDetailBody({required this.detail});

  final UnlistedDetail detail;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final unlisted = detail.unlisted;
    final converted = unlisted.isConverted;
    final lastVisit = detail.lastVisit;
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
                  unlisted.name,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s),
              const UnlistedTag(),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  unlisted.categoryName,
                  style: text.bodyMedium?.copyWith(color: p.inkMuted),
                ),
              ),
              _StatusPill(converted: converted),
            ],
          ),
          const SizedBox(height: AppSpace.l),
          DetailLine(
            label: 'Patch',
            value: '${unlisted.zoneName}  ›  ${unlisted.subzoneName}',
          ),
          DetailLine(
            label: 'Added by',
            value: unlisted.addedBy ?? 'Unknown user',
          ),
          DetailLine(label: 'Added on', value: formatMoment(unlisted.addedAt)),
          if (converted) ...[
            DetailLine(
              label: 'Converted by',
              value: unlisted.convertedBy ?? 'Unknown user',
            ),
            DetailLine(
              label: 'Converted on',
              value: unlisted.convertedAt == null
                  ? 'Not recorded'
                  : formatMoment(unlisted.convertedAt!),
            ),
          ],
          DetailLine(label: 'Calls', value: '${detail.callsTotal}'),
          DetailLine(label: 'Reps who called on them', value: '${detail.reps}'),
          DetailLine(
            label: 'Last call',
            value: lastVisit == null ? 'No calls yet' : formatDay(lastVisit),
          ),
          const SizedBox(height: AppSpace.s),
          Text(
            'Calls',
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
          const SizedBox(height: AppSpace.s),
          if (detail.calls.isEmpty)
            Text(
              'No calls recorded yet.',
              style: text.bodyMedium?.copyWith(color: p.inkMuted),
            )
          else
            for (final call in detail.calls)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s),
                child: _CallLineRow(call: call, contact: unlisted),
              ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.converted});

  final bool converted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final color = converted ? p.go : p.warning;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadius.sm,
      ),
      child: Text(
        converted ? 'Converted' : 'Open',
        style: text.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// One call on the contact. Opens the call's own detail.
class _CallLineRow extends StatelessWidget {
  const _CallLineRow({required this.call, required this.contact});

  final UnlistedCallLine call;
  final UnlistedContact contact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final status = callStatusStyle(p, call.status);
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.md,
        border: Border.all(color: p.border),
      ),
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: () =>
            showCallDetail(context, CallDetail.fromUnlistedCall(call, contact)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${formatDay(call.visitDate)}  ·  ${callTimeLabel(call.dayPart, call.visitTime)}',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      call.repName,
                      style: text.bodySmall?.copyWith(color: p.inkMuted),
                    ),
                  ],
                ),
              ),
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
        ),
      ),
    );
  }
}
