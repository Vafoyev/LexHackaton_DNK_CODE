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

  /// Jismoniy shaxs (Personal): Apple Sapphire Ice (#0066FF)
  static const individualLight = LexRiskColors(
    segment: AccountSegment.individual,
    rolePrimary: Color(0xFF0066FF),
    rolePrimaryDark: Color(0xFF0046C7),
    roleAccent: Color(0xFF38BDF8),
    roleGradientStart: Color(0xFF0046C7),
    roleGradientEnd: Color(0xFF0A84FF),
    roleGlow: Color(0x4D0066FF),
    canvasBg: Color(0xFFF2F5FA),
    ambientOrbA: Color(0xFFBFDBFE),
    ambientOrbB: Color(0xFFBAE6FD),
    glassFill: Color(0xB8FFFFFF),
    glassFillStrong: Color(0xE0FFFFFF),
    glassBorder: Color(0xCCFFFFFF),
    glassHighlight: Color(0xFFE0EEFF),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    redText: Color(0xFFDC2626),
    redBg: Color(0xCCFEF2F2),
    redBorder: Color(0xFFFECACA),
    yellowText: Color(0xFFD97706),
    yellowBg: Color(0xCCFFFBEB),
    yellowBorder: Color(0xFFFDE68A),
    grayText: Color(0xFF475569),
    grayBg: Color(0xCCF1F5F9),
    grayBorder: Color(0xFFCBD5E1),
    greenText: Color(0xFF16A34A),
    greenBg: Color(0xCCF0FDF4),
    greenBorder: Color(0xFFBBF7D0),
  );

  static const individualDark = LexRiskColors(
    segment: AccountSegment.individual,
    rolePrimary: Color(0xFF38BDF8),
    rolePrimaryDark: Color(0xFF0A84FF),
    roleAccent: Color(0xFF60A5FA),
    roleGradientStart: Color(0xFF0A3A8A),
    roleGradientEnd: Color(0xFF0284C7),
    roleGlow: Color(0x550A84FF),
    canvasBg: Color(0xFF070B14),
    ambientOrbA: Color(0xFF1E3A8A),
    ambientOrbB: Color(0xFF0C4A6E),
    glassFill: Color(0x99111827),
    glassFillStrong: Color(0xCC111827),
    glassBorder: Color(0x2EFFFFFF),
    glassHighlight: Color(0xFF1E293B),
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

  /// Yuridik shaxs (Business / B2B): Deep Executive Emerald (#047857) + Champagne Gold
  static const businessLight = LexRiskColors(
    segment: AccountSegment.business,
    rolePrimary: Color(0xFF047857),
    rolePrimaryDark: Color(0xFF064E3B),
    roleAccent: Color(0xFFB45309),
    roleGradientStart: Color(0xFF064E3B),
    roleGradientEnd: Color(0xFF059669),
    roleGlow: Color(0x4D047857),
    canvasBg: Color(0xFFF2F7F5),
    ambientOrbA: Color(0xFFA7F3D0),
    ambientOrbB: Color(0xFFFDE68A),
    glassFill: Color(0xB8FFFFFF),
    glassFillStrong: Color(0xE0FFFFFF),
    glassBorder: Color(0xCCFFFFFF),
    glassHighlight: Color(0xFFD1FAE5),
    textPrimary: Color(0xFF06281E),
    textSecondary: Color(0xFF3B5249),
    redText: Color(0xFFDC2626),
    redBg: Color(0xCCFEF2F2),
    redBorder: Color(0xFFFECACA),
    yellowText: Color(0xFFD97706),
    yellowBg: Color(0xCCFFFBEB),
    yellowBorder: Color(0xFFFDE68A),
    grayText: Color(0xFF475569),
    grayBg: Color(0xCCF1F5F9),
    grayBorder: Color(0xFFCBD5E1),
    greenText: Color(0xFF16A34A),
    greenBg: Color(0xCCF0FDF4),
    greenBorder: Color(0xFFBBF7D0),
  );

  static const businessDark = LexRiskColors(
    segment: AccountSegment.business,
    rolePrimary: Color(0xFF10B981),
    rolePrimaryDark: Color(0xFF065F46),
    roleAccent: Color(0xFFFBBF24),
    roleGradientStart: Color(0xFF064E3B),
    roleGradientEnd: Color(0xFF059669),
    roleGlow: Color(0x5510B981),
    canvasBg: Color(0xFF06110E),
    ambientOrbA: Color(0xFF064E3B),
    ambientOrbB: Color(0xFF78350F),
    glassFill: Color(0x990B1C16),
    glassFillStrong: Color(0xCC0B1C16),
    glassBorder: Color(0x2EFFFFFF),
    glassHighlight: Color(0xFF0F2921),
    textPrimary: Color(0xFFECFDF5),
    textSecondary: Color(0xFF9CA3AF),
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
          foregroundColor: tokens.rolePrimaryDark,
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
