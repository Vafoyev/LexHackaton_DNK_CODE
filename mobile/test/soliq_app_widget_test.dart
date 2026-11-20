import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexguard_mobile/app/app.dart';

void main() {
  testWidgets(
      'Soliq-style LexGuard mobile UI renders 4 tabs, Center Scan FAB and runs demo analysis',
      (tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const LexGuardApp());
    await tester.pumpAndSettle();

    // Soliq Home structure checks
    expect(find.text('DNK Tech MChJ'), findsOneWidget);
    expect(find.text('Tezkor xizmatlar'), findsOneWidget);
    expect(find.text('Oxirgi tekshiruvlar'), findsOneWidget);
    expect(find.byKey(const Key('center_scan_fab')), findsOneWidget);

    // 4 Bottom Bar tabs present
    expect(find.text('Asosiy'), findsOneWidget);
    expect(find.text('Hujjatlar'), findsOneWidget);
    expect(find.text('Qonunlar'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    // Open Center Scan BottomSheet and launch B2B Service demo
    await tester.tap(find.byKey(const Key('center_scan_fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('demo_sample_service')), findsOneWidget);
    await tester.tap(find.byKey(const Key('demo_sample_service')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Verify Analysis Detail screen per 3.2 (4 colors + Neutrality, NO fake % score)
    expect(find.textContaining('Taraf balansi'), findsOneWidget);
    expect(find.textContaining('Eng muhim 3 ta muammo'), findsOneWidget);
    expect(find.textContaining('Xavf indeksi:'), findsNothing);
  });
}
