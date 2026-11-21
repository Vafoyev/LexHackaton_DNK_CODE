import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexguard_mobile/core/network/api_client.dart';
import 'package:lexguard_mobile/core/security/screen_security.dart';
import 'package:lexguard_mobile/features/contracts/data/remote_lexguard_repository.dart';
import 'package:lexguard_mobile/features/contracts/domain/entities/lex_models.dart';

class _MockHttpAdapter implements HttpClientAdapter {
  _MockHttpAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(dynamic data, {int statusCode = 200}) {
  final raw = jsonEncode(data);
  return ResponseBody.fromString(
    raw,
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  group('RemoteLexGuardRepository API Routes', () {
    late ApiClient client;
    late RemoteLexGuardRepository repo;
    late RequestOptions lastRequest;

    setUp(() {
      client = ApiClient(tokenStore: SecureTokenStore());
      repo = RemoteLexGuardRepository(client);
    });

    test('getAnalyses correctly parses direct JSON List from /api/v1/analyses',
        () async {
      client.dio.httpClientAdapter = _MockHttpAdapter((options) async {
        lastRequest = options;
        return _jsonResponse([
          {
            'id': 'analysis-001',
            'filename': 'it_xizmat.docx',
            'contract_date': '2026-11-21',
            'balance_label': 'Muvozanatli',
            'findings': [
              {
                'id': 'f-01',
                'clause_number': '7.3',
                'issue_title': 'Bir tomonlama bekor qilish',
                'rule_id': 'SVC_UNILATERAL_TERMINATION',
                'severity': 'RED',
                'original_quote': 'Ogohlantirmasdan bekor qilish',
                'suggested_redline': '15 kun oldin ogohlantirish',
              }
            ],
          }
        ]);
      });

      final list = await repo.getAnalyses();
      expect(lastRequest.path, '/api/v1/analyses');
      expect(list.length, 1);
      expect(list.first.id, 'analysis-001');
      expect(list.first.findings.length, 1);
      expect(list.first.findings.first.riskColor, RiskColor.red);
      expect(list.first.findings.first.title, 'Bir tomonlama bekor qilish');
    });

    test('getLegalNorms correctly handles direct List from /api/v1/legal-sources',
        () async {
      client.dio.httpClientAdapter = _MockHttpAdapter((options) async {
        lastRequest = options;
        return _jsonResponse([
          {
            'id': 'fk-707',
            'code': 'FK',
            'article': '707-modda',
            'title': 'Haq evaziga xizmat',
            'norm_nature': 'IMPERATIVE',
            'lex_uz_url': 'https://lex.uz/docs/111181',
          }
        ]);
      });

      final norms = await repo.getLegalNorms();
      expect(lastRequest.path, '/api/v1/legal-sources');
      expect(norms.length, 1);
      expect(norms.first.article, '707-modda');
      expect(norms.first.officialUrl, 'https://lex.uz/docs/111181');
    });

    test('getRules correctly handles direct List from /api/v1/rules',
        () async {
      client.dio.httpClientAdapter = _MockHttpAdapter((options) async {
        lastRequest = options;
        return _jsonResponse([
          {
            'code': 'R1_FK707',
            'name': 'Bir tomonlama bekor qilishni cheklash',
            'category': 'LEGAL',
            'severity': 'RED',
          }
        ]);
      });

      final rules = await repo.getRules();
      expect(lastRequest.path, '/api/v1/rules');
      expect(rules.length, 1);
      expect(rules.first.code, 'R1_FK707');
      expect(rules.first.title, 'Bir tomonlama bekor qilishni cheklash');
    });

    test('getIntegrationStatuses correctly parses /api/v1/integrations/status',
        () async {
      client.dio.httpClientAdapter = _MockHttpAdapter((options) async {
        lastRequest = options;
        return _jsonResponse([
          {
            'name': 'E-IMZO Soliq',
            'mode': 'MOCK',
            'is_healthy': true,
          }
        ]);
      });

      final items = await repo.getIntegrationStatuses();
      expect(lastRequest.path, '/api/v1/integrations/status');
      expect(items.length, 1);
      expect(items.first.name, 'E-IMZO Soliq');
      expect(items.first.isMock, isTrue);
    });

    test('analyzeDemoSample posts sample_id and handles sync response',
        () async {
      client.dio.httpClientAdapter = _MockHttpAdapter((options) async {
        lastRequest = options;
        return _jsonResponse({
          'id': 'demo-analysis-99',
          'filename': 'IT_Xizmat_Shartnomasi.docx',
          'findings': [
            {
              'id': 'f-99',
              'clause_number': '4.2',
              'severity': 'YELLOW',
              'title': 'Nomutanosib penya',
            }
          ]
        });
      });

      final result = await repo.analyzeDemoSample(
        'sample_b2b_service',
        allowExternalAi: true,
      );

      expect(lastRequest.path, '/api/v1/analyses');
      expect(lastRequest.data['sample_id'], 'sample_b2b_service');
      expect(result.id, 'demo-analysis-99');
      expect(result.findings.first.riskColor, RiskColor.yellow);
    });

    test('analyzeUploadedFile posts document then analyses with correct document_id',
        () async {
      int step = 0;
      client.dio.httpClientAdapter = _MockHttpAdapter((options) async {
        if (options.path == '/api/v1/documents') {
          step = 1;
          return _jsonResponse({'id': 'doc-uuid-12345'});
        } else if (options.path == '/api/v1/analyses') {
          step = 2;
          expect(options.data['document_id'], 'doc-uuid-12345');
          return _jsonResponse({
            'id': 'analysis-uuid-67890',
            'filename': 'test.docx',
            'findings': [
              {
                'id': 'f-01',
                'severity': 'GREEN',
                'title': 'Xavfsiz band',
              }
            ]
          });
        }
        throw UnimplementedError();
      });

      final result = await repo.analyzeUploadedFile(
        fileName: 'test.docx',
        bytes: Uint8List.fromList([1, 2, 3]),
        isCameraScan: false,
        allowExternalAi: true,
        hintType: ContractType.service,
      );

      expect(step, 2);
      expect(result.id, 'analysis-uuid-67890');
      expect(result.findings.first.riskColor, RiskColor.green);
    });

    test('toggleFindingDecision posts uppercase decision to correct finding endpoint',
        () async {
      String? decisionPath;
      String? sentDecision;

      client.dio.httpClientAdapter = _MockHttpAdapter((options) async {
        if (options.path.contains('/decision')) {
          decisionPath = options.path;
          sentDecision = options.data['decision'];
          return _jsonResponse({'status': 'ok'});
        } else if (options.path == '/api/v1/analyses/analysis-123') {
          return _jsonResponse({
            'id': 'analysis-123',
            'filename': 'doc.docx',
            'findings': []
          });
        }
        throw UnimplementedError();
      });

      await repo.toggleFindingDecision(
        analysisId: 'analysis-123',
        findingId: 'f-456',
        decision: FindingDecision.accepted,
      );

      expect(decisionPath, '/api/v1/analyses/analysis-123/findings/f-456/decision');
      expect(sentDecision, 'ACCEPTED');
    });
  });
}
