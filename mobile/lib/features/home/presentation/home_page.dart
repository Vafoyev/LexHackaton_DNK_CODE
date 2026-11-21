import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/risk_badges.dart';
import '../../analysis/presentation/clause_detail_sheet.dart';
import '../../contracts/domain/entities/lex_models.dart';
import '../../contracts/presentation/cubit/contracts_cubit.dart';
import '../../scanner_upload/presentation/scan_upload_sheet.dart';
import '../../session/presentation/cubit/session_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final contracts = context.watch<ContractsCubit>().state;
    final lang = session.lang;
    final isBusiness = session.segment == AccountSegment.business;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          // Top iOS Utility & Role Bar
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Flexible(
                    child: GlassPill(
                      key: const Key('role_switch_pill'),
                      onTap: () => _showRoleQuickSwitch(context, session.segment),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.rolePrimary,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              isBusiness
                                  ? AppStrings.t(lang, 'business_b2b')
                                  : AppStrings.t(lang, 'individual_b2c'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            CupertinoIcons.chevron_down,
                            size: 13,
                            color: c.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassPill(
                    onTap: () => context.read<SessionCubit>().cycleLang(),
                    child: Text(
                      lang.code,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GlassPill(
                    padding: const EdgeInsets.all(8),
                    onTap: () =>
                        context.read<SessionCubit>().toggleThemeMode(),
                    child: Icon(
                      session.themeMode == ThemeMode.dark
                          ? CupertinoIcons.sun_max_fill
                          : CupertinoIcons.moon_fill,
                      size: 15,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Apple Large Title & Account Subtitle
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.organizationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.authProviderLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Apple Wallet Style Executive Gradient Glass Quota Card
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: RepaintBoundary(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [c.roleGradientStart, c.roleGradientEnd],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: c.roleGlow,
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                AppStrings.t(lang, 'trial_badge'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${AppStrings.t(lang, 'today_limit')}: ${session.quota.todayUsed}/${session.quota.todayLimit}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${session.quota.remainingTotal} / ${session.quota.totalLimit}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppStrings.t(lang, 'remaining_analyses'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: session.quota.totalLimit == 0
                              ? 0
                              : session.quota.totalUsed /
                                  session.quota.totalLimit,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.22),
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => ScanUploadSheet.show(context),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.viewfinder,
                                      size: 16,
                                      color: c.rolePrimaryDark,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        AppStrings.t(lang, 'scan'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: c.rolePrimaryDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => context.go('/profile'),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.sparkles,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        AppStrings.t(lang, 'plans'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Control Center Glass Services Grid (Monochrome Role-Tinted Icons!)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            sliver: SliverToBoxAdapter(
              child: Text(
                AppStrings.t(lang, 'quick_services'),
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: c.textPrimary,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.0,
                children: [
                  _GlassServiceTile(
                    icon: CupertinoIcons.doc_on_doc_fill,
                    label: AppStrings.t(lang, 'svc_upload'),
                    onTap: () => ScanUploadSheet.show(context),
                  ),
                  _GlassServiceTile(
                    icon: CupertinoIcons.camera_fill,
                    label: AppStrings.t(lang, 'svc_camera'),
                    onTap: () =>
                        ScanUploadSheet.show(context, focusCamera: true),
                  ),
                  _GlassServiceTile(
                    icon: CupertinoIcons.checkmark_shield_fill,
                    label: AppStrings.t(lang, 'svc_notarial'),
                    onTap: () => _launchNotarialQuick(context),
                  ),
                  _GlassServiceTile(
                    icon: CupertinoIcons.envelope_fill,
                    label: AppStrings.t(lang, 'svc_claim'),
                    onTap: () => _openLatestProtocol(context, contracts),
                  ),
                  _GlassServiceTile(
                    icon: CupertinoIcons.chat_bubble_2_fill,
                    label: AppStrings.t(lang, 'svc_mediation'),
                    onTap: () => _showInfoSheet(
                      context,
                      title: 'Mediatsiya bandi va reestr (1-trek)',
                      body:
                          'LexGuard R5 qoidasi har bir shartnomada 10 kunlik pretenziya va professional mediatsiya bosqichini qo‘shishni taklif qiladi (Mediatsiya qonuni, 16-modda).',
                    ),
                  ),
                  _GlassServiceTile(
                    icon: CupertinoIcons.person_2_fill,
                    label: AppStrings.t(lang, 'svc_lawyer'),
                    onTap: () => _showInfoSheet(
                      context,
                      title: 'Hamkor advokat ko‘rigi (3.2 modeli)',
                      body:
                          'Kulrang (Unknown) yoki tasdiqlanmagan bandlar hamkor advokatga yo‘naltiriladi. Pullik ko‘rik faqat reyestrdagi advokat orqali amalga oshiriladi (VM 675).',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Recent Checks Header
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.t(lang, 'recent_checks'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/documents'),
                    child: Text(
                      AppStrings.t(lang, 'see_all'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: c.rolePrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Frosted Glass Recent Analyses List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: contracts.analyses.length.clamp(0, 4),
              itemBuilder: (context, index) {
                final item = contracts.analyses[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    radius: 22,
                    padding: const EdgeInsets.all(14),
                    onTap: () => context.push('/analysis/${item.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: c.rolePrimary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                CupertinoIcons.doc_text_fill,
                                size: 18,
                                color: c.rolePrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.formatLabel} · ${item.overallBalanceLabel}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              CupertinoIcons.chevron_forward,
                              size: 16,
                              color: c.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        RiskColorSummaryRow(analysis: item),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Subtle O'RQ-1115 Footer + Floating Navbar Clearance
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
            sliver: SliverToBoxAdapter(
              child: GlassCard(
                radius: 18,
                padding: const EdgeInsets.all(12),
                child: Text(
                  AppStrings.t(lang, 'orq_1115_banner'),
                  style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRoleQuickSwitch(BuildContext context, AccountSegment current) {
    final c = context.lexColors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(14),
        child: GlassCard(
          radius: 28,
          blurSigma: 26,
          tintColor: c.glassFillStrong,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Rolni tanlang (rang va muhit darhol o‘zgaradi)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF0066FF),
                  child: Icon(
                    CupertinoIcons.person_fill,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                title: const Text(
                  'Jismoniy shaxs (Sapphire Ko‘k)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: current == AccountSegment.individual
                    ? const Icon(CupertinoIcons.checkmark_circle_fill,
                        color: Color(0xFF0066FF))
                    : null,
                onTap: () {
                  context
                      .read<SessionCubit>()
                      .setSegment(AccountSegment.individual);
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF047857),
                  child: Icon(
                    CupertinoIcons.building_2_fill,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                title: const Text(
                  'Yuridik shaxs B2B (Executive Zumrad)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: current == AccountSegment.business
                    ? const Icon(CupertinoIcons.checkmark_circle_fill,
                        color: Color(0xFF047857))
                    : null,
                onTap: () {
                  context
                      .read<SessionCubit>()
                      .setSegment(AccountSegment.business);
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.read<SessionCubit>().returnToRoleSelect();
                  context.go('/role-select');
                },
                child: const Text('Kirish ekraniga qaytish'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchNotarialQuick(BuildContext context) async {
    final session = context.read<SessionCubit>();
    final contracts = context.read<ContractsCubit>();
    final res = await contracts.runDemoAnalysis(
      'sample_notarial_r6',
      allowExternalAi: session.state.externalAiConsent,
    );
    if (context.mounted && res != null) {
      session.consumeQuota();
      context.push('/analysis/${res.id}');
    }
  }

  void _openLatestProtocol(BuildContext context, ContractsState contracts) {
    if (contracts.analyses.isEmpty) {
      ScanUploadSheet.show(context);
      return;
    }
    ExportPreviewSheet.showCommentsAndProtocol(
      context,
      contracts.analyses.first,
    );
  }

  void _showInfoSheet(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    final c = context.lexColors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(14),
        child: GlassCard(
          radius: 26,
          tintColor: c.glassFillStrong,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tushunarli'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassServiceTile extends StatelessWidget {
  const _GlassServiceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.rolePrimary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 21, color: c.rolePrimary),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.15,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
