/// Uzbek Latin alphabet utilities supporting both the proposed reformed
/// orthography (`Ğ ğ`, `Ö ö`, `Ş ş`, `Ç ç`) and standard Uzbek Latin
/// (`G‘ g‘`, `O‘ o‘`, `Sh sh`, `Ch ch`).
enum UzbekScript {
  /// Yangi takomillashtirilgan alifbo: `G‘ -> Ğ`, `O‘ -> Ö`, `Sh -> Ş`, `Ch -> Ç`.
  reformed,

  /// An’anaviy lotin alifbosi: `O‘`, `G‘`, `Sh`, `Ch`.
  standard,
}

extension UzbekScriptX on UzbekScript {
  String get shortCode => switch (this) {
        UzbekScript.reformed => 'ĞÖŞÇ',
        UzbekScript.standard => 'O‘G‘',
      };
}

class UzbekAlphabet {
  const UzbekAlphabet._();

  static final RegExp _protectedPattern = RegExp(
    r'https?://[^\s)\]]+|'
    r'lex\.uz[^\s)\]]*|'
    r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|'
    r'\b(?:FLAG_SECURE|Lock-in|E-IMZO|LexGuard|OneID|Unknown|Sapphire|Emerald|'
    r'Desktop|Workspace|Preview|Business|Verifier|Verifier\.go|Passport|'
    r'Imperative|IMPERATIVE|Dispositive|DISPOSITIVE|Unknown|Camera|Upload|'
    r'WhatsApp|Telegram|Chrome|Flutter|FaceID|Unknown|Email|email|Dark|Light|'
    r'Mode|Tech|Mock|MOCK|DOCX|PDF|TXT|JPG|PNG|EXIF|SHA|PII|B2B|B2C|MVP|'
    r'Click|Payme|iPhone|iOS|LOYIHA|Pro|Go|AI|R1|R5|R6|Rule)\b',
  );

  static final RegExp _upperO = RegExp(r"O[‘'ʻ`]");
  static final RegExp _lowerO = RegExp(r"o[‘'ʻ`]");
  static final RegExp _upperG = RegExp(r"G[‘'ʻ`]");
  static final RegExp _lowerG = RegExp(r"g[‘'ʻ`]");

  /// Formats Uzbek text according to [script].
  /// Protects URLs, emails, and English/technical/brand identifiers before
  /// applying the 4 reformed Uzbek letter mappings (`G‘/O‘/Sh/Ch -> Ğ/Ö/Ş/Ç`).
  static String format(String text, UzbekScript script) {
    if (script == UzbekScript.standard || text.isEmpty) {
      return text;
    }

    final preserved = <String>[];
    final masked = text.replaceAllMapped(_protectedPattern, (match) {
      final token = '\uE000${preserved.length}\uE001';
      preserved.add(match.group(0)!);
      return token;
    });

    final converted = masked
        .replaceAll(_upperO, 'Ö')
        .replaceAll(_lowerO, 'ö')
        .replaceAll(_upperG, 'Ğ')
        .replaceAll(_lowerG, 'ğ')
        .replaceAll('SH', 'Ş')
        .replaceAll('Sh', 'Ş')
        .replaceAll('sh', 'ş')
        .replaceAll('CH', 'Ç')
        .replaceAll('Ch', 'Ç')
        .replaceAll('ch', 'ç');

    if (preserved.isEmpty) {
      return converted;
    }

    var result = converted;
    for (var i = 0; i < preserved.length; i++) {
      result = result.replaceAll('\uE000$i\uE001', preserved[i]);
    }
    return result;
  }
}
