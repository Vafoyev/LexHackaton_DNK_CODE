import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
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

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.t(lang, 'docs_title'),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                GlassPill(
                  onTap: () => ScanUploadSheet.show(context),
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    CupertinoIcons.add,
                    size: 18,
                    color: c.rolePrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: TextField(
                onChanged: (v) =>
                    context.read<ContractsCubit>().setSearchQuery(v),
                decoration: InputDecoration(
                  hintText: 'Shartnoma nomi yoki fayl qidirish...',
                  hintStyle: TextStyle(fontSize: 13.5, color: c.textSecondary),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterGlassChip(
                  label: 'Barchasi',
                  selected: state.typeFilter == null,
                  onTap: () =>
                      context.read<ContractsCubit>().setTypeFilter(null),
                ),
                const SizedBox(width: 6),
                _FilterGlassChip(
                  label: 'Xizmat',
                  selected: state.typeFilter == ContractType.service,
                  onTap: () => context
                      .read<ContractsCubit>()
                      .setTypeFilter(ContractType.service),
                ),
                const SizedBox(width: 6),
                _FilterGlassChip(
                  label: 'Yetkazib berish',
                  selected: state.typeFilter == ContractType.supply,
                  onTap: () => context
                      .read<ContractsCubit>()
                      .setTypeFilter(ContractType.supply),
                ),
                const SizedBox(width: 6),
                _FilterGlassChip(
                  label: 'Notarial (R6)',
                  selected: state.typeFilter == ContractType.realEstateSale,
                  onTap: () => context
                      .read<ContractsCubit>()
                      .setTypeFilter(ContractType.realEstateSale),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: GlassCard(
                      radius: 24,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.folder,
                            size: 46,
                            color: c.textSecondary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Hujjat topilmadi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => ScanUploadSheet.show(context),
                            icon: const Icon(CupertinoIcons.viewfinder, size: 17),
                            label: const Text('Yangi shartnoma tekshirish'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          radius: 22,
                          padding: const EdgeInsets.all(14),
                          onTap: () => context.push('/analysis/${item.id}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'O‘chirish',
                                    icon: Icon(
                                      CupertinoIcons.trash,
                                      size: 18,
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
                                  color: c.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              RiskColorSummaryRow(analysis: item),
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

  Future<void> _confirmDelete(
    BuildContext context,
    ContractAnalysis item,
  ) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Hujjatni o‘chirish'),
        content: Text(
          '"${item.title}" hujjati qurilma va serverdan o‘chiriladi (3.2 maxfiylik qoidasi).',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Bekor qilish'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
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

class _FilterGlassChip extends StatelessWidget {
  const _FilterGlassChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return GlassPill(
      onTap: onTap,
      tintColor: selected ? c.rolePrimary : c.glassFillStrong,
      borderColor: selected ? c.rolePrimary : c.glassBorder,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : c.textPrimary,
        ),
      ),
    );
  }
}
