import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../app/routes/app_routes.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/team_dashboard_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_feedback.dart';
import '../../core/utils/business_time.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glass_bar.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/glass_tray.dart';
import '../../core/widgets/home_graphs.dart';
import '../../core/widgets/loading_list.dart';
import '../../core/widgets/pill_tabs.dart';
import '../../core/widgets/mesh_hero.dart';
import '../../core/widgets/press_scale.dart';
import '../../models/current_user.dart';
import '../../models/dashboard.dart';
import '../../models/report.dart';
import '../../services/auth_service.dart';
import '../admin/team_dashboard_view.dart';
import 'dashboard_sections.dart';

/// Home: a mesh hero with this month's coverage and the last two weeks of calls, then a few short cards.
/// Every figure comes from the server's dashboard, so a card shows only when the caller may see it.
/// Callers with admin.dashboard see the team's figures below the hero instead of their own cards.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final size = AppLayout.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Obx(() {
        final user = controller.user;
        if (user == null) {
          return const EmptyState(
            icon: Iconsax.lock,
            title: 'Sign in again',
            message: 'Your session is no longer available.',
          );
        }
        final dashboard = controller.dashboard;
        final isAdmin = Get.find<AuthService>().can('admin.dashboard');
        final team = Get.find<TeamDashboardController>();
        final gutter = AppLayout.gutter(size);
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth(size),
            ),
            child: RefreshIndicator(
              onRefresh: () async {
                await Get.find<AuthService>().refreshCurrentUser().catchError(
                  (_) {},
                );
                await controller.loadDashboard();
                if (isAdmin) await team.load();
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpace.xxl),
                children: [
                  _Hero(user: user, dashboard: dashboard),
                  if (isAdmin)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        AppSpace.l,
                        gutter,
                        0,
                      ),
                      child: _TeamSections(team: team),
                    )
                  else if (dashboard != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        AppSpace.l,
                        gutter,
                        0,
                      ),
                      child: DashboardSections(dashboard: dashboard),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// The team figures on Home for admin.dashboard: loading and error states, then the shared team sections.
class _TeamSections extends StatelessWidget {
  const _TeamSections({required this.team});

  final TeamDashboardController team;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PeriodBar(team: team),
        const SizedBox(height: AppSpace.l),
        Obx(() {
          if (team.isLoading.value) {
            return const SizedBox(height: 240, child: LoadingList(count: 3));
          }
          final error = team.loadError.value;
          if (error != null) {
            return EmptyState(
              icon: Iconsax.warning_2,
              title: 'Could not load the team figures',
              message: error,
            );
          }
          final data = team.dashboard.value;
          if (data == null) return const SizedBox.shrink();
          return TeamDashboardSections(dashboard: data);
        }),
      ],
    );
  }
}

/// Today, 7 days, 30 days and a custom range, in one row above the team figures. The shown dates sit under it.
class _PeriodBar extends StatelessWidget {
  const _PeriodBar({required this.team});

  final TeamDashboardController team;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PillTabs<TeamPeriod>(
            items: const [
              (TeamPeriod.today, 'Today'),
              (TeamPeriod.thisMonth, 'Month'),
              (TeamPeriod.last7Days, '7 days'),
              (TeamPeriod.custom, 'Custom'),
            ],
            selected: team.period.value,
            onSelected: (value) => value == TeamPeriod.custom
                ? _pickRange(context)
                : team.choose(value),
          ),
          const SizedBox(height: AppSpace.m),
          SizedBox(
            width: double.infinity,
            child: Text(
              '${formatDay(team.from.value)} to ${formatDay(team.to.value)}',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: p.inkMuted),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final today = indiaToday();
    final range = await showDateRangePicker(
      context: context,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: team.from.value,
        end: team.to.value,
      ),
    );
    if (range != null) team.setCustomRange(range);
  }
}

/// The hero, laid out as the original: the notification button, the greeting and name, the stats bar, then a
/// frosted card. The card holds the graphs rather than the role.
class _Hero extends StatelessWidget {
  const _Hero({required this.user, required this.dashboard});

  final CurrentUser user;
  final Dashboard? dashboard;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final coverage = dashboard?.coverage;
    final calls = dashboard?.dailyCalls;

    return MeshHero(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpace.s,
                right: AppSpace.l,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: _HeroIconButton(
                  icon: Iconsax.notification,
                  onTap: () => showAppMessage(
                    'Notifications',
                    'Notifications arrive in a later update.',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 88),
            Text(
              timeOfDayGreeting(indiaNow()),
              style: text.bodyLarge?.copyWith(
                color: p.onHero,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              user.fullName,
              textAlign: TextAlign.center,
              style: text.displaySmall?.copyWith(
                color: p.onHero,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            const SizedBox(height: AppSpace.xxl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
              child: _statBar(dashboard),
            ),
            const SizedBox(height: AppSpace.l),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
              child: GlassTray(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (coverage != null)
                      GestureDetector(
                        onTap: () => Get.toNamed(
                          AppRoutes.report,
                          arguments: ReportKind.coverage,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Coverage this month',
                                    style: text.titleLarge?.copyWith(
                                      color: p.ink,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpace.xs),
                                  Text(
                                    '${coverage.visited} of ${coverage.total} contacts visited',
                                    style: text.bodyLarge?.copyWith(
                                      color: p.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CoverageRing(
                              percent: coverage.percent,
                              color: p.primary,
                              track: p.border,
                              size: 64,
                            ),
                          ],
                        ),
                      ),
                    if (calls != null) ...[
                      const SizedBox(height: AppSpace.l),
                      Divider(height: 1, color: p.border),
                      const SizedBox(height: AppSpace.l),
                      GestureDetector(
                        onTap: () => Get.toNamed(
                          AppRoutes.report,
                          arguments: ReportKind.calls,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Calls, last 14 days',
                              style: text.titleSmall?.copyWith(
                                color: p.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: AppSpace.m),
                            CallBars(
                              days: calls,
                              color: p.primary,
                              muted: p.inkMuted,
                              empty: p.border,
                              barHeight: 56,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xxl),
          ],
        ),
      ),
    );
  }

  /// Calls this month and the contacts still unvisited. Admins see the team's figures, everyone else their own.
  Widget _statBar(Dashboard? dashboard) {
    if (Get.find<AuthService>().can('admin.dashboard')) {
      final team = Get.find<TeamDashboardController>();
      return Obx(() {
        final summary = team.dashboard.value?.summary;
        return GlassBar(
          count: summary?.calls ?? 0,
          message: summary == null
              ? 'Calls this month'
              : 'Calls this month · ${summary.missedCalls} missed',
        );
      });
    }
    return GlassBar(
      count: dashboard?.month?.calls ?? 0,
      message:
          'Calls this month · ${dashboard?.missed?.missedContacts ?? 0} missed',
    );
  }
}

/// The round icon button on the hero: frosted glass with a white icon.
class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressScale(
      onTap: onTap,
      child: GlassSurface(
        radius: AppRadius.pill,
        tint: p.onHero.withValues(alpha: 0.2),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: Icon(icon, color: p.onHero, size: 20)),
        ),
      ),
    );
  }
}
