import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/security/screen_security.dart';
import '../../../contracts/domain/entities/lex_models.dart';

class SessionState extends Equatable {
  const SessionState({
    this.lang = AppLang.uz,
    this.themeMode = ThemeMode.light,
    this.segment = AccountSegment.business,
    this.hasSelectedRole = false,
    this.quota = const QuotaState(
      planName: 'Sinov (14 kun)',
      trialDaysRemaining: 14,
      totalUsed: 2,
      totalLimit: 10,
      todayUsed: 1,
      todayLimit: 3,
    ),
    this.organizationName = 'DNK Tech MChJ',
    this.userName = 'Vafoyev Isobek',
    this.authProviderLabel = 'E-IMZO (Demo · Yuridik)',
    this.flagSecureEnabled = true,
    this.privacyCurtainEnabled = true,
    this.biometricLockEnabled = false,
    this.externalAiConsent = true,
    this.phoneFrameOnDesktop = true,
  });

  final AppLang lang;
  final ThemeMode themeMode;
  final AccountSegment segment;
  final bool hasSelectedRole;
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
    ThemeMode? themeMode,
    AccountSegment? segment,
    bool? hasSelectedRole,
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
      themeMode: themeMode ?? this.themeMode,
      segment: segment ?? this.segment,
      hasSelectedRole: hasSelectedRole ?? this.hasSelectedRole,
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
        themeMode,
        segment,
        hasSelectedRole,
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

  void enterRole(AccountSegment segment) {
    emit(
      state.copyWith(
        segment: segment,
        hasSelectedRole: true,
        organizationName: segment == AccountSegment.business
            ? 'DNK Tech MChJ'
            : 'Vafoyev Isobek · Shaxsiy',
        authProviderLabel: segment == AccountSegment.business
            ? 'E-IMZO (Mock · Yuridik)'
            : 'OneID (Mock · Jismoniy)',
      ),
    );
  }

  void setSegment(AccountSegment segment) {
    emit(
      state.copyWith(
        segment: segment,
        organizationName: segment == AccountSegment.business
            ? 'DNK Tech MChJ'
            : 'Vafoyev Isobek · Shaxsiy',
        authProviderLabel: segment == AccountSegment.business
            ? 'E-IMZO (Mock · Yuridik)'
            : 'OneID (Mock · Jismoniy)',
      ),
    );
  }

  void returnToRoleSelect() {
    emit(state.copyWith(hasSelectedRole: false));
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
