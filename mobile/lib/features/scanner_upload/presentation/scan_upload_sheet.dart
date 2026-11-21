import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/security/file_integrity.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
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
      useRootNavigator: true,
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
        const SnackBar(content: Text('Fayl hajmi 10 MB limitidan katta.')),
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

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          decoration: BoxDecoration(
            color: c.glassFillStrong,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(top: BorderSide(color: c.glassBorder)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            22 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.textSecondary.withValues(alpha: 0.35),
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
                          colors: [c.roleGradientStart, c.roleGradientEnd],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        CupertinoIcons.viewfinder,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.t(lang, 'scan_title'),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Maks 10 MB · Lokal PII maskalash avtomatik',
                            style:
                                TextStyle(fontSize: 12, color: c.textSecondary),
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
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _TypePill(
                        label: 'Xizmat (B2B)',
                        selected: _selectedType == ContractType.service,
                        onTap: () => setState(
                          () => _selectedType = ContractType.service,
                        ),
                      ),
                      _TypePill(
                        label: 'Yetkazib berish',
                        selected: _selectedType == ContractType.supply,
                        onTap: () => setState(
                          () => _selectedType = ContractType.supply,
                        ),
                      ),
                      _TypePill(
                        label: 'Noturar ijara',
                        selected:
                            _selectedType == ContractType.nonResidentialLease,
                        onTap: () => setState(
                          () =>
                              _selectedType = ContractType.nonResidentialLease,
                        ),
                      ),
                      _TypePill(
                        label: 'Ko‘chmas mulk (R6)',
                        selected: _selectedType == ContractType.realEstateSale,
                        onTap: () => setState(
                          () => _selectedType = ContractType.realEstateSale,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          icon: CupertinoIcons.doc_on_doc_fill,
                          title: 'Fayl tanlash',
                          subtitle: 'DOCX, PDF, TXT',
                          highlighted: !widget.initialFocusCamera,
                          onTap: () => _pickAndAnalyze(isCamera: false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionTile(
                          icon: CupertinoIcons.camera_fill,
                          title: 'Kamera / Rasm',
                          subtitle: 'EXIF tozalanadi',
                          highlighted: widget.initialFocusCamera,
                          onTap: () => _pickAndAnalyze(isCamera: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    radius: 16,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.t(lang, 'external_ai_consent'),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                session.externalAiConsent
                                    ? 'Gibrid AI + Go Verifier (PII maskalanadi)'
                                    : 'Faqat lokal Go qoidalari (tashqariga chiqmaydi)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        CupertinoSwitch(
                          activeTrackColor: c.rolePrimary,
                          value: session.externalAiConsent,
                          onChanged: (v) => context
                              .read<SessionCubit>()
                              .setExternalAiConsent(v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.t(lang, 'demo_samples'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: c.rolePrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DemoSampleTile(
                    key: const Key('demo_sample_service'),
                    title: 'B2B Xizmat ko‘rsatish shartnomasi (UZ-Lotin)',
                    subtitle: 'R1–R5 qoidalari · 3 rang + PII maskalash',
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
      (
        AnalysisStage.redactingPii,
        '2. Shaxsiy ma’lumotlar (PII) lokal maskalanmoqda',
      ),
      (
        AnalysisStage.checkingRules,
        '3. Deterministik R1–R6 qoidalar tekshirilmoqda',
      ),
      (
        AnalysisStage.verifyingSources,
        '4. Go Verifier modda va sanalarni tasdiqlamoqda',
      ),
    ];

    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CupertinoActivityIndicator(color: c.rolePrimary),
              const SizedBox(width: 10),
              Text(
                'Tahlil bajarilmoqda...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
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
                        ? CupertinoIcons.checkmark_circle_fill
                        : stage == step.$1
                            ? CupertinoIcons.arrow_2_circlepath
                            : CupertinoIcons.circle,
                    size: 16,
                    color: stage.index >= step.$1.index
                        ? c.rolePrimary
                        : c.textSecondary,
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
                        color: c.textPrimary,
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

class _TypePill extends StatelessWidget {
  const _TypePill({
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
      tintColor: selected ? c.rolePrimary : c.grayBg,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: highlighted
            ? LinearGradient(
                colors: [c.roleGradientStart, c.roleGradientEnd],
              )
            : null,
        color: highlighted ? null : c.grayBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted ? c.rolePrimary : c.glassBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: highlighted ? Colors.white : c.rolePrimary,
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: highlighted ? Colors.white : c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: highlighted ? Colors.white70 : c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
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
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: c.rolePrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: c.rolePrimary,
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.play_circle_fill,
            color: c.rolePrimary,
            size: 22,
          ),
        ],
      ),
    );
  }
}
