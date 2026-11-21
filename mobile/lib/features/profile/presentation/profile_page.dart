import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/language_picker_sheet.dart';
import '../../../core/widgets/lex_toast.dart';
import '../../../core/widgets/theme_reveal_scope.dart';
import '../../contracts/domain/entities/lex_models.dart';
import '../../monitoring/domain/law_monitoring_models.dart';
import '../../monitoring/presentation/monitoring_sheets.dart';
import '../../session/presentation/cubit/session_cubit.dart';
import 'plans_modal_sheet.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final monitoring = context.watch<MonitoringCubit>().state;
    final cubit = context.read<SessionCubit>();
    final lang = session.lang;
    final script = session.uzbekScript;
    final isBusiness = session.segment == AccountSegment.business;
    final isDark = session.themeMode == ThemeMode.dark;

    final initials = _initialsFor(
      isBusiness ? session.organizationName : session.userName,
    );

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 114),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 14),
            child: Text(
              AppStrings.t(lang, 'nav_profile', script: script),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: c.textPrimary,
              ),
            ),
          ),

          // 1. MyGov.uz-style Executive Passport Identity Card
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.roleGradientStart, c.roleGradientEnd],
                ),
                boxShadow: [
                  BoxShadow(
                    color: c.roleGlow,
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -28,
                    top: -28,
                    child: Container(
                      width: 136,
                      height: 136,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isBusiness
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFF7DD3FC))
                            .withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.18),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppStrings.adaptUz(
                                      isBusiness
                                          ? session.organizationName
                                          : session.userName,
                                      lang,
                                      script,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        CupertinoIcons.checkmark_seal_fill,
                                        size: 14,
                                        color: Color(0xFF86EFAC),
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          AppStrings.t(
                                            lang,
                                            'verified_id',
                                            script: script,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _PassportChip(
                              icon: isBusiness
                                  ? CupertinoIcons.building_2_fill
                                  : CupertinoIcons.person_fill,
                              text: isBusiness
                                  ? AppStrings.t(
                                      lang,
                                      'business_b2b',
                                      script: script,
                                    )
                                  : AppStrings.t(
                                      lang,
                                      'individual_b2c',
                                      script: script,
                                    ),
                            ),
                            _PassportChip(
                              icon: CupertinoIcons.shield_lefthalf_fill,
                              text: isBusiness ? 'E-IMZO' : 'OneID',
                            ),
                            if (isBusiness)
                              _PassportChip(
                                icon: CupertinoIcons.number_square_fill,
                                text: AppStrings.t(
                                  lang,
                                  'b2b_stir_label',
                                  script: script,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 1b. B2B Company Documents Vault (Upload & Live Law Monitoring)
          if (isBusiness) ...[
            GlassCard(
              radius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c.rolePrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          CupertinoIcons.folder_fill,
                          color: c.rolePrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.t(
                                lang,
                                'company_docs_title',
                                script: script,
                              ),
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppStrings.t(
                                lang,
                                'company_docs_sub',
                                script: script,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (monitoring.companyDocs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        AppStrings.t(
                          lang,
                          'company_docs_empty',
                          script: script,
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: c.textSecondary,
                        ),
                      ),
                    )
                  else ...[
                    for (int i = 0; i < monitoring.companyDocs.length; i++) ...[
                      Builder(
                        builder: (context) {
                          final doc = monitoring.companyDocs[i];
                          final alert = monitoring.alertById(doc.alertId);
                          final hasAlert = alert != null && !alert.isResolved;
                          return InkWell(
                            onTap: hasAlert
                                ? () => MonitoringAlertDetailSheet.show(
                                      context,
                                      alert: alert,
                                    )
                                : null,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: c.grayBg,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color:
                                          hasAlert ? c.yellowText : c.greenText,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppStrings.adaptUz(
                                            doc.title,
                                            lang,
                                            script,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: c.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          hasAlert
                                              ? '${AppStrings.t(lang, 'b2b_monitoring_affected_pill', script: script)} · ${AppStrings.adaptUz(alert.affectedClause, lang, script)}'
                                              : AppStrings.t(
                                                  lang,
                                                  'b2b_monitoring_active_pill',
                                                  script: script,
                                                ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: hasAlert
                                                ? c.yellowText
                                                : c.greenText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (hasAlert)
                                    Icon(
                                      CupertinoIcons.chevron_forward,
                                      size: 14,
                                      color: c.yellowText,
                                    )
                                  else
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 30,
                                        minHeight: 30,
                                      ),
                                      icon: Icon(
                                        CupertinoIcons.trash,
                                        size: 15,
                                        color: c.textSecondary,
                                      ),
                                      onPressed: () {
                                        context
                                            .read<MonitoringCubit>()
                                            .removeCompanyDoc(doc.id);
                                        LexToast.show(
                                          context,
                                          AppStrings.t(
                                            lang,
                                            'toast_deleted',
                                            script: script,
                                          ),
                                          type: LexToastType.info,
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 4),
                  ],
                  SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () => _uploadCompanyDocument(context),
                      icon: const Icon(
                        CupertinoIcons.cloud_upload_fill,
                        size: 17,
                      ),
                      label: Text(
                        AppStrings.t(
                          lang,
                          'company_docs_upload_btn',
                          script: script,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 2. Interactive Subscription & Plan Card
          GlassCard(
            radius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.rolePrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        CupertinoIcons.sparkles,
                        color: c.rolePrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.t(
                              lang,
                              'subscription_title',
                              script: script,
                            ),
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppStrings.adaptUz(
                              session.quota.planName,
                              lang,
                              script,
                            ),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: c.rolePrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${session.quota.remainingTotal}/${session.quota.totalLimit}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isBusiness
                      ? AppStrings.t(lang, 'business_quota_sub', script: script)
                      : AppStrings.t(lang, 'citizen_quota_sub', script: script),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: session.quota.totalLimit == 0
                        ? 0
                        : session.quota.totalUsed / session.quota.totalLimit,
                    minHeight: 6,
                    backgroundColor: c.rolePrimary.withValues(alpha: 0.14),
                    color: c.rolePrimary,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () => PlansModalSheet.show(context),
                    child: Text(
                      AppStrings.t(lang, 'choose_plan', script: script),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Appearance & Language (MyGov-style grouped settings)
          GlassCard(
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                Builder(
                  builder: (btnCtx) => InkWell(
                    onTap: () => ThemeRevealScope.toggleFromContext(btnCtx),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: c.rolePrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isDark
                                  ? CupertinoIcons.moon_stars_fill
                                  : CupertinoIcons.sun_max_fill,
                              size: 19,
                              color: c.rolePrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isDark
                                      ? AppStrings.t(
                                          lang,
                                          'theme_dark',
                                          script: script,
                                        )
                                      : AppStrings.t(
                                          lang,
                                          'theme_light',
                                          script: script,
                                        ),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary,
                                  ),
                                ),
                                Text(
                                  AppStrings.t(
                                    lang,
                                    'theme_dark_sub',
                                    script: script,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CupertinoSwitch(
                            activeTrackColor: c.rolePrimary,
                            value: isDark,
                            onChanged: (_) =>
                                ThemeRevealScope.toggleFromContext(btnCtx),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                InkWell(
                  onTap: () => LanguagePickerSheet.show(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: c.rolePrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            CupertinoIcons.globe,
                            size: 19,
                            color: c.rolePrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppStrings.t(lang, 'lang_label', script: script),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: c.rolePrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            switch (lang) {
                              AppLang.uz => 'Özbekça',
                              AppLang.ru => 'Русский',
                              AppLang.en => 'English',
                            },
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: c.rolePrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          CupertinoIcons.chevron_forward,
                          size: 15,
                          color: c.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. Privacy & Security Card
          GlassCard(
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                _CupertinoSettingRow(
                  title: AppStrings.t(lang, 'sec_flag_title', script: script),
                  subtitle: AppStrings.t(lang, 'sec_flag_sub', script: script),
                  value: session.flagSecureEnabled,
                  onChanged: cubit.setFlagSecure,
                ),
                const Divider(height: 1),
                _CupertinoSettingRow(
                  title:
                      AppStrings.t(lang, 'sec_curtain_title', script: script),
                  subtitle:
                      AppStrings.t(lang, 'sec_curtain_sub', script: script),
                  value: session.privacyCurtainEnabled,
                  onChanged: cubit.setPrivacyCurtain,
                ),
                const Divider(height: 1),
                _CupertinoSettingRow(
                  title: AppStrings.t(lang, 'sec_bio_title', script: script),
                  subtitle: AppStrings.t(lang, 'sec_bio_sub', script: script),
                  value: session.biometricLockEnabled,
                  onChanged: cubit.setBiometricLock,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 5. Sign Out
          GlassCard(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            onTap: () {
              HapticFeedback.lightImpact();
              cubit.logout();
              context.go('/role-select');
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.square_arrow_left,
                  size: 18,
                  color: c.redText,
                ),
                const SizedBox(width: 8),
                Text(
                  AppStrings.t(lang, 'logout_btn', script: script),
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: c.redText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadCompanyDocument(BuildContext context) async {
    final session = context.read<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['docx', 'pdf', 'txt', 'jpg', 'jpeg', 'png'],
    );
    if (!context.mounted || file == null) return;
    final cleanTitle = file.name
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll('_', ' ')
        .trim();
    context.read<MonitoringCubit>().addCompanyDoc(
          title: cleanTitle.isEmpty ? 'Firma hujjati' : cleanTitle,
          category: 'Ichki hujjat',
          fileName: file.name,
        );
    LexToast.show(
      context,
      AppStrings.t(lang, 'b2b_mon_toast_added', script: script),
      type: LexToastType.success,
    );
  }

  String _initialsFor(String raw) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'LG';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _PassportChip extends StatelessWidget {
  const _PassportChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CupertinoSettingRow extends StatelessWidget {
  const _CupertinoSettingRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          CupertinoSwitch(
            activeTrackColor: c.rolePrimary,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
