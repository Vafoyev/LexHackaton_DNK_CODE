import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/uzbek_alphabet.dart';
import '../../../../core/security/screen_security.dart';
import '../../../contracts/domain/entities/lex_models.dart';

class SessionState extends Equatable {
  const SessionState({
    this.lang = AppLang.uz,
    this.uzbekScript = UzbekScript.reformed,
    this.themeMode = ThemeMode.light,
    this.segment = AccountSegment.business,
    this.hasCompletedOnboarding = false,
    this.hasSelectedRole = false,
    this.isAuthenticated = false,
    this.activePlanId = 'b2b_trial',
    this.quota = const QuotaState(
      planName: 'Biznes sinov · 14 kun',
      trialDaysRemaining: 14,
      totalUsed: 2,
      totalLimit: 10,
      todayUsed: 1,
      todayLimit: 3,
    ),
    this.organizationName = 'DNK Tech MChJ',
    this.userName = 'Vafoyev Isobek',
    this.authProviderLabel = 'E-IMZO (Mock · Yuridik)',
    this.flagSecureEnabled = true,
    this.privacyCurtainEnabled = true,
    this.biometricLockEnabled = false,
    this.externalAiConsent = true,
    this.phoneFrameOnDesktop = true,
  });

  final AppLang lang;
  final UzbekScript uzbekScript;
  final ThemeMode themeMode;
  final AccountSegment segment;
  final bool hasCompletedOnboarding;
  final bool hasSelectedRole;
  final bool isAuthenticated;
  final String activePlanId;
  final QuotaState quota;
  final String organizationName;
  final String userName;
  final String authProviderLabel;
  final bool flagSecureEnabled;
  final bool privacyCurtainEnabled;
  final bool biometricLockEnabled;
  final bool externalAiConsent;
  final bool phoneFrameOnDesktop;

  SessionState copyWith({
    AppLang? lang,
    UzbekScript? uzbekScript,
    ThemeMode? themeMode,
    AccountSegment? segment,
    bool? hasCompletedOnboarding,
    bool? hasSelectedRole,
    bool? isAuthenticated,
    String? activePlanId,
    QuotaState? quota,
    String? organizationName,
    String? userName,
    String? authProviderLabel,
    bool? flagSecureEnabled,
    bool? privacyCurtainEnabled,
    bool? biometricLockEnabled,
    bool? externalAiConsent,
    bool? phoneFrameOnDesktop,
  }) {
    return SessionState(
      lang: lang ?? this.lang,
      uzbekScript: uzbekScript ?? this.uzbekScript,
      themeMode: themeMode ?? this.themeMode,
      segment: segment ?? this.segment,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      hasSelectedRole: hasSelectedRole ?? this.hasSelectedRole,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      activePlanId: activePlanId ?? this.activePlanId,
      quota: quota ?? this.quota,
      organizationName: organizationName ?? this.organizationName,
      userName: userName ?? this.userName,
      authProviderLabel: authProviderLabel ?? this.authProviderLabel,
      flagSecureEnabled: flagSecureEnabled ?? this.flagSecureEnabled,
      privacyCurtainEnabled:
          privacyCurtainEnabled ?? this.privacyCurtainEnabled,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      externalAiConsent: externalAiConsent ?? this.externalAiConsent,
      phoneFrameOnDesktop: phoneFrameOnDesktop ?? this.phoneFrameOnDesktop,
    );
  }

  @override
  List<Object?> get props => [
        lang,
        uzbekScript,
        themeMode,
        segment,
        hasCompletedOnboarding,
        hasSelectedRole,
        isAuthenticated,
        activePlanId,
        quota,
        organizationName,
        userName,
        authProviderLabel,
        flagSecureEnabled,
        privacyCurtainEnabled,
        biometricLockEnabled,
        externalAiConsent,
        phoneFrameOnDesktop,
      ];
}

class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._screenSecurity) : super(const SessionState()) {
    _screenSecurity.setFlagSecure(state.flagSecureEnabled);
  }

  final ScreenSecurityService _screenSecurity;

  void setLang(AppLang lang) => emit(state.copyWith(lang: lang));

  void setUzbekScript(UzbekScript script) =>
      emit(state.copyWith(uzbekScript: script));

  void setLanguageConfig(AppLang lang, {UzbekScript? uzbekScript}) {
    emit(
      state.copyWith(
        lang: lang,
        uzbekScript: uzbekScript ?? state.uzbekScript,
      ),
    );
  }

  void cycleLang() {
    final next = switch (state.lang) {
      AppLang.uz => AppLang.ru,
      AppLang.ru => AppLang.en,
      AppLang.en => AppLang.uz,
    };
    emit(state.copyWith(lang: next));
  }

  void toggleThemeMode() {
    emit(
      state.copyWith(
        themeMode: state.themeMode == ThemeMode.light
            ? ThemeMode.dark
            : ThemeMode.light,
      ),
    );
  }

  void completeOnboarding() {
    emit(state.copyWith(hasCompletedOnboarding: true));
  }

  void selectRole(AccountSegment segment) {
    final isBusiness = segment == AccountSegment.business;
    emit(
      state.copyWith(
        segment: segment,
        hasSelectedRole: true,
        activePlanId: isBusiness ? 'b2b_trial' : 'b2c_free',
        organizationName:
            isBusiness ? 'DNK Tech MChJ' : 'Vafoyev Isobek',
        authProviderLabel: isBusiness ? 'E-IMZO · B2B' : 'OneID',
        quota: isBusiness
            ? const QuotaState(
                planName: 'Biznes sinov · 14 kun',
                trialDaysRemaining: 14,
                totalUsed: 2,
                totalLimit: 10,
                todayUsed: 1,
                todayLimit: 3,
              )
            : const QuotaState(
                planName: 'Fuqaro · Bepul (3/oy)',
                trialDaysRemaining: 30,
                totalUsed: 1,
                totalLimit: 3,
                todayUsed: 1,
                todayLimit: 3,
              ),
      ),
    );
  }

  /// Selects a tariff strictly within the user's current segment (B2C vs B2B).
  void selectPlan(String planId) {
    final isBusiness = state.segment == AccountSegment.business;
    if (!isBusiness) {
      switch (planId) {
        case 'b2c_free':
          emit(
            state.copyWith(
              activePlanId: 'b2c_free',
              quota: QuotaState(
                planName: 'Fuqaro · Bepul (3/oy)',
                trialDaysRemaining: 30,
                totalUsed: state.quota.totalUsed.clamp(0, 3),
                totalLimit: 3,
                todayUsed: state.quota.todayUsed.clamp(0, 3),
                todayLimit: 3,
              ),
            ),
          );
          return;
        case 'b2c_once':
          emit(
            state.copyWith(
              activePlanId: 'b2c_once',
              quota: QuotaState(
                planName: 'Fuqaro · Bir martalik',
                trialDaysRemaining: 30,
                totalUsed: state.quota.totalUsed,
                totalLimit: state.quota.totalLimit + 1,
                todayUsed: state.quota.todayUsed,
                todayLimit: state.quota.todayLimit + 1,
              ),
            ),
          );
          return;
      }
      return;
    }

    switch (planId) {
      case 'b2b_trial':
        emit(
          state.copyWith(
            activePlanId: 'b2b_trial',
            quota: QuotaState(
              planName: 'Biznes sinov · 14 kun',
              trialDaysRemaining: 14,
              totalUsed: state.quota.totalUsed.clamp(0, 10),
              totalLimit: 10,
              todayUsed: state.quota.todayUsed.clamp(0, 3),
              todayLimit: 3,
            ),
          ),
        );
      case 'b2b_business':
        emit(
          state.copyWith(
            activePlanId: 'b2b_business',
            quota: QuotaState(
              planName: 'Business · 30/oy',
              trialDaysRemaining: 30,
              totalUsed: state.quota.totalUsed.clamp(0, 30),
              totalLimit: 30,
              todayUsed: state.quota.todayUsed,
              todayLimit: 30,
            ),
          ),
        );
      case 'b2b_pro':
        emit(
          state.copyWith(
            activePlanId: 'b2b_pro',
            quota: QuotaState(
              planName: 'Pro · 80/oy',
              trialDaysRemaining: 30,
              totalUsed: state.quota.totalUsed.clamp(0, 80),
              totalLimit: 80,
              todayUsed: state.quota.todayUsed,
              todayLimit: 80,
            ),
          ),
        );
      case 'b2b_extra':
        emit(
          state.copyWith(
            quota: QuotaState(
              planName: state.quota.planName,
              trialDaysRemaining: state.quota.trialDaysRemaining,
              totalUsed: state.quota.totalUsed,
              totalLimit: state.quota.totalLimit + 1,
              todayUsed: state.quota.todayUsed,
              todayLimit: state.quota.todayLimit + 1,
            ),
          ),
        );
    }
  }

  void completeLogin({
    required String providerLabel,
    String? userName,
    String? organizationName,
  }) {
    emit(
      state.copyWith(
        isAuthenticated: true,
        hasSelectedRole: true,
        authProviderLabel: providerLabel,
        userName: (userName != null && userName.trim().isNotEmpty)
            ? userName.trim()
            : state.userName,
        organizationName:
            (organizationName != null && organizationName.trim().isNotEmpty)
                ? organizationName.trim()
                : state.organizationName,
      ),
    );
  }

  void enterRole(AccountSegment segment) {
    selectRole(segment);
    emit(state.copyWith(isAuthenticated: true));
  }

  void setSegment(AccountSegment segment) {
    selectRole(segment);
  }

  void returnToRoleSelect() {
    emit(state.copyWith(hasSelectedRole: false));
  }

  void logout() {
    emit(state.copyWith(isAuthenticated: false, hasSelectedRole: false));
  }

  void consumeQuota() {
    emit(state.copyWith(quota: state.quota.incrementUsed()));
  }

  Future<void> setFlagSecure(bool enabled) async {
    emit(state.copyWith(flagSecureEnabled: enabled));
    await _screenSecurity.setFlagSecure(enabled);
  }

  void setPrivacyCurtain(bool enabled) =>
      emit(state.copyWith(privacyCurtainEnabled: enabled));

  void setBiometricLock(bool enabled) =>
      emit(state.copyWith(biometricLockEnabled: enabled));

  void setExternalAiConsent(bool enabled) =>
      emit(state.copyWith(externalAiConsent: enabled));

  void toggleDesktopFrame() =>
      emit(state.copyWith(phoneFrameOnDesktop: !state.phoneFrameOnDesktop));

  void signInMockProvider(String providerLabel) {
    emit(state.copyWith(authProviderLabel: providerLabel));
  }
}
