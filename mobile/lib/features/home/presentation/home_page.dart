import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/uzbek_alphabet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/language_picker_sheet.dart';
import '../../../core/widgets/lex_modal_sheet.dart';
import '../../../core/widgets/risk_badges.dart';
import '../../../core/widgets/theme_reveal_scope.dart';
import '../../contracts/domain/entities/lex_models.dart';
import '../../contracts/presentation/cubit/contracts_cubit.dart';
import '../../monitoring/domain/law_monitoring_models.dart';
import '../../monitoring/presentation/monitoring_sheets.dart';
import '../../profile/presentation/plans_modal_sheet.dart';
import '../../session/presentation/cubit/session_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final contracts = context.watch<ContractsCubit>().state;
    final monitoring = context.watch<MonitoringCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;
    final isBusiness = session.segment == AccountSegment.business;

    final lawNews = [
      _LawNewsItem(
        code: AppStrings.t(lang, 'news_1_code', script: script),
        tag: AppStrings.t(lang, 'news_1_date', script: script),
        title: AppStrings.t(lang, 'news_1_title', script: script),
        body: AppStrings.t(lang, 'news_1_body', script: script),
        icon: CupertinoIcons.sparkles,
        highlight: true,
      ),
      _LawNewsItem(
        code: AppStrings.t(lang, 'news_2_code', script: script),
        tag: AppStrings.t(lang, 'news_2_date', script: script),
        title: AppStrings.t(lang, 'news_2_title', script: script),
        body: AppStrings.t(lang, 'news_2_body', script: script),
        icon: CupertinoIcons.checkmark_shield_fill,
      ),
      _LawNewsItem(
        code: AppStrings.t(lang, 'news_3_code', script: script),
        tag: AppStrings.t(lang, 'news_3_date', script: script),
        title: AppStrings.t(lang, 'news_3_title', script: script),
        body: AppStrings.t(lang, 'news_3_body', script: script),
        icon: CupertinoIcons.lock_shield_fill,
      ),
      _LawNewsItem(
        code: AppStrings.t(lang, 'news_4_code', script: script),
        tag: AppStrings.t(lang, 'news_4_date', script: script),
        title: AppStrings.t(lang, 'news_4_title', script: script),
        body: AppStrings.t(lang, 'news_4_body', script: script),
        icon: CupertinoIcons.doc_text_fill,
      ),
    ];

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          // Top Brand & Utility Bar
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [c.roleGradientStart, c.roleGradientEnd],
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.shield_lefthalf_fill,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'LexGuard AI',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: c.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (isBusiness) ...[
                    _NotificationBellPill(
                      unreadCount: monitoring.unreadCount,
                      onTap: () => MonitoringNotificationsSheet.show(context),
                    ),
                    const SizedBox(width: 6),
                  ],
                  GlassPill(
                    key: const Key('lang_picker_pill'),
                    onTap: () => LanguagePickerSheet.show(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lang.code,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          CupertinoIcons.chevron_down,
                          size: 12,
                          color: c.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  LexThemeTogglePill(
                    isDark: session.themeMode == ThemeMode.dark,
                  ),
                ],
              ),
            ),
          ),

          // Account Title + Role Design System Pill
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.adaptUz(session.organizationName, lang, script),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    key: const Key('role_switch_pill'),
                    onTap: () => _showRoleQuickSwitch(
                      context,
                      session.segment,
                      lang,
                      script,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: c.rolePrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: c.rolePrimary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.rolePrimary,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isBusiness
                                ? AppStrings.t(lang, 'business_b2b', script: script)
                                : AppStrings.t(
                                    lang,
                                    'individual_b2c',
                                    script: script,
                                  ),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: c.rolePrimary,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            CupertinoIcons.chevron_down,
                            size: 11,
                            color: c.rolePrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dual-Role Executive Status Card (Sapphire vs Emerald+Gold)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [c.roleGradientStart, c.roleGradientEnd],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: c.roleGlow,
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -32,
                          top: -36,
                          child: Container(
                            width: 148,
                            height: 148,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (isBusiness
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFF7DD3FC))
                                  .withValues(alpha: 0.16),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (isBusiness
                                                  ? const Color(0xFFFBBF24)
                                                  : Colors.white)
                                              .withValues(
                                            alpha: isBusiness ? 0.22 : 0.18,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: (isBusiness
                                                    ? const Color(0xFFFDE68A)
                                                    : Colors.white)
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: Text(
                                          AppStrings.adaptUz(
                                            session.quota.planName,
                                            lang,
                                            script,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => PlansModalSheet.show(context),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.16),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            CupertinoIcons.sparkles,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            AppStrings.t(
                                              lang,
                                              'plans',
                                              script: script,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${session.quota.remainingTotal} / ${session.quota.totalLimit}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.0,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      AppStrings.t(
                                        lang,
                                        'remaining_analyses',
                                        script: script,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${AppStrings.t(lang, 'today_limit', script: script)}: ${session.quota.todayUsed}/${session.quota.todayLimit}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: session.quota.totalLimit == 0
                                      ? 0
                                      : session.quota.totalUsed /
                                          session.quota.totalLimit,
                                  minHeight: 6,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.22),
                                  color: isBusiness
                                      ? const Color(0xFFFDE68A)
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // B2B Live Law-Change Monitoring Section (DOCX §8) — clean, zero noise
          if (isBusiness) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              AppStrings.t(
                                lang,
                                'b2b_monitoring_title',
                                script: script,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                          if (monitoring.activeCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: c.redBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${monitoring.activeCount}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: c.redText,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          MonitoringNotificationsSheet.show(context),
                      child: Text(
                        AppStrings.t(lang, 'see_all', script: script),
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
            SliverToBoxAdapter(
              child: monitoring.activeCount == 0
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: GlassCard(
                        radius: 20,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.checkmark_seal_fill,
                              size: 18,
                              color: c.greenText,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                AppStrings.t(
                                  lang,
                                  'b2b_monitoring_all_clear',
                                  script: script,
                                ),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 122,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        itemCount: monitoring.alerts
                            .where((a) => !a.isResolved)
                            .length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final activeAlerts = monitoring.alerts
                              .where((a) => !a.isResolved)
                              .toList(growable: false);
                          final alert = activeAlerts[index];
                          return _MonitoringAlertCard(
                            alert: alert,
                            lang: lang,
                            script: script,
                            onTap: () => MonitoringAlertDetailSheet.show(
                              context,
                              alert: alert,
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],

          // Result Statuses Guide (Natija: 3 rang) — compact & clean
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _StatusGuideCard(
                lang: lang,
                script: script,
                onTapMore: () => _showStatusGuideDetail(
                  context,
                  lang: lang,
                  script: script,
                ),
              ),
            ),
          ),

          // Law Updates / Legal News Section (Citizen B2C only; B2B has targeted Law Monitoring above)
          if (!isBusiness) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.t(lang, 'law_updates_title', script: script),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/laws'),
                      child: Text(
                        AppStrings.t(lang, 'see_all', script: script),
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
            SliverToBoxAdapter(
              child: SizedBox(
                height: 138,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: lawNews.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final news = lawNews[index];
                    return _LawNewsCard(
                      item: news,
                      onTap: () => _showNewsDetail(
                        context,
                        item: news,
                        lang: lang,
                        script: script,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          // Recent Checks Header
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.t(lang, 'recent_checks', script: script),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/documents'),
                    child: Text(
                      AppStrings.t(lang, 'see_all', script: script),
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

          // Recent Analyses List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: contracts.analyses.length.clamp(0, 4),
              itemBuilder: (context, index) {
                final item = contracts.analyses[index];
                final monAlert =
                    isBusiness ? monitoring.alertForContract(item.id) : null;
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
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: c.rolePrimary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                CupertinoIcons.doc_text_fill,
                                size: 18,
                                color: c.rolePrimary,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppStrings.adaptUz(
                                      item.title,
                                      lang,
                                      script,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.formatLabel} · ${AppStrings.adaptUz(item.overallBalanceLabel, lang, script)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
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
                        if (monAlert != null) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => MonitoringAlertDetailSheet.show(
                              context,
                              alert: monAlert,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: c.yellowText,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      '${AppStrings.t(lang, 'b2b_monitoring_affected_pill', script: script)} · ${AppStrings.adaptUz(monAlert.affectedClause, lang, script)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: c.yellowText,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    CupertinoIcons.chevron_forward,
                                    size: 12,
                                    color: c.yellowText,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        RiskColorSummaryRow(analysis: item, compact: true),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 110),
          ),
        ],
      ),
    );
  }

  void _showNewsDetail(
    BuildContext context, {
    required _LawNewsItem item,
    required AppLang lang,
    required UzbekScript script,
  }) {
    final c = context.lexColors;
    showLexModalSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: c.rolePrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.code,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: c.rolePrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.tag,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.body,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/laws');
                  },
                  child: Text(
                    AppStrings.t(lang, 'nav_laws', script: script),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    AppStrings.t(lang, 'ok_btn', script: script),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStatusGuideDetail(
    BuildContext context, {
    required AppLang lang,
    required UzbekScript script,
  }) {
    final c = context.lexColors;
    final items = [
      (
        dot: c.redText,
        title: AppStrings.t(lang, 'status_red_title', script: script),
        body: AppStrings.t(lang, 'status_red_detail', script: script),
      ),
      (
        dot: c.yellowText,
        title: AppStrings.t(lang, 'status_yellow_title', script: script),
        body: AppStrings.t(lang, 'status_yellow_detail', script: script),
      ),
      (
        dot: c.greenText,
        title: AppStrings.t(lang, 'status_green_title', script: script),
        body: AppStrings.t(lang, 'status_green_detail', script: script),
      ),
    ];

    showLexModalSheet<void>(
      context: context,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.78,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.t(lang, 'status_guide_title', script: script),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              for (int i = 0; i < items.length; i++) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.grayBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: items[i].dot,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              items[i].title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        items[i].body,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              // Uncolored ("0" verdict) rule — explicitly NOT a 4th color
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: c.glassBorder, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: c.textSecondary,
                              width: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            AppStrings.t(
                              lang,
                              'status_gray_title',
                              script: script,
                            ),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      AppStrings.t(lang, 'status_gray_detail', script: script),
                      style: TextStyle(
                        fontSize: 13.2,
                        height: 1.45,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppStrings.t(lang, 'status_guide_footer', script: script),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(AppStrings.t(lang, 'ok_btn', script: script)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoleQuickSwitch(
    BuildContext context,
    AccountSegment current,
    AppLang lang,
    UzbekScript script,
  ) {
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
                AppStrings.t(lang, 'role_switch_title', script: script),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                key: const Key('quick_switch_individual'),
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
                title: Text(
                  AppStrings.t(lang, 'role_individual_title', script: script),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                trailing: current == AccountSegment.individual
                    ? const Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        color: Color(0xFF0066FF),
                      )
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
                key: const Key('quick_switch_business'),
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
                title: Text(
                  AppStrings.t(lang, 'role_business_title', script: script),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                trailing: current == AccountSegment.business
                    ? const Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        color: Color(0xFF047857),
                      )
                    : null,
                onTap: () {
                  context
                      .read<SessionCubit>()
                      .setSegment(AccountSegment.business);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationBellPill extends StatelessWidget {
  const _NotificationBellPill({
    required this.unreadCount,
    required this.onTap,
  });

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GlassPill(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Icon(
            CupertinoIcons.bell_fill,
            size: 15,
            color: unreadCount > 0 ? c.rolePrimary : c.textPrimary,
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: -2,
            top: -3,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.redText,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: c.canvasBg, width: 1.5),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonitoringAlertCard extends StatelessWidget {
  const _MonitoringAlertCard({
    required this.alert,
    required this.lang,
    required this.script,
    required this.onTap,
  });

  final LawMonitoringAlert alert;
  final AppLang lang;
  final UzbekScript script;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final accent = alert.isRead ? c.yellowText : c.redText;

    return SizedBox(
      width: 264,
      child: GlassCard(
        radius: 22,
        padding: const EdgeInsets.all(14),
        borderColor: accent.withValues(alpha: 0.35),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    AppStrings.adaptUz(alert.lawCode, lang, script),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.rolePrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    AppStrings.adaptUz(alert.affectedClause, lang, script),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: c.rolePrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.adaptUz(alert.documentTitle, lang, script),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.adaptUz(alert.changeSummary, lang, script),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.32,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusGuideCard extends StatelessWidget {
  const _StatusGuideCard({
    required this.lang,
    required this.script,
    required this.onTapMore,
  });

  final AppLang lang;
  final UzbekScript script;
  final VoidCallback onTapMore;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final rows = [
      (
        dot: c.redText,
        title: AppStrings.t(lang, 'status_red_title', script: script),
        desc: AppStrings.t(lang, 'status_red_short', script: script),
      ),
      (
        dot: c.yellowText,
        title: AppStrings.t(lang, 'status_yellow_title', script: script),
        desc: AppStrings.t(lang, 'status_yellow_short', script: script),
      ),
      (
        dot: c.greenText,
        title: AppStrings.t(lang, 'status_green_title', script: script),
        desc: AppStrings.t(lang, 'status_green_short', script: script),
      ),
    ];

    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: onTapMore,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.t(lang, 'status_guide_title', script: script),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: c.textPrimary,
                  ),
                ),
              ),
              Text(
                AppStrings.t(lang, 'status_guide_more', script: script),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: c.rolePrimary,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 13,
                color: c.rolePrimary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < rows.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: rows[i].dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rows[i].title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        rows[i].desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.2,
                          height: 1.32,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (i < rows.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _LawNewsItem {
  const _LawNewsItem({
    required this.code,
    required this.tag,
    required this.title,
    required this.body,
    required this.icon,
    this.highlight = false,
  });

  final String code;
  final String tag;
  final String title;
  final String body;
  final IconData icon;
  final bool highlight;
}

class _LawNewsCard extends StatelessWidget {
  const _LawNewsCard({
    required this.item,
    required this.onTap,
  });

  final _LawNewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final accent = item.highlight ? c.roleAccent : c.rolePrimary;

    return SizedBox(
      width: 236,
      child: GlassCard(
        radius: 22,
        padding: const EdgeInsets.all(14),
        borderColor: item.highlight
            ? accent.withValues(alpha: 0.35)
            : c.glassBorder,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.code,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  item.tag,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  letterSpacing: -0.2,
                  color: c.textPrimary,
                ),
              ),
            ),
            Row(
              children: [
                Icon(item.icon, size: 13, color: c.rolePrimary),
                const SizedBox(width: 5),
                Text(
                  'Lex.uz',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: c.rolePrimary,
                  ),
                ),
                const Spacer(),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 13,
                  color: c.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
