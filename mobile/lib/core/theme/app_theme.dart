import 'package:flutter/material.dart';

import '../../features/contracts/domain/entities/lex_models.dart';

/// LexGuard AI 3.2 Dual-Role Executive Glass & Semantic Risk Theme Extension.
@immutable
class LexRiskColors extends ThemeExtension<LexRiskColors> {
  const LexRiskColors({
    required this.segment,
    required this.rolePrimary,
    required this.rolePrimaryDark,
    required this.roleAccent,
    required this.roleGradientStart,
    required this.roleGradientEnd,
    required this.roleGlow,
    required this.canvasBg,
    required this.ambientOrbA,
    required this.ambientOrbB,
    required this.glassFill,
    required this.glassFillStrong,
    required this.glassBorder,
    required this.glassHighlight,
    required this.textPrimary,
    required this.textSecondary,
    required this.redText,
    required this.redBg,
    required this.redBorder,
    required this.yellowText,
    required this.yellowBg,
    required this.yellowBorder,
    required this.grayText,
    required this.grayBg,
    required this.grayBorder,
    required this.greenText,
    required this.greenBg,
    required this.greenBorder,
  });

  final AccountSegment segment;
  final Color rolePrimary;
  final Color rolePrimaryDark;
  final Color roleAccent;
  final Color roleGradientStart;
  final Color roleGradientEnd;
  final Color roleGlow;
  final Color canvasBg;
  final Color ambientOrbA;
  final Color ambientOrbB;
  final Color glassFill;
  final Color glassFillStrong;
  final Color glassBorder;
  final Color glassHighlight;
  final Color textPrimary;
  final Color textSecondary;

  final Color redText;
  final Color redBg;
  final Color redBorder;
  final Color yellowText;
  final Color yellowBg;
  final Color yellowBorder;
  final Color grayText;
  final Color grayBg;
  final Color grayBorder;
  final Color greenText;
  final Color greenBg;
  final Color greenBorder;

  // Aliases used across cards & badges mapped dynamically to active role
  Color get brandDeepBlue => rolePrimaryDark;
  Color get brandPrimaryBlue => rolePrimary;
  Color get brandCyan => roleAccent;
  Color get cardBorder => glassBorder;

  /// Jismoniy shaxs (Personal): Royal Sapphire (#1D63FF) Design System
  static const individualLight = LexRiskColors(
    segment: AccountSegment.individual,
    rolePrimary: Color(0xFF1D63FF),
    rolePrimaryDark: Color(0xFF0E3EC9),
    roleAccent: Color(0xFF0EA5E9),
    roleGradientStart: Color(0xFF0F3FD1),
    roleGradientEnd: Color(0xFF2B7FFF),
    roleGlow: Color(0x421D63FF),
    canvasBg: Color(0xFFF3F6FC),
    ambientOrbA: Color(0xFF93C5FD),
    ambientOrbB: Color(0xFF7DD3FC),
    glassFill: Color(0xEBFFFFFF),
    glassFillStrong: Color(0xF7FFFFFF),
    glassBorder: Color(0xFFE2E9F6),
    glassHighlight: Color(0xFFE5F0FF),
    textPrimary: Color(0xFF0D1526),
    textSecondary: Color(0xFF52627A),
    redText: Color(0xFFDC2626),
    redBg: Color(0xFFFEF2F2),
    redBorder: Color(0xFFFECACA),
    yellowText: Color(0xFFD97706),
    yellowBg: Color(0xFFFFFBEB),
    yellowBorder: Color(0xFFFDE68A),
    grayText: Color(0xFF475569),
    grayBg: Color(0xFFF1F5F9),
    grayBorder: Color(0xFFCBD5E1),
    greenText: Color(0xFF16A34A),
    greenBg: Color(0xFFF0FDF4),
    greenBorder: Color(0xFFBBF7D0),
  );

  static const individualDark = LexRiskColors(
    segment: AccountSegment.individual,
    rolePrimary: Color(0xFF3B82F6),
    rolePrimaryDark: Color(0xFF1D4ED8),
    roleAccent: Color(0xFF38BDF8),
    roleGradientStart: Color(0xFF0E3385),
    roleGradientEnd: Color(0xFF1D63FF),
    roleGlow: Color(0x523B82F6),
    canvasBg: Color(0xFF080D1A),
    ambientOrbA: Color(0xFF1E3A8A),
    ambientOrbB: Color(0xFF0C4A6E),
    glassFill: Color(0xCC11192B),
    glassFillStrong: Color(0xE6141F35),
    glassBorder: Color(0x2660A5FA),
    glassHighlight: Color(0xFF1B2A48),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    redText: Color(0xFFF87171),
    redBg: Color(0xB33B1219),
    redBorder: Color(0xFF7F1D1D),
    yellowText: Color(0xFFFBBF24),
    yellowBg: Color(0xB336250B),
    yellowBorder: Color(0xFF78350F),
    grayText: Color(0xFF94A3B8),
    grayBg: Color(0xB31E293B),
    grayBorder: Color(0xFF334155),
    greenText: Color(0xFF4ADE80),
    greenBg: Color(0xB30E2B1A),
    greenBorder: Color(0xFF166534),
  );

  /// Yuridik shaxs (Business / B2B): Executive Forest Emerald (#047857) + Warm Gold Design System
  static const businessLight = LexRiskColors(
    segment: AccountSegment.business,
    rolePrimary: Color(0xFF047857),
    rolePrimaryDark: Color(0xFF064E3B),
    roleAccent: Color(0xFFD97706),
    roleGradientStart: Color(0xFF053D2F),
    roleGradientEnd: Color(0xFF059669),
    roleGlow: Color(0x42047857),
    canvasBg: Color(0xFFF2F7F4),
    ambientOrbA: Color(0xFF6EE7B7),
    ambientOrbB: Color(0xFFFCD34D),
    glassFill: Color(0xEBFFFFFF),
    glassFillStrong: Color(0xF7FFFFFF),
    glassBorder: Color(0xFFDCECE4),
    glassHighlight: Color(0xFFD9F7EA),
    textPrimary: Color(0xFF06251C),
    textSecondary: Color(0xFF435B52),
    redText: Color(0xFFDC2626),
    redBg: Color(0xFFFEF2F2),
    redBorder: Color(0xFFFECACA),
    yellowText: Color(0xFFD97706),
    yellowBg: Color(0xFFFFFBEB),
    yellowBorder: Color(0xFFFDE68A),
    grayText: Color(0xFF475569),
    grayBg: Color(0xFFF1F5F3),
    grayBorder: Color(0xFFCBD5E1),
    greenText: Color(0xFF16A34A),
    greenBg: Color(0xFFF0FDF4),
    greenBorder: Color(0xFFBBF7D0),
  );

  static const businessDark = LexRiskColors(
    segment: AccountSegment.business,
    rolePrimary: Color(0xFF10B981),
    rolePrimaryDark: Color(0xFF047857),
    roleAccent: Color(0xFFF59E0B),
    roleGradientStart: Color(0xFF05382B),
    roleGradientEnd: Color(0xFF059669),
    roleGlow: Color(0x5210B981),
    canvasBg: Color(0xFF06110D),
    ambientOrbA: Color(0xFF065F46),
    ambientOrbB: Color(0xFF92400E),
    glassFill: Color(0xCC0C1D17),
    glassFillStrong: Color(0xE610261E),
    glassBorder: Color(0x2634D399),
    glassHighlight: Color(0xFF123026),
    textPrimary: Color(0xFFECFDF5),
    textSecondary: Color(0xFF94A8A0),
    redText: Color(0xFFF87171),
    redBg: Color(0xB33B1219),
    redBorder: Color(0xFF7F1D1D),
    yellowText: Color(0xFFFBBF24),
    yellowBg: Color(0xB336250B),
    yellowBorder: Color(0xFF78350F),
    grayText: Color(0xFF94A3B8),
    grayBg: Color(0xB31E293B),
    grayBorder: Color(0xFF334155),
    greenText: Color(0xFF4ADE80),
    greenBg: Color(0xB30E2B1A),
    greenBorder: Color(0xFF166534),
  );

  static LexRiskColors forConfig(AccountSegment seg, Brightness brightness) {
    return switch ((seg, brightness)) {
      (AccountSegment.individual, Brightness.light) => individualLight,
      (AccountSegment.individual, Brightness.dark) => individualDark,
      (AccountSegment.business, Brightness.light) => businessLight,
      (AccountSegment.business, Brightness.dark) => businessDark,
    };
  }

  @override
  LexRiskColors copyWith({
    AccountSegment? segment,
    Color? rolePrimary,
    Color? rolePrimaryDark,
    Color? roleAccent,
    Color? roleGradientStart,
    Color? roleGradientEnd,
    Color? roleGlow,
    Color? canvasBg,
    Color? ambientOrbA,
    Color? ambientOrbB,
    Color? glassFill,
    Color? glassFillStrong,
    Color? glassBorder,
    Color? glassHighlight,
    Color? textPrimary,
    Color? textSecondary,
    Color? redText,
    Color? redBg,
    Color? redBorder,
    Color? yellowText,
    Color? yellowBg,
    Color? yellowBorder,
    Color? grayText,
    Color? grayBg,
    Color? grayBorder,
    Color? greenText,
    Color? greenBg,
    Color? greenBorder,
  }) {
    return LexRiskColors(
      segment: segment ?? this.segment,
      rolePrimary: rolePrimary ?? this.rolePrimary,
      rolePrimaryDark: rolePrimaryDark ?? this.rolePrimaryDark,
      roleAccent: roleAccent ?? this.roleAccent,
      roleGradientStart: roleGradientStart ?? this.roleGradientStart,
      roleGradientEnd: roleGradientEnd ?? this.roleGradientEnd,
      roleGlow: roleGlow ?? this.roleGlow,
      canvasBg: canvasBg ?? this.canvasBg,
      ambientOrbA: ambientOrbA ?? this.ambientOrbA,
      ambientOrbB: ambientOrbB ?? this.ambientOrbB,
      glassFill: glassFill ?? this.glassFill,
      glassFillStrong: glassFillStrong ?? this.glassFillStrong,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      redText: redText ?? this.redText,
      redBg: redBg ?? this.redBg,
      redBorder: redBorder ?? this.redBorder,
      yellowText: yellowText ?? this.yellowText,
      yellowBg: yellowBg ?? this.yellowBg,
      yellowBorder: yellowBorder ?? this.yellowBorder,
      grayText: grayText ?? this.grayText,
      grayBg: grayBg ?? this.grayBg,
      grayBorder: grayBorder ?? this.grayBorder,
      greenText: greenText ?? this.greenText,
      greenBg: greenBg ?? this.greenBg,
      greenBorder: greenBorder ?? this.greenBorder,
    );
  }

  @override
  LexRiskColors lerp(ThemeExtension<LexRiskColors>? other, double t) {
    if (other is! LexRiskColors) return this;
    return LexRiskColors(
      segment: t < 0.5 ? segment : other.segment,
      rolePrimary: Color.lerp(rolePrimary, other.rolePrimary, t)!,
      rolePrimaryDark: Color.lerp(rolePrimaryDark, other.rolePrimaryDark, t)!,
      roleAccent: Color.lerp(roleAccent, other.roleAccent, t)!,
      roleGradientStart:
          Color.lerp(roleGradientStart, other.roleGradientStart, t)!,
      roleGradientEnd: Color.lerp(roleGradientEnd, other.roleGradientEnd, t)!,
      roleGlow: Color.lerp(roleGlow, other.roleGlow, t)!,
      canvasBg: Color.lerp(canvasBg, other.canvasBg, t)!,
      ambientOrbA: Color.lerp(ambientOrbA, other.ambientOrbA, t)!,
      ambientOrbB: Color.lerp(ambientOrbB, other.ambientOrbB, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassFillStrong: Color.lerp(glassFillStrong, other.glassFillStrong, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      redText: Color.lerp(redText, other.redText, t)!,
      redBg: Color.lerp(redBg, other.redBg, t)!,
      redBorder: Color.lerp(redBorder, other.redBorder, t)!,
      yellowText: Color.lerp(yellowText, other.yellowText, t)!,
      yellowBg: Color.lerp(yellowBg, other.yellowBg, t)!,
      yellowBorder: Color.lerp(yellowBorder, other.yellowBorder, t)!,
      grayText: Color.lerp(grayText, other.grayText, t)!,
      grayBg: Color.lerp(grayBg, other.grayBg, t)!,
      grayBorder: Color.lerp(grayBorder, other.grayBorder, t)!,
      greenText: Color.lerp(greenText, other.greenText, t)!,
      greenBg: Color.lerp(greenBg, other.greenBg, t)!,
      greenBorder: Color.lerp(greenBorder, other.greenBorder, t)!,
    );
  }
}

extension LexThemeX on BuildContext {
  LexRiskColors get lexColors =>
      Theme.of(this).extension<LexRiskColors>() ??
      LexRiskColors.businessLight;
}

class AppTheme {
  const AppTheme._();

  static ThemeData build({
    required AccountSegment segment,
    required Brightness brightness,
  }) {
    final tokens = LexRiskColors.forConfig(segment, brightness);
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: tokens.rolePrimary,
      onPrimary: Colors.white,
      secondary: tokens.roleAccent,
      onSecondary: isDark ? Colors.black : Colors.white,
      error: tokens.redText,
      onError: Colors.white,
      surface: isDark ? const Color(0xFF0F172A) : Colors.white,
      onSurface: tokens.textPrimary,
      surfaceContainerHighest: tokens.canvasBg,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.canvasBg,
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: tokens.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.rolePrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.rolePrimary,
          side: BorderSide(color: tokens.rolePrimary.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.glassFillStrong,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: tokens.glassBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: tokens.glassBorder),
      ),
    );
  }
}
