import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexguard_mobile/app/app.dart';
import 'package:lexguard_mobile/core/theme/app_theme.dart';

void main() {
  testWidgets(
      'Full iOS Glassmorphism Flow: Splash -> Onboarding -> Role Select -> Login -> Home -> Analysis',
      (tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const LexGuardApp(splashDelay: Duration(milliseconds: 150)),
    );
    await tester.pump();

    // 1. Splash Screen renders cleanly
    expect(find.byKey(const Key('splash_screen')), findsOneWidget);
    expect(find.text('LexGuard AI'), findsOneWidget);
    expect(
      find.text('Imzolashdan oldin shartnomani tekshiring'),
      findsOneWidget,
    );

    // Wait for auto-navigation to Onboarding
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();

    // 2. Onboarding 3 slides -> finish
    expect(find.byKey(const Key('onboarding_screen')), findsOneWidget);
    expect(find.text('Bandma-band aqlli tekshiruv'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_next_btn')));
    await tester.pumpAndSettle();
    expect(find.text('Shaxsiy ma’lumotlar lokal himoyada'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_next_btn')));
    await tester.pumpAndSettle();
    expect(find.text('Lex.uz havola va 2 xil DOCX eksport'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_next_btn')));
    await tester.pumpAndSettle();

    // 3. Role Selection screen renders with the dual-role question
    expect(find.byKey(const Key('role_select_screen')), findsOneWidget);
    expect(
      find.text('Yuridik shaxsmisiz yoki Jismoniy shaxs?'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('role_card_individual')), findsOneWidget);
    expect(find.byKey(const Key('role_card_business')), findsOneWidget);

    // 4. Select Yuridik shaxs -> Login in Deep Executive Emerald (#047857)
    await tester.tap(find.byKey(const Key('role_card_business')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_screen')), findsOneWidget);
    expect(find.text('E-IMZO / ERI bilan kirish (Mock)'), findsOneWidget);
    final loginCtx =
        tester.element(find.byKey(const Key('login_primary_auth_btn')));
    expect(loginCtx.lexColors.rolePrimary, const Color(0xFF047857));

    // Complete Mock E-IMZO login -> Home
    await tester.tap(find.byKey(const Key('login_primary_auth_btn')));
    await tester.pumpAndSettle();

    expect(find.text('DNK Tech MChJ'), findsOneWidget);
    expect(find.byKey(const Key('center_scan_fab')), findsOneWidget);
    expect(find.text('Asosiy'), findsOneWidget);
    expect(find.text('Hujjatlar'), findsOneWidget);
    expect(find.text('Qonunlar'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    // 5. Switch role to Jismoniy shaxs -> Sapphire (#0066FF)
    await tester.tap(find.byKey(const Key('role_switch_pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_switch_individual')));
    await tester.pumpAndSettle();

    final homeCtx = tester.element(find.text('Vafoyev Isobek · Shaxsiy'));
    expect(homeCtx.lexColors.rolePrimary, const Color(0xFF0066FF));

    // 6. Open Floating Scan Orb -> Run B2B Service Demo -> Analysis Detail
    await tester.tap(find.byKey(const Key('center_scan_fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scan_quick_upload')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo_sample_service')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.textContaining('Taraf balansi'), findsOneWidget);
    expect(find.textContaining('Eng muhim 3 ta muammo'), findsOneWidget);
    expect(find.textContaining('Xavf indeksi:'), findsNothing);
  });
}
