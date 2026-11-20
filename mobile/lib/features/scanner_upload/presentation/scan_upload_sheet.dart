import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/security/file_integrity.dart';
import '../../../core/theme/app_theme.dart';
import '../../contracts/domain/entities/lex_models.dart';
import '../../contracts/presentation/cubit/contracts_cubit.dart';
import '../../session/presentation/cubit/session_cubit.dart';

class ScanUploadSheet extends StatefulWidget {
  const ScanUploadSheet({super.key, this.initialFocusCamera = false});

  final bool initialFocusCamera;

  static Future<void> show(
    BuildContext context, {
    bool focusCamera = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScanUploadSheet(initialFocusCamera: focusCamera),
    );
  }

  @override
  State<ScanUploadSheet> createState() => _ScanUploadSheetState();
}

class _ScanUploadSheetState extends State<ScanUploadSheet> {
  ContractType _selectedType = ContractType.service;
  bool _running = false;

  Future<void> _pickAndAnalyze({required bool isCamera}) async {
    if (_running) return;
    final messenger = ScaffoldMessenger.of(context);
    final file = await FilePicker.pickFile(
      type: isCamera ? FileType.image : FileType.custom,
      allowedExtensions:
          isCamera ? null : const ['docx', 'pdf', 'txt', 'jpg', 'jpeg', 'png'],
    );
    if (!mounted || file == null) return;

    final fileLen = file.lengthSync() ?? await file.length() ?? 0;
    if (fileLen > FileIntegrity.maxBytes) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Fayl hajmi 10 MB limitidan katta.'),
        ),
      );
      return;
    }

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Fayl ma’lumotini o‘qib bo‘lmadi. Boshqa fayl tanlang.'),
        ),
      );
      return;
    }

    setState(() => _running = true);
    final session = context.read<SessionCubit>();
    final contracts = context.read<ContractsCubit>();
    final result = await contracts.runFileAnalysis(
      fileName: file.name,
      bytes: bytes,
      isCameraScan: isCamera,
      allowExternalAi: session.state.externalAiConsent,
      hintType: _selectedType,
    );
    if (!mounted) return;
    setState(() => _running = false);
    if (result != null) {
      session.consumeQuota();
      Navigator.of(context).pop();
      context.push('/analysis/${result.id}');
    }
  }

  Future<void> _runSample(String sampleId) async {
    if (_running) return;
    setState(() => _running = true);
    final session = context.read<SessionCubit>();
    final contracts = context.read<ContractsCubit>();
    final result = await contracts.runDemoAnalysis(
      sampleId,
      allowExternalAi: session.state.externalAiConsent,
    );
    if (!mounted) return;
    setState(() => _running = false);
    if (result != null) {
      session.consumeQuota();
      Navigator.of(context).pop();
      context.push('/analysis/${result.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final contracts = context.watch<ContractsCubit>().state;
    final lang = session.lang;
    final surface = Theme.of(context).colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: c.grayBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.brandDeepBlue, c.brandCyan],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.document_scanner_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t(lang, 'scan_title'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Maks 10 MB · Lokal PII maskalash avtomatik ishlaydi',
                        style: TextStyle(fontSize: 12, color: c.grayText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_running) ...[
              _LiveProgressCard(stage: contracts.stage),
              const SizedBox(height: 12),
            ] else ...[
              // Contract type hint selector
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _TypeChip(
                    label: 'Xizmat (B2B)',
                    selected: _selectedType == ContractType.service,
                    onTap: () =>
                        setState(() => _selectedType = ContractType.service),
                  ),
                  _TypeChip(
                    label: 'Yetkazib berish',
                    selected: _selectedType == ContractType.supply,
                    onTap: () =>
                        setState(() => _selectedType = ContractType.supply),
                  ),
                  _TypeChip(
                    label: 'Noturar ijara',
                    selected: _selectedType == ContractType.nonResidentialLease,
                    onTap: () => setState(
                      () => _selectedType = ContractType.nonResidentialLease,
                    ),
                  ),
                  _TypeChip(
                    label: 'Ko‘chmas mulk (R6)',
                    selected: _selectedType == ContractType.realEstateSale,
                    onTap: () => setState(
                      () => _selectedType = ContractType.realEstateSale,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Primary Soliq-style Action Buttons
              Row(
                children: [
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.upload_file_rounded,
                      title: 'Fayl tanlash',
                      subtitle: 'DOCX, PDF, TXT',
                      highlighted: !widget.initialFocusCamera,
                      onTap: () => _pickAndAnalyze(isCamera: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.camera_alt_rounded,
                      title: 'Kamera / Rasm',
                      subtitle: 'EXIF tozalanadi',
                      highlighted: widget.initialFocusCamera,
                      onTap: () => _pickAndAnalyze(isCamera: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // External AI Consent toggle
              Material(
                color: c.grayBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: c.cardBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: session.externalAiConsent,
                    onChanged: (v) =>
                        context.read<SessionCubit>().setExternalAiConsent(v),
                    title: Text(
                      AppStrings.t(lang, 'external_ai_consent'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      session.externalAiConsent
                          ? 'Rejim: Gibrid AI + Go Verifier (JSHSHIR/Pasport maskalanadi)'
                          : 'Rejim: Faqat lokal Go qoidalari (tashqariga matn chiqmaydi)',
                      style: TextStyle(fontSize: 11, color: c.grayText),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.t(lang, 'demo_samples'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.brandDeepBlue,
                ),
              ),
              const SizedBox(height: 8),
              _DemoSampleTile(
                key: const Key('demo_sample_service'),
                title: 'B2B Xizmat ko‘rsatish shartnomasi (UZ-Lotin)',
                subtitle: 'R1–R5 qoidalari · Qizil/Sariq/Kulrang/Yashil + PII',
                badge: 'DOCX',
                onTap: () => _runSample('sample_b2b_service'),
              ),
              const SizedBox(height: 8),
              _DemoSampleTile(
                key: const Key('demo_sample_notarial'),
                title: 'Bino oldi-sotdi loyihasi (Notarial R6)',
                subtitle: 'FK 110–112 majburiy notarial tasdiq signali',
                badge: 'R6',
                onTap: () => _runSample('sample_notarial_r6'),
              ),
              const SizedBox(height: 8),
              _DemoSampleTile(
                key: const Key('demo_sample_supply_ru'),
                title: 'Договор поставки оборудования №19 (RU)',
                subtitle: 'Ko‘p tilli tahlil + Neytral balans + Mediatsiya',
                badge: 'PDF · RU',
                onTap: () => _runSample('sample_supply_ru'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveProgressCard extends StatelessWidget {
  const _LiveProgressCard({required this.stage});

  final AnalysisStage stage;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final steps = [
      (AnalysisStage.reading, '1. Hujjat matni va bandlar ajratilmoqda'),
      (AnalysisStage.redactingPii, '2. Shaxsiy ma’lumotlar (PII) lokal maskalanmoqda'),
      (AnalysisStage.checkingRules, '3. Deterministik R1–R6 qoidalar tekshirilmoqda'),
      (AnalysisStage.verifyingSources, '4. Go Verifier modda va sanalarni tasdiqlamoqda'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.brandDeepBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.brandPrimaryBlue.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: c.brandPrimaryBlue,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Tahlil bajarilmoqda...',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    stage.index > step.$1.index
                        ? Icons.check_circle_rounded
                        : stage == step.$1
                            ? Icons.sync_rounded
                            : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: stage.index >= step.$1.index
                        ? c.brandPrimaryBlue
                        : c.grayText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.$2,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: stage == step.$1
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
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
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: c.brandPrimaryBlue.withValues(alpha: 0.14),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? c.brandDeepBlue : null,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.highlighted,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: highlighted
              ? LinearGradient(colors: [c.brandDeepBlue, c.brandPrimaryBlue])
              : null,
          color: highlighted ? null : c.grayBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted ? c.brandPrimaryBlue : c.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 26,
              color: highlighted ? Colors.white : c.brandPrimaryBlue,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: highlighted ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: highlighted ? Colors.white70 : c.grayText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoSampleTile extends StatelessWidget {
  const _DemoSampleTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: c.brandPrimaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: c.brandPrimaryBlue,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: c.grayText),
                  ),
                ],
              ),
            ),
            Icon(Icons.play_arrow_rounded, color: c.brandPrimaryBlue),
          ],
        ),
      ),
    );
  }
}
