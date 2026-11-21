import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/contracts/domain/entities/lex_models.dart';
import '../../features/session/presentation/cubit/session_cubit.dart';
import '../l10n/app_strings.dart';
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
  final session = context.watch<SessionCubit>().state;
  final lang = session.lang;
  final script = session.uzbekScript;

  return switch (risk) {
    RiskColor.red => RiskStyle(
        fg: c.redText,
        bg: c.redBg,
        border: c.redBorder,
        icon: CupertinoIcons.exclamationmark_shield_fill,
        label: AppStrings.t(lang, 'red_full', script: script),
      ),
    RiskColor.yellow => RiskStyle(
        fg: c.yellowText,
        bg: c.yellowBg,
        border: c.yellowBorder,
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        label: AppStrings.t(lang, 'yellow_full', script: script),
      ),
    RiskColor.gray => RiskStyle(
        fg: c.grayText,
        bg: c.grayBg,
        border: c.grayBorder,
        icon: CupertinoIcons.question_circle_fill,
        label: AppStrings.t(lang, 'gray_full', script: script),
      ),
    RiskColor.green => RiskStyle(
        fg: c.greenText,
        bg: c.greenBg,
        border: c.greenBorder,
        icon: CupertinoIcons.checkmark_seal_fill,
        label: AppStrings.t(lang, 'green_full', script: script),
      ),
  };
}

class RiskColorSummaryRow extends StatelessWidget {
  const RiskColorSummaryRow({
    super.key,
    required this.analysis,
    this.compact = false,
  });

  final ContractAnalysis analysis;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;

    final entries = [
      (
        count: analysis.countByColor(RiskColor.red),
        label: AppStrings.t(lang, 'red_label', script: script),
        fg: c.redText,
        bg: c.redBg,
        border: c.redBorder,
        icon: CupertinoIcons.exclamationmark_shield_fill,
      ),
      (
        count: analysis.countByColor(RiskColor.yellow),
        label: AppStrings.t(lang, 'yellow_label', script: script),
        fg: c.yellowText,
        bg: c.yellowBg,
        border: c.yellowBorder,
        icon: CupertinoIcons.exclamationmark_triangle_fill,
      ),
      (
        count: analysis.countByColor(RiskColor.gray),
        label: AppStrings.t(lang, 'gray_label', script: script),
        fg: c.grayText,
        bg: c.grayBg,
        border: c.grayBorder,
        icon: CupertinoIcons.question_circle_fill,
      ),
      (
        count: analysis.countByColor(RiskColor.green),
        label: AppStrings.t(lang, 'green_label', script: script),
        fg: c.greenText,
        bg: c.greenBg,
        border: c.greenBorder,
        icon: CupertinoIcons.checkmark_seal_fill,
      ),
    ];

    final visible = compact
        ? entries.where((e) => e.count > 0).toList(growable: false)
        : entries;
    final shown = visible.isEmpty ? entries : visible;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in shown)
          _CountPill(
            count: item.count,
            label: item.label,
            fg: item.fg,
            bg: item.bg,
            border: item.border,
            icon: item.icon,
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
          Flexible(
            child: Text(
              '$count $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
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
    final session = context.watch<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;

    final (label, fg, bg, icon) = switch (status) {
      VerificationStatus.verified => (
          AppStrings.t(lang, 'verif_verified', script: script),
          c.greenText,
          c.greenBg,
          CupertinoIcons.checkmark_seal_fill,
        ),
      VerificationStatus.unverified => (
          AppStrings.t(lang, 'verif_unverified', script: script),
          c.yellowText,
          c.yellowBg,
          CupertinoIcons.exclamationmark_circle_fill,
        ),
      VerificationStatus.reviewRequired => (
          AppStrings.t(lang, 'verif_review', script: script),
          c.grayText,
          c.grayBg,
          CupertinoIcons.person_2_fill,
        ),
      VerificationStatus.unknown => (
          AppStrings.t(lang, 'verif_unknown', script: script),
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
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
