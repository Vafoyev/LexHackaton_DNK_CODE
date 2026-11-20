import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/risk_badges.dart';
import '../../contracts/domain/entities/lex_models.dart';
import '../../contracts/presentation/cubit/contracts_cubit.dart';
import '../../scanner_upload/presentation/scan_upload_sheet.dart';
import '../../session/presentation/cubit/session_cubit.dart';

class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final lang = context.watch<SessionCubit>().state.lang;
    final state = context.watch<ContractsCubit>().state;
    final items = state.filteredAnalyses;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t(lang, 'docs_title')),
        actions: [
          IconButton(
            tooltip: AppStrings.t(lang, 'scan'),
            onPressed: () => ScanUploadSheet.show(context),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) =>
                  context.read<ContractsCubit>().setSearchQuery(v),
              decoration: InputDecoration(
                hintText: 'Shartnoma nomi yoki fayl bo‘yicha qidirish...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.cardBorder),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Barchasi'),
                  selected: state.typeFilter == null,
                  onSelected: (_) =>
                      context.read<ContractsCubit>().setTypeFilter(null),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Xizmat'),
                  selected: state.typeFilter == ContractType.service,
                  onSelected: (_) => context
                      .read<ContractsCubit>()
                      .setTypeFilter(ContractType.service),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Yetkazib berish'),
                  selected: state.typeFilter == ContractType.supply,
                  onSelected: (_) => context
                      .read<ContractsCubit>()
                      .setTypeFilter(ContractType.supply),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Notarial (R6)'),
                  selected: state.typeFilter == ContractType.realEstateSale,
                  onSelected: (_) => context
                      .read<ContractsCubit>()
                      .setTypeFilter(ContractType.realEstateSale),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_open_rounded,
                            size: 56,
                            color: c.grayText,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Hujjat topilmadi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => ScanUploadSheet.show(context),
                            icon: const Icon(Icons.document_scanner_rounded),
                            label: const Text('Yangi shartnoma tekshirish'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => context.push('/analysis/${item.id}'),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Hujjatni o‘chirish',
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 20,
                                          color: c.redText,
                                        ),
                                        onPressed: () =>
                                            _confirmDelete(context, item),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${item.fileName} · ${item.languageLabel} · Saqlash: ${item.retentionDays} kun',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: c.grayText,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  RiskColorSummaryRow(analysis: item),
                                ],
                              ),
                            ),
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

  Future<void> _confirmDelete(
    BuildContext context,
    ContractAnalysis item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hujjatni o‘chirish'),
        content: Text(
          '"${item.title}" hujjati va uning tahlil izlari qurilmadan hamda serverdan o‘chiriladi (3.2 maxfiylik qoidasi).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('O‘chirish'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<ContractsCubit>().deleteAnalysis(item.id);
    }
  }
}
