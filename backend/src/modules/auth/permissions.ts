export const permisosEmpleado = [
  {
    codigo: 'VER_EMPLEADOS',
    nombre: 'Ver empleados',
    rolNombre: 'Permiso ver empleados',
    predeterminado: false,
  },
  {
    codigo: 'CREAR_CAJA_MENOR',
    nombre: 'Crear caja menor',
    rolNombre: 'Permiso crear caja menor',
  },
  {
    codigo: 'REGISTRAR_FLUJO_CAJA',
    nombre: 'Registrar flujo en caja menor',
    rolNombre: 'Permiso registrar flujo en caja menor',
  },
  {
    codigo: 'CREAR_CREDITOS',
    nombre: 'Crear creditos',
    rolNombre: 'Permiso crear creditos',
  },
  {
    codigo: 'REFINANCIAR_CREDITOS',
    nombre: 'Refinanciar creditos',
    rolNombre: 'Permiso refinanciar creditos',
  },
  {
    codigo: 'MODIFICAR_CREDITOS',
    nombre: 'Modificar creditos',
    rolNombre: 'Permiso modificar creditos',
  },
  {
    codigo: 'ELIMINAR_CREDITOS',
    nombre: 'Eliminar creditos',
    rolNombre: 'Permiso eliminar creditos',
  },
  {
    codigo: 'AGREGAR_CUOTA',
    nombre: 'Agregar cuota',
    rolNombre: 'Permiso agregar cuota',
  },
  {
    codigo: 'MODIFICAR_MOVIMIENTOS',
    nombre: 'Modificar movimientos',
    rolNombre: 'Permiso modificar movimientos',
  },
  {
    codigo: 'ELIMINAR_MOVIMIENTOS',
    nombre: 'Eliminar movimientos',
    rolNombre: 'Permiso eliminar movimientos',
  },
] as const;

export type PermisoEmpleadoCodigo = (typeof permisosEmpleado)[number]['codigo'];

export const permisosEmpleadoCodigos = permisosEmpleado.map(
  (permiso) => permiso.codigo,
);

export const permisosEmpleadoPredeterminadosCodigos: string[] =
  permisosEmpleadoCodigos.filter((codigo) => codigo !== 'VER_EMPLEADOS');

export const permisosEmpleadoPorCodigo = new Map(
  permisosEmpleado.map((permiso) => [permiso.codigo, permiso]),
);
const permisosEmpleadoSet: ReadonlySet<string> = new Set(
  permisosEmpleadoCodigos,
);

export function esPermisoEmpleado(
  value: string,
): value is PermisoEmpleadoCodigo {
  return permisosEmpleadoSet.has(value);
}
