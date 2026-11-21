import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/uzbek_alphabet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/lex_modal_sheet.dart';
import '../../../core/widgets/lex_toast.dart';
import '../../contracts/domain/entities/lex_models.dart';
import '../../contracts/presentation/cubit/contracts_cubit.dart';
import '../../session/presentation/cubit/session_cubit.dart';

class LegalCorpusPage extends StatefulWidget {
  const LegalCorpusPage({super.key});

  @override
  State<LegalCorpusPage> createState() => _LegalCorpusPageState();
}

class _LegalCorpusPageState extends State<LegalCorpusPage> {
  String _query = '';
  int _tab = 0; // 0 = Lex.uz Moddalar, 1 = R1-R6 Qoidalar

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;
    final contracts = context.watch<ContractsCubit>().state;

    final q = _query.trim().toLowerCase();
    final filteredNorms = q.isEmpty
        ? contracts.legalNorms
        : contracts.legalNorms.where((n) {
            return n.code.toLowerCase().contains(q) ||
                n.article.toLowerCase().contains(q) ||
                n.title.toLowerCase().contains(q) ||
                n.summary.toLowerCase().contains(q);
          }).toList(growable: false);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.t(lang, 'nav_laws', script: script),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.rolePrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.book_fill,
                        size: 13,
                        color: c.rolePrimary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Lex.uz',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: c.rolePrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lex.uz-style search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(fontSize: 14.5, color: c.textPrimary),
                decoration: InputDecoration(
                  hintText:
                      AppStrings.t(lang, 'laws_search_hint', script: script),
                  hintStyle: TextStyle(fontSize: 14, color: c.textSecondary),
                  prefixIcon: Icon(
                    CupertinoIcons.search,
                    size: 18,
                    color: c.textSecondary,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _tab,
              children: {
                0: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Text(
                    AppStrings.t(lang, 'laws_tab_articles', script: script),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                1: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Text(
                    AppStrings.t(lang, 'laws_tab_rules', script: script),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              },
              onValueChanged: (v) {
                if (v != null) setState(() => _tab = v);
              },
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _tab == 0
                ? ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 114),
                    itemCount: filteredNorms.length,
                    itemBuilder: (context, idx) {
                      final n = filteredNorms[idx];
                      final isImperative = n.normNature == 'IMPERATIVE';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          radius: 22,
                          padding: const EdgeInsets.all(15),
                          onTap: () => _showArticleReader(
                            context,
                            norm: n,
                            lang: lang,
                            script: script,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: c.rolePrimary
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        AppStrings.adaptUz(
                                          '${n.code} · ${n.article}',
                                          lang,
                                          script,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: c.rolePrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.greenBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      AppStrings.t(
                                        lang,
                                        'law_active_badge',
                                        script: script,
                                      ),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: c.greenText,
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
                              const SizedBox(height: 10),
                              Text(
                                AppStrings.adaptUz(n.title, lang, script),
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                AppStrings.adaptUz(n.summary, lang, script),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: c.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.calendar,
                                    size: 12.5,
                                    color: c.textSecondary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${AppStrings.t(lang, 'active_since', script: script)}: ${n.effectiveFrom}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    isImperative ? 'Majburiy' : 'Tavsiyaviy',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isImperative
                                          ? c.redText
                                          : c.yellowText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 114),
                    itemCount: contracts.rules.length,
                    itemBuilder: (context, idx) {
                      final r = contracts.rules[idx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          radius: 22,
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(13),
                                  gradient: LinearGradient(
                                    colors: [
                                      c.roleGradientStart,
                                      c.roleGradientEnd,
                                    ],
                                  ),
                                ),
                                child: Text(
                                  r.code,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppStrings.adaptUz(r.title, lang, script),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      AppStrings.adaptUz(
                                        r.description,
                                        lang,
                                        script,
                                      ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: c.textSecondary,
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
                  ),
          ),
        ],
      ),
    );
  }

  void _showArticleReader(
    BuildContext context, {
    required LegalNorm norm,
    required AppLang lang,
    required UzbekScript script,
  }) {
    final c = context.lexColors;
    final isImperative = norm.normNature == 'IMPERATIVE';

    showLexModalSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.rolePrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  AppStrings.adaptUz(
                    '${norm.code} · ${norm.article}',
                    lang,
                    script,
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: c.rolePrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isImperative ? c.redBg : c.yellowBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  AppStrings.adaptUz(
                    isImperative ? 'Majburiy' : 'Tavsiyaviy',
                    lang,
                    script,
                  ),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isImperative ? c.redText : c.yellowText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            AppStrings.adaptUz(norm.title, lang, script),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.grayBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.t(lang, 'law_meaning', script: script),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: c.rolePrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppStrings.adaptUz(norm.summary, lang, script),
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                CupertinoIcons.calendar,
                size: 14,
                color: c.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                '${AppStrings.t(lang, 'effective_from', script: script)}: ${norm.effectiveFrom}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: norm.officialUrl),
                    );
                    Navigator.of(ctx).pop();
                    LexToast.show(
                      context,
                      AppStrings.t(lang, 'link_copied', script: script),
                      type: LexToastType.success,
                    );
                  },
                  icon: const Icon(CupertinoIcons.link, size: 16),
                  label: const Text('Lex.uz'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    AppStrings.t(lang, 'ok_btn', script: script),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
