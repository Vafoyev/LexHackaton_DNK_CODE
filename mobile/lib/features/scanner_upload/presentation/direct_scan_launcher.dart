import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/security/file_integrity.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/lex_toast.dart';
import '../../contracts/domain/entities/lex_models.dart';
import '../../contracts/presentation/cubit/contracts_cubit.dart';
import '../../profile/presentation/plans_modal_sheet.dart';
import '../../session/presentation/cubit/session_cubit.dart';

class DirectScanLauncher {
  const DirectScanLauncher._();

  static const MethodChannel _cameraChannel =
      MethodChannel('uz.lexguard/camera');

  static bool _busy = false;

  /// Directly opens the system file/photo picker and runs contract analysis
  /// without any intermediate redundant modal.
  static Future<void> pickFileAndAnalyze(BuildContext context) async {
    if (_busy) return;
    _busy = true;
    try {
      final session = context.read<SessionCubit>();
      final lang = session.state.lang;
      final script = session.state.uzbekScript;

      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['docx', 'pdf', 'txt', 'jpg', 'jpeg', 'png'],
      );
      if (!context.mounted || file == null) return;

      final fileLen = file.lengthSync() ?? await file.length() ?? 0;
      if (!context.mounted) return;
      if (fileLen > FileIntegrity.maxBytes) {
        LexToast.show(
          context,
          AppStrings.t(lang, 'file_too_large', script: script),
          type: LexToastType.warning,
        );
        return;
      }

      final bytes = await file.readAsBytes();
      if (!context.mounted) return;
      if (bytes.isEmpty) {
        LexToast.show(
          context,
          AppStrings.t(lang, 'file_unreadable', script: script),
          type: LexToastType.error,
        );
        return;
      }

      await _analyzeBytes(
        context,
        fileName: file.name,
        bytes: bytes,
        isCameraScan: false,
      );
    } finally {
      _busy = false;
    }
  }

  /// Directly requests camera permission and launches the native Android camera,
  /// then analyzes the captured contract photo.
  static Future<void> captureCameraAndAnalyze(BuildContext context) async {
    if (_busy) return;
    _busy = true;
    try {
      final session = context.read<SessionCubit>();
      final lang = session.state.lang;
      final script = session.state.uzbekScript;

      String? fileName;
      Uint8List? bytes;

      try {
        final raw = await _cameraChannel
            .invokeMapMethod<String, dynamic>('capturePhoto');
        if (!context.mounted || raw == null) return;
        fileName = (raw['name'] as String?) ?? 'camera_scan.jpg';
        final rawBytes = raw['bytes'];
        if (rawBytes is Uint8List) {
          bytes = rawBytes;
        } else if (rawBytes is List<int>) {
          bytes = Uint8List.fromList(rawBytes);
        }
      } on PlatformException catch (e) {
        if (!context.mounted) return;
        final msg = e.code == 'PERMISSION_DENIED'
            ? AppStrings.t(lang, 'camera_permission_denied', script: script)
            : AppStrings.t(lang, 'camera_unavailable', script: script);
        LexToast.show(context, msg, type: LexToastType.warning);
        return;
      } on MissingPluginException {
        // Fallback on non-Android platforms (Desktop / Web)
        final file = await FilePicker.pickFile(type: FileType.image);
        if (!context.mounted || file == null) return;
        fileName = file.name;
        bytes = await file.readAsBytes();
      }

      if (!context.mounted || bytes == null || bytes.isEmpty) return;

      if (bytes.length > FileIntegrity.maxBytes) {
        LexToast.show(
          context,
          AppStrings.t(lang, 'file_too_large', script: script),
          type: LexToastType.warning,
        );
        return;
      }

      await _analyzeBytes(
        context,
        fileName: fileName,
        bytes: bytes,
        isCameraScan: true,
      );
    } finally {
      _busy = false;
    }
  }

  static Future<void> _analyzeBytes(
    BuildContext context, {
    required String fileName,
    required Uint8List bytes,
    required bool isCameraScan,
  }) async {
    final session = context.read<SessionCubit>();
    if (session.state.quota.remainingTotal <= 0) {
      await PlansModalSheet.show(context);
      return;
    }
    final contracts = context.read<ContractsCubit>();
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final lang = session.state.lang;
    final script = session.state.uzbekScript;
    final isBusiness = session.state.segment == AccountSegment.business;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const _AnalyzingOverlay(),
    );

    ContractAnalysis? result;
    try {
      final isIndividual = !isBusiness;
      result = await contracts.runFileAnalysis(
        fileName: fileName,
        bytes: bytes,
        isCameraScan: isCameraScan,
        allowExternalAi: session.state.externalAiConsent,
        hintType: (isIndividual && isCameraScan)
            ? ContractType.realEstateSale
            : ContractType.service,
      );
    } finally {
      if (navigator.canPop()) {
        navigator.pop();
      }
    }

    if (result != null) {
      session.consumeQuota();
      router.push('/analysis/${result.id}');
      if (isBusiness && context.mounted) {
        LexToast.show(
          context,
          AppStrings.t(lang, 'b2b_mon_toast_added', script: script),
          type: LexToastType.success,
        );
      }
    }
  }
}

class _AnalyzingOverlay extends StatelessWidget {
  const _AnalyzingOverlay();

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final contracts = context.watch<ContractsCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;

    final stageText = switch (contracts.stage) {
      AnalysisStage.reading => AppStrings.t(lang, 'stage_1', script: script),
      AnalysisStage.redactingPii =>
        AppStrings.t(lang, 'stage_2', script: script),
      AnalysisStage.checkingRules =>
        AppStrings.t(lang, 'stage_3', script: script),
      AnalysisStage.verifyingSources =>
        AppStrings.t(lang, 'stage_4', script: script),
      _ => '',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          color: Colors.transparent,
          child: GlassCard(
            radius: 26,
            blurSigma: 24,
            tintColor: c.glassFillStrong,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoActivityIndicator(
                  radius: 15,
                  color: c.rolePrimary,
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.t(lang, 'analyzing_title', script: script),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                if (stageText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    stageText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                    ),
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
