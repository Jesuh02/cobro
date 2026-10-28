import 'package:cobro_app/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Map<String, dynamic> jsonCompleto = <String, dynamic>{
    'id': '11111111-1111-1111-1111-111111111111',
    'usuario': 'ana.admin',
    'nombreCompleto': 'Ana Admin',
    'nombres': 'Ana',
    'apellidos': 'Admin',
    'identificacion': '1000123456',
    'correo': 'ana@example.com',
    'telefono': '3001234567',
    'activo': true,
    'organizacionId': '22222222-2222-2222-2222-222222222222',
    'organizacionNombre': 'Institución Demo',
    'organizacionSuspendida': false,
    'roles': <String>['ADMINISTRADOR', 'AUDITOR'],
    'creadoEn': '2026-10-27T14:30:00.000Z',
  };

  test('deserializa todos los campos y expone helpers de interfaz', () {
    final UsuarioSuperAdminItem item =
        UsuarioSuperAdminItem.fromJson(jsonCompleto);

    expect(item.id, '11111111-1111-1111-1111-111111111111');
    expect(item.nombreVisible, 'Ana Admin');
    expect(item.organizacionVisible, 'Institución Demo');
    expect(item.esAdministrador, isTrue);
    expect(item.esAdmin, isTrue);
    expect(item.esAuditor, isTrue);
    expect(item.esCobrador, isFalse);
    expect(item.creadoEn, DateTime.utc(2026, 10, 27, 14, 30));
  });

  test('tolera campos opcionales nulos y usa textos de respaldo', () {
    final UsuarioSuperAdminItem item = UsuarioSuperAdminItem.fromJson(
      <String, dynamic>{
        ...jsonCompleto,
        'nombreCompleto': '',
        'identificacion': null,
        'telefono': null,
        'organizacionId': null,
        'organizacionNombre': null,
        'roles': null,
        'creadoEn': null,
      },
    );

    expect(item.nombreVisible, 'Ana Admin');
    expect(item.organizacionVisible, 'Sin institución');
    expect(item.identificacion, isNull);
    expect(item.roles, isEmpty);
    expect(item.creadoEn, isNull);
  });

  test('copyWith permite una actualización optimista sin mutar el original',
      () {
    final UsuarioSuperAdminItem original =
        UsuarioSuperAdminItem.fromJson(jsonCompleto);
    final UsuarioSuperAdminItem actualizado = original.copyWith(activo: false);

    expect(original.activo, isTrue);
    expect(actualizado.activo, isFalse);
    expect(actualizado.id, original.id);
    expect(actualizado.toJson()['roles'], original.roles);
  });
}
