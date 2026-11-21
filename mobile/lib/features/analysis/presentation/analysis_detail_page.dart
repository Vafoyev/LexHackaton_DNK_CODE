import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/risk_badges.dart';
import '../../contracts/domain/entities/lex_models.dart';
import '../../contracts/presentation/cubit/contracts_cubit.dart';
import '../../session/presentation/cubit/session_cubit.dart';
import 'clause_detail_sheet.dart';

class AnalysisDetailPage extends StatefulWidget {
  const AnalysisDetailPage({super.key, required this.analysisId});

  final String analysisId;

  @override
  State<AnalysisDetailPage> createState() => _AnalysisDetailPageState();
}

class _AnalysisDetailPageState extends State<AnalysisDetailPage> {
  RiskColor? _colorFilter;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final lang = context.watch<SessionCubit>().state.lang;
    final analysis =
        context.watch<ContractsCubit>().state.findById(widget.analysisId);

    if (analysis == null) {
      return AmbientGlassBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('Tahlil topilmadi')),
          body: Center(
            child: FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Asosiy sahifaga qaytish'),
            ),
          ),
        ),
      );
    }

    final filtered = _colorFilter == null
        ? analysis.findings
        : analysis.findings
            .where((f) => f.riskColor == _colorFilter)
            .toList(growable: false);

    return AmbientGlassBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(CupertinoIcons.chevron_back, color: c.textPrimary),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                analysis.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              Text(
                '${analysis.formatLabel} · ${analysis.languageLabel} · ${analysis.executionMode}',
                style: TextStyle(fontSize: 11.5, color: c.textSecondary),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GlassCard(
                            radius: 24,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RiskColorSummaryRow(analysis: analysis),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color:
                                        c.rolePrimary.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.equal_square_fill,
                                        size: 18,
                                        color: c.rolePrimary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${AppStrings.t(lang, 'neutrality_title')}: ${analysis.overallBalanceLabel}',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: c.rolePrimaryDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _MetaPill(
                                      icon: CupertinoIcons.shield_fill,
                                      text:
                                          '${analysis.piiMaskedCount} ta PII maskalandi',
                                    ),
                                    _MetaPill(
                                      icon: CupertinoIcons.lock_fill,
                                      text: 'SHA: ${analysis.sha256Short}',
                                    ),
                                    _MetaPill(
                                      icon: CupertinoIcons.clock_fill,
                                      text:
                                          'Saqlash: ${analysis.retentionDays} kun',
                                    ),
                                  ],
                                ),
                                if (analysis.topThreeIssues.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    AppStrings.t(lang, 'top_3_issues'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  for (final issue in analysis.topThreeIssues)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            styleForRisk(
                                              context,
                                              issue.riskColor,
                                            ).icon,
                                            size: 14,
                                            color: styleForRisk(
                                              context,
                                              issue.riskColor,
                                            ).fg,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${issue.clauseNumber}: ${issue.title}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: c.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          GlassCard(
                            radius: 16,
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              '${AppStrings.t(lang, 'orq_1115_banner')}\n${AppStrings.t(lang, 'green_disclaimer')}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _ColorFilterPill(
                                  label:
                                      'Barchasi (${analysis.findings.length})',
                                  selected: _colorFilter == null,
                                  onTap: () =>
                                      setState(() => _colorFilter = null),
                                ),
                                const SizedBox(width: 6),
                                for (final rc in RiskColor.values) ...[
                                  _ColorFilterPill(
                                    label:
                                        '${_shortColorLabel(rc)} (${analysis.countByColor(rc)})',
                                    selected: _colorFilter == rc,
                                    onTap: () =>
                                        setState(() => _colorFilter = rc),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    sliver: SliverList.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final f = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ClauseFindingCard(
                            finding: f,
                            onTap: () => ClauseDetailSheet.show(
                              context,
                              finding: f,
                              analysis: analysis,
                              onDecision: (decision) {
                                context
                                    .read<ContractsCubit>()
                                    .setFindingDecision(
                                      analysisId: analysis.id,
                                      findingId: f.id,
                                      decision: decision,
                                    );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Frosted Glass Dual Export Bar (3.2)
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: BoxDecoration(
                      color: c.glassFillStrong,
                      border: Border(top: BorderSide(color: c.glassBorder)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                ExportPreviewSheet.showCommentsAndProtocol(
                              context,
                              analysis,
                            ),
                            icon: const Icon(CupertinoIcons.doc_text, size: 17),
                            label: Text(
                              AppStrings.t(lang, 'export_comments'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () =>
                                ExportPreviewSheet.showCleanDraftLoyiha(
                              context,
                              analysis,
                            ),
                            icon: const Icon(
                              CupertinoIcons.doc_checkmark,
                              size: 17,
                            ),
                            label: Text(
                              AppStrings.t(lang, 'export_draft'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortColorLabel(RiskColor rc) => switch (rc) {
        RiskColor.red => 'Qizil',
        RiskColor.yellow => 'Sariq',
        RiskColor.gray => 'Kulrang',
        RiskColor.green => 'Yashil',
      };
}

class _ColorFilterPill extends StatelessWidget {
  const _ColorFilterPill({
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
    return GlassPill(
      onTap: onTap,
      tintColor: selected ? c.rolePrimary : c.glassFillStrong,
      borderColor: selected ? c.rolePrimary : c.glassBorder,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : c.textPrimary,
        ),
      ),
    );
  }
}

class _ClauseFindingCard extends StatelessWidget {
  const _ClauseFindingCard({required this.finding, required this.onTap});

  final ClauseFinding finding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final rs = styleForRisk(context, finding.riskColor);

    return GlassCard(
      radius: 22,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: rs.fg, width: 5)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(rs.icon, size: 17, color: rs.fg),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Band ${finding.clauseNumber} · ${finding.title}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                if (finding.decision != FindingDecision.pending)
                  Icon(
                    finding.decision == FindingDecision.accepted
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.xmark_circle_fill,
                    size: 18,
                    color: finding.decision == FindingDecision.accepted
                        ? c.greenText
                        : c.grayText,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              finding.explanation,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                VerificationBadge(status: finding.verificationStatus),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.grayBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    finding.balanceLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ),
                if (finding.citation != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.rolePrimary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      finding.citation!.article,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: c.rolePrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.grayBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c.rolePrimary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
