import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouedna_admin/features/dashboard/presentation/tabs/place_form_dialog.dart';

void main() {
  testWidgets('نموذج المعلم يفتح اختيار الخريطة على هاتف صغير دون استثناء',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceFormDialog(tileProvider: AssetTileProvider()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('تحديد موقع المعلم'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('من الخريطة'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('من الخريطة'));
    await tester.pump();

    expect(find.byType(FlutterMap), findsOneWidget);
  });
}
