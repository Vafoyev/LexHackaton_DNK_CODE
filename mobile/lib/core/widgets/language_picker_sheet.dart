import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/session/presentation/cubit/session_cubit.dart';
import '../l10n/app_strings.dart';
import '../l10n/uzbek_alphabet.dart';
import '../theme/app_theme.dart';
import 'lex_modal_sheet.dart';

class LanguagePickerSheet extends StatelessWidget {
  const LanguagePickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showLexModalSheet<void>(
      context: context,
      builder: (_) => const LanguagePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final cubit = context.read<SessionCubit>();

    return Column(
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
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        _LangOptionTile(
          key: const Key('lang_opt_uz_reformed'),
          badge: 'UZ',
          title: 'Özbekça',
          selected: session.lang == AppLang.uz,
          onTap: () {
            HapticFeedback.selectionClick();
            cubit.setLanguageConfig(
              AppLang.uz,
              uzbekScript: UzbekScript.reformed,
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
            HapticFeedback.selectionClick();
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
            HapticFeedback.selectionClick();
            cubit.setLanguageConfig(AppLang.en);
            Navigator.of(context).pop();
          },
        ),
      ],
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? c.rolePrimary.withValues(alpha: 0.13) : c.grayBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? c.rolePrimary : c.glassBorder,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? c.rolePrimary : c.glassFillStrong,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : c.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  size: 20,
                  color: c.rolePrimary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
