import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lex_modal_sheet.dart';
import '../../../core/widgets/lex_toast.dart';
import '../../contracts/domain/entities/lex_models.dart';
import '../../session/presentation/cubit/session_cubit.dart';

/// Segment-strict tariff modal aligned 1-to-1 with LexGuard-AI-Loyiha.docx (§7 & §12).
/// - Jismoniy shaxs (B2C): ONLY Fuqaro · Bepul (0 so‘m / 3/oy) + Bir martalik (19 900 so‘m)
/// - Yuridik shaxs (B2B): ONLY Biznes sinov (14 kun / 10 ta) + Business (199k / 30) + Pro (399k / 80) + Qo‘shimcha (9 900)
class PlansModalSheet {
  const PlansModalSheet._();

  static Future<void> show(BuildContext context) {
    final session = context.read<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;
    final isBusiness = session.segment == AccountSegment.business;
    final c = context.lexColors;

    final plans = isBusiness
        ? [
            _PlanSpec(
              id: 'b2b_trial',
              title: AppStrings.t(lang, 'plan_b2b_trial_title', script: script),
              price: AppStrings.t(lang, 'plan_b2b_trial_price', script: script),
              badge: AppStrings.t(lang, 'plan_b2b_trial_badge', script: script),
              features: [
                AppStrings.t(lang, 'plan_b2b_trial_f1', script: script),
                AppStrings.t(lang, 'plan_b2b_trial_f2', script: script),
              ],
            ),
            _PlanSpec(
              id: 'b2b_business',
              title: AppStrings.t(lang, 'plan_b2b_bus_title', script: script),
              price: AppStrings.t(lang, 'plan_b2b_bus_price', script: script),
              badge: AppStrings.t(lang, 'plan_b2b_bus_badge', script: script),
              highlighted: true,
              features: [
                AppStrings.t(lang, 'plan_b2b_bus_f1', script: script),
                AppStrings.t(lang, 'plan_b2b_bus_f2', script: script),
                AppStrings.t(lang, 'plan_b2b_bus_f3', script: script),
              ],
            ),
            _PlanSpec(
              id: 'b2b_pro',
              title: AppStrings.t(lang, 'plan_b2b_pro_title', script: script),
              price: AppStrings.t(lang, 'plan_b2b_pro_price', script: script),
              badge: AppStrings.t(lang, 'plan_b2b_pro_badge', script: script),
              features: [
                AppStrings.t(lang, 'plan_b2b_pro_f1', script: script),
                AppStrings.t(lang, 'plan_b2b_pro_f2', script: script),
                AppStrings.t(lang, 'plan_b2b_pro_f3', script: script),
              ],
            ),
            _PlanSpec(
              id: 'b2b_extra',
              title: AppStrings.t(lang, 'plan_b2b_extra_title', script: script),
              price: AppStrings.t(lang, 'plan_b2b_extra_price', script: script),
              badge: AppStrings.t(lang, 'plan_b2b_extra_badge', script: script),
              features: [
                AppStrings.t(lang, 'plan_b2b_extra_f1', script: script),
                AppStrings.t(lang, 'plan_b2b_extra_f2', script: script),
              ],
            ),
          ]
        : [
            _PlanSpec(
              id: 'b2c_free',
              title: AppStrings.t(lang, 'plan_b2c_free_title', script: script),
              price: AppStrings.t(lang, 'plan_b2c_free_price', script: script),
              badge: AppStrings.t(lang, 'plan_b2c_free_badge', script: script),
              highlighted: true,
              features: [
                AppStrings.t(lang, 'plan_b2c_free_f1', script: script),
                AppStrings.t(lang, 'plan_b2c_free_f2', script: script),
                AppStrings.t(lang, 'plan_b2c_free_f3', script: script),
                AppStrings.t(lang, 'plan_b2c_free_f4', script: script),
              ],
            ),
            _PlanSpec(
              id: 'b2c_once',
              title: AppStrings.t(lang, 'plan_b2c_once_title', script: script),
              price: AppStrings.t(lang, 'plan_b2c_once_price', script: script),
              badge: AppStrings.t(lang, 'plan_b2c_once_badge', script: script),
              features: [
                AppStrings.t(lang, 'plan_b2c_once_f1', script: script),
                AppStrings.t(lang, 'plan_b2c_once_f2', script: script),
                AppStrings.t(lang, 'plan_b2c_once_f3', script: script),
              ],
            ),
          ];

    return showLexModalSheet<void>(
      context: context,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.78;
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
                        isBusiness
                            ? AppStrings.t(
                                lang,
                                'plans_b2b_title',
                                script: script,
                              )
                            : AppStrings.t(
                                lang,
                                'plans_b2c_title',
                                script: script,
                              ),
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: c.rolePrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
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
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isBusiness
                      ? AppStrings.t(lang, 'plans_b2b_sub', script: script)
                      : AppStrings.t(lang, 'plans_b2c_sub', script: script),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < plans.length; i++) ...[
                  _DetailedPlanCard(
                    spec: plans[i],
                    active: session.activePlanId == plans[i].id,
                    activeBadgeLabel: AppStrings.t(
                      lang,
                      'plan_active_badge',
                      script: script,
                    ),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.read<SessionCubit>().selectPlan(plans[i].id);
                      Navigator.of(ctx).pop();
                      LexToast.show(
                        context,
                        '${plans[i].title} · ${AppStrings.t(lang, 'toast_plan_selected', script: script)}',
                        type: LexToastType.success,
                      );
                    },
                  ),
                  if (i < plans.length - 1) const SizedBox(height: 12),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: c.grayBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        CupertinoIcons.info_circle_fill,
                        size: 15,
                        color: c.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isBusiness
                              ? AppStrings.t(
                                  lang,
                                  'plans_b2b_footer',
                                  script: script,
                                )
                              : AppStrings.t(
                                  lang,
                                  'plans_b2c_footer',
                                  script: script,
                                ),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ],
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

class _PlanSpec {
  const _PlanSpec({
    required this.id,
    required this.title,
    required this.price,
    required this.badge,
    required this.features,
    this.highlighted = false,
  });

  final String id;
  final String title;
  final String price;
  final String badge;
  final List<String> features;
  final bool highlighted;
}

class _DetailedPlanCard extends StatelessWidget {
  const _DetailedPlanCard({
    required this.spec,
    required this.active,
    required this.activeBadgeLabel,
    required this.onTap,
  });

  final _PlanSpec spec;
  final bool active;
  final String activeBadgeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active
              ? c.rolePrimary.withValues(alpha: 0.09)
              : c.glassFillStrong,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? c.rolePrimary
                : spec.highlighted
                    ? c.rolePrimary.withValues(alpha: 0.35)
                    : c.glassBorder,
            width: active ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    spec.title,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? c.rolePrimary
                        : c.rolePrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    active ? activeBadgeLabel : spec.badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : c.rolePrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              spec.price,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: c.rolePrimary,
              ),
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < spec.features.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      size: 15,
                      color: active ? c.rolePrimary : c.greenText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      spec.features[i],
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.38,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              if (i < spec.features.length - 1) const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}
