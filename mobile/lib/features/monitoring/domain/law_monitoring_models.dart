import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A targeted B2B law-change alert tied to a specific clause of a company's
/// uploaded contract or internal document (LexGuard-AI-Loyiha.docx §8).
class LawMonitoringAlert extends Equatable {
  const LawMonitoringAlert({
    required this.id,
    required this.contractId,
    required this.documentTitle,
    required this.isCompanyDoc,
    required this.affectedClause,
    required this.lawCode,
    required this.lawTitle,
    required this.effectiveDate,
    required this.changeSummary,
    required this.currentClauseText,
    required this.recommendedClauseText,
    required this.impactRisk,
    required this.isRead,
    required this.isResolved,
  });

  final String id;

  /// Links to a [ContractAnalysis.id] when this alert affects a contract,
  /// or null when it affects an internal company document.
  final String? contractId;
  final String documentTitle;
  final bool isCompanyDoc;
  final String affectedClause;
  final String lawCode;
  final String lawTitle;
  final String effectiveDate;
  final String changeSummary;
  final String currentClauseText;
  final String recommendedClauseText;
  final String impactRisk;
  final bool isRead;
  final bool isResolved;

  LawMonitoringAlert copyWith({
    bool? isRead,
    bool? isResolved,
  }) {
    return LawMonitoringAlert(
      id: id,
      contractId: contractId,
      documentTitle: documentTitle,
      isCompanyDoc: isCompanyDoc,
      affectedClause: affectedClause,
      lawCode: lawCode,
      lawTitle: lawTitle,
      effectiveDate: effectiveDate,
      changeSummary: changeSummary,
      currentClauseText: currentClauseText,
      recommendedClauseText: recommendedClauseText,
      impactRisk: impactRisk,
      isRead: isRead ?? this.isRead,
      isResolved: isResolved ?? this.isResolved,
    );
  }

  @override
  List<Object?> get props => [
        id,
        contractId,
        documentTitle,
        isCompanyDoc,
        affectedClause,
        lawCode,
        lawTitle,
        effectiveDate,
        changeSummary,
        currentClauseText,
        recommendedClauseText,
        impactRisk,
        isRead,
        isResolved,
      ];
}

/// Internal company document stored in B2B "Hujjatlarim" (§7.1).
class CompanyInternalDoc extends Equatable {
  const CompanyInternalDoc({
    required this.id,
    required this.title,
    required this.category,
    required this.fileName,
    required this.updatedLabel,
    this.monitored = true,
    this.alertId,
  });

  final String id;
  final String title;
  final String category;
  final String fileName;
  final String updatedLabel;
  final bool monitored;
  final String? alertId;

  @override
  List<Object?> get props => [
        id,
        title,
        category,
        fileName,
        updatedLabel,
        monitored,
        alertId,
      ];
}

class MonitoringState extends Equatable {
  const MonitoringState({
    required this.alerts,
    required this.companyDocs,
  });

  final List<LawMonitoringAlert> alerts;
  final List<CompanyInternalDoc> companyDocs;

  int get unreadCount =>
      alerts.where((a) => !a.isRead && !a.isResolved).length;

  int get activeCount => alerts.where((a) => !a.isResolved).length;

  LawMonitoringAlert? alertForContract(String contractId) {
    for (final a in alerts) {
      if (a.contractId == contractId && !a.isResolved) return a;
    }
    return null;
  }

  LawMonitoringAlert? alertById(String? alertId) {
    if (alertId == null) return null;
    for (final a in alerts) {
      if (a.id == alertId) return a;
    }
    return null;
  }

  MonitoringState copyWith({
    List<LawMonitoringAlert>? alerts,
    List<CompanyInternalDoc>? companyDocs,
  }) {
    return MonitoringState(
      alerts: alerts ?? this.alerts,
      companyDocs: companyDocs ?? this.companyDocs,
    );
  }

  @override
  List<Object?> get props => [alerts, companyDocs];
}

class MonitoringCubit extends Cubit<MonitoringState> {
  MonitoringCubit()
      : super(
          const MonitoringState(
            alerts: _initialAlerts,
            companyDocs: _initialCompanyDocs,
          ),
        );

  void markRead(String alertId) {
    final updated = state.alerts
        .map((a) => a.id == alertId ? a.copyWith(isRead: true) : a)
        .toList(growable: false);
    emit(state.copyWith(alerts: updated));
  }

  void resolveAlert(String alertId) {
    final updated = state.alerts
        .map(
          (a) => a.id == alertId
              ? a.copyWith(isRead: true, isResolved: true)
              : a,
        )
        .toList(growable: false);
    emit(state.copyWith(alerts: updated));
  }

  void markAllRead() {
    final updated = state.alerts
        .map((a) => a.copyWith(isRead: true))
        .toList(growable: false);
    emit(state.copyWith(alerts: updated));
  }

  void addCompanyDoc({
    required String title,
    required String category,
    required String fileName,
  }) {
    final doc = CompanyInternalDoc(
      id: 'doc_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      category: category,
      fileName: fileName,
      updatedLabel: 'Bugun',
      monitored: true,
    );
    emit(state.copyWith(companyDocs: [doc, ...state.companyDocs]));
  }

  void removeCompanyDoc(String docId) {
    emit(
      state.copyWith(
        companyDocs:
            state.companyDocs.where((d) => d.id != docId).toList(growable: false),
      ),
    );
  }

  static const List<LawMonitoringAlert> _initialAlerts = [
    LawMonitoringAlert(
      id: 'mon_fk_327',
      contractId: 'ana_service_01',
      documentTitle: 'B2B Xizmat ko‘rsatish shartnomasi №42',
      isCompanyDoc: false,
      affectedClause: 'Band 5.2',
      lawCode: 'FK 327-modda',
      lawTitle: 'Penya miqdori va yuqori chegarasi',
      effectiveDate: '01.11.2026',
      changeSummary:
          'Chegarasiz kunlik penya shartnomani uzaytirishda sudda kamaytirilishi va nizo chiqarishi mumkin.',
      currentClauseText:
          'To‘lov kechiktirilgan har bir kun uchun 1% miqdorida chegarasiz penya undiriladi.',
      recommendedClauseText:
          'To‘lov kechiktirilgan har bir kun uchun 0.2%, ammo jami kechiktirilgan summaning 50% dan oshmagan miqdorda penya undiriladi.',
      impactRisk:
          'Penya chegarasi qo‘yilmasa, 2 hafta kechikishda summaning 14%i yo‘qotiladi va hamkor bilan nizo yuzaga keladi.',
      isRead: false,
      isResolved: false,
    ),
    LawMonitoringAlert(
      id: 'mon_med_16',
      contractId: 'ana_lease_03',
      documentTitle: 'Noturar joy ijarasi shartnomasi №18',
      isCompanyDoc: false,
      affectedClause: 'Band 7.1',
      lawCode: 'Mediatsiya 16-m.',
      lawTitle: 'Sudgacha pretenziya va mediatsiya tartibi',
      effectiveDate: '15.10.2026',
      changeSummary:
          'Ijara shartnomalarida nizoni suddan oldin 10 kunlik pretenziya va mediatsiya orqali hal qilish tavsiya etiladi.',
      currentClauseText:
          'Kelishmovchiliklar yuzaga kelganda taraflar to‘g‘ridan-to‘g‘ri iqtisodiy sudga murojaat qiladi.',
      recommendedClauseText:
          'Nizolar avvalo 10 kunlik yozma pretenziya va professional mediatsiya orqali hal qilinadi; kelishuv bo‘lmasa sudga oshiriladi.',
      impactRisk:
          'Sudgacha tartib ko‘rsatilmasa, da’vo cho‘zilishi va qo‘shimcha sud xarajati chiqishi mumkin.',
      isRead: false,
      isResolved: false,
    ),
    LawMonitoringAlert(
      id: 'mon_pd_547',
      contractId: null,
      documentTitle: 'Mehnat shartnomasi (Namunaviy)',
      isCompanyDoc: true,
      affectedClause: 'Band 4.3',
      lawCode: 'O‘RQ-547 / 1125',
      lawTitle: 'Xodim shaxsiy ma’lumotlarini qayta ishlash',
      effectiveDate: '01.10.2026',
      changeSummary:
          'Xodim pasporti va JSHSHIR ma’lumotlarini tashqi xizmatlarga yuborishdan oldin alohida rozilik va himoya talab etiladi.',
      currentClauseText:
          'Ish beruvchi xodimning shaxsiy ma’lumotlarini uchinchi tomon hamkorlarga cheklovsiz taqdim etishi mumkin.',
      recommendedClauseText:
          'Xodimning shaxsiy ma’lumotlari faqat yozma rozilik asosida va O‘RQ-547 talablariga muvofiq himoyalangan holda qayta ishlanadi.',
      impactRisk:
          'Roziliksiz shaxsiy ma’lumotlarni uzatish ma’muriy javobgarlikka sabab bo‘lishi mumkin.',
      isRead: false,
      isResolved: false,
    ),
  ];

  static const List<CompanyInternalDoc> _initialCompanyDocs = [
    CompanyInternalDoc(
      id: 'doc_hr_01',
      title: 'Mehnat shartnomasi (Namunaviy)',
      category: 'Kadrlar · HR',
      fileName: 'mehnat_shartnomasi_2026.docx',
      updatedLabel: '2 kun oldin',
      monitored: true,
      alertId: 'mon_pd_547',
    ),
    CompanyInternalDoc(
      id: 'doc_poa_02',
      title: 'Bosh buxgalter ishonchnomasi',
      category: 'Ishonchnoma',
      fileName: 'ishonchnoma_buxgalter.pdf',
      updatedLabel: '5 kun oldin',
      monitored: true,
    ),
    CompanyInternalDoc(
      id: 'doc_charter_03',
      title: 'DNK Tech MChJ Nizomi',
      category: 'Ta’sis hujjati',
      fileName: 'dnk_tech_nizom_2025.pdf',
      updatedLabel: '12 kun oldin',
      monitored: true,
    ),
  ];
}
