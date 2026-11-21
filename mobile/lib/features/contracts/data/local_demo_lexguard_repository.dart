import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/security/file_integrity.dart';
import '../../../../core/security/pii_redactor.dart';
import '../domain/entities/lex_models.dart';
import '../domain/repositories/lexguard_repository.dart';

class LocalDemoLexGuardRepository implements LexGuardRepository {
  LocalDemoLexGuardRepository() {
    _analyses.addAll([
      _buildSampleServiceAgreement(
        id: 'ana_service_01',
        allowExternalAi: true,
        analyzedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      _buildSampleNotarialSale(
        id: 'ana_notarial_02',
        allowExternalAi: false,
        analyzedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);
  }

  final List<ContractAnalysis> _analyses = [];

  @override
  Future<List<ContractAnalysis>> getAnalyses() async {
    return List.unmodifiable(_analyses);
  }

  @override
  Future<ContractAnalysis?> getAnalysisById(String id) async {
    for (final item in _analyses) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<ContractAnalysis> analyzeDemoSample(
    String sampleId, {
    required bool allowExternalAi,
  }) async {
    final now = DateTime.now();
    final uniqueId = 'ana_${now.microsecondsSinceEpoch}';
    final ContractAnalysis result;

    switch (sampleId) {
      case 'sample_notarial_r6':
        result = _buildSampleNotarialSale(
          id: uniqueId,
          allowExternalAi: allowExternalAi,
          analyzedAt: now,
        );
      case 'sample_supply_ru':
        result = _buildSampleSupplyRu(
          id: uniqueId,
          allowExternalAi: allowExternalAi,
          analyzedAt: now,
        );
      case 'sample_b2b_service':
      default:
        result = _buildSampleServiceAgreement(
          id: uniqueId,
          allowExternalAi: allowExternalAi,
          analyzedAt: now,
        );
    }

    _analyses.insert(0, result);
    return result;
  }

  @override
  Future<ContractAnalysis> analyzeUploadedFile({
    required String fileName,
    required Uint8List bytes,
    required bool isCameraScan,
    required bool allowExternalAi,
    required ContractType hintType,
  }) async {
    if (bytes.length > FileIntegrity.maxBytes) {
      throw const FormatException('Fayl hajmi 10 MB limitidan oshib ketdi.');
    }
    if (!FileIntegrity.isSupportedExtension(fileName)) {
      throw const FormatException(
        'Qo‘llab-quvvatlanadigan formatlar: DOCX, PDF, TXT, JPG, PNG.',
      );
    }

    final shaHex = await FileIntegrity.computeSha256Async(bytes);
    final rawText = utf8.decode(bytes, allowMalformed: true);
    final redaction = await PiiRedactor.redactAsync(rawText);
    final lower = redaction.redactedText.toLowerCase();

    final findings = <ClauseFinding>[];
    final ext = fileName.split('.').last.toUpperCase();

    // R6: Mandatory notarial signal check
    final looksRealEstate = hintType == ContractType.realEstateSale ||
        lower.contains('kvartira') ||
        lower.contains('uy-joy') ||
        lower.contains('ko‘chmas mulk') ||
        lower.contains('недвижимост');
    final hasNotaryEvidence = lower.contains('notarius') ||
        lower.contains('reestr') ||
        lower.contains('нотариус');

    if (looksRealEstate && !hasNotaryEvidence) {
      findings.add(
        const ClauseFinding(
          id: 'f_notarial_auto',
          clauseNumber: 'Shakl',
          title: 'Notarial tasdiq qo‘yilmagan',
          ruleCode: 'R6_NOTARIAL_FORM',
          riskColor: RiskColor.red,
          backendCategory: 'LEGAL',
          verificationStatus: VerificationStatus.verified,
          balance: NeutralityBalance.balanced,
          balanceLabel: 'Qonun talabi',
          originalText:
              'Taraflar uy-joy oldi-sotdisini oddiy yozma shaklda o‘zaro imzolab yakunlaydilar.',
          explanation:
              'Uy-joy va ko‘chmas mulk oldi-sotdisi notariusda tasdiqlanmasa, shartnoma yuridik kuchga kirmaydi.',
          suggestedRevision:
              'Ushbu shartnoma notarius tomonidan tasdiqlangach va davlat reyestridan o‘tkazilgach kuchga kiradi.',
          citation: LegalCitation(
            code: 'FK',
            title: 'Fuqarolik kodeksi',
            article: 'FK 110–112-modda',
            part: '1-qism',
            normNature: 'IMPERATIVE',
            effectiveFrom: '1997-03-01',
            officialUrl: 'https://lex.uz/uz/acts/-111189',
          ),
          actionTag: 'NOTARIAL',
        ),
      );
    }

    // R1: Payment terms
    findings.add(
      ClauseFinding(
        id: 'f_r1_auto',
        clauseNumber: '2.1',
        title: 'To‘lov muddati aniq emas',
        ruleCode: 'R1_PAYMENT_TERMS',
        riskColor: RiskColor.yellow,
        backendCategory: 'COMMERCIAL',
        verificationStatus: VerificationStatus.verified,
        balance: NeutralityBalance.heavyPartyB,
        balanceLabel: 'Bir tarafga og‘ir',
        originalText:
            'To‘lov kelishuvga ko‘ra amalga oshiriladi, kechikish holatida javobgarlik belgilanmagan.',
        explanation:
            'Aniq muddat qo‘yilmasa, to‘lov kechikganda pulni o‘z vaqtida undirish qiyinlashadi.',
        suggestedRevision:
            'To‘lov shartnoma imzolangandan so‘ng 5 bank ish kuni ichida to‘liq o‘tkaziladi.',
        citation: const LegalCitation(
          code: 'FK',
          title: 'Fuqarolik kodeksi',
          article: 'FK 705-modda',
          part: '1-qism',
          normNature: 'DISPOSITIVE',
          effectiveFrom: '1997-03-01',
          officialUrl: 'https://lex.uz/uz/acts/-180552',
        ),
      ),
    );

    // R5: Mediation & Dispute resolution
    if (!lower.contains('mediatsiya') && !lower.contains('медиац')) {
      findings.add(
        const ClauseFinding(
          id: 'f_r5_auto',
          clauseNumber: '5.1',
          title: 'Nizoni tinch hal qilish bandi yo‘q',
          ruleCode: 'R5_DISPUTE_MEDIATION',
          riskColor: RiskColor.yellow,
          backendCategory: 'COMMERCIAL',
          verificationStatus: VerificationStatus.verified,
          balance: NeutralityBalance.balanced,
          balanceLabel: 'Muvozanatli',
          originalText:
              'Barcha kelishmovchiliklar to‘g‘ridan-to‘g‘ri sud tartibida ko‘rib chiqiladi.',
          explanation:
              'Sudgacha 10 kunlik yozma ogohlantirish va mediatsiya qo‘shilsa, ortiqcha sud xarajati tejaladi.',
          suggestedRevision:
              'Nizolar avval 10 kun ichida o‘zaro muzokara va mediatsiya orqali, hal bo‘lmasa sudda ko‘riladi.',
          citation: LegalCitation(
            code: 'Mediatsiya',
            title: 'Mediatsiya qonuni',
            article: '16-modda',
            part: '2-qism',
            normNature: 'DISPOSITIVE',
            effectiveFrom: '2019-01-01',
            officialUrl: 'https://lex.uz/uz/docs/-3805227',
          ),
          actionTag: 'MEDIATION',
        ),
      );
    }

    // Green verified clause
    findings.add(
      const ClauseFinding(
        id: 'f_green_auto',
        clauseNumber: '1.1',
        title: 'Taraflar va sana to‘g‘ri yozilgan',
        ruleCode: 'CORE_METADATA_OK',
        riskColor: RiskColor.green,
        backendCategory: 'OK',
        verificationStatus: VerificationStatus.verified,
        balance: NeutralityBalance.balanced,
        balanceLabel: 'Muvozanatli',
        originalText:
            'Shartnoma taraflari, sanasi va asosiy predmeti aniq ko‘rsatilgan.',
        explanation: 'Bu bandda muammo topilmadi.',
        suggestedRevision: 'O‘zgartirish kerak emas.',
        citation: LegalCitation(
          code: 'FK',
          title: 'Fuqarolik kodeksi',
          article: 'FK 364-modda',
          part: '1-qism',
          normNature: 'DISPOSITIVE',
          effectiveFrom: '1997-03-01',
          officialUrl: 'https://lex.uz/uz/acts/-111189',
        ),
      ),
    );

    final preview = redaction.redactedText.trim().isEmpty
        ? '[Binar fayl: $ext, ${bytes.length} bayt, SHA-256: ${shaHex.substring(0, 12)}...]'
        : redaction.redactedText.substring(
            0,
            redaction.redactedText.length.clamp(0, 260),
          );

    final cleanTitle = isCameraScan
        ? (looksRealEstate
            ? 'Uy-joy oldi-sotdi shartnomasi'
            : 'Skanerlangan shartnoma')
        : fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

    final analysis = ContractAnalysis(
      id: 'ana_${DateTime.now().microsecondsSinceEpoch}',
      title: cleanTitle,
      fileName: fileName,
      formatLabel: isCameraScan ? 'KAMERA/$ext' : ext,
      languageLabel: 'UZ-Lotin',
      contractType:
          looksRealEstate ? ContractType.realEstateSale : hintType,
      contractDate: DateTime.now().toIso8601String().substring(0, 10),
      analyzedAt: DateTime.now(),
      executionMode: allowExternalAi ? 'HYBRID_AI (Redacted)' : 'RULE_ONLY',
      partyAName: 'Buyurtmachi',
      partyBName: 'Ijrochi',
      overallBalanceLabel: 'Buyurtmachi foydasiga moyil',
      piiMaskedCount: redaction.maskedCount,
      piiCategories: redaction.categories,
      sha256Short: shaHex.substring(0, 12),
      retentionDays: 7,
      findings: findings,
      redactedPreview: preview,
    );

    _analyses.insert(0, analysis);
    return analysis;
  }

  @override
  Future<ContractAnalysis> toggleFindingDecision({
    required String analysisId,
    required String findingId,
    required FindingDecision decision,
  }) async {
    final idx = _analyses.indexWhere((a) => a.id == analysisId);
    if (idx < 0) {
      throw StateError('Tahlil topilmadi: $analysisId');
    }
    final target = _analyses[idx];
    final updatedFindings = target.findings
        .map((f) => f.id == findingId ? f.copyWith(decision: decision) : f)
        .toList(growable: false);
    final updated = target.copyWith(findings: updatedFindings);
    _analyses[idx] = updated;
    return updated;
  }

  @override
  Future<void> deleteAnalysis(String id) async {
    _analyses.removeWhere((a) => a.id == id);
  }

  @override
  Future<List<LegalNorm>> getLegalNorms() async => _curatedNorms;

  @override
  Future<List<RuleDescriptor>> getRules() async => _mvpRules;

  @override
  Future<List<IntegrationItem>> getIntegrationStatuses() async => _integrations;

  ContractAnalysis _buildSampleServiceAgreement({
    required String id,
    required bool allowExternalAi,
    required DateTime analyzedAt,
  }) {
    const sampleRaw =
        'Buyurtmachi "Alfa Savdo MChJ" (STIR: 301234567, hisob: 20208000100123456789) '
        'va Ijrochi Aliyev V. (JSHSHIR 31205941234567, tel: +998901234567, email: info@alfa.uz).';
    final redacted = redactUzbekPiiSync(sampleRaw);

    return ContractAnalysis(
      id: id,
      title: 'IT va konsalting xizmat ko‘rsatish shartnomasi №42',
      fileName: 'xizmat_shartnomasi_42.docx',
      formatLabel: 'DOCX',
      languageLabel: 'UZ-Lotin',
      contractType: ContractType.service,
      contractDate: '2026-11-21',
      analyzedAt: analyzedAt,
      executionMode: allowExternalAi ? 'HYBRID_AI' : 'RULE_ONLY',
      partyAName: 'Alfa Savdo MChJ (Buyurtmachi)',
      partyBName: 'Digital Tech YaTT (Ijrochi)',
      overallBalanceLabel: 'Ijrochiga og‘ir (3 ta band)',
      piiMaskedCount: redacted.maskedCount,
      piiCategories: redacted.categories,
      sha256Short: '9f84b2c1a014',
      retentionDays: 7,
      redactedPreview: redacted.redactedText,
      findings: const [
        ClauseFinding(
          id: 'f_svc_1',
          clauseNumber: '4.2',
          title: 'Xarajatlarni qoplamasdan bir tomonlama bekor qilish',
          ruleCode: 'R4_UNILATERAL_TERMINATION',
          riskColor: RiskColor.red,
          backendCategory: 'LEGAL',
          verificationStatus: VerificationStatus.verified,
          balance: NeutralityBalance.heavyPartyB,
          balanceLabel: 'Ijrochiga og‘ir',
          originalText:
              'Buyurtmachi istalgan vaqtda ogohlantirmasdan va hech qanday to‘lovsiz shartnomani bir tomonlama bekor qilishga haqli.',
          explanation:
              'Fuqarolik kodeksining 707-moddasiga ko‘ra, buyurtmachi shartnomani bekor qilganda ijrochi amalda qilgan xarajatlarni to‘lab berishi shart.',
          suggestedRevision:
              'Buyurtmachi 10 kalendar kun oldin yozma ogohlantirib, Ijrochi amalda bajargan ishlar va hujjatlashtirilgan xarajatlarni qoplagan holda shartnomani bekor qilishi mumkin.',
          citation: LegalCitation(
            code: 'FK-UZ',
            title: 'O‘zbekiston Respublikasi Fuqarolik kodeksi',
            article: '707-modda',
            part: '1-qism',
            normNature: 'IMPERATIVE',
            effectiveFrom: '1997-03-01',
            officialUrl: 'https://lex.uz/uz/acts/-180552',
          ),
          actionTag: 'CLAIM',
        ),
        ClauseFinding(
          id: 'f_svc_2',
          clauseNumber: '3.1',
          title: 'To‘lov muddati noaniq va dalolatnoma tartibi yo‘q',
          ruleCode: 'R1_R2_PAYMENT_ACCEPTANCE',
          riskColor: RiskColor.yellow,
          backendCategory: 'COMMERCIAL',
          verificationStatus: VerificationStatus.verified,
          balance: NeutralityBalance.heavyPartyB,
          balanceLabel: 'Ijrochiga og‘ir',
          originalText:
              'To‘lov ishlar to‘liq yoqib qolganidan keyin Buyurtmachi imkoniyatiga qarab amalga oshiriladi.',
          explanation:
              '«Yoqib qolganidan keyin» va «imkoniyatiga qarab» iboralari to‘lovni cheksiz kechiktirish xavfini tug‘diradi. Dalolatnoma va e’tiroz muddati belgilanmagan.',
          suggestedRevision:
              'Ijrochi dalolatnomani topshirgach, Buyurtmachi 5 ish kunida imzolaydi yoki asosli e’tiroz beradi; to‘lov imzolangandan so‘ng 5 bank kunida o‘tkaziladi.',
          citation: LegalCitation(
            code: 'FK-UZ',
            title: 'Fuqarolik kodeksi',
            article: '705-modda',
            part: '1–2-qism',
            normNature: 'DISPOSITIVE',
            effectiveFrom: '1997-03-01',
            officialUrl: 'https://lex.uz/uz/acts/-180552',
          ),
        ),
        ClauseFinding(
          id: 'f_svc_3',
          clauseNumber: '5.3',
          title: 'Cheklanmagan jarima va bir tomonlama penya',
          ruleCode: 'R3_LIABILITY_PENALTY',
          riskColor: RiskColor.yellow,
          backendCategory: 'COMMERCIAL',
          verificationStatus: VerificationStatus.verified,
          balance: NeutralityBalance.heavyPartyB,
          balanceLabel: 'Ijrochiga og‘ir',
          originalText:
              'Har bir kechiktirilgan kun uchun Ijrochi shartnoma summasining 2% miqdorida penya va barcha bilvosita zararlarni to‘laydi.',
          explanation:
              'Kunlik 2% penya (oyiga 60%) va cheklanmagan zarar ikki taraf o‘rtasida keskin nomutanosiblik yaratadi; FK 326-modda bo‘yicha sud penyani kamaytirishi mumkin.',
          suggestedRevision:
              'Kechiktirish uchun ikkala tarafga teng 0.1% kunlik penya (jami shartnoma summasining 10% dan oshmasligi) belgilanadi.',
          citation: LegalCitation(
            code: 'FK-UZ',
            title: 'Fuqarolik kodeksi',
            article: '326-modda',
            part: '1-qism',
            normNature: 'DISPOSITIVE',
            effectiveFrom: '1997-03-01',
            officialUrl: 'https://lex.uz/uz/acts/-111189',
          ),
        ),
        ClauseFinding(
          id: 'f_svc_4',
          clauseNumber: '7.1',
          title: 'Mediatsiya va sudgacha hal qilish bandi kiritilmagan',
          ruleCode: 'R5_DISPUTE_MEDIATION',
          riskColor: RiskColor.yellow,
          backendCategory: 'COMMERCIAL',
          verificationStatus: VerificationStatus.verified,
          balance: NeutralityBalance.balanced,
          balanceLabel: 'Muvozanatli',
          originalText:
              'Barcha nizolar Buyurtmachi joylashgan tumandagi sudda hal etiladi.',
          explanation:
              'Pretenziya va mediatsiya bosqichisiz to‘g‘ridan-to‘g‘ri sudga murojaat qilish vaqt va davlat boji xarajatini oshiradi.',
          suggestedRevision:
              'Nizolar dastlab 10 kunlik pretenziya va professional mediatsiya tartibida ko‘rib chiqiladi; kelishuv bo‘lmasa iqtisodiy sudda hal etiladi.',
          citation: LegalCitation(
            code: 'MED-UZ',
            title: '«Mediatsiya to‘g‘risida»gi Qonun',
            article: '16-modda',
            part: '2-qism',
            normNature: 'DISPOSITIVE',
            effectiveFrom: '2019-01-01',
            officialUrl: 'https://lex.uz/uz/docs/-3805227',
          ),
          actionTag: 'MEDIATION',
        ),
        ClauseFinding(
          id: 'f_svc_5',
          clauseNumber: '8.4',
          title: 'Xorijiy arbitraj havolasi (Qamrov tekshiruvi zarur)',
          ruleCode: 'JURISDICTION_SCOPE',
          riskColor: RiskColor.gray,
          backendCategory: 'UNKNOWN',
          verificationStatus: VerificationStatus.reviewRequired,
          balance: NeutralityBalance.balanced,
          balanceLabel: 'Aniqlanmadi',
          originalText:
              'Intellektual mulk nizolarida xalqaro savdo odatlari qo‘llanilishi mumkin.',
          explanation:
              'Xorijiy huquq qo‘llanilishi mumkin bo‘lgan band LexGuard AI qamrovidan tashqarida (O‘zbekiston qonunchiligi bo‘yicha tekshiriladi). Hamkor advokat ko‘rigiga yo‘naltirildi.',
          suggestedRevision:
              'O‘zbekiston Respublikasi amaldagi qonunchiligi qo‘llanilishini aniq ko‘rsating yoki hamkor advokat bilan kelishing.',
          actionTag: 'LAWYER',
        ),
        ClauseFinding(
          id: 'f_svc_6',
          clauseNumber: '1.1',
          title: 'Xizmat ko‘rsatish predmeti aniq yozilgan',
          ruleCode: 'SUBJECT_SCOPE_OK',
          riskColor: RiskColor.green,
          backendCategory: 'OK',
          verificationStatus: VerificationStatus.verified,
          balance: NeutralityBalance.balanced,
          balanceLabel: 'Muvozanatli',
          originalText:
              'Ijrochi 1-ilovadagi texnik topshiriq bo‘yicha veb-modulni 30 kalendar kunda ishlab chiqib topshiradi.',
          explanation:
              'Tekshirilgan qoidalarda muammo topilmadi. Eslatma: Yashil rang hujjatni to‘liq «xavfsiz» deb kafolatlamaydi.',
          suggestedRevision: 'O‘zgartirish talab etilmaydi.',
          citation: LegalCitation(
            code: 'FK-UZ',
            title: 'Fuqarolik kodeksi',
            article: '703-modda',
            part: '1-qism',
            normNature: 'DISPOSITIVE',
            effectiveFrom: '1997-03-01',
            officialUrl: 'https://lex.uz/uz/acts/-180552',
          ),
        ),
      ],
    );
  }

  ContractAnalysis _buildSampleNotarialSale({
    required String id,
    required bool allowExternalAi,
    required DateTime analyzedAt,
  }) {
    return ContractAnalysis(
      id: id,
      title: 'Tijorat binosini oldi-sotdi shartnomasi (R6 Namuna)',
      fileName: 'bino_oldi_sotdi_loyiha.pdf',
      formatLabel: 'PDF',
      languageLabel: 'UZ-Lotin',
      contractType: ContractType.realEstateSale,
      contractDate: '2026-11-21',
      analyzedAt: analyzedAt,
      executionMode: allowExternalAi ? 'HYBRID_AI' : 'RULE_ONLY',
      partyAName: 'Sotuvchi MChJ',
      partyBName: 'Xaridor YaTT',
      overallBalanceLabel: 'Majburiy shakl buzilishi (Qonun)',
      piiMaskedCount: 2,
      piiCategories: const {'STIR': 1, 'BANK_ACC': 1},
      sha256Short: '3e11c8a910bb',
      retentionDays: 7,
      redactedPreview:
          'Ko‘chmas mulk (noturar bino) oldi-sotdi shartnomasi. STIR: [STIR_1], Hisob: [BANK_ACC_1].',
      findings: const [
        ClauseFinding(
          id: 'f_not_1',
          clauseNumber: 'Shakl (R6)',
          title: 'Notarial tasdiqlash shart — hujjatda tasdiq yo‘q',
          ruleCode: 'R6_NOTARIAL_FORM',
          riskColor: RiskColor.red,
          backendCategory: 'LEGAL',
          verificationStatus: VerificationStatus.verified,
          balance: NeutralityBalance.balanced,
          balanceLabel: 'Imperativ qonun',
          originalText:
              'Taraflar ko‘chmas mulk obyektini oddiy yozma shaklda imzolash bilan mulk huquqini o‘tkazishga kelishdilar.',
          explanation:
              'Bu turdagi shartnoma qonunga ko‘ra notarial tasdiqlanishi SHART [FK 110, 480-modda]. Hujjatda notarial tasdiq (reyestr raqami, QR) topilmadi. Tasdiqlanmasa bitim HAQIQIY EMAS [FK 112-modda].',
          suggestedRevision:
              'Shartnomani notariusda rasmiylashtiring va Kadastr organida davlat ro‘yxatidan o‘tkazing.',
          citation: LegalCitation(
            code: 'FK-UZ',
            title: 'Fuqarolik kodeksi',
            article: '110–112, 480-modda',
            part: '1-qism',
            normNature: 'IMPERATIVE',
            effectiveFrom: '1997-03-01',
            officialUrl: 'https://lex.uz/uz/acts/-111189',
          ),
          actionTag: 'NOTARIAL',
        ),
      ],
    );
  }

  ContractAnalysis _buildSampleSupplyRu({
    required String id,
    required bool allowExternalAi,
    required DateTime analyzedAt,
  }) {
    return ContractAnalysis(
      id: id,
      title: 'Договор поставки оборудования №19 (RU)',
      fileName: 'dogovor_postavki_19.pdf',
      formatLabel: 'PDF',
      languageLabel: 'RU',
      contractType: ContractType.supply,
      contractDate: '2026-11-21',
      analyzedAt: analyzedAt,
      executionMode: allowExternalAi ? 'HYBRID_AI' : 'RULE_ONLY',
      partyAName: 'Покупатель ООО',
      partyBName: 'Поставщик ИП',
      overallBalanceLabel: 'Тяжелее для Поставщика',
      piiMaskedCount: 3,
      piiCategories: const {'STIR': 2, 'PHONE': 1},
      sha256Short: '7a90d11c4f22',
      retentionDays: 7,
      redactedPreview:
          'Договор поставки. ИНН [STIR_1] и [STIR_2], контакт [PHONE_1].',
      findings: const [
        ClauseFinding(
          id: 'f_ru_1',
          clauseNumber: '6.2',
          title: 'Односторонний отказ без возмещения затрат',
          ruleCode: 'R4_UNILATERAL_TERMINATION',
          riskColor: RiskColor.yellow,
          backendCategory: 'COMMERCIAL',
          verificationStatus: VerificationStatus.verified,
          balance: NeutralityBalance.heavyPartyB,
          balanceLabel: 'Тяжелее для Поставщика',
          originalText:
              'Покупатель вправе отказаться от уже заказанного товара в любой момент без компенсации расходов.',
          explanation:
              'Односторонний отказ от исполнения договора поставки без возмещения фактических убытков создаёт высокий коммерческий риск для Поставщика.',
          suggestedRevision:
              'Отказ от заказа возможен за 14 дней с возмещением документально подтверждённых затрат на закупку/доставку.',
          citation: LegalCitation(
            code: 'FK-UZ',
            title: 'Гражданский кодекс РУз',
            article: '437-modda',
            part: '1-qism',
            normNature: 'DISPOSITIVE',
            effectiveFrom: '1997-03-01',
            officialUrl: 'https://lex.uz/uz/acts/-180552',
          ),
          actionTag: 'CLAIM',
        ),
        ClauseFinding(
          id: 'f_ru_2',
          clauseNumber: '9.1',
          title: 'Нет досудебного урегулирования и медиации',
          ruleCode: 'R5_DISPUTE_MEDIATION',
          riskColor: RiskColor.yellow,
          backendCategory: 'COMMERCIAL',
          verificationStatus: VerificationStatus.verified,
          balance: NeutralityBalance.balanced,
          balanceLabel: 'Сбалансировано',
          originalText:
              'Споры передаются сразу в межрайонный экономический суд.',
          explanation:
              'Рекомендуется добавить 10-дневный претензионный порядок и этап медиации для экономии времени и пошлин.',
          suggestedRevision:
              'До обращения в суд стороны направляют письменную претензию (срок ответа 10 дней) и рассматривают медиацию.',
          citation: LegalCitation(
            code: 'MED-UZ',
            title: 'Закон «О медиации»',
            article: '16-modda',
            part: '2-qism',
            normNature: 'DISPOSITIVE',
            effectiveFrom: '2019-01-01',
            officialUrl: 'https://lex.uz/uz/docs/-3805227',
          ),
          actionTag: 'MEDIATION',
        ),
      ],
    );
  }
}

const List<LegalNorm> _curatedNorms = [
  LegalNorm(
    id: 'fk_4',
    code: 'FK-UZ',
    title: 'Fuqarolik kodeksi — Qonunning vaqt bo‘yicha amal qilishi',
    article: '4-modda',
    normNature: 'IMPERATIVE',
    effectiveFrom: '1997-03-01',
    summary:
        'Fuqarolik qonun hujjatlari orqaga qaytish kuchiga ega emas va shartnoma tuzilgan sanadagi tahrir qo‘llaniladi.',
    officialUrl: 'https://lex.uz/uz/acts/-111189',
  ),
  LegalNorm(
    id: 'fk_110_112',
    code: 'FK-UZ',
    title: 'Fuqarolik kodeksi — Bitimning notarial shakli va oqibati',
    article: '110–112-modda',
    normNature: 'IMPERATIVE',
    effectiveFrom: '1997-03-01',
    summary:
        'Qonun bilan notarial tasdiqlash shart qilingan bitim oddiy yozma tuzilsa, haqiqiy emas (o‘z-o‘zidan bekor).',
    officialUrl: 'https://lex.uz/uz/acts/-111189',
  ),
  LegalNorm(
    id: 'fk_326',
    code: 'FK-UZ',
    title: 'Fuqarolik kodeksi — Sud tomonidan neustoykani kamaytirish',
    article: '326-modda',
    normNature: 'DISPOSITIVE',
    effectiveFrom: '1997-03-01',
    summary:
        'To‘lanishi lozim bo‘lgan neustoyka majburiyat buzilishi oqibatlariga nomutanosib bo‘lsa, sud uni kamaytirishi mumkin.',
    officialUrl: 'https://lex.uz/uz/acts/-111189',
  ),
  LegalNorm(
    id: 'fk_705',
    code: 'FK-UZ',
    title: 'Fuqarolik kodeksi — Haq evaziga xizmat ko‘rsatish haqini to‘lash',
    article: '705-modda',
    normNature: 'DISPOSITIVE',
    effectiveFrom: '1997-03-01',
    summary:
        'Buyurtmachi ko‘rsatilgan xizmatlar haqini shartnomada belgilangan muddatda va tartibda to‘lashi shart.',
    officialUrl: 'https://lex.uz/uz/acts/-180552',
  ),
  LegalNorm(
    id: 'fk_707',
    code: 'FK-UZ',
    title: 'Fuqarolik kodeksi — Xizmat shartnomasini bir tomonlama bekor qilish',
    article: '707-modda',
    normNature: 'IMPERATIVE',
    effectiveFrom: '1997-03-01',
    summary:
        'Buyurtmachi ijrochiga haqiqatda qilgan xarajatlarini to‘lash sharti bilan shartnomani bekor qilishga haqli.',
    officialUrl: 'https://lex.uz/uz/acts/-180552',
  ),
  LegalNorm(
    id: 'orq_1115',
    code: 'O‘RQ-1115',
    title: 'Axborotlashtirish to‘g‘risida (AI cheklovlari, 21.01.2026)',
    article: 'AI nazorat normasi',
    normNature: 'IMPERATIVE',
    effectiveFrom: '2026-01-21',
    summary:
        'Inson huquq va erkinliklariga ta’sir qiluvchi yuridik qarorlarni faqat sun’iy intellekt xulosasiga tayanib chiqarish taqiqlanadi.',
    officialUrl: 'https://www.lex.uz/uz/docs/-8008401',
  ),
  LegalNorm(
    id: 'orq_547_1125',
    code: 'O‘RQ-547 / 1125',
    title: 'Shaxsga doir ma’lumotlar to‘g‘risida',
    article: 'Transchegaraviy va himoya',
    normNature: 'IMPERATIVE',
    effectiveFrom: '2026-03-26',
    summary:
        'Shaxsga doir ma’lumotlarni minimallashtirish, rozilik olish va maxfiy ma’lumotlarni himoyalash majburiy.',
    officialUrl: 'https://www.lex.uz/uz/docs/-8099215',
  ),
];

const List<RuleDescriptor> _mvpRules = [
  RuleDescriptor(
    code: 'R1',
    title: 'To‘lov muddati va tartibi',
    scope: 'Xizmat ko‘rsatish (B2B)',
    defaultCategory: 'COMMERCIAL (muhim shart yo‘q bo‘lsa LEGAL)',
    description:
        'Summa, muddat, 100% oldindan to‘lov xavfi va kechikish oqibatlarini tekshiradi.',
  ),
  RuleDescriptor(
    code: 'R2',
    title: 'Xizmatni qabul qilish dalolatnomasi',
    scope: 'Xizmat ko‘rsatish (B2B)',
    defaultCategory: 'COMMERCIAL',
    description:
        'Bajarilgan ishlar dalolatnomasi va e’tiroz bildirish muddatini tekshiradi.',
  ),
  RuleDescriptor(
    code: 'R3',
    title: 'Javobgarlik va neustoyka (penya)',
    scope: 'Xizmat ko‘rsatish (B2B)',
    defaultCategory: 'COMMERCIAL / LEGAL',
    description:
        'Penya/jarima bir tomonlama yoki cheksiz yuklanganligini aniqlaydi.',
  ),
  RuleDescriptor(
    code: 'R4',
    title: 'Bir tomonlama bekor qilish',
    scope: 'Xizmat ko‘rsatish (B2B)',
    defaultCategory: 'LEGAL / COMMERCIAL',
    description:
        'Xarajatlarni qoplash va ogohlantirish muddati (FK 707-m) mavjudligini tekshiradi.',
  ),
  RuleDescriptor(
    code: 'R5',
    title: 'Nizolar: Pretenziya va Mediatsiya',
    scope: 'Xizmat ko‘rsatish (B2B)',
    defaultCategory: 'COMMERCIAL + 1-trek',
    description:
        'Sudgacha pretenziya va professional mediatsiya bandi kiritilishini taklif qiladi.',
  ),
  RuleDescriptor(
    code: 'R6',
    title: 'Majburiy notarial shakl signali',
    scope: 'Barcha turlar (1-trek)',
    defaultCategory: 'LEGAL (Qizil) / UNKNOWN',
    description:
        'Notarial shakl majburiy bo‘lgan bitimda tasdiq/QR yo‘qligini tekshiradi.',
  ),
];

const List<IntegrationItem> _integrations = [
  IntegrationItem(
    name: 'Go Backend API (/api/v1)',
    statusLabel: 'TAYYOR (ARXITEKTURA)',
    isMock: false,
    description:
        'Yagona Web, Mobile va Admin REST + SSE shartnomasi; dev muhitda lokal Demo engine faol.',
  ),
  IntegrationItem(
    name: 'Lex.uz Normativ Baza',
    statusLabel: 'MOCK (CURATED SEED)',
    isMock: true,
    description:
        'MVPda huquqshunos tekshirgan minimal moddalar bazasi; rasmiy API shartnomadan keyin ulanadi.',
  ),
  IntegrationItem(
    name: 'OneID Identifikatsiya',
    statusLabel: 'MOCK (OAuth PKCE)',
    isMock: true,
    description:
        'VM 679 bo‘yicha shartnomaviy ulanish kutilmoqda; parol yoki SMS-kod hech qachon so‘ralmaydi.',
  ),
  IntegrationItem(
    name: 'E-IMZO / ERI Imzo',
    statusLabel: 'MOCK (KALITSIZ)',
    isMock: true,
    description:
        'O‘RQ-793: server .pfx yoki maxfiy kalitni olmaydi; faqat hash challenge va verify.',
  ),
];
