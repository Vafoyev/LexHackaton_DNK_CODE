import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
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
    final analysis = context.watch<ContractsCubit>().state.findById(widget.analysisId);

    if (analysis == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tahlil topilmadi')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/home'),
            child: const Text('Asosiy sahifaga qaytish'),
          ),
        ),
      );
    }

    final filtered = _colorFilter == null
        ? analysis.findings
        : analysis.findings
            .where((f) => f.riskColor == _colorFilter)
            .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              analysis.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              '${analysis.formatLabel} · ${analysis.languageLabel} · ${analysis.executionMode}',
              style: const TextStyle(fontSize: 11.5, color: Colors.white70),
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 3.2 Summary Card (NO fake percentage risk score!)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RiskColorSummaryRow(analysis: analysis),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: c.brandPrimaryBlue
                                        .withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.balance_rounded,
                                        size: 18,
                                        color: c.brandDeepBlue,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${AppStrings.t(lang, 'neutrality_title')}: ${analysis.overallBalanceLabel}',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: c.brandDeepBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _MetaPill(
                                      icon: Icons.shield_rounded,
                                      text:
                                          '${analysis.piiMaskedCount} ta PII maskalandi',
                                    ),
                                    _MetaPill(
                                      icon: Icons.fingerprint_rounded,
                                      text: 'SHA: ${analysis.sha256Short}',
                                    ),
                                    _MetaPill(
                                      icon: Icons.schedule_rounded,
                                      text:
                                          'Saqlash: ${analysis.retentionDays} kun',
                                    ),
                                  ],
                                ),
                                if (analysis.topThreeIssues.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    AppStrings.t(lang, 'top_3_issues'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  for (final issue in analysis.topThreeIssues)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            styleForRisk(context, issue.riskColor)
                                                .icon,
                                            size: 15,
                                            color: styleForRisk(
                                              context,
                                              issue.riskColor,
                                            ).fg,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${issue.clauseNumber}: ${issue.title}',
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // O'RQ-1115 + Green honesty note
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: c.grayBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.cardBorder),
                          ),
                          child: Text(
                            '${AppStrings.t(lang, 'orq_1115_banner')}\n${AppStrings.t(lang, 'green_disclaimer')}',
                            style: TextStyle(fontSize: 11.5, color: c.grayText),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 4-color filter chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: Text(
                                  'Barchasi (${analysis.findings.length})',
                                ),
                                selected: _colorFilter == null,
                                onSelected: (_) =>
                                    setState(() => _colorFilter = null),
                              ),
                              const SizedBox(width: 6),
                              for (final rc in RiskColor.values) ...[
                                FilterChip(
                                  label: Text(
                                    '${_shortColorLabel(rc)} (${analysis.countByColor(rc)})',
                                  ),
                                  selected: _colorFilter == rc,
                                  onSelected: (_) =>
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
                // Virtualized SliverList for 60/120 FPS on 50+ page contracts
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  sliver: SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final f = filtered[index];
                      return RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ClauseFindingCard(
                            finding: f,
                            onTap: () => ClauseDetailSheet.show(
                              context,
                              finding: f,
                              analysis: analysis,
                              onDecision: (decision) {
                                context.read<ContractsCubit>().setFindingDecision(
                                      analysisId: analysis.id,
                                      findingId: f.id,
                                      decision: decision,
                                    );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // 3.2 Dual Export Bar (Always open - no Lock-in!)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(top: BorderSide(color: c.cardBorder)),
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
                      icon: const Icon(Icons.description_outlined, size: 18),
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
                      onPressed: () => ExportPreviewSheet.showCleanDraftLoyiha(
                        context,
                        analysis,
                      ),
                      icon: const Icon(Icons.edit_document, size: 18),
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
        ],
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

class _ClauseFindingCard extends StatelessWidget {
  const _ClauseFindingCard({required this.finding, required this.onTap});

  final ClauseFinding finding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final rs = styleForRisk(context, finding.riskColor);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
                  Icon(rs.icon, size: 18, color: rs.fg),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Band ${finding.clauseNumber} · ${finding.title}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (finding.decision != FindingDecision.pending)
                    Icon(
                      finding.decision == FindingDecision.accepted
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
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
                style: TextStyle(fontSize: 12.5, color: c.grayText),
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      finding.balanceLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.grayText,
                      ),
                    ),
                  ),
                  if (finding.citation != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: c.brandPrimaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        finding.citation!.article,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c.brandDeepBlue,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c.brandDeepBlue),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
