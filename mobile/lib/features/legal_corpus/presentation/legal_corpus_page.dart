import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t(lang, 'laws_title'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Moddalar')),
                ButtonSegment(value: 1, label: Text('R1–R6')),
                ButtonSegment(value: 2, label: Text('Integratsiya')),
              ],
              selected: {_tab},
              onSelectionChanged: (v) => setState(() => _tab = v.first),
            ),
          ),
          Expanded(
            child: switch (_tab) {
              0 => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  itemCount: contracts.legalNorms.length,
                  itemBuilder: (context, idx) {
                    final n = contracts.legalNorms[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.brandPrimaryBlue
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${n.code} · ${n.article}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: c.brandDeepBlue,
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
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n.summary,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: c.grayText,
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
                                    color: c.brandPrimaryBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              1 => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  itemCount: contracts.rules.length,
                  itemBuilder: (context, idx) {
                    final r = contracts.rules[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: c.brandDeepBlue,
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
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
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
                                  fontWeight: FontWeight.w600,
                                  color: c.brandPrimaryBlue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                r.description,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: c.grayText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              _ => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  itemCount: contracts.integrations.length,
                  itemBuilder: (context, idx) {
                    final it = contracts.integrations[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      it.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
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
                                      borderRadius: BorderRadius.circular(8),
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
                                  color: c.grayText,
                                ),
                              ),
                            ],
                          ),
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
