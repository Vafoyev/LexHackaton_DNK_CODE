import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/session/presentation/cubit/session_cubit.dart';
import '../l10n/app_strings.dart';
import '../l10n/uzbek_alphabet.dart';
import '../theme/app_theme.dart';
import 'glass_surface.dart';

class LanguagePickerSheet extends StatelessWidget {
  const LanguagePickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const LanguagePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final cubit = context.read<SessionCubit>();

    return Padding(
      padding: const EdgeInsets.all(14),
      child: GlassCard(
        radius: 28,
        blurSigma: 26,
        tintColor: c.glassFillStrong,
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.t(
                session.lang,
                'lang_title',
                script: session.uzbekScript,
              ),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _LangOptionTile(
              key: const Key('lang_opt_uz_reformed'),
              badge: 'UZ',
              title: 'Özbekça · Yangi (Ğ Ö Ş Ç)',
              selected: session.lang == AppLang.uz &&
                  session.uzbekScript == UzbekScript.reformed,
              onTap: () {
                cubit.setLanguageConfig(
                  AppLang.uz,
                  uzbekScript: UzbekScript.reformed,
                );
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 8),
            _LangOptionTile(
              key: const Key('lang_opt_uz_standard'),
              badge: 'UZ',
              title: 'O‘zbekcha · Lotin (O‘ G‘)',
              selected: session.lang == AppLang.uz &&
                  session.uzbekScript == UzbekScript.standard,
              onTap: () {
                cubit.setLanguageConfig(
                  AppLang.uz,
                  uzbekScript: UzbekScript.standard,
                );
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 8),
            _LangOptionTile(
              key: const Key('lang_opt_ru'),
              badge: 'RU',
              title: 'Русский',
              selected: session.lang == AppLang.ru,
              onTap: () {
                cubit.setLanguageConfig(AppLang.ru);
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 8),
            _LangOptionTile(
              key: const Key('lang_opt_en'),
              badge: 'EN',
              title: 'English',
              selected: session.lang == AppLang.en,
              onTap: () {
                cubit.setLanguageConfig(AppLang.en);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LangOptionTile extends StatelessWidget {
  const _LangOptionTile({
    super.key,
    required this.badge,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String badge;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? c.rolePrimary.withValues(alpha: 0.13) : c.grayBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? c.rolePrimary : c.glassBorder,
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? c.rolePrimary : c.glassFillStrong,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : c.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ),
            if (selected)
              Icon(
                CupertinoIcons.checkmark_circle_fill,
                size: 18,
                color: c.rolePrimary,
              ),
          ],
        ),
      ),
    );
  }
}
