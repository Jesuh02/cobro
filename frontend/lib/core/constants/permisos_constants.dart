const String permisoCrearCajaMenor = 'CREAR_CAJA_MENOR';
const String permisoRegistrarFlujoCaja = 'REGISTRAR_FLUJO_CAJA';
const String permisoCrearCreditos = 'CREAR_CREDITOS';
const String permisoRefinanciarCreditos = 'REFINANCIAR_CREDITOS';
const String permisoModificarCreditos = 'MODIFICAR_CREDITOS';
const String permisoEliminarCreditos = 'ELIMINAR_CREDITOS';
const String permisoModificarClientes = 'MODIFICAR_CLIENTES';
const String permisoEliminarClientes = 'ELIMINAR_CLIENTES';
const String permisoAgregarCuota = 'AGREGAR_CUOTA';
const String permisoModificarMovimientos = 'MODIFICAR_MOVIMIENTOS';

enum GrupoPermisoEmpleado {
  caja,
  creditos,
  clientes,
  movimientos,
}

class PermisoEmpleadoDef {
  const PermisoEmpleadoDef({
    required this.codigo,
    required this.nombre,
    required this.descripcion,
    required this.grupo,
  });

  final String codigo;
  final String nombre;
  final String descripcion;
  final GrupoPermisoEmpleado grupo;
}

const List<PermisoEmpleadoDef> permisosEmpleado = <PermisoEmpleadoDef>[
  PermisoEmpleadoDef(
    codigo: permisoCrearCajaMenor,
    nombre: 'Crear caja menor',
    descripcion: 'Permite crear nuevas cajas menores.',
    grupo: GrupoPermisoEmpleado.caja,
  ),
  PermisoEmpleadoDef(
    codigo: permisoRegistrarFlujoCaja,
    nombre: 'Registrar flujo en caja menor',
    descripcion: 'Permite registrar entradas y salidas de caja.',
    grupo: GrupoPermisoEmpleado.caja,
  ),
  PermisoEmpleadoDef(
    codigo: permisoCrearCreditos,
    nombre: 'Crear créditos',
    descripcion: 'Permite registrar créditos para los clientes.',
    grupo: GrupoPermisoEmpleado.creditos,
  ),
  PermisoEmpleadoDef(
    codigo: permisoRefinanciarCreditos,
    nombre: 'Refinanciar créditos',
    descripcion: 'Permite reemplazar el plan de un crédito vigente.',
    grupo: GrupoPermisoEmpleado.creditos,
  ),
  PermisoEmpleadoDef(
    codigo: permisoModificarCreditos,
    nombre: 'Modificar créditos',
    descripcion: 'Permite editar las condiciones de los créditos.',
    grupo: GrupoPermisoEmpleado.creditos,
  ),
  PermisoEmpleadoDef(
    codigo: permisoEliminarCreditos,
    nombre: 'Eliminar créditos',
    descripcion: 'Permite enviar créditos a la papelera.',
    grupo: GrupoPermisoEmpleado.creditos,
  ),
  PermisoEmpleadoDef(
    codigo: permisoModificarClientes,
    nombre: 'Modificar clientes',
    descripcion: 'Permite actualizar la información de clientes.',
    grupo: GrupoPermisoEmpleado.clientes,
  ),
  PermisoEmpleadoDef(
    codigo: permisoEliminarClientes,
    nombre: 'Eliminar clientes',
    descripcion: 'Permite enviar clientes a la papelera.',
    grupo: GrupoPermisoEmpleado.clientes,
  ),
  PermisoEmpleadoDef(
    codigo: permisoAgregarCuota,
    nombre: 'Agregar cuota',
    descripcion: 'Permite registrar cuotas adicionales a un crédito.',
    grupo: GrupoPermisoEmpleado.creditos,
  ),
  PermisoEmpleadoDef(
    codigo: permisoModificarMovimientos,
    nombre: 'Modificar movimientos',
    descripcion: 'Permite corregir movimientos registrados.',
    grupo: GrupoPermisoEmpleado.movimientos,
  ),
];

const List<String> permisosEmpleadoCodigos = <String>[
  permisoCrearCajaMenor,
  permisoRegistrarFlujoCaja,
  permisoCrearCreditos,
  permisoRefinanciarCreditos,
  permisoModificarCreditos,
  permisoEliminarCreditos,
  permisoModificarClientes,
  permisoEliminarClientes,
  permisoAgregarCuota,
  permisoModificarMovimientos,
];
