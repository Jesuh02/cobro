import 'package:cobro_app/app/app_theme.dart';
import 'package:cobro_app/data/models/models.dart';
import 'package:cobro_app/features/clientes/presentation/widgets/cliente_detalle_sheet.dart';
import 'package:cobro_app/features/clientes/presentation/widgets/cliente_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Cliente clientePrueba = Cliente(
    id: 'cli-123',
    nombreCompleto: 'Jennifer Arroyo',
    nombreComercial: 'Tienda La Esquina',
    cedula: '1119390987',
    telefono: '3001234567',
    direccion: 'Cra 15 # 24-12, Barrio Centro',
    correo: 'jennifer@example.com',
    estadoNombre: 'Activo',
    latitude: 4.60971,
    longitude: -74.08175,
  );

  Widget crearEntornoTest(Widget child) {
    return MaterialApp(
      theme: CobroAppTheme.light(),
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  testWidgets('ClienteItem muestra datos clave y responde al toque', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    bool modificado = false;
    bool eliminado = false;

    await tester.pumpWidget(
      crearEntornoTest(
        ClienteItem(
          cliente: clientePrueba,
          esAdministrador: true,
          puedeModificar: true,
          puedeEliminar: true,
          onTap: () => tapped = true,
          onModificar: () => modificado = true,
          onEliminar: () => eliminado = true,
        ),
      ),
    );

    // Verificación de datos en tarjeta
    expect(find.text('Jennifer Arroyo'), findsOneWidget);
    expect(find.text('Tienda La Esquina'), findsOneWidget);
    expect(find.text('CC 1119390987'), findsOneWidget);
    expect(find.text('3001234567'), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);

    // Simular tap sobre la tarjeta completa
    await tester.tap(find.text('Jennifer Arroyo'));
    await tester.pump();
    expect(tapped, isTrue);
    expect(modificado, isFalse);
    expect(eliminado, isFalse);
  });

  testWidgets('ClienteDetalleSheet despliega todos los datos y permite acciones', (
    WidgetTester tester,
  ) async {
    bool modificado = false;
    bool eliminado = false;
    String? datoCopiado;

    await tester.pumpWidget(
      crearEntornoTest(
        ClienteDetalleSheet(
          cliente: clientePrueba,
          esAdministrador: true,
          puedeModificar: true,
          puedeEliminar: true,
          onModificar: () => modificado = true,
          onEliminar: () => eliminado = true,
          onCopiarDato: (String etiqueta, String valor) {
            datoCopiado = '$etiqueta: $valor';
          },
        ),
      ),
    );

    // Datos detallados
    expect(find.text('Jennifer Arroyo'), findsOneWidget);
    expect(find.text('Tienda La Esquina'), findsOneWidget);
    expect(find.text('CC 1119390987'), findsOneWidget);
    expect(find.text('3001234567'), findsOneWidget);
    expect(find.text('Cra 15 # 24-12, Barrio Centro'), findsOneWidget);
    expect(find.text('jennifer@example.com'), findsOneWidget);
    expect(find.textContaining('Coordenadas: 4.60971, -74.08175'), findsOneWidget);

    // Acción de copiar cédula
    final Finder botonCopiarCedula = find.byTooltip('Copiar Documento / Cédula');
    expect(botonCopiarCedula, findsOneWidget);
    await tester.tap(botonCopiarCedula);
    await tester.pump();
    expect(datoCopiado, equals('Documento / Cédula: 1119390987'));

    // Acción de modificar
    final Finder botonModificar = find.widgetWithText(FilledButton, 'Modificar');
    expect(botonModificar, findsOneWidget);
    await tester.tap(botonModificar);
    await tester.pump();
    expect(modificado, isTrue);
  });
}
