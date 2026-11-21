import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/lex_modal_sheet.dart';
import '../../../core/widgets/lex_toast.dart';
import '../../../core/widgets/risk_badges.dart';
import '../../contracts/domain/entities/lex_models.dart';
import '../../contracts/presentation/cubit/contracts_cubit.dart';
import '../../monitoring/domain/law_monitoring_models.dart';
import '../../monitoring/presentation/monitoring_sheets.dart';
import '../../scanner_upload/presentation/direct_scan_launcher.dart';
import '../../session/presentation/cubit/session_cubit.dart';

class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;
    final isBusiness = session.segment == AccountSegment.business;
    final state = context.watch<ContractsCubit>().state;
    final monitoring = context.watch<MonitoringCubit>().state;
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
                    AppStrings.t(lang, 'docs_title', script: script),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                GlassPill(
                  onTap: () => DirectScanLauncher.pickFileAndAnalyze(context),
                  padding: const EdgeInsets.all(9),
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
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: TextField(
                onChanged: (v) =>
                    context.read<ContractsCubit>().setSearchQuery(v),
                style: TextStyle(fontSize: 14.5, color: c.textPrimary),
                decoration: InputDecoration(
                  hintText:
                      AppStrings.t(lang, 'docs_search_hint', script: script),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterGlassChip(
                  label: AppStrings.t(lang, 'filter_all', script: script),
                  selected: state.typeFilter == null,
                  onTap: () =>
                      context.read<ContractsCubit>().setTypeFilter(null),
                ),
                const SizedBox(width: 6),
                _FilterGlassChip(
                  label: AppStrings.t(lang, 'filter_service', script: script),
                  selected: state.typeFilter == ContractType.service,
                  onTap: () => context
                      .read<ContractsCubit>()
                      .setTypeFilter(ContractType.service),
                ),
                const SizedBox(width: 6),
                _FilterGlassChip(
                  label: AppStrings.t(lang, 'filter_lease', script: script),
                  selected:
                      state.typeFilter == ContractType.nonResidentialLease,
                  onTap: () => context
                      .read<ContractsCubit>()
                      .setTypeFilter(ContractType.nonResidentialLease),
                ),
                const SizedBox(width: 6),
                _FilterGlassChip(
                  label: AppStrings.t(lang, 'filter_supply', script: script),
                  selected: state.typeFilter == ContractType.supply,
                  onTap: () => context
                      .read<ContractsCubit>()
                      .setTypeFilter(ContractType.supply),
                ),
                const SizedBox(width: 6),
                _FilterGlassChip(
                  label: AppStrings.t(lang, 'filter_notarial', script: script),
                  selected: state.typeFilter == ContractType.realEstateSale,
                  onTap: () => context
                      .read<ContractsCubit>()
                      .setTypeFilter(ContractType.realEstateSale),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                            AppStrings.t(lang, 'docs_empty', script: script),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: () =>
                                DirectScanLauncher.pickFileAndAnalyze(context),
                            icon: const Icon(CupertinoIcons.add, size: 17),
                            label: Text(
                              AppStrings.t(
                                lang,
                                'docs_new_check',
                                script: script,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 114),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final monAlert = isBusiness
                          ? monitoring.alertForContract(item.id)
                          : null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          radius: 22,
                          padding: const EdgeInsets.all(15),
                          onTap: () => context.push('/analysis/${item.id}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color:
                                          c.rolePrimary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.doc_text_fill,
                                      size: 19,
                                      color: c.rolePrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppStrings.adaptUz(
                                            item.title,
                                            lang,
                                            script,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: c.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item.fileName} · ${item.formatLabel}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: c.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: AppStrings.t(
                                      lang,
                                      'delete',
                                      script: script,
                                    ),
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
                              if (monAlert != null) ...[
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => MonitoringAlertDetailSheet.show(
                                    context,
                                    alert: monAlert,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            color: c.yellowText,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        Expanded(
                                          child: Text(
                                            '${AppStrings.t(lang, 'b2b_monitoring_affected_pill', script: script)} · ${AppStrings.adaptUz(monAlert.affectedClause, lang, script)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: c.yellowText,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          CupertinoIcons.chevron_forward,
                                          size: 12,
                                          color: c.yellowText,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
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
    final c = context.lexColors;
    final session = context.read<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;
    final confirmed = await showLexModalSheet<bool>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.t(lang, 'delete_doc_title', script: script),
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"${AppStrings.adaptUz(item.title, lang, script)}" ${AppStrings.t(lang, 'delete_doc_body', script: script)}',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(AppStrings.t(lang, 'cancel', script: script)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: c.redText),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(AppStrings.t(lang, 'delete', script: script)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<ContractsCubit>().deleteAnalysis(item.id);
      if (context.mounted) {
        LexToast.show(
          context,
          AppStrings.t(lang, 'toast_deleted', script: script),
          type: LexToastType.info,
        );
      }
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
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : c.textPrimary,
        ),
      ),
    );
  }
}
