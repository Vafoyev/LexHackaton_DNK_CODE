import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../contracts/presentation/cubit/contracts_cubit.dart';
import '../../session/presentation/cubit/session_cubit.dart';

class LegalCorpusPage extends StatefulWidget {
  const LegalCorpusPage({super.key});

  @override
  State<LegalCorpusPage> createState() => _LegalCorpusPageState();
}

class _LegalCorpusPageState extends State<LegalCorpusPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final lang = context.watch<SessionCubit>().state.lang;
    final contracts = context.watch<ContractsCubit>().state;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Text(
              AppStrings.t(lang, 'laws_title'),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
                color: c.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _tab,
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text('Moddalar', style: TextStyle(fontSize: 12.5)),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text('R1–R6', style: TextStyle(fontSize: 12.5)),
                ),
                2: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text('Integratsiya', style: TextStyle(fontSize: 12.5)),
                ),
              },
              onValueChanged: (v) {
                if (v != null) setState(() => _tab = v);
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: switch (_tab) {
              0 => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 112),
                  itemCount: contracts.legalNorms.length,
                  itemBuilder: (context, idx) {
                    final n = contracts.legalNorms[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        radius: 22,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        c.rolePrimary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${n.code} · ${n.article}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: c.rolePrimary,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  n.normNature,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: n.normNature == 'IMPERATIVE'
                                        ? c.redText
                                        : c.yellowText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              n.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              n.summary,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: c.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: n.officialUrl),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Lex.uz havolasi nusxalandi: ${n.officialUrl}',
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                'Amalda: ${n.effectiveFrom} · ${n.officialUrl}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: c.rolePrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              1 => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 112),
                  itemCount: contracts.rules.length,
                  itemBuilder: (context, idx) {
                    final r = contracts.rules[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        radius: 22,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 15,
                                  backgroundColor: c.rolePrimary,
                                  child: Text(
                                    r.code,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    r.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${r.scope} · ${r.defaultCategory}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: c.rolePrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              r.description,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              _ => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 112),
                  itemCount: contracts.integrations.length,
                  itemBuilder: (context, idx) {
                    final it = contracts.integrations[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        radius: 22,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    it.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: it.isMock ? c.yellowBg : c.greenBg,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: it.isMock
                                          ? c.yellowBorder
                                          : c.greenBorder,
                                    ),
                                  ),
                                  child: Text(
                                    it.statusLabel,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: it.isMock
                                          ? c.yellowText
                                          : c.greenText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              it.description,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            },
          ),
        ],
      ),
    );
  }
}
