import 'package:cobro_app/app/app_theme.dart';
import 'package:cobro_app/data/models/models.dart';
import 'package:cobro_app/features/organizaciones/presentation/super_admin_activacion_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String usuarioActualId = '11111111-1111-1111-1111-111111111111';
const String administradorId = '22222222-2222-2222-2222-222222222222';
const String organizacionId = '33333333-3333-3333-3333-333333333333';

void main() {
  final OrganizacionAdmin organizacion = OrganizacionAdmin.fromJson(
    <String, dynamic>{
      'id': organizacionId,
      'nombre': 'Institución Uno',
      'telefono': null,
      'correo': 'contacto@institucion.test',
      'activo': true,
      'esSistema': false,
      'montoPlan': 0,
      'monedaPlan': 'COP',
      'accesoHasta': null,
      'suspendidaEn': null,
      'motivoSuspension': null,
      'suspendida': false,
      'diasRestantes': null,
      'usuariosTotal': 2,
      'usuariosActivos': 1,
      'administradores': <String>['admin.uno'],
    },
  );

  final List<UsuarioSuperAdminItem> usuarios = <UsuarioSuperAdminItem>[
    _usuario(
      id: usuarioActualId,
      usuario: 'super.admin',
      nombre: 'Super Administrador',
      activo: true,
      roles: const <String>['SUPER_ADMIN'],
    ),
    _usuario(
      id: administradorId,
      usuario: 'admin.uno',
      nombre: 'Administrador Uno',
      activo: true,
      roles: const <String>['ADMINISTRADOR'],
    ),
  ];

  testWidgets('muestra filtros, métricas y protege al usuario actual',
      (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    String? organizacionSeleccionada;
    String? consulta;
    await tester.pumpWidget(
      _app(
        SuperAdminActivacionView(
          usuarios: usuarios,
          organizaciones: <OrganizacionAdmin>[organizacion],
          usuarioActualId: usuarioActualId,
          organizacionSeleccionadaId: null,
          consulta: '',
          cargando: false,
          actualizandoIds: const <String>{},
          onRefresh: () async {},
          onOrganizacionChanged: (String? value) {
            organizacionSeleccionada = value;
          },
          onConsultaChanged: (String value) {
            consulta = value;
          },
          onEstadoChanged: (_, __) async {},
        ),
      ),
    );

    expect(find.text('Gestión de acceso'), findsOneWidget);
    expect(find.text('Todas las instituciones'), findsOneWidget);
    expect(find.text('Eres tú'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('metrica-usuarios-total'),
        ),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Switch>(
            find.byKey(
              const ValueKey<String>('estado-usuario-$usuarioActualId'),
            ),
          )
          .onChanged,
      isNull,
    );

    final Finder selectorInstitucion = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.labelText == 'Institución',
    );
    await tester.tap(selectorInstitucion);
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('organizacion-picker-$organizacionId'),
      ),
    );
    await tester.pump();
    expect(organizacionSeleccionada, organizacionId);

    await tester.enterText(
      find.byKey(
        const ValueKey<String>('buscar-usuarios-super-admin'),
      ),
      'Administrador',
    );
    expect(consulta, 'Administrador');
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirma antes de desactivar un administrador',
      (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    UsuarioSuperAdminItem? usuarioActualizado;
    bool? estadoSolicitado;
    await tester.pumpWidget(
      _app(
        SuperAdminActivacionView(
          usuarios: usuarios,
          organizaciones: <OrganizacionAdmin>[organizacion],
          usuarioActualId: usuarioActualId,
          organizacionSeleccionadaId: null,
          consulta: '',
          cargando: false,
          actualizandoIds: const <String>{},
          onRefresh: () async {},
          onOrganizacionChanged: (_) {},
          onConsultaChanged: (_) {},
          onEstadoChanged: (UsuarioSuperAdminItem usuario, bool activo) async {
            usuarioActualizado = usuario;
            estadoSolicitado = activo;
          },
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('estado-usuario-$administradorId'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Desactivar administrador'), findsOneWidget);
    expect(usuarioActualizado, isNull);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('confirmar-desactivar-admin'),
      ),
    );
    await tester.pumpAndSettle();

    expect(usuarioActualizado?.id, administradorId);
    expect(estadoSolicitado, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: CobroAppTheme.light(),
    home: Scaffold(body: child),
  );
}

UsuarioSuperAdminItem _usuario({
  required String id,
  required String usuario,
  required String nombre,
  required bool activo,
  required List<String> roles,
}) {
  return UsuarioSuperAdminItem.fromJson(<String, dynamic>{
    'id': id,
    'usuario': usuario,
    'nombreCompleto': nombre,
    'nombres': nombre.split(' ').first,
    'apellidos': nombre.split(' ').skip(1).join(' '),
    'identificacion': '100$id',
    'correo': '$usuario@cobro.test',
    'telefono': '3001234567',
    'activo': activo,
    'organizacionId': organizacionId,
    'organizacionNombre': 'Institución Uno',
    'organizacionSuspendida': false,
    'roles': roles,
    'creadoEn': '2026-10-27T14:30:00.000Z',
  });
}
