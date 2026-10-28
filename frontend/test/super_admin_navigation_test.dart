import 'package:cobro_app/app/app_theme.dart';
import 'package:cobro_app/features/organizaciones/presentation/widgets/super_admin_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('permite cambiar de sección con navegación superior adaptativa',
      (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    int selectedIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CobroAppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SuperAdminNavigation(
                selectedIndex: selectedIndex,
                onSelected: (int value) {
                  setState(() => selectedIndex = value);
                },
                instituciones: const SizedBox(
                  key: ValueKey<String>('contenido-instituciones'),
                ),
                gestionAcceso: const SizedBox(
                  key: ValueKey<String>('contenido-acceso'),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<SegmentedButton<int>>(
            find.byKey(const ValueKey<String>('super-admin-navigation')),
          )
          .selected,
      <int>{0},
    );
    expect(
      find.byKey(const ValueKey<String>('contenido-instituciones')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.apartment_rounded), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('super-admin-tab-acceso')),
    );
    await tester.pumpAndSettle();

    expect(selectedIndex, 1);
    expect(
      tester
          .widget<SegmentedButton<int>>(
            find.byKey(const ValueKey<String>('super-admin-navigation')),
          )
          .selected,
      <int>{1},
    );
    expect(
      find.byKey(const ValueKey<String>('contenido-acceso')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra iconos cuando dispone de ancho de escritorio',
      (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: CobroAppTheme.light(),
        home: Scaffold(
          body: SuperAdminNavigation(
            selectedIndex: 0,
            onSelected: (_) {},
            instituciones: const SizedBox(),
            gestionAcceso: const SizedBox(),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.apartment_rounded), findsOneWidget);
    expect(find.byIcon(Icons.manage_accounts_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
