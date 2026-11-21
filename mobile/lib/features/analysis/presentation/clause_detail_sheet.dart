import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/lex_modal_sheet.dart';
import '../../../core/widgets/lex_toast.dart';
import '../../../core/widgets/risk_badges.dart';
import '../../contracts/domain/entities/lex_models.dart';
import '../../session/presentation/cubit/session_cubit.dart';

class ClauseDetailSheet extends StatelessWidget {
  const ClauseDetailSheet({
    super.key,
    required this.finding,
    required this.analysis,
    required this.onDecision,
  });

  final ClauseFinding finding;
  final ContractAnalysis analysis;
  final ValueChanged<FindingDecision> onDecision;

  static Future<void> show(
    BuildContext context, {
    required ClauseFinding finding,
    required ContractAnalysis analysis,
    required ValueChanged<FindingDecision> onDecision,
  }) {
    return showLexModalSheet<void>(
      context: context,
      builder: (_) => ClauseDetailSheet(
        finding: finding,
        analysis: analysis,
        onDecision: onDecision,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;
    final rs = styleForRisk(context, finding.riskColor);
    final isClean = finding.riskColor == RiskColor.green;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: rs.bg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: rs.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(rs.icon, size: 14, color: rs.fg),
                  const SizedBox(width: 5),
                  Text(
                    '${AppStrings.t(lang, 'clause_prefix', script: script)} ${AppStrings.adaptUz(finding.clauseNumber, lang, script)} · ${rs.shortLabel}',
                    style: TextStyle(
                      color: rs.fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: c.grayBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                AppStrings.adaptUz(finding.balanceLabel, lang, script),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: c.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.adaptUz(finding.title, lang, script),
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 14),

        // BEFORE (Original text in contract)
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: isClean ? c.grayBg : c.redBg,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(
                color: isClean ? c.greenText : c.redText,
                width: 4,
              ),
              top: BorderSide(color: isClean ? c.glassBorder : c.redBorder),
              right: BorderSide(color: isClean ? c.glassBorder : c.redBorder),
              bottom: BorderSide(color: isClean ? c.glassBorder : c.redBorder),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isClean
                    ? AppStrings.t(lang, 'original_text', script: script)
                    : '−  ${AppStrings.t(lang, 'diff_before', script: script)}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: isClean ? c.greenText : c.redText,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                AppStrings.adaptUz(finding.originalText, lang, script),
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
        ),

        if (!isClean) ...[
          const SizedBox(height: 10),
          // AFTER (Suggested revision)
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: c.greenBg,
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(color: c.greenText, width: 4),
                top: BorderSide(color: c.greenBorder),
                right: BorderSide(color: c.greenBorder),
                bottom: BorderSide(color: c.greenBorder),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+  ${AppStrings.t(lang, 'diff_after', script: script)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: c.greenText,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  AppStrings.adaptUz(finding.suggestedRevision, lang, script),
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: c.grayBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.t(lang, 'diff_consequence', script: script),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.adaptUz(finding.explanation, lang, script),
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
        ),

        if (finding.citation != null) ...[
          const SizedBox(height: 12),
          GlassCard(
            radius: 16,
            padding: const EdgeInsets.all(13),
            borderColor: c.rolePrimary.withValues(alpha: 0.30),
            onTap: () {
              Clipboard.setData(
                ClipboardData(text: finding.citation!.officialUrl),
              );
              LexToast.show(
                context,
                AppStrings.t(lang, 'link_copied', script: script),
                type: LexToastType.success,
              );
            },
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c.rolePrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    CupertinoIcons.book_fill,
                    size: 17,
                    color: c.rolePrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.adaptUz(
                          '${finding.citation!.article} · Lex.uz',
                          lang,
                          script,
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: c.rolePrimary,
                        ),
                      ),
                      Text(
                        AppStrings.adaptUz(
                          finding.citation!.title,
                          lang,
                          script,
                        ),
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
                  CupertinoIcons.doc_on_clipboard,
                  size: 16,
                  color: c.rolePrimary,
                ),
              ],
            ),
          ),
        ],

        if (!isClean) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    onDecision(FindingDecision.dismissed);
                    Navigator.of(context).pop();
                    LexToast.show(
                      context,
                      AppStrings.t(lang, 'toast_dismissed', script: script),
                      type: LexToastType.info,
                    );
                  },
                  icon: const Icon(CupertinoIcons.xmark, size: 16),
                  label: Text(
                    AppStrings.t(lang, 'dismiss_btn', script: script),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    onDecision(FindingDecision.accepted);
                    Navigator.of(context).pop();
                    LexToast.show(
                      context,
                      AppStrings.t(lang, 'toast_accepted', script: script),
                      type: LexToastType.success,
                    );
                  },
                  icon: const Icon(CupertinoIcons.checkmark, size: 16),
                  label: Text(
                    AppStrings.t(lang, 'accept_btn', script: script),
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

class ExportPreviewSheet extends StatelessWidget {
  const ExportPreviewSheet({
    super.key,
    required this.title,
    required this.content,
    required this.isDraftLoyiha,
  });

  final String title;
  final String content;
  final bool isDraftLoyiha;

  static Future<void> showCommentsAndProtocol(
    BuildContext context,
    ContractAnalysis analysis,
  ) {
    final session = context.read<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;

    final buf = StringBuffer()
      ..writeln('IZOHLI TAKLIFLAR VA BAYONNOMA')
      ..writeln('Hujjat: ${analysis.title} (${analysis.fileName})')
      ..writeln('Sana: ${analysis.contractDate}')
      ..writeln('----------------------------------------');
    for (final f
        in analysis.findings.where((e) => e.riskColor != RiskColor.green)) {
      buf
        ..writeln('\n[Band ${f.clauseNumber}] ${f.title}')
        ..writeln('− Oldin: ${f.originalText}')
        ..writeln('+ Keyin: ${f.suggestedRevision}')
        ..writeln('• Asos: ${f.citation?.article ?? 'Lex.uz'}');
    }
    return showLexModalSheet<void>(
      context: context,
      builder: (_) => ExportPreviewSheet(
        title: AppStrings.t(lang, 'export_comments_title', script: script),
        content: buf.toString(),
        isDraftLoyiha: false,
      ),
    );
  }

  static Future<void> showCleanDraftLoyiha(
    BuildContext context,
    ContractAnalysis analysis,
  ) {
    final session = context.read<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;

    final accepted = analysis.findings
        .where((f) => f.decision == FindingDecision.accepted)
        .toList();
    final buf = StringBuffer()
      ..writeln('LOYIHA TAHRIR — ${analysis.title}')
      ..writeln('Qabul qilingan tahrirlar: ${accepted.length} ta')
      ..writeln('----------------------------------------');
    if (accepted.isEmpty) {
      for (final f in analysis.findings) {
        buf
          ..writeln('\n[Band ${f.clauseNumber}]')
          ..writeln(
            f.riskColor == RiskColor.green
                ? f.originalText
                : f.suggestedRevision,
          );
      }
    } else {
      for (final f in accepted) {
        buf
          ..writeln('\n[Band ${f.clauseNumber}]')
          ..writeln(f.suggestedRevision);
      }
    }
    return showLexModalSheet<void>(
      context: context,
      builder: (_) => ExportPreviewSheet(
        title: AppStrings.t(lang, 'export_draft_title', script: script),
        content: buf.toString(),
        isDraftLoyiha: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
            ),
            if (isDraftLoyiha)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.yellowBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.yellowBorder),
                ),
                child: Text(
                  'LOYIHA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: c.yellowText,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.grayBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.glassBorder),
              ),
              child: SelectableText(
                AppStrings.adaptUz(content, lang, script),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.45,
                  color: c.textPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: content));
            Navigator.of(context).pop();
            LexToast.show(
              context,
              AppStrings.t(lang, 'export_copied_snack', script: script),
              type: LexToastType.success,
            );
          },
          icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 17),
          label: Text(AppStrings.t(lang, 'export_copy_btn', script: script)),
        ),
      ],
    );
  }
}
