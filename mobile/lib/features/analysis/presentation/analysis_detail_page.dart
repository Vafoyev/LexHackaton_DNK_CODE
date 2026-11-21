import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/uzbek_alphabet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/lex_modal_sheet.dart';
import '../../../core/widgets/lex_toast.dart';
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
  /// 0 = Clean Clauses summary, 1 = Full Document Before/After Diff
  int _viewMode = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;
    final analysis =
        context.watch<ContractsCubit>().state.findById(widget.analysisId);

    if (analysis == null) {
      return AmbientGlassBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              AppStrings.t(lang, 'analysis_not_found', script: script),
            ),
          ),
          body: Center(
            child: FilledButton(
              onPressed: () => context.go('/home'),
              child: Text(AppStrings.t(lang, 'back_home', script: script)),
            ),
          ),
        ),
      );
    }

    final redCount = analysis.countByColor(RiskColor.red);
    final yellowCount = analysis.countByColor(RiskColor.yellow);
    final grayCount = analysis.countByColor(RiskColor.gray);
    final greenCount = analysis.countByColor(RiskColor.green);
    final hasNotarial = analysis.findings.any(
      (f) => f.actionTag == 'NOTARIAL' || f.ruleCode.contains('R6'),
    );

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
          title: Text(
            AppStrings.adaptUz(analysis.title, lang, script),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: c.textPrimary,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Calm, Ultra-Clear Verdict & Navigator Card
                          _CleanVerdictCard(
                            hasNotarial: hasNotarial,
                            redCount: redCount,
                            yellowCount: yellowCount,
                            grayCount: grayCount,
                            greenCount: greenCount,
                            lang: lang,
                            script: script,
                          ),
                          const SizedBox(height: 16),

                          // 2. Simple 2-Tab Switcher: Xulosalar | Hujjat (Diff)
                          CupertinoSlidingSegmentedControl<int>(
                            groupValue: _viewMode,
                            children: {
                              0: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                child: Text(
                                  AppStrings.t(
                                    lang,
                                    'tab_clauses',
                                    script: script,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              1: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                child: Text(
                                  AppStrings.t(
                                    lang,
                                    'tab_doc_diff',
                                    script: script,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            },
                            onValueChanged: (v) {
                              if (v != null) {
                                HapticFeedback.selectionClick();
                                setState(() => _viewMode = v);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tab 0: Clean Spacious Clauses | Tab 1: Clean Git Diff Document
                  if (_viewMode == 0)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.separated(
                        itemCount: analysis.findings.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final f = analysis.findings[index];
                          return _CleanClauseCard(
                            finding: f,
                            lang: lang,
                            script: script,
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
                          );
                        },
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverToBoxAdapter(
                        child: _CleanDocumentDiffView(
                          analysis: analysis,
                          lang: lang,
                          script: script,
                          onDecision: (findingId, decision) {
                            context.read<ContractsCubit>().setFindingDecision(
                                  analysisId: analysis.id,
                                  findingId: findingId,
                                  decision: decision,
                                );
                            LexToast.show(
                              context,
                              decision == FindingDecision.accepted
                                  ? AppStrings.t(
                                      lang,
                                      'toast_accepted',
                                      script: script,
                                    )
                                  : AppStrings.t(
                                      lang,
                                      'toast_dismissed',
                                      script: script,
                                    ),
                              type: decision == FindingDecision.accepted
                                  ? LexToastType.success
                                  : LexToastType.info,
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Single Clean Bottom Export CTA
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    decoration: BoxDecoration(
                      color: c.glassFillStrong,
                      border: Border(top: BorderSide(color: c.glassBorder)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: () => _showExportChooser(
                          context,
                          analysis: analysis,
                          lang: lang,
                          script: script,
                        ),
                        icon: const Icon(
                          CupertinoIcons.arrow_down_doc_fill,
                          size: 19,
                        ),
                        label: Text(
                          AppStrings.t(lang, 'download_docx_btn', script: script),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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

  void _showExportChooser(
    BuildContext context, {
    required ContractAnalysis analysis,
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
          Text(
            AppStrings.t(lang, 'download_docx_btn', script: script),
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _ExportOptionRow(
            icon: CupertinoIcons.doc_checkmark_fill,
            title: AppStrings.t(lang, 'export_draft_title', script: script),
            onTap: () {
              Navigator.of(ctx).pop();
              ExportPreviewSheet.showCleanDraftLoyiha(context, analysis);
            },
          ),
          const SizedBox(height: 10),
          _ExportOptionRow(
            icon: CupertinoIcons.doc_text_fill,
            title: AppStrings.t(lang, 'export_comments_title', script: script),
            onTap: () {
              Navigator.of(ctx).pop();
              ExportPreviewSheet.showCommentsAndProtocol(context, analysis);
            },
          ),
        ],
      ),
    );
  }
}

/// Calm, clean, neutral-surface verdict card with minimal color dots
/// and a clear 3-step plain-language Navigator.
class _CleanVerdictCard extends StatelessWidget {
  const _CleanVerdictCard({
    required this.hasNotarial,
    required this.redCount,
    required this.yellowCount,
    required this.grayCount,
    required this.greenCount,
    required this.lang,
    required this.script,
  });

  final bool hasNotarial;
  final int redCount;
  final int yellowCount;
  final int grayCount;
  final int greenCount;
  final AppLang lang;
  final UzbekScript script;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final hasIssues = redCount > 0 || yellowCount > 0;

    final (statusColor, statusLabel, title, body, steps) = hasNotarial
        ? (
            c.redText,
            AppStrings.t(lang, 'red_label', script: script),
            AppStrings.t(lang, 'nav_title_notarial', script: script),
            AppStrings.t(lang, 'nav_body_notarial', script: script),
            [
              AppStrings.t(lang, 'nav_step_notary_1', script: script),
              AppStrings.t(lang, 'nav_step_notary_2', script: script),
              AppStrings.t(lang, 'nav_step_notary_3', script: script),
            ],
          )
        : hasIssues
            ? (
                redCount > 0 ? c.redText : c.yellowText,
                redCount > 0
                    ? AppStrings.t(lang, 'red_label', script: script)
                    : AppStrings.t(lang, 'yellow_label', script: script),
                AppStrings.t(lang, 'nav_title_issues', script: script),
                AppStrings.t(lang, 'nav_body_issues', script: script),
                [
                  AppStrings.t(lang, 'nav_step_1', script: script),
                  AppStrings.t(lang, 'nav_step_2', script: script),
                  AppStrings.t(lang, 'nav_step_3', script: script),
                ],
              )
            : (
                c.greenText,
                AppStrings.t(lang, 'green_label', script: script),
                AppStrings.t(lang, 'nav_title_clean', script: script),
                AppStrings.t(lang, 'nav_body_clean', script: script),
                <String>[],
              );

    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quiet header row: 1 semantic dot + compact 3-color counters
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
              const Spacer(),
              _MiniDotCounter(color: c.redText, count: redCount),
              const SizedBox(width: 10),
              _MiniDotCounter(color: c.yellowText, count: yellowCount),
              const SizedBox(width: 10),
              _MiniDotCounter(color: c.greenText, count: greenCount),
              if (grayCount > 0) ...[
                const SizedBox(width: 10),
                _MiniDotCounter(color: c.grayText, count: grayCount),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              height: 1.15,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.48,
              color: c.textSecondary,
            ),
          ),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.grayBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < steps.length; i++) ...[
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.rolePrimary.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: c.rolePrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            steps[i].replaceFirst(RegExp(r'^\d+\.\s*'), ''),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (i < steps.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniDotCounter extends StatelessWidget {
  const _MiniDotCounter({required this.color, required this.count});

  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: c.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Airy, calm, single-glance clause card — zero rainbow badges, crisp typography.
class _CleanClauseCard extends StatelessWidget {
  const _CleanClauseCard({
    required this.finding,
    required this.lang,
    required this.script,
    required this.onTap,
  });

  final ClauseFinding finding;
  final AppLang lang;
  final UzbekScript script;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final rs = styleForRisk(context, finding.riskColor);
    final isAccepted = finding.decision == FindingDecision.accepted;

    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: rs.fg, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                '${AppStrings.t(lang, 'clause_prefix', script: script)} ${AppStrings.adaptUz(finding.clauseNumber, lang, script)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: c.textSecondary,
                ),
              ),
              if (finding.citation != null) ...[
                Text(
                  '  ·  ',
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
                Flexible(
                  child: Text(
                    AppStrings.adaptUz(finding.citation!.article, lang, script),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: c.rolePrimary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (isAccepted)
                Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  size: 18,
                  color: c.greenText,
                )
              else
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: c.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppStrings.adaptUz(finding.title, lang, script),
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.adaptUz(finding.explanation, lang, script),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Clean Git/Agent-style inline Before/After Document Diff view.
class _CleanDocumentDiffView extends StatelessWidget {
  const _CleanDocumentDiffView({
    required this.analysis,
    required this.lang,
    required this.script,
    required this.onDecision,
  });

  final ContractAnalysis analysis;
  final AppLang lang;
  final UzbekScript script;
  final void Function(String findingId, FindingDecision decision) onDecision;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;

    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < analysis.findings.length; i++) ...[
            _CleanDiffBlock(
              finding: analysis.findings[i],
              lang: lang,
              script: script,
              onDecision: (d) => onDecision(analysis.findings[i].id, d),
            ),
            if (i < analysis.findings.length - 1)
              Divider(
                height: 28,
                color: c.textSecondary.withValues(alpha: 0.14),
              ),
          ],
        ],
      ),
    );
  }
}

class _CleanDiffBlock extends StatelessWidget {
  const _CleanDiffBlock({
    required this.finding,
    required this.lang,
    required this.script,
    required this.onDecision,
  });

  final ClauseFinding finding;
  final AppLang lang;
  final UzbekScript script;
  final ValueChanged<FindingDecision> onDecision;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final isClean = finding.riskColor == RiskColor.green;
    final isAccepted = finding.decision == FindingDecision.accepted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${AppStrings.t(lang, 'clause_prefix', script: script)} ${AppStrings.adaptUz(finding.clauseNumber, lang, script)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppStrings.adaptUz(finding.title, lang, script),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (isClean)
          Text(
            AppStrings.adaptUz(finding.originalText, lang, script),
            style: TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: c.textPrimary,
            ),
          )
        else ...[
          // − BEFORE
          Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(
              color: c.redBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              border: Border(left: BorderSide(color: c.redText, width: 3.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '−',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: c.redText,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    AppStrings.adaptUz(finding.originalText, lang, script),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.48,
                      color: c.textPrimary,
                      decoration: isAccepted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: c.redText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // + AFTER
          Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(
              color: c.greenBg,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
              border: Border(left: BorderSide(color: c.greenText, width: 3.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: c.greenText,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    AppStrings.adaptUz(finding.suggestedRevision, lang, script),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.48,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onDecision(FindingDecision.dismissed),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    AppStrings.t(lang, 'dismiss_btn', script: script),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => onDecision(FindingDecision.accepted),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    backgroundColor: isAccepted ? c.greenText : c.rolePrimary,
                  ),
                  child: Text(
                    AppStrings.t(lang, 'accept_btn', script: script),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ExportOptionRow extends StatelessWidget {
  const _ExportOptionRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: c.grayBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.glassBorder),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: c.rolePrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 16,
                color: c.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
