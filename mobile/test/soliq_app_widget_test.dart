import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexguard_mobile/app/app.dart';
import 'package:lexguard_mobile/core/theme/app_theme.dart';

void main() {
  testWidgets(
      'Dual-role iOS Glassmorphism UI: Sapphire Individual & Emerald Business + Floating Navbar + Demo Analysis',
      (tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const LexGuardApp());
    await tester.pumpAndSettle();

    // 1. Role Select entry screen renders both roles cleanly
    expect(find.byKey(const Key('role_card_individual')), findsOneWidget);
    expect(find.byKey(const Key('role_card_business')), findsOneWidget);

    // 2. Tap Yuridik shaxs -> Executive Emerald (#047857)
    await tester.tap(find.byKey(const Key('role_card_business')));
    await tester.pumpAndSettle();

    final ctxBusiness = tester.element(find.text('DNK Tech MChJ'));
    expect(ctxBusiness.lexColors.rolePrimary, const Color(0xFF047857));

    // iPhone Floating Glass Navbar & 4 tabs
    expect(find.byKey(const Key('center_scan_fab')), findsOneWidget);
    expect(find.text('Asosiy'), findsOneWidget);
    expect(find.text('Hujjatlar'), findsOneWidget);
    expect(find.text('Qonunlar'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    // 3. Switch role to Jismoniy shaxs via quick role pill -> Sapphire (#0066FF)
    await tester.tap(find.byKey(const Key('role_switch_pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jismoniy shaxs (Sapphire Ko‘k)'));
    await tester.pumpAndSettle();

    final ctxIndividual =
        tester.element(find.text('Vafoyev Isobek · Shaxsiy'));
    expect(ctxIndividual.lexColors.rolePrimary, const Color(0xFF0066FF));

    // 4. Open iPhone Floating Glass Scan button & run B2B Service demo
    await tester.tap(find.byKey(const Key('center_scan_fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('demo_sample_service')), findsOneWidget);
    await tester.tap(find.byKey(const Key('demo_sample_service')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // 5. Verify Analysis Detail per 3.2 (4 colors + Neutrality, NO fake % score)
    expect(find.textContaining('Taraf balansi'), findsOneWidget);
    expect(find.textContaining('Eng muhim 3 ta muammo'), findsOneWidget);
    expect(find.textContaining('Xavf indeksi:'), findsNothing);
  });
}
