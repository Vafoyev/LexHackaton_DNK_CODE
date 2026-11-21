import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../domain/entities/lex_models.dart';
import '../domain/repositories/lexguard_repository.dart';

/// Production HTTP adapter targeting the Go Modular Monolith (`/api/v1`).
/// Matches Go `platform.WriteJSON` envelope (`{"data": ...}`) and async worker flow.
class RemoteLexGuardRepository implements LexGuardRepository {
  RemoteLexGuardRepository(this._client);

  final ApiClient _client;

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  List<dynamic> _unwrapList(dynamic body) {
    final inner = _unwrap(body);
    if (inner is List<dynamic>) return inner;
    if (inner is Map<String, dynamic> && inner['items'] is List<dynamic>) {
      return inner['items'] as List<dynamic>;
    }
    return const [];
  }

  @override
  Future<List<ContractAnalysis>> getAnalyses() async {
    final res = await _client.dio.get<dynamic>('/api/v1/analyses');
    return _unwrapList(res.data)
        .map((e) => _parseAnalysis(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<ContractAnalysis?> getAnalysisById(String id) async {
    final res = await _client.dio.get<dynamic>('/api/v1/analyses/$id');
    final data = _unwrap(res.data);
    if (data is! Map<String, dynamic>) return null;
    return _parseAnalysis(data);
  }

  @override
  Future<ContractAnalysis> analyzeDemoSample(
    String sampleId, {
    required bool allowExternalAi,
  }) async {
    final res = await _client.dio.get<dynamic>('/api/v1/mock/analysis-sample');
    final data = _unwrap(res.data);
    if (data is Map<String, dynamic>) {
      return _parseAnalysis(data);
    }
    throw StateError('Demo tahlil natijasini olib bo‘lmadi.');
  }

  @override
  Future<ContractAnalysis> analyzeUploadedFile({
    required String fileName,
    required Uint8List bytes,
    required bool isCameraScan,
    required bool allowExternalAi,
    required ContractType hintType,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      'is_camera_scan': isCameraScan,
      'doc_type': _backendDocType(hintType),
    });
    final uploadRes = await _client.dio.post<dynamic>(
      '/api/v1/documents',
      data: form,
    );
    final uploadData = _unwrap(uploadRes.data) as Map<String, dynamic>? ?? {};
    final docId = (uploadData['id'] ?? uploadData['document_version_id'] ?? '')
        .toString();
    if (docId.isEmpty) {
      throw StateError('Hujjat yuklandi, ammo ID qaytmadi.');
    }

    final createRes = await _client.dio.post<dynamic>(
      '/api/v1/analyses',
      data: {
        'document_id': docId,
        'doc_type': _backendDocType(hintType),
        'execution_mode': allowExternalAi ? 'HYBRID_AI' : 'RULE_ONLY',
      },
    );
    final created = _unwrap(createRes.data) as Map<String, dynamic>? ?? {};
    final analysisId =
        (created['analysis_id'] ?? created['id'] ?? '').toString();
    if (analysisId.isEmpty) {
      return _parseAnalysis(created);
    }

    // Poll async Go WorkerPool (FOR UPDATE SKIP LOCKED) until COMPLETED or FAILED
    for (int attempt = 0; attempt < 25; attempt++) {
      final detail = await getAnalysisById(analysisId);
      if (detail != null) {
        final rawStatus = (created['status'] ?? '').toString().toUpperCase();
        if (detail.findings.isNotEmpty ||
            (attempt >= 2 && rawStatus != 'PENDING')) {
          return detail;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }

    final finalDetail = await getAnalysisById(analysisId);
    if (finalDetail != null) return finalDetail;
    throw StateError('Tahlil yakunlanishini kutish muddati tugadi.');
  }

  @override
  Future<ContractAnalysis> toggleFindingDecision({
    required String analysisId,
    required String findingId,
    required FindingDecision decision,
  }) async {
    await _client.dio.post<void>(
      '/api/v1/analyses/$analysisId/findings/$findingId/decision',
      data: {'decision': decision.name.toUpperCase()},
    );
    final updated = await getAnalysisById(analysisId);
    if (updated == null) {
      throw StateError('Tahlil topilmadi: $analysisId');
    }
    return updated;
  }

  @override
  Future<void> deleteAnalysis(String id) async {
    await _client.dio.delete<void>('/api/v1/documents/$id');
  }

  @override
  Future<List<LegalNorm>> getLegalNorms() async {
    final res = await _client.dio.get<dynamic>('/api/v1/legal-sources');
    return _unwrapList(res.data).map((e) {
      final m = e as Map<String, dynamic>;
      return LegalNorm(
        id: m['id'] as String? ?? '',
        code: m['code'] as String? ?? 'LEX-UZ',
        title: m['title'] as String? ?? '',
        article: (m['article'] ?? m['article_number'] ?? '').toString(),
        normNature: m['norm_nature'] as String? ?? 'DISPOSITIVE',
        effectiveFrom: m['effective_from'] as String? ?? '',
        summary: (m['summary'] ?? m['description'] ?? '').toString(),
        officialUrl: m['official_url'] as String? ?? 'https://lex.uz/',
      );
    }).toList(growable: false);
  }

  @override
  Future<List<RuleDescriptor>> getRules() async {
    final res = await _client.dio.get<dynamic>('/api/v1/rules');
    return _unwrapList(res.data).map((e) {
      final m = e as Map<String, dynamic>;
      return RuleDescriptor(
        code: m['code'] as String? ?? '',
        title: (m['name'] ?? m['title'] ?? '').toString(),
        scope: (m['category'] ?? m['scope'] ?? '').toString(),
        defaultCategory:
            (m['severity'] ?? m['default_category'] ?? '').toString(),
        description: (m['description'] ?? m['name'] ?? '').toString(),
      );
    }).toList(growable: false);
  }

  @override
  Future<List<IntegrationItem>> getIntegrationStatuses() async {
    final res = await _client.dio.get<dynamic>('/api/v1/integrations/status');
    return _unwrapList(res.data).map((e) {
      final m = e as Map<String, dynamic>;
      final mode = (m['mode'] ?? m['status'] ?? 'MOCK').toString();
      return IntegrationItem(
        name: m['name'] as String? ?? '',
        statusLabel: mode,
        isMock: mode.toUpperCase().contains('MOCK'),
        description: (m['description'] ?? '').toString(),
      );
    }).toList(growable: false);
  }

  String _backendDocType(ContractType type) => switch (type) {
        ContractType.service => 'SERVICE_AGREEMENT',
        ContractType.supply => 'SUPPLY_AGREEMENT',
        ContractType.nonResidentialLease => 'LEASE_AGREEMENT',
        ContractType.realEstateSale => 'REAL_ESTATE_SALE',
        ContractType.unknown => 'UNKNOWN',
      };

  ContractType _parseContractType(String raw) {
    final u = raw.toUpperCase();
    if (u.contains('LEASE') || u.contains('IJARA')) {
      return ContractType.nonResidentialLease;
    }
    if (u.contains('SUPPLY') || u.contains('YETKAZIB')) {
      return ContractType.supply;
    }
    if (u.contains('REAL_ESTATE') || u.contains('NOTAR')) {
      return ContractType.realEstateSale;
    }
    return ContractType.service;
  }

  ContractAnalysis _parseAnalysis(Map<String, dynamic> m) {
    final summary = m['summary'] as Map<String, dynamic>? ?? const {};
    final rawFindings = (m['findings'] as List<dynamic>? ?? const []);
    final fileName =
        (m['filename'] ?? m['file_name'] ?? 'shartnoma.docx').toString();
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toUpperCase()
        : 'DOCX';
    final sha = (m['sha256'] ?? m['sha256_short'] ?? '').toString();
    final shaShort = sha.length > 12 ? sha.substring(0, 12) : sha;

    return ContractAnalysis(
      id: (m['id'] ?? '').toString(),
      title: (m['title'] ?? fileName.replaceAll(RegExp(r'\.[^.]+$'), ''))
          .toString(),
      fileName: fileName,
      formatLabel: (m['format'] ?? ext).toString(),
      languageLabel: (m['language'] ?? 'UZ').toString(),
      contractType: _parseContractType((m['doc_type'] ?? '').toString()),
      contractDate: (m['contract_date'] ?? '2026-11-21').toString(),
      analyzedAt: DateTime.tryParse(
            (m['completed_at'] ?? m['created_at'] ?? m['analyzed_at'] ?? '')
                .toString(),
          ) ??
          DateTime.now(),
      executionMode: (m['execution_mode'] ?? 'HYBRID_AI').toString(),
      partyAName: (m['party_a'] ?? 'Buyurtmachi').toString(),
      partyBName: (m['party_b'] ?? 'Ijrochi').toString(),
      overallBalanceLabel:
          (summary['balance_label'] ?? m['balance_label'] ?? 'Muvozanatli')
              .toString(),
      piiMaskedCount:
          (summary['pii_masked'] ?? m['pii_masked'] ?? 0) as int? ?? 0,
      piiCategories: const {},
      sha256Short: shaShort,
      retentionDays: (m['retention_days'] ?? 30) as int? ?? 30,
      findings: rawFindings.map((item) {
        final f = item as Map<String, dynamic>;
        final sev =
            (f['severity'] ?? f['risk_level'] ?? 'GRAY').toString().toUpperCase();
        final vStatusRaw =
            (f['verification_status'] ?? 'VERIFIED').toString().toUpperCase();
        final vStatus = switch (vStatusRaw) {
          'VERIFIED' => VerificationStatus.verified,
          'REVIEW_REQUIRED' => VerificationStatus.reviewRequired,
          'UNVERIFIED' => VerificationStatus.unverified,
          _ => VerificationStatus.unknown,
        };
        final color = (vStatus == VerificationStatus.unknown ||
                vStatus == VerificationStatus.unverified)
            ? RiskColor.gray
            : switch (sev) {
                'RED' => RiskColor.red,
                'YELLOW' => RiskColor.yellow,
                'GREEN' => RiskColor.green,
                _ => RiskColor.gray,
              };
        final src = f['legal_source'] as Map<String, dynamic>?;
        final citation = src != null && (src['article'] ?? '').toString().isNotEmpty
            ? LegalCitation(
                code: (src['code'] ?? 'FK-UZ').toString(),
                title: (src['code'] ?? 'O‘zbekiston qonunchiligi').toString(),
                article: (src['article'] ?? '').toString(),
                part: '1-qism',
                normNature: (src['norm_nature'] ?? 'IMPERATIVE').toString(),
                effectiveFrom: '2026-01-01',
                officialUrl:
                    (src['official_url'] ?? 'https://lex.uz').toString(),
              )
            : null;
        return ClauseFinding(
          id: (f['id'] ?? '').toString(),
          clauseNumber: (f['clause_number'] ?? '—').toString(),
          title: (f['issue_title'] ?? f['title'] ?? f['rule_code'] ?? '')
              .toString(),
          ruleCode: (f['rule_code'] ?? '').toString(),
          riskColor: color,
          backendCategory: (f['risk_category'] ?? 'UNKNOWN').toString(),
          verificationStatus: vStatus,
          balance: NeutralityBalance.balanced,
          balanceLabel: (f['balance_label'] ?? 'Muvozanatli').toString(),
          originalText:
              (f['original_quote'] ?? f['problematic_quote'] ?? '').toString(),
          explanation:
              (f['explanation'] ?? f['issue_explanation'] ?? '').toString(),
          suggestedRevision:
              (f['suggested_revision'] ?? f['suggested_redline'] ?? '')
                  .toString(),
          citation: citation,
        );
      }).toList(growable: false),
    );
  }
}
