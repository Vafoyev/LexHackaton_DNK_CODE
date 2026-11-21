import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lex_modal_sheet.dart';
import '../../../core/widgets/lex_toast.dart';
import '../../session/presentation/cubit/session_cubit.dart';
import '../domain/law_monitoring_models.dart';

/// B2B Notification Center showing law changes that directly affect
/// clauses in the company's uploaded contracts & documents.
class MonitoringNotificationsSheet {
  const MonitoringNotificationsSheet._();

  static Future<void> show(BuildContext context) {
    return showLexModalSheet<void>(
      context: context,
      builder: (ctx) => const _NotificationsBody(),
    );
  }
}

class _NotificationsBody extends StatelessWidget {
  const _NotificationsBody();

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final monitoring = context.watch<MonitoringCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;
    final maxH = MediaQuery.sizeOf(context).height * 0.78;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.t(lang, 'b2b_notif_title', script: script),
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                if (monitoring.unreadCount > 0)
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      context.read<MonitoringCubit>().markAllRead();
                    },
                    child: Text(
                      AppStrings.t(lang, 'b2b_notif_mark_read', script: script),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: c.rolePrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.t(lang, 'b2b_monitoring_slogan', script: script),
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < monitoring.alerts.length; i++) ...[
              _AlertListTile(
                alert: monitoring.alerts[i],
                onTap: () {
                  final alert = monitoring.alerts[i];
                  context.read<MonitoringCubit>().markRead(alert.id);
                  Navigator.of(context).pop();
                  MonitoringAlertDetailSheet.show(context, alert: alert);
                },
              ),
              if (i < monitoring.alerts.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertListTile extends StatelessWidget {
  const _AlertListTile({
    required this.alert,
    required this.onTap,
  });

  final LawMonitoringAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;
    final dotColor = alert.isResolved
        ? c.greenText
        : (alert.isRead ? c.yellowText : c.redText);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: (!alert.isRead && !alert.isResolved)
              ? c.rolePrimary.withValues(alpha: 0.08)
              : c.grayBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: (!alert.isRead && !alert.isResolved)
                ? c.rolePrimary.withValues(alpha: 0.35)
                : c.glassBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppStrings.adaptUz(alert.lawCode, lang, script),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: alert.isResolved ? c.greenText : c.rolePrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '· ${AppStrings.adaptUz(alert.affectedClause, lang, script)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.textSecondary,
                  ),
                ),
                const Spacer(),
                if (alert.isResolved)
                  Text(
                    AppStrings.t(
                      lang,
                      'b2b_mon_resolved_badge',
                      script: script,
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: c.greenText,
                    ),
                  )
                else
                  Text(
                    alert.effectiveDate,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
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
                fontSize: 15,
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
                fontSize: 13,
                height: 1.38,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detailed Git-style Before/After Diff modal showing how a law change
/// affects a specific clause in the company's uploaded document.
class MonitoringAlertDetailSheet {
  const MonitoringAlertDetailSheet._();

  static Future<void> show(
    BuildContext context, {
    required LawMonitoringAlert alert,
  }) {
    context.read<MonitoringCubit>().markRead(alert.id);
    final c = context.lexColors;
    final session = context.read<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;

    return showLexModalSheet<void>(
      context: context,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.82;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top law badge + effective date
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
                        AppStrings.adaptUz(alert.lawCode, lang, script),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: c.rolePrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      alert.effectiveDate,
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
                  AppStrings.adaptUz(alert.lawTitle, lang, script),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Affected Document & Clause Highlight
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
                        AppStrings.t(
                          lang,
                          'b2b_mon_affected_doc',
                          script: script,
                        ),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: c.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.doc_text_fill,
                            size: 16,
                            color: c.rolePrimary,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              '${AppStrings.adaptUz(alert.documentTitle, lang, script)} · ${AppStrings.adaptUz(alert.affectedClause, lang, script)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Before (Red diff)
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: c.redBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border(
                      left: BorderSide(color: c.redText, width: 3.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '− ${AppStrings.t(lang, 'diff_before', script: script)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: c.redText,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        AppStrings.adaptUz(
                          alert.currentClauseText,
                          lang,
                          script,
                        ),
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.42,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // After (Green diff)
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: c.greenBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border(
                      left: BorderSide(color: c.greenText, width: 3.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '+ ${AppStrings.t(lang, 'diff_after', script: script)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: c.greenText,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        AppStrings.adaptUz(
                          alert.recommendedClauseText,
                          lang,
                          script,
                        ),
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.42,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Consequence + FK 4 Note
                Text(
                  '${AppStrings.t(lang, 'diff_consequence', script: script)}: ${AppStrings.adaptUz(alert.impactRisk, lang, script)}',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.42,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.t(lang, 'b2b_mon_fk4_note', script: script),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),

                // Primary Actions
                if (alert.contractId != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            context.push('/analysis/${alert.contractId}');
                          },
                          child: Text(
                            AppStrings.t(
                              lang,
                              'b2b_mon_open_contract',
                              script: script,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context
                                .read<MonitoringCubit>()
                                .resolveAlert(alert.id);
                            Navigator.of(ctx).pop();
                            LexToast.show(
                              context,
                              AppStrings.t(
                                lang,
                                'b2b_mon_toast_resolved',
                                script: script,
                              ),
                              type: LexToastType.success,
                            );
                          },
                          child: Text(
                            AppStrings.t(
                              lang,
                              'b2b_mon_accept_btn',
                              script: script,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else
                  FilledButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.read<MonitoringCubit>().resolveAlert(alert.id);
                      Navigator.of(ctx).pop();
                      LexToast.show(
                        context,
                        AppStrings.t(
                          lang,
                          'b2b_mon_toast_resolved',
                          script: script,
                        ),
                        type: LexToastType.success,
                      );
                    },
                    child: Text(
                      AppStrings.t(
                        lang,
                        'b2b_mon_accept_btn',
                        script: script,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
