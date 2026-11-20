import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/lex_models.dart';
import '../../domain/repositories/lexguard_repository.dart';

enum AnalysisStage {
  idle,
  reading,
  redactingPii,
  checkingRules,
  verifyingSources,
  completed,
  error,
}

class ContractsState extends Equatable {
  const ContractsState({
    this.loading = false,
    this.analyses = const [],
    this.legalNorms = const [],
    this.rules = const [],
    this.integrations = const [],
    this.stage = AnalysisStage.idle,
    this.lastCompletedId,
    this.errorMessage,
    this.searchQuery = '',
    this.typeFilter,
  });

  final bool loading;
  final List<ContractAnalysis> analyses;
  final List<LegalNorm> legalNorms;
  final List<RuleDescriptor> rules;
  final List<IntegrationItem> integrations;
  final AnalysisStage stage;
  final String? lastCompletedId;
  final String? errorMessage;
  final String searchQuery;
  final ContractType? typeFilter;

  List<ContractAnalysis> get filteredAnalyses {
    return analyses.where((item) {
      final matchesType =
          typeFilter == null || item.contractType == typeFilter;
      final q = searchQuery.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          item.title.toLowerCase().contains(q) ||
          item.fileName.toLowerCase().contains(q);
      return matchesType && matchesQuery;
    }).toList(growable: false);
  }

  ContractAnalysis? findById(String id) {
    for (final item in analyses) {
      if (item.id == id) return item;
    }
    return null;
  }

  ContractsState copyWith({
    bool? loading,
    List<ContractAnalysis>? analyses,
    List<LegalNorm>? legalNorms,
    List<RuleDescriptor>? rules,
    List<IntegrationItem>? integrations,
    AnalysisStage? stage,
    String? lastCompletedId,
    String? errorMessage,
    String? searchQuery,
    ContractType? typeFilter,
    bool clearTypeFilter = false,
    bool clearError = false,
  }) {
    return ContractsState(
      loading: loading ?? this.loading,
      analyses: analyses ?? this.analyses,
      legalNorms: legalNorms ?? this.legalNorms,
      rules: rules ?? this.rules,
      integrations: integrations ?? this.integrations,
      stage: stage ?? this.stage,
      lastCompletedId: lastCompletedId ?? this.lastCompletedId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
    );
  }

  @override
  List<Object?> get props => [
        loading,
        analyses,
        legalNorms,
        rules,
        integrations,
        stage,
        lastCompletedId,
        errorMessage,
        searchQuery,
        typeFilter,
      ];
}

class ContractsCubit extends Cubit<ContractsState> {
  ContractsCubit(this._repo) : super(const ContractsState());

  final LexGuardRepository _repo;

  Future<void> bootstrap() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final results = await Future.wait([
        _repo.getAnalyses(),
        _repo.getLegalNorms(),
        _repo.getRules(),
        _repo.getIntegrationStatuses(),
      ]);
      emit(
        state.copyWith(
          loading: false,
          analyses: results[0] as List<ContractAnalysis>,
          legalNorms: results[1] as List<LegalNorm>,
          rules: results[2] as List<RuleDescriptor>,
          integrations: results[3] as List<IntegrationItem>,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, errorMessage: e.toString()));
    }
  }

  Future<ContractAnalysis?> runDemoAnalysis(
    String sampleId, {
    required bool allowExternalAi,
    Duration stepDelay = const Duration(milliseconds: 220),
  }) async {
    try {
      emit(state.copyWith(stage: AnalysisStage.reading, clearError: true));
      await Future<void>.delayed(stepDelay);
      emit(state.copyWith(stage: AnalysisStage.redactingPii));
      await Future<void>.delayed(stepDelay);
      emit(state.copyWith(stage: AnalysisStage.checkingRules));
      await Future<void>.delayed(stepDelay);
      emit(state.copyWith(stage: AnalysisStage.verifyingSources));
      final analysis = await _repo.analyzeDemoSample(
        sampleId,
        allowExternalAi: allowExternalAi,
      );
      final updated = await _repo.getAnalyses();
      emit(
        state.copyWith(
          analyses: updated,
          stage: AnalysisStage.completed,
          lastCompletedId: analysis.id,
        ),
      );
      return analysis;
    } catch (e) {
      emit(
        state.copyWith(
          stage: AnalysisStage.error,
          errorMessage: e.toString(),
        ),
      );
      return null;
    }
  }

  Future<ContractAnalysis?> runFileAnalysis({
    required String fileName,
    required Uint8List bytes,
    required bool isCameraScan,
    required bool allowExternalAi,
    ContractType hintType = ContractType.service,
    Duration stepDelay = const Duration(milliseconds: 180),
  }) async {
    try {
      emit(state.copyWith(stage: AnalysisStage.reading, clearError: true));
      await Future<void>.delayed(stepDelay);
      emit(state.copyWith(stage: AnalysisStage.redactingPii));
      await Future<void>.delayed(stepDelay);
      emit(state.copyWith(stage: AnalysisStage.checkingRules));
      await Future<void>.delayed(stepDelay);
      emit(state.copyWith(stage: AnalysisStage.verifyingSources));
      final analysis = await _repo.analyzeUploadedFile(
        fileName: fileName,
        bytes: bytes,
        isCameraScan: isCameraScan,
        allowExternalAi: allowExternalAi,
        hintType: hintType,
      );
      final updated = await _repo.getAnalyses();
      emit(
        state.copyWith(
          analyses: updated,
          stage: AnalysisStage.completed,
          lastCompletedId: analysis.id,
        ),
      );
      return analysis;
    } catch (e) {
      emit(
        state.copyWith(
          stage: AnalysisStage.error,
          errorMessage: e.toString(),
        ),
      );
      return null;
    }
  }

  void resetStage() {
    emit(state.copyWith(stage: AnalysisStage.idle, clearError: true));
  }

  Future<void> setFindingDecision({
    required String analysisId,
    required String findingId,
    required FindingDecision decision,
  }) async {
    final updatedItem = await _repo.toggleFindingDecision(
      analysisId: analysisId,
      findingId: findingId,
      decision: decision,
    );
    final nextList = state.analyses
        .map((a) => a.id == analysisId ? updatedItem : a)
        .toList(growable: false);
    emit(state.copyWith(analyses: nextList));
  }

  Future<void> deleteAnalysis(String id) async {
    await _repo.deleteAnalysis(id);
    final updated = await _repo.getAnalyses();
    emit(state.copyWith(analyses: updated));
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  void setTypeFilter(ContractType? type) {
    if (type == null) {
      emit(state.copyWith(clearTypeFilter: true));
    } else {
      emit(state.copyWith(typeFilter: type));
    }
  }
}
