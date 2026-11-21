import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/risk_badges.dart';
import '../../contracts/domain/entities/lex_models.dart';

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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
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
    final rs = styleForRisk(context, finding.riskColor);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, controller) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: BoxDecoration(
                color: c.glassFillStrong,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border(top: BorderSide(color: c.glassBorder)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.textSecondary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
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
                              'Band ${finding.clauseNumber} · ${rs.label}',
                              style: TextStyle(
                                color: rs.fg,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      VerificationBadge(status: finding.verificationStatus),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    finding.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Balans: ${finding.balanceLabel}  •  Qoida: ${finding.ruleCode}',
                    style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  _BoxBlock(
                    label: 'Shartnomadagi asl matn',
                    body: finding.originalText,
                    bg: rs.bg,
                    border: rs.border,
                  ),
                  const SizedBox(height: 10),
                  _BoxBlock(
                    label: 'Huquqiy va tijoriy izoh',
                    body: finding.explanation,
                    bg: c.grayBg,
                    border: c.glassBorder,
                  ),
                  const SizedBox(height: 10),
                  _BoxBlock(
                    label: 'Tavsiya etiladigan tahrir',
                    body: finding.suggestedRevision,
                    bg: c.greenBg,
                    border: c.greenBorder,
                  ),
                  if (finding.citation != null) ...[
                    const SizedBox(height: 12),
                    GlassCard(
                      radius: 16,
                      padding: const EdgeInsets.all(14),
                      borderColor: c.rolePrimary.withValues(alpha: 0.35),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rasmiy norma (Lex.uz manba)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: c.rolePrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${finding.citation!.title} · ${finding.citation!.article} (${finding.citation!.part})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Norma turi: ${finding.citation!.normNature} · Kuchga kirgan: ${finding.citation!.effectiveFrom}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text: finding.citation!.officialUrl,
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Havola nusxalandi: ${finding.citation!.officialUrl}',
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              finding.citation!.officialUrl,
                              style: TextStyle(
                                fontSize: 12,
                                color: c.rolePrimary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (finding.actionTag == 'LAWYER') ...[
                    const SizedBox(height: 12),
                    GlassCard(
                      radius: 14,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Hamkor advokatga yo‘naltirish: Ushbu band Unknown toifasida. Pullik ko‘rik faqat reyestrdagi hamkor advokat orqali amalga oshiriladi (LexGuard mijozdan komissiya olmaydi).',
                        style:
                            TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            onDecision(FindingDecision.dismissed);
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(CupertinoIcons.xmark, size: 17),
                          label: const Text('Rad etish'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            onDecision(FindingDecision.accepted);
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(CupertinoIcons.checkmark, size: 17),
                          label: const Text('Tahrirni qabul qilish'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BoxBlock extends StatelessWidget {
  const _BoxBlock({
    required this.label,
    required this.body,
    required this.bg,
    required this.border,
  });

  final String label;
  final String body;
  final Color bg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(fontSize: 13, height: 1.45, color: c.textPrimary),
          ),
        ],
      ),
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
    final buf = StringBuffer()
      ..writeln('IZOHLI TAKLIFLAR VA KELISHMOVCHILIKLAR BAYONNOMASI')
      ..writeln('Hujjat: ${analysis.title} (${analysis.fileName})')
      ..writeln(
        'Sana: ${analysis.contractDate} | Rejim: ${analysis.executionMode}',
      )
      ..writeln(
        'PII himoyasi: ${analysis.piiMaskedCount} ta shaxsiy maydon maskalandi',
      )
      ..writeln('--------------------------------------------------');
    for (final f
        in analysis.findings.where((e) => e.riskColor != RiskColor.green)) {
      buf
        ..writeln(
          '\n[Band ${f.clauseNumber}] ${f.title} (${f.riskColor.name.toUpperCase()})',
        )
        ..writeln('• Asl matn: ${f.originalText}')
        ..writeln('• Nega xavfli: ${f.explanation}')
        ..writeln('• Modda: ${f.citation?.article ?? 'Tasdiqlanmagan (Unknown)'}')
        ..writeln('• Taklif: ${f.suggestedRevision}');
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExportPreviewSheet(
        title: '1. Izohli takliflar .docx + Bayonnoma',
        content: buf.toString(),
        isDraftLoyiha: false,
      ),
    );
  }

  static Future<void> showCleanDraftLoyiha(
    BuildContext context,
    ContractAnalysis analysis,
  ) {
    final accepted = analysis.findings
        .where(
          (f) =>
              f.decision == FindingDecision.accepted &&
              f.verificationStatus == VerificationStatus.verified,
        )
        .toList();
    final buf = StringBuffer()
      ..writeln('=== LOYIHA (IMZOLANMAGAN TAHRIR) ===')
      ..writeln('Shartnoma: ${analysis.title}')
      ..writeln(
        'Kiritilgan tasdiqlangan tahrirlar soni: ${accepted.length} ta',
      )
      ..writeln('--------------------------------------------------');
    if (accepted.isEmpty) {
      buf.writeln(
        '\nHali birorta tahrir qabul qilinmagan. Band ustiga bosib "Tahrirni qabul qilish" tugmasini bosing — faqat tasdiqlangan topilmalar LOYIHA matniga kiritiladi.',
      );
    } else {
      for (final f in accepted) {
        buf
          ..writeln('\n[Band ${f.clauseNumber} — YANGILANGAN MATN]')
          ..writeln(f.suggestedRevision)
          ..writeln('(Asos: ${f.citation?.article ?? ''})');
      }
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExportPreviewSheet(
        title: '2. To‘liq tahrir .docx (LOYIHA)',
        content: buf.toString(),
        isDraftLoyiha: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: GlassCard(
        radius: 28,
        blurSigma: 26,
        tintColor: c.glassFillStrong,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                if (isDraftLoyiha)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              constraints: const BoxConstraints(maxHeight: 340),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.grayBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.glassBorder),
                  ),
                  child: SelectableText(
                    content,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Eksport matni nusxalandi (DOCX tayyor shablon).'),
                  ),
                );
              },
              icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 17),
              label: const Text('Nusxalash (Eksport doim ochiq — Lock-in yo‘q)'),
            ),
          ],
        ),
      ),
    );
  }
}
