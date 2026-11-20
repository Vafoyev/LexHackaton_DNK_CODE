import 'package:flutter/material.dart';

/// LexGuard AI 3.2 Semantic Risk & Brand Color Extension.
@immutable
class LexRiskColors extends ThemeExtension<LexRiskColors> {
  const LexRiskColors({
    required this.brandDeepBlue,
    required this.brandPrimaryBlue,
    required this.brandCyan,
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
    required this.cardBorder,
  });

  final Color brandDeepBlue;
  final Color brandPrimaryBlue;
  final Color brandCyan;
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
  final Color cardBorder;

  static const light = LexRiskColors(
    brandDeepBlue: Color(0xFF0B3B8C),
    brandPrimaryBlue: Color(0xFF1463D6),
    brandCyan: Color(0xFF0EA5E9),
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
    cardBorder: Color(0xFFE2E8F0),
  );

  static const dark = LexRiskColors(
    brandDeepBlue: Color(0xFF0A2A66),
    brandPrimaryBlue: Color(0xFF3B82F6),
    brandCyan: Color(0xFF38BDF8),
    redText: Color(0xFFF87171),
    redBg: Color(0xFF3B1219),
    redBorder: Color(0xFF7F1D1D),
    yellowText: Color(0xFFFBBF24),
    yellowBg: Color(0xFF36250B),
    yellowBorder: Color(0xFF78350F),
    grayText: Color(0xFF94A3B8),
    grayBg: Color(0xFF1E293B),
    grayBorder: Color(0xFF334155),
    greenText: Color(0xFF4ADE80),
    greenBg: Color(0xFF0E2B1A),
    greenBorder: Color(0xFF166534),
    cardBorder: Color(0xFF1E293B),
  );

  @override
  LexRiskColors copyWith({
    Color? brandDeepBlue,
    Color? brandPrimaryBlue,
    Color? brandCyan,
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
    Color? cardBorder,
  }) {
    return LexRiskColors(
      brandDeepBlue: brandDeepBlue ?? this.brandDeepBlue,
      brandPrimaryBlue: brandPrimaryBlue ?? this.brandPrimaryBlue,
      brandCyan: brandCyan ?? this.brandCyan,
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
      cardBorder: cardBorder ?? this.cardBorder,
    );
  }

  @override
  LexRiskColors lerp(ThemeExtension<LexRiskColors>? other, double t) {
    if (other is! LexRiskColors) return this;
    return LexRiskColors(
      brandDeepBlue: Color.lerp(brandDeepBlue, other.brandDeepBlue, t)!,
      brandPrimaryBlue: Color.lerp(brandPrimaryBlue, other.brandPrimaryBlue, t)!,
      brandCyan: Color.lerp(brandCyan, other.brandCyan, t)!,
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
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
    );
  }
}

extension LexThemeX on BuildContext {
  LexRiskColors get lexColors =>
      Theme.of(this).extension<LexRiskColors>() ?? LexRiskColors.light;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: Color(0xFF1463D6),
      onPrimary: Colors.white,
      secondary: Color(0xFF0EA5E9),
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: Color(0xFF0F172A),
      surfaceContainerHighest: Color(0xFFF3F6FB),
      error: Color(0xFFDC2626),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF3F6FB),
      extensions: const [LexRiskColors.light],
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B3B8C),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: Color(0xFF3B82F6),
      onPrimary: Colors.white,
      secondary: Color(0xFF38BDF8),
      onSecondary: Color(0xFF0F172A),
      surface: Color(0xFF111827),
      onSurface: Color(0xFFF8FAFC),
      surfaceContainerHighest: Color(0xFF0B1120),
      error: Color(0xFFF87171),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0B1120),
      extensions: const [LexRiskColors.dark],
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A2A66),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF111827),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
