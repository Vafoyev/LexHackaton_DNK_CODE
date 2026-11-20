import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
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

    return CustomScrollView(
      slivers: [
        // Soliq-style Deep Blue Gradient Header + Overlapping Floating Quota Card
        SliverToBoxAdapter(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                  18,
                  MediaQuery.paddingOf(context).top + 14,
                  18,
                  76,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c.brandDeepBlue, c.brandPrimaryBlue],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          child: const Icon(
                            Icons.gavel_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.organizationName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'LexGuard AI · ${session.authProviderLabel}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Compact UZ / RU / EN switcher
                        InkWell(
                          onTap: () =>
                              context.read<SessionCubit>().cycleLang(),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              lang.code,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // B2B / Individual Soliq Segment Pill
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SegmentBtn(
                              label: AppStrings.t(lang, 'business_b2b'),
                              selected:
                                  session.segment == AccountSegment.business,
                              onTap: () => context
                                  .read<SessionCubit>()
                                  .setSegment(AccountSegment.business),
                            ),
                          ),
                          Expanded(
                            child: _SegmentBtn(
                              label: AppStrings.t(lang, 'individual_b2c'),
                              selected:
                                  session.segment == AccountSegment.individual,
                              onTap: () => context
                                  .read<SessionCubit>()
                                  .setSegment(AccountSegment.individual),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Floating Overlapped Quota Card (Soliq Cashback Card signature)
              Positioned(
                left: 16,
                right: 16,
                bottom: -52,
                child: Card(
                  elevation: 4,
                  shadowColor: c.brandDeepBlue.withValues(alpha: 0.15),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: c.brandCyan.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  AppStrings.t(lang, 'trial_badge'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: c.brandDeepBlue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${AppStrings.t(lang, 'today_limit')}: ${session.quota.todayUsed}/${session.quota.todayLimit}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: c.grayText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${session.quota.remainingTotal} / ${session.quota.totalLimit}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                AppStrings.t(lang, 'remaining_analyses'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    TextStyle(fontSize: 13, color: c.grayText),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: session.quota.totalLimit == 0
                                ? 0
                                : session.quota.totalUsed /
                                    session.quota.totalLimit,
                            minHeight: 7,
                            backgroundColor: c.grayBg,
                            color: c.brandPrimaryBlue,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => context.go('/profile'),
                                icon: const Icon(Icons.workspace_premium_outlined,
                                    size: 16),
                                label: Text(
                                  AppStrings.t(lang, 'plans'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => context.go('/laws'),
                                icon: const Icon(Icons.hub_outlined, size: 16),
                                label: Text(
                                  AppStrings.t(lang, 'integrations'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
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
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 68)),
        // 6-Tile Soliq Quick Services Grid
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.t(lang, 'quick_services'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.0,
                  children: [
                    _QuickTile(
                      icon: Icons.upload_file_rounded,
                      color: c.brandPrimaryBlue,
                      label: AppStrings.t(lang, 'svc_upload'),
                      onTap: () => ScanUploadSheet.show(context),
                    ),
                    _QuickTile(
                      icon: Icons.camera_alt_rounded,
                      color: c.brandCyan,
                      label: AppStrings.t(lang, 'svc_camera'),
                      onTap: () =>
                          ScanUploadSheet.show(context, focusCamera: true),
                    ),
                    _QuickTile(
                      icon: Icons.verified_user_rounded,
                      color: c.redText,
                      label: AppStrings.t(lang, 'svc_notarial'),
                      onTap: () => _launchNotarialQuick(context),
                    ),
                    _QuickTile(
                      icon: Icons.mail_outline_rounded,
                      color: c.yellowText,
                      label: AppStrings.t(lang, 'svc_claim'),
                      onTap: () => _openLatestProtocol(context, contracts),
                    ),
                    _QuickTile(
                      icon: Icons.handshake_outlined,
                      color: c.greenText,
                      label: AppStrings.t(lang, 'svc_mediation'),
                      onTap: () => _showInfoSheet(
                        context,
                        title: 'Mediatsiya bandi va reestr (1-trek)',
                        body:
                            'O‘zbekistonda nizolarning katta qismi sudgacha hal qilinmaydi. LexGuard R5 qoidasi har bir shartnomada 10 kunlik pretenziya va professional mediatsiya bandini qo‘shishni taklif qiladi (Mediatsiya qonuni, 16-modda).',
                      ),
                    ),
                    _QuickTile(
                      icon: Icons.support_agent_rounded,
                      color: c.grayText,
                      label: AppStrings.t(lang, 'svc_lawyer'),
                      onTap: () => _showInfoSheet(
                        context,
                        title: 'Hamkor advokat ko‘rigi (3.2 modeli)',
                        body:
                            'Kulrang (Unknown) yoki tasdiqlanmagan bandlar avtomatik ravishda hamkor advokatga yo‘naltirilishi mumkin. VM 675 ga ko‘ra pullik ko‘rik faqat reyestrdagi advokat/yuridik tashkilot tomonidan ko‘rsatiladi; LexGuard mijozdan ulush olmaydi.',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 18)),
        // Recent Checks Header
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.t(lang, 'recent_checks'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/documents'),
                  child: Text(AppStrings.t(lang, 'see_all')),
                ),
              ],
            ),
          ),
        ),
        // Recent Analyses Cards
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList.builder(
            itemCount: contracts.analyses.length.clamp(0, 4),
            itemBuilder: (context, index) {
              final item = contracts.analyses[index];
              return RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => context.push('/analysis/${item.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: c.brandPrimaryBlue
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.description_rounded,
                                    size: 18,
                                    color: c.brandDeepBlue,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '${item.formatLabel} · ${item.overallBalanceLabel}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: c.grayText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                            const SizedBox(height: 10),
                            RiskColorSummaryRow(analysis: item),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // O'RQ-1115 Legal Disclaimer Footer
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.grayBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.cardBorder),
              ),
              child: Text(
                AppStrings.t(lang, 'orq_1115_banner'),
                style: TextStyle(fontSize: 11.5, color: c.grayText),
              ),
            ),
          ),
        ),
      ],
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
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(body, style: const TextStyle(fontSize: 13.5, height: 1.45)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tushunarli'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentBtn extends StatelessWidget {
  const _SegmentBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? c.brandDeepBlue : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
