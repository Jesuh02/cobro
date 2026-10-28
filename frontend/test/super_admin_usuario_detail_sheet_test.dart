import 'package:cobro_app/app/app_theme.dart';
import 'package:cobro_app/core/constants/permisos_constants.dart';
import 'package:cobro_app/core/ui/island_modal_sheet.dart';
import 'package:cobro_app/data/models/models.dart';
import 'package:cobro_app/features/organizaciones/presentation/widgets/super_admin_usuario_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String _organizacionId = '33333333-3333-3333-3333-333333333333';

void main() {
  testWidgets('edita y guarda permisos individuales de un cobrador',
      (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final UsuarioSuperAdminItem usuario = _usuario(
      roles: const <String>['COBRADOR'],
      permisos: const <String>[permisoCrearCajaMenor],
    );
    List<String>? permisosGuardados;
    String? mensaje;

    await tester.pumpWidget(
      _app(
        usuario: usuario,
        onGuardar: (UsuarioSuperAdminItem actual, List<String> permisos) async {
          permisosGuardados = permisos;
          return actual.copyWith(permisos: permisos);
        },
        onMensaje: (String value) => mensaje = value,
      ),
    );
    await tester.tap(find.text('Abrir detalle'));
    await tester.pumpAndSettle();

    expect(find.byType(IslandModalSheet), findsOneWidget);
    expect(find.text('Identificación'), findsOneWidget);

    await tester.tap(find.text('Permisos'));
    await tester.pumpAndSettle();

    final Finder crearCaja = find.byKey(
      const ValueKey<String>('permiso-usuario-$permisoCrearCajaMenor'),
    );
    final Finder crearCredito = find.byKey(
      const ValueKey<String>('permiso-usuario-$permisoCrearCreditos'),
    );
    expect(tester.widget<CheckboxListTile>(crearCaja).value, isTrue);
    await tester.ensureVisible(crearCredito);
    await tester.tap(crearCredito);
    await tester.pump();

    await tester.tap(
      find.byKey(
        const ValueKey<String>('guardar-permisos-usuario'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      permisosGuardados,
      <String>[permisoCrearCajaMenor, permisoCrearCreditos],
    );
    expect(mensaje, 'Permisos actualizados');
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(
              const ValueKey<String>('guardar-permisos-usuario'),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra permisos heredados de administrador en solo lectura',
      (WidgetTester tester) async {
    final UsuarioSuperAdminItem usuario = _usuario(
      roles: const <String>['ADMINISTRADOR'],
      permisos: permisosEmpleadoCodigos,
    );

    await tester.pumpWidget(
      _app(
        usuario: usuario,
        onGuardar: (UsuarioSuperAdminItem actual, _) async => actual,
      ),
    );
    await tester.tap(find.text('Abrir detalle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permisos'));
    await tester.pumpAndSettle();

    expect(find.text('Permisos heredados'), findsOneWidget);
    expect(
      find.text(
        'Este usuario recibe sus permisos por un rol elevado y no admite excepciones individuales.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(
              const ValueKey<String>(
                'permiso-usuario-$permisoCrearCajaMenor',
              ),
            ),
          )
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(
              const ValueKey<String>('guardar-permisos-usuario'),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required UsuarioSuperAdminItem usuario,
  required Future<UsuarioSuperAdminItem> Function(
    UsuarioSuperAdminItem usuario,
    List<String> permisos,
  ) onGuardar,
  void Function(String mensaje)? onMensaje,
}) {
  return MaterialApp(
    theme: CobroAppTheme.light(),
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) {
          return Center(
            child: FilledButton(
              onPressed: () async {
                await mostrarSuperAdminUsuarioDetalleSheet(
                  context: context,
                  usuario: usuario,
                  onGuardarPermisos: onGuardar,
                  mensajeError: (Object error) => error.toString(),
                  mostrarMensaje: onMensaje,
                );
              },
              child: const Text('Abrir detalle'),
            ),
          );
        },
      ),
    ),
  );
}

UsuarioSuperAdminItem _usuario({
  required List<String> roles,
  required List<String> permisos,
}) {
  return UsuarioSuperAdminItem.fromJson(<String, dynamic>{
    'id': '22222222-2222-2222-2222-222222222222',
    'usuario': 'empleado.uno',
    'nombreCompleto': 'Empleado Uno',
    'nombres': 'Empleado',
    'apellidos': 'Uno',
    'identificacion': '100200300',
    'correo': 'empleado@cobro.test',
    'telefono': '3001234567',
    'activo': true,
    'organizacionId': _organizacionId,
    'organizacionNombre': 'Institución Uno',
    'organizacionSuspendida': false,
    'roles': roles,
    'permisos': permisos,
    'creadoEn': '2026-10-27T14:30:00.000Z',
  });
}
