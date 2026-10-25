import 'package:cobro_app/app/app_theme.dart';
import 'package:cobro_app/data/models/models.dart';
import 'package:cobro_app/features/creditos/presentation/widgets/credito_detalle_sheet.dart';
import 'package:cobro_app/features/creditos/presentation/widgets/tarjeta_credito_registro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final CreditoRegistro creditoPrueba = CreditoRegistro(
    id: 'cred-101',
    clienteId: 'cli-001',
    cliente: 'Carlos Alberto Perez',
    cedula: '1098765432',
    negocio: 'Tienda La Esperanza',
    direccion: 'Calle 10 # 5-20',
    rutaId: 'ruta-1',
    ruta: 'Ruta Norte',
    cajaMenorId: 'caja-1',
    cajaMenor: 'Caja Principal 01',
    monedaCodigo: 'COP',
    frecuenciaPago: const FrecuenciaPago(
      id: 1,
      codigo: 'DIARIO',
      nombre: 'Diario',
      diasIntervalo: 1,
    ),
    estado: const EstadoCreditoRegistro(
      codigo: 'ACTIVO',
      nombre: 'Activo',
    ),
    fechaInicio: DateTime(2026, 10, 1),
    fechaMaxima: DateTime(2026, 10, 31),
    valorPrincipal: 1000000,
    porcentajeInteres: 20,
    plazoDias: 30,
    omitirDomingos: true,
    valorTotal: 1200000,
    valorCuota: 40000,
    totalAbonado: 720000,
    saldo: 480000,
    numeroCuotas: 30,
    cuotasRestantes: 12,
  );

  Widget crearEntornoTest(Widget child) {
    return MaterialApp(
      theme: CobroAppTheme.light(),
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('TarjetaCreditoRegistro', () {
    testWidgets('renderiza métricas compactas (Saldo, Cuota, Cuotas) y responde al toque', (
      WidgetTester tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        crearEntornoTest(
          TarjetaCreditoRegistro(
            credito: creditoPrueba,
            puedeModificar: true,
            puedeEliminar: true,
            onModificar: () {},
            onEliminar: () {},
            onRefinanciar: () {},
            onTap: () => tapped = true,
          ),
        ),
      );

      // Verificación de datos de cabecera y ruta
      expect(find.text('Carlos Alberto Perez'), findsOneWidget);
      expect(find.textContaining('1098765432'), findsOneWidget);
      expect(find.textContaining('Ruta Norte'), findsOneWidget);
      expect(find.text('Activo'), findsOneWidget);

      // Verificación de 3 métricas clave
      expect(find.text('Saldo'), findsOneWidget);
      expect(find.text('Cuota'), findsOneWidget);
      expect(find.text('Pagadas'), findsOneWidget);
      expect(find.text('18 / 30'), findsOneWidget);

      // Simular tap para abrir detalle
      await tester.tap(find.byType(TarjetaCreditoRegistro));
      expect(tapped, isTrue);
    });
  });

  group('CreditoDetalleSheet', () {
    testWidgets('despliega balance financiero, condiciones, fechas y permite acciones', (
      WidgetTester tester,
    ) async {
      bool refinanciarPressed = false;
      String? mensajeCopiado;

      await tester.pumpWidget(
        crearEntornoTest(
          Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () {
                  mostrarCreditoDetalleSheet(
                    context: context,
                    credito: creditoPrueba,
                    puedeModificar: true,
                    puedeEliminar: true,
                    puedeRefinanciar: true,
                    onModificar: () {},
                    onEliminar: () {},
                    onRefinanciar: () => refinanciarPressed = true,
                    mostrarMensaje: (String msg) => mensajeCopiado = msg,
                  );
                },
                child: const Text('Abrir Detalle'),
              );
            },
          ),
        ),
      );

      // Abrir el sheet
      await tester.tap(find.text('Abrir Detalle'));
      await tester.pumpAndSettle();

      // Verificar que el modal flotante está visible
      expect(find.byType(CreditoDetalleSheet), findsOneWidget);
      expect(find.text('Carlos Alberto Perez'), findsOneWidget);
      expect(find.text('CC 1098765432'), findsOneWidget);
      expect(find.text('Ruta Norte'), findsOneWidget);

      // Secciones
      expect(find.text('Balance y Recaudo'), findsOneWidget);
      expect(find.text('Condiciones del Crédito'), findsOneWidget);
      expect(find.text('Fechas y Trazabilidad'), findsOneWidget);

      // Datos financieros
      expect(find.text('Saldo pendiente'), findsOneWidget);
      expect(find.text('Total con intereses'), findsOneWidget);
      expect(find.text('Principal prestado'), findsOneWidget);
      expect(find.text('Valor por cuota'), findsOneWidget);

      // Botón copiar cédula
      final Finder botonCopiar = find.byTooltip('Copiar cédula');
      expect(botonCopiar, findsOneWidget);
      await tester.tap(botonCopiar);
      await tester.pump();
      expect(mensajeCopiado, contains('copiado al portapapeles'));

      // Botones de acción en footer
      expect(find.text('Cerrar'), findsOneWidget);
      expect(find.text('Refinanciar crédito'), findsOneWidget);

      // Probar callback de refinanciar
      await tester.tap(find.text('Refinanciar crédito'));
      await tester.pumpAndSettle();
      expect(refinanciarPressed, isTrue);
      // El sheet se debió cerrar tras la acción
      expect(find.byType(CreditoDetalleSheet), findsNothing);
    });
  });
}
