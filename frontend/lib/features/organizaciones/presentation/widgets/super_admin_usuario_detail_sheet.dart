import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/constants/permisos_constants.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/island_modal_sheet.dart';
import '../../../../core/ui/page_layout.dart';
import '../../../../data/models/models.dart';

enum SuperAdminUsuarioDetalleSeccion {
  informacion,
  permisos,
}

Future<void> mostrarSuperAdminUsuarioDetalleSheet({
  required BuildContext context,
  required UsuarioSuperAdminItem usuario,
  required Future<UsuarioSuperAdminItem> Function(
    UsuarioSuperAdminItem usuario,
    List<String> permisos,
  ) onGuardarPermisos,
  required String Function(Object error) mensajeError,
  void Function(String mensaje)? mostrarMensaje,
}) async {
  await mostrarIslandModalBottomSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) {
      return SuperAdminUsuarioDetalleSheet(
        usuario: usuario,
        onGuardarPermisos: onGuardarPermisos,
        mensajeError: mensajeError,
        onCopiarDato: (String etiqueta, String valor) {
          copiarDatoAlPortapapeles(
            context: sheetContext,
            etiqueta: etiqueta,
            valor: valor,
            mostrarMensaje: mostrarMensaje,
          );
        },
        mostrarMensaje: mostrarMensaje,
      );
    },
  );
}

class SuperAdminUsuarioDetalleSheet extends StatefulWidget {
  const SuperAdminUsuarioDetalleSheet({
    required this.usuario,
    required this.onGuardarPermisos,
    required this.mensajeError,
    required this.onCopiarDato,
    this.mostrarMensaje,
    super.key,
  });

  final UsuarioSuperAdminItem usuario;
  final Future<UsuarioSuperAdminItem> Function(
    UsuarioSuperAdminItem usuario,
    List<String> permisos,
  ) onGuardarPermisos;
  final String Function(Object error) mensajeError;
  final void Function(String etiqueta, String valor) onCopiarDato;
  final void Function(String mensaje)? mostrarMensaje;

  @override
  State<SuperAdminUsuarioDetalleSheet> createState() =>
      _SuperAdminUsuarioDetalleSheetState();
}

class _SuperAdminUsuarioDetalleSheetState
    extends State<SuperAdminUsuarioDetalleSheet> {
  SuperAdminUsuarioDetalleSeccion _seccion =
      SuperAdminUsuarioDetalleSeccion.informacion;
  late UsuarioSuperAdminItem _usuario;
  late Set<String> _permisosGuardados;
  late Set<String> _permisosSeleccionados;
  bool _guardando = false;
  String? _error;

  bool get _puedeEditarPermisos =>
      _usuario.esCobrador &&
      !_usuario.esAdmin &&
      _usuario.organizacionId != null;

  bool get _hayCambios =>
      !setEquals(_permisosGuardados, _permisosSeleccionados);

  @override
  void initState() {
    super.initState();
    _usuario = widget.usuario;
    _permisosGuardados = widget.usuario.permisos.toSet();
    _permisosSeleccionados = Set<String>.of(_permisosGuardados);
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations = MediaQuery.disableAnimationsOf(context);

    return PopScope(
      canPop: !_guardando,
      child: IslandModalSheet(
        maxHeightFactor: 0.88,
        footer: _SuperAdminUsuarioFooter(
          mostrandoPermisos:
              _seccion == SuperAdminUsuarioDetalleSeccion.permisos,
          puedeGuardar: _puedeEditarPermisos && _hayCambios && !_guardando,
          guardando: _guardando,
          onCerrar: _guardando ? null : () => Navigator.of(context).pop(),
          onGuardar: _guardarPermisos,
        ),
        children: <Widget>[
          _SuperAdminUsuarioHeader(usuario: _usuario),
          const SizedBox(height: 14),
          SegmentedButton<SuperAdminUsuarioDetalleSeccion>(
            key: const ValueKey<String>('detalle-usuario-secciones'),
            segments: const <ButtonSegment<SuperAdminUsuarioDetalleSeccion>>[
              ButtonSegment<SuperAdminUsuarioDetalleSeccion>(
                value: SuperAdminUsuarioDetalleSeccion.informacion,
                icon: Icon(Icons.person_outline_rounded),
                label: Text('Información'),
              ),
              ButtonSegment<SuperAdminUsuarioDetalleSeccion>(
                value: SuperAdminUsuarioDetalleSeccion.permisos,
                icon: Icon(Icons.admin_panel_settings_outlined),
                label: Text('Permisos'),
              ),
            ],
            selected: <SuperAdminUsuarioDetalleSeccion>{_seccion},
            onSelectionChanged:
                (Set<SuperAdminUsuarioDetalleSeccion> selection) {
              setState(() {
                _seccion = selection.single;
                _error = null;
              });
            },
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: _seccion == SuperAdminUsuarioDetalleSeccion.informacion
                ? _SuperAdminUsuarioInformacion(
                    key: const ValueKey<String>('detalle-usuario-informacion'),
                    usuario: _usuario,
                    onCopiarDato: widget.onCopiarDato,
                  )
                : _SuperAdminUsuarioPermisos(
                    key: const ValueKey<String>('detalle-usuario-permisos'),
                    usuario: _usuario,
                    seleccionados: _permisosSeleccionados,
                    editable: _puedeEditarPermisos && !_guardando,
                    error: _error,
                    onChanged: _cambiarPermiso,
                    onSeleccionarTodos: _seleccionarTodos,
                    onLimpiar: _limpiarPermisos,
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _cambiarPermiso(String codigo, bool seleccionado) {
    setState(() {
      if (seleccionado) {
        _permisosSeleccionados.add(codigo);
      } else {
        _permisosSeleccionados.remove(codigo);
      }
      _error = null;
    });
  }

  void _seleccionarTodos() {
    setState(() {
      _permisosSeleccionados = permisosEmpleadoCodigos.toSet();
      _error = null;
    });
  }

  void _limpiarPermisos() {
    setState(() {
      _permisosSeleccionados = <String>{};
      _error = null;
    });
  }

  Future<void> _guardarPermisos() async {
    if (!_puedeEditarPermisos || !_hayCambios || _guardando) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final List<String> permisos = permisosEmpleado
          .where(
            (PermisoEmpleadoDef permiso) =>
                _permisosSeleccionados.contains(permiso.codigo),
          )
          .map((PermisoEmpleadoDef permiso) => permiso.codigo)
          .toList(growable: false);
      final UsuarioSuperAdminItem actualizado =
          await widget.onGuardarPermisos(_usuario, permisos);
      if (!mounted) return;

      setState(() {
        _usuario = actualizado;
        _permisosGuardados = actualizado.permisos.toSet();
        _permisosSeleccionados = Set<String>.of(_permisosGuardados);
      });
      widget.mostrarMensaje?.call('Permisos actualizados');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = widget.mensajeError(error));
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }
}

class _SuperAdminUsuarioHeader extends StatelessWidget {
  const _SuperAdminUsuarioHeader({required this.usuario});

  final UsuarioSuperAdminItem usuario;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final Color estadoColor =
        usuario.activo ? CobroAppTheme.success : CobroAppTheme.danger;
    final String inicial = usuario.nombreVisible.trim().isEmpty
        ? '?'
        : usuario.nombreVisible.trim().substring(0, 1).toUpperCase();

    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 24,
          backgroundColor: estadoColor.withValues(alpha: 0.14),
          foregroundColor: estadoColor,
          child: Text(
            inicial,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                usuario.nombreVisible,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: clay.text,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '@${usuario.usuario}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: clay.subtleText,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: estadoColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(ClayRadius.small),
            border: Border.all(color: estadoColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            usuario.activo ? 'Activo' : 'Inactivo',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: estadoColor,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ],
    );
  }
}

class _SuperAdminUsuarioInformacion extends StatelessWidget {
  const _SuperAdminUsuarioInformacion({
    required this.usuario,
    required this.onCopiarDato,
    super.key,
  });

  final UsuarioSuperAdminItem usuario;
  final void Function(String etiqueta, String valor) onCopiarDato;

  @override
  Widget build(BuildContext context) {
    final String identificacion = usuario.identificacion?.trim() ?? '';
    final String telefono = usuario.telefono?.trim() ?? '';
    final String roles = usuario.roles.isEmpty
        ? 'Sin rol asignado'
        : usuario.roles.map(_nombreRol).join(', ');

    return Column(
      children: <Widget>[
        TarjetaSeccionSheet(
          titulo: 'Identificación',
          icono: Icons.badge_outlined,
          children: <Widget>[
            FilaDatoSheet(
              etiqueta: 'Nombre completo',
              valor: usuario.nombreVisible,
              valorCopiable: usuario.nombreVisible,
              onCopiar: onCopiarDato,
            ),
            const SizedBox(height: 7),
            FilaDatoSheet(
              etiqueta: 'Usuario',
              valor: '@${usuario.usuario}',
              valorCopiable: usuario.usuario,
              onCopiar: onCopiarDato,
            ),
            const SizedBox(height: 7),
            FilaDatoSheet(
              etiqueta: 'Documento',
              valor: identificacion.isEmpty ? 'No registrado' : identificacion,
              valorCopiable: identificacion.isEmpty ? null : identificacion,
              onCopiar: onCopiarDato,
            ),
          ],
        ),
        const SizedBox(height: 8),
        TarjetaSeccionSheet(
          titulo: 'Contacto',
          icono: Icons.contact_phone_outlined,
          children: <Widget>[
            FilaDatoSheet(
              etiqueta: 'Correo',
              valor: usuario.correo.trim().isEmpty
                  ? 'No registrado'
                  : usuario.correo,
              valorCopiable:
                  usuario.correo.trim().isEmpty ? null : usuario.correo,
              icono: Icons.alternate_email_rounded,
              onCopiar: onCopiarDato,
            ),
            const SizedBox(height: 7),
            FilaDatoSheet(
              etiqueta: 'Teléfono',
              valor: telefono.isEmpty ? 'No registrado' : telefono,
              valorCopiable: telefono.isEmpty ? null : telefono,
              icono: Icons.phone_outlined,
              onCopiar: onCopiarDato,
            ),
          ],
        ),
        const SizedBox(height: 8),
        TarjetaSeccionSheet(
          titulo: 'Institución y acceso',
          icono: Icons.apartment_rounded,
          children: <Widget>[
            FilaDatoSheet(
              etiqueta: 'Institución',
              valor: usuario.organizacionVisible,
              icono: Icons.business_outlined,
              onCopiar: onCopiarDato,
            ),
            const SizedBox(height: 7),
            FilaDatoSheet(
              etiqueta: 'Roles',
              valor: roles,
              icono: Icons.shield_outlined,
              onCopiar: onCopiarDato,
            ),
            const SizedBox(height: 7),
            FilaDatoSheet(
              etiqueta: 'Fecha de creación',
              valor: formatDateLabel(usuario.creadoEn),
              icono: Icons.event_outlined,
              onCopiar: onCopiarDato,
            ),
          ],
        ),
      ],
    );
  }
}

class _SuperAdminUsuarioPermisos extends StatelessWidget {
  const _SuperAdminUsuarioPermisos({
    required this.usuario,
    required this.seleccionados,
    required this.editable,
    required this.onChanged,
    required this.onSeleccionarTodos,
    required this.onLimpiar,
    this.error,
    super.key,
  });

  final UsuarioSuperAdminItem usuario;
  final Set<String> seleccionados;
  final bool editable;
  final String? error;
  final void Function(String codigo, bool seleccionado) onChanged;
  final VoidCallback onSeleccionarTodos;
  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    final bool heredados = usuario.esAdministrador || usuario.esSuperAdmin;
    final bool configurable = usuario.esCobrador && !heredados;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PermisosResumen(
          seleccionados: seleccionados.length,
          total: permisosEmpleado.length,
          heredados: heredados,
        ),
        if (!configurable) ...<Widget>[
          const SizedBox(height: 8),
          _PermisosSoloLecturaBanner(heredados: heredados),
        ],
        if (configurable) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            runSpacing: 4,
            children: <Widget>[
              TextButton(
                onPressed: editable ? onLimpiar : null,
                child: const Text('Quitar todos'),
              ),
              TextButton(
                onPressed: editable ? onSeleccionarTodos : null,
                child: const Text('Seleccionar todos'),
              ),
            ],
          ),
        ],
        if (error != null) ...<Widget>[
          const SizedBox(height: 8),
          ErrorBanner(message: error!),
        ],
        const SizedBox(height: 8),
        for (final GrupoPermisoEmpleado grupo in GrupoPermisoEmpleado.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GrupoPermisosCard(
              grupo: grupo,
              permisos: permisosEmpleado
                  .where(
                    (PermisoEmpleadoDef permiso) => permiso.grupo == grupo,
                  )
                  .toList(growable: false),
              seleccionados: seleccionados,
              editable: editable,
              onChanged: onChanged,
            ),
          ),
      ],
    );
  }
}

class _PermisosResumen extends StatelessWidget {
  const _PermisosResumen({
    required this.seleccionados,
    required this.total,
    required this.heredados,
  });

  final int seleccionados;
  final int total;
  final bool heredados;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '$seleccionados de $total permisos habilitados',
      child: TarjetaSeccionSheet(
        titulo: heredados ? 'Permisos heredados' : 'Permisos habilitados',
        icono: Icons.verified_user_outlined,
        colorIcono: CobroAppTheme.success,
        children: <Widget>[
          Text(
            '$seleccionados de $total permisos',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.clay.text,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _PermisosSoloLecturaBanner extends StatelessWidget {
  const _PermisosSoloLecturaBanner({required this.heredados});

  final bool heredados;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CobroAppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ClayRadius.small),
        border: Border.all(
          color: CobroAppTheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            color: CobroAppTheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              heredados
                  ? 'Este usuario recibe sus permisos por un rol elevado y no admite excepciones individuales.'
                  : 'Este rol no admite permisos configurables de empleado.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: clay.text,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrupoPermisosCard extends StatelessWidget {
  const _GrupoPermisosCard({
    required this.grupo,
    required this.permisos,
    required this.seleccionados,
    required this.editable,
    required this.onChanged,
  });

  final GrupoPermisoEmpleado grupo;
  final List<PermisoEmpleadoDef> permisos;
  final Set<String> seleccionados;
  final bool editable;
  final void Function(String codigo, bool seleccionado) onChanged;

  @override
  Widget build(BuildContext context) {
    return TarjetaSeccionSheet(
      titulo: _nombreGrupo(grupo),
      icono: _iconoGrupo(grupo),
      children: <Widget>[
        for (int index = 0; index < permisos.length; index++) ...<Widget>[
          if (index > 0) Divider(color: context.clay.border),
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              key: ValueKey<String>(
                'permiso-usuario-${permisos[index].codigo}',
              ),
              value: seleccionados.contains(permisos[index].codigo),
              onChanged: editable
                  ? (bool? value) {
                      onChanged(permisos[index].codigo, value ?? false);
                    }
                  : null,
              title: Text(
                permisos[index].nombre,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(permisos[index].descripcion),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ],
    );
  }
}

class _SuperAdminUsuarioFooter extends StatelessWidget {
  const _SuperAdminUsuarioFooter({
    required this.mostrandoPermisos,
    required this.puedeGuardar,
    required this.guardando,
    required this.onCerrar,
    required this.onGuardar,
  });

  final bool mostrandoPermisos;
  final bool puedeGuardar;
  final bool guardando;
  final VoidCallback? onCerrar;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: clay.surface,
        border: Border(
          top: BorderSide(color: clay.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(
              onPressed: onCerrar,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ClayRadius.control),
                ),
              ),
              child: const Text('Cerrar'),
            ),
          ),
          if (mostrandoPermisos) ...<Widget>[
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                key: const ValueKey<String>('guardar-permisos-usuario'),
                onPressed: puedeGuardar ? onGuardar : null,
                icon: guardando
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(guardando ? 'Guardando…' : 'Guardar permisos'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ClayRadius.control),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _nombreRol(String rol) {
  switch (rol) {
    case 'SUPER_ADMIN':
      return 'SuperAdmin';
    case 'ADMINISTRADOR':
      return 'Administrador';
    case 'COBRADOR':
      return 'Cobrador';
    case 'AUDITOR':
      return 'Auditor';
    default:
      return rol.replaceAll('_', ' ');
  }
}

String _nombreGrupo(GrupoPermisoEmpleado grupo) {
  switch (grupo) {
    case GrupoPermisoEmpleado.caja:
      return 'Caja menor';
    case GrupoPermisoEmpleado.creditos:
      return 'Créditos';
    case GrupoPermisoEmpleado.clientes:
      return 'Clientes';
    case GrupoPermisoEmpleado.movimientos:
      return 'Movimientos';
  }
}

IconData _iconoGrupo(GrupoPermisoEmpleado grupo) {
  switch (grupo) {
    case GrupoPermisoEmpleado.caja:
      return Icons.savings_outlined;
    case GrupoPermisoEmpleado.creditos:
      return Icons.request_quote_outlined;
    case GrupoPermisoEmpleado.clientes:
      return Icons.groups_outlined;
    case GrupoPermisoEmpleado.movimientos:
      return Icons.swap_horiz_rounded;
  }
}
