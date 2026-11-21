import 'package:flutter/cupertino.dart';

import '../../features/contracts/domain/entities/lex_models.dart';
import '../theme/app_theme.dart';

class RiskStyle {
  const RiskStyle({
    required this.fg,
    required this.bg,
    required this.border,
    required this.icon,
    required this.label,
  });

  final Color fg;
  final Color bg;
  final Color border;
  final IconData icon;
  final String label;
}

RiskStyle styleForRisk(BuildContext context, RiskColor risk) {
  final c = context.lexColors;
  return switch (risk) {
    RiskColor.red => RiskStyle(
        fg: c.redText,
        bg: c.redBg,
        border: c.redBorder,
        icon: CupertinoIcons.exclamationmark_shield_fill,
        label: 'Qizil · Qonun xavfi',
      ),
    RiskColor.yellow => RiskStyle(
        fg: c.yellowText,
        bg: c.yellowBg,
        border: c.yellowBorder,
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        label: 'Sariq · Tijoriy risk',
      ),
    RiskColor.gray => RiskStyle(
        fg: c.grayText,
        bg: c.grayBg,
        border: c.grayBorder,
        icon: CupertinoIcons.question_circle_fill,
        label: 'Kulrang · Unknown',
      ),
    RiskColor.green => RiskStyle(
        fg: c.greenText,
        bg: c.greenBg,
        border: c.greenBorder,
        icon: CupertinoIcons.checkmark_seal_fill,
        label: 'Yashil · Topilma yo‘q',
      ),
  };
}

class RiskColorSummaryRow extends StatelessWidget {
  const RiskColorSummaryRow({super.key, required this.analysis});

  final ContractAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _CountPill(
          count: analysis.countByColor(RiskColor.red),
          label: 'Qizil',
          fg: c.redText,
          bg: c.redBg,
          border: c.redBorder,
          icon: CupertinoIcons.exclamationmark_shield_fill,
        ),
        _CountPill(
          count: analysis.countByColor(RiskColor.yellow),
          label: 'Sariq',
          fg: c.yellowText,
          bg: c.yellowBg,
          border: c.yellowBorder,
          icon: CupertinoIcons.exclamationmark_triangle_fill,
        ),
        _CountPill(
          count: analysis.countByColor(RiskColor.gray),
          label: 'Kulrang',
          fg: c.grayText,
          bg: c.grayBg,
          border: c.grayBorder,
          icon: CupertinoIcons.question_circle_fill,
        ),
        _CountPill(
          count: analysis.countByColor(RiskColor.green),
          label: 'Yashil',
          fg: c.greenText,
          bg: c.greenBg,
          border: c.greenBorder,
          icon: CupertinoIcons.checkmark_seal_fill,
        ),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.count,
    required this.label,
    required this.fg,
    required this.bg,
    required this.border,
    required this.icon,
  });

  final int count;
  final String label;
  final Color fg;
  final Color bg;
  final Color border;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            '$count $label',
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class VerificationBadge extends StatelessWidget {
  const VerificationBadge({super.key, required this.status});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final (label, fg, bg, icon) = switch (status) {
      VerificationStatus.verified => (
          'Manba tasdiqlangan',
          c.greenText,
          c.greenBg,
          CupertinoIcons.checkmark_seal_fill,
        ),
      VerificationStatus.unverified => (
          'Tasdiqlanmagan',
          c.yellowText,
          c.yellowBg,
          CupertinoIcons.exclamationmark_circle_fill,
        ),
      VerificationStatus.reviewRequired => (
          'Hamkor advokat ko‘rigiga',
          c.grayText,
          c.grayBg,
          CupertinoIcons.person_2_fill,
        ),
      VerificationStatus.unknown => (
          'Manba topilmadi (0)',
          c.grayText,
          c.grayBg,
          CupertinoIcons.question_circle_fill,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
