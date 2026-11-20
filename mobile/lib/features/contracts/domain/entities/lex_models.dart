import 'package:equatable/equatable.dart';

enum RiskColor { red, yellow, gray, green }

enum VerificationStatus { verified, unverified, reviewRequired, unknown }

enum NeutralityBalance { balanced, heavyPartyA, heavyPartyB }

enum AccountSegment { business, individual }

enum ContractType {
  service,
  supply,
  nonResidentialLease,
  realEstateSale,
  unknown,
}

enum FindingDecision { pending, accepted, dismissed }

class LegalCitation extends Equatable {
  const LegalCitation({
    required this.code,
    required this.title,
    required this.article,
    required this.part,
    required this.normNature,
    required this.effectiveFrom,
    required this.officialUrl,
  });

  final String code;
  final String title;
  final String article;
  final String part;
  final String normNature; // IMPERATIVE / DISPOSITIVE
  final String effectiveFrom;
  final String officialUrl;

  @override
  List<Object?> get props => [
        code,
        title,
        article,
        part,
        normNature,
        effectiveFrom,
        officialUrl,
      ];
}

class ClauseFinding extends Equatable {
  const ClauseFinding({
    required this.id,
    required this.clauseNumber,
    required this.title,
    required this.ruleCode,
    required this.riskColor,
    required this.backendCategory,
    required this.verificationStatus,
    required this.balance,
    required this.balanceLabel,
    required this.originalText,
    required this.explanation,
    required this.suggestedRevision,
    this.citation,
    this.parseLowConfidence = false,
    this.decision = FindingDecision.pending,
    this.actionTag,
  });

  final String id;
  final String clauseNumber;
  final String title;
  final String ruleCode;
  final RiskColor riskColor;
  final String backendCategory; // LEGAL / COMMERCIAL / UNKNOWN / OK
  final VerificationStatus verificationStatus;
  final NeutralityBalance balance;
  final String balanceLabel;
  final String originalText;
  final String explanation;
  final String suggestedRevision;
  final LegalCitation? citation;
  final bool parseLowConfidence;
  final FindingDecision decision;
  final String? actionTag; // NOTARIAL / CLAIM / MEDIATION / LAWYER

  ClauseFinding copyWith({
    FindingDecision? decision,
  }) {
    return ClauseFinding(
      id: id,
      clauseNumber: clauseNumber,
      title: title,
      ruleCode: ruleCode,
      riskColor: riskColor,
      backendCategory: backendCategory,
      verificationStatus: verificationStatus,
      balance: balance,
      balanceLabel: balanceLabel,
      originalText: originalText,
      explanation: explanation,
      suggestedRevision: suggestedRevision,
      citation: citation,
      parseLowConfidence: parseLowConfidence,
      decision: decision ?? this.decision,
      actionTag: actionTag,
    );
  }

  @override
  List<Object?> get props => [
        id,
        clauseNumber,
        title,
        ruleCode,
        riskColor,
        backendCategory,
        verificationStatus,
        balance,
        balanceLabel,
        originalText,
        explanation,
        suggestedRevision,
        citation,
        parseLowConfidence,
        decision,
        actionTag,
      ];
}

class ContractAnalysis extends Equatable {
  const ContractAnalysis({
    required this.id,
    required this.title,
    required this.fileName,
    required this.formatLabel,
    required this.languageLabel,
    required this.contractType,
    required this.contractDate,
    required this.analyzedAt,
    required this.executionMode,
    required this.partyAName,
    required this.partyBName,
    required this.overallBalanceLabel,
    required this.piiMaskedCount,
    required this.piiCategories,
    required this.sha256Short,
    required this.retentionDays,
    required this.findings,
    this.redactedPreview,
  });

  final String id;
  final String title;
  final String fileName;
  final String formatLabel;
  final String languageLabel;
  final ContractType contractType;
  final String contractDate;
  final DateTime analyzedAt;
  final String executionMode; // RULE_ONLY / HYBRID_AI
  final String partyAName;
  final String partyBName;
  final String overallBalanceLabel;
  final int piiMaskedCount;
  final Map<String, int> piiCategories;
  final String sha256Short;
  final int retentionDays; // 7 for trial, 30 for paid
  final List<ClauseFinding> findings;
  final String? redactedPreview;

  int countByColor(RiskColor color) =>
      findings.where((f) => f.riskColor == color).length;

  List<ClauseFinding> get topThreeIssues {
    final sorted = List<ClauseFinding>.from(findings)
      ..sort((a, b) => a.riskColor.index.compareTo(b.riskColor.index));
    return sorted
        .where((f) => f.riskColor != RiskColor.green)
        .take(3)
        .toList(growable: false);
  }

  ContractAnalysis copyWith({List<ClauseFinding>? findings}) {
    return ContractAnalysis(
      id: id,
      title: title,
      fileName: fileName,
      formatLabel: formatLabel,
      languageLabel: languageLabel,
      contractType: contractType,
      contractDate: contractDate,
      analyzedAt: analyzedAt,
      executionMode: executionMode,
      partyAName: partyAName,
      partyBName: partyBName,
      overallBalanceLabel: overallBalanceLabel,
      piiMaskedCount: piiMaskedCount,
      piiCategories: piiCategories,
      sha256Short: sha256Short,
      retentionDays: retentionDays,
      findings: findings ?? this.findings,
      redactedPreview: redactedPreview,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        fileName,
        formatLabel,
        languageLabel,
        contractType,
        contractDate,
        analyzedAt,
        executionMode,
        partyAName,
        partyBName,
        overallBalanceLabel,
        piiMaskedCount,
        piiCategories,
        sha256Short,
        retentionDays,
        findings,
        redactedPreview,
      ];
}

class LegalNorm extends Equatable {
  const LegalNorm({
    required this.id,
    required this.code,
    required this.title,
    required this.article,
    required this.normNature,
    required this.effectiveFrom,
    required this.summary,
    required this.officialUrl,
  });

  final String id;
  final String code;
  final String title;
  final String article;
  final String normNature;
  final String effectiveFrom;
  final String summary;
  final String officialUrl;

  @override
  List<Object?> get props => [
        id,
        code,
        title,
        article,
        normNature,
        effectiveFrom,
        summary,
        officialUrl,
      ];
}

class RuleDescriptor extends Equatable {
  const RuleDescriptor({
    required this.code,
    required this.title,
    required this.scope,
    required this.defaultCategory,
    required this.description,
  });

  final String code;
  final String title;
  final String scope;
  final String defaultCategory;
  final String description;

  @override
  List<Object?> get props => [code, title, scope, defaultCategory, description];
}

class QuotaState extends Equatable {
  const QuotaState({
    required this.planName,
    required this.trialDaysRemaining,
    required this.totalUsed,
    required this.totalLimit,
    required this.todayUsed,
    required this.todayLimit,
  });

  final String planName;
  final int trialDaysRemaining;
  final int totalUsed;
  final int totalLimit;
  final int todayUsed;
  final int todayLimit;

  int get remainingTotal => (totalLimit - totalUsed).clamp(0, totalLimit);
  int get remainingToday => (todayLimit - todayUsed).clamp(0, todayLimit);

  QuotaState incrementUsed() => QuotaState(
        planName: planName,
        trialDaysRemaining: trialDaysRemaining,
        totalUsed: totalUsed + 1,
        totalLimit: totalLimit,
        todayUsed: todayUsed + 1,
        todayLimit: todayLimit,
      );

  @override
  List<Object?> get props => [
        planName,
        trialDaysRemaining,
        totalUsed,
        totalLimit,
        todayUsed,
        todayLimit,
      ];
}

class IntegrationItem extends Equatable {
  const IntegrationItem({
    required this.name,
    required this.statusLabel,
    required this.isMock,
    required this.description,
  });

  final String name;
  final String statusLabel;
  final bool isMock;
  final String description;

  @override
  List<Object?> get props => [name, statusLabel, isMock, description];
}
