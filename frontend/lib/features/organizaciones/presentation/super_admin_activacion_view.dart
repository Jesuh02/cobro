import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/ui/page_layout.dart';
import '../../../data/models/models.dart';
import 'widgets/organizacion_admin_picker.dart';

const String _todasLasInstituciones = 'Todas las instituciones';

class SuperAdminActivacionView extends StatefulWidget {
  const SuperAdminActivacionView({
    required this.usuarios,
    required this.organizaciones,
    required this.usuarioActualId,
    required this.organizacionSeleccionadaId,
    required this.consulta,
    required this.cargando,
    required this.actualizandoIds,
    required this.onRefresh,
    required this.onOrganizacionChanged,
    required this.onConsultaChanged,
    required this.onEstadoChanged,
    this.error,
    super.key,
  });

  final List<UsuarioSuperAdminItem> usuarios;
  final List<OrganizacionAdmin> organizaciones;
  final String usuarioActualId;
  final String? organizacionSeleccionadaId;
  final String consulta;
  final bool cargando;
  final Set<String> actualizandoIds;
  final String? error;
  final Future<void> Function() onRefresh;
  final ValueChanged<String?> onOrganizacionChanged;
  final ValueChanged<String> onConsultaChanged;
  final Future<void> Function(UsuarioSuperAdminItem usuario, bool activo)
      onEstadoChanged;

  @override
  State<SuperAdminActivacionView> createState() =>
      _SuperAdminActivacionViewState();
}

class _SuperAdminActivacionViewState extends State<SuperAdminActivacionView> {
  late final TextEditingController _organizacionController;
  late final FocusNode _organizacionFocusNode;
  late final TextEditingController _busquedaController;

  OrganizacionAdmin? get _organizacionSeleccionada {
    final String? id = widget.organizacionSeleccionadaId;
    if (id == null) return null;
    for (final OrganizacionAdmin organizacion in widget.organizaciones) {
      if (organizacion.id == id) return organizacion;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _organizacionFocusNode = FocusNode();
    _organizacionController = TextEditingController(
      text: _organizacionSeleccionada?.nombre ?? _todasLasInstituciones,
    );
    _busquedaController = TextEditingController(text: widget.consulta);
  }

  @override
  void didUpdateWidget(covariant SuperAdminActivacionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.consulta != widget.consulta &&
        _busquedaController.text != widget.consulta) {
      _busquedaController.value = TextEditingValue(
        text: widget.consulta,
        selection: TextSelection.collapsed(offset: widget.consulta.length),
      );
    }

    if (!_organizacionFocusNode.hasFocus &&
        (oldWidget.organizacionSeleccionadaId !=
                widget.organizacionSeleccionadaId ||
            oldWidget.organizaciones != widget.organizaciones)) {
      final String texto =
          _organizacionSeleccionada?.nombre ?? _todasLasInstituciones;
      if (_organizacionController.text != texto) {
        _organizacionController.text = texto;
      }
    }
  }

  @override
  void dispose() {
    _organizacionController.dispose();
    _organizacionFocusNode.dispose();
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int activos = widget.usuarios
        .where((UsuarioSuperAdminItem usuario) => usuario.activo)
        .length;
    final int inactivos = widget.usuarios.length - activos;

    return Pagina(
      titulo: 'Gestión de acceso',
      subtitulo: 'Activación de administradores y empleados por institución',
      error: widget.error,
      onRefresh: widget.onRefresh,
      acciones: <Widget>[
        IconButton.filledTonal(
          onPressed: widget.cargando ? null : widget.onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Recargar usuarios',
        ),
      ],
      children: <Widget>[
        ClaySurface(
          radius: 16,
          padding: const EdgeInsets.all(16),
          elevated: false,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget organizacion = OrganizacionAdminPicker(
                organizaciones: widget.organizaciones,
                controller: _organizacionController,
                focusNode: _organizacionFocusNode,
                seleccionada: _organizacionSeleccionada,
                incluirTodas: true,
                labelText: 'Institución',
                hintText: 'Todas o busca una institución',
                onChanged: (OrganizacionAdmin? value) {
                  widget.onOrganizacionChanged(value?.id);
                },
              );
              final Widget busqueda = TextField(
                key: const ValueKey<String>('buscar-usuarios-super-admin'),
                controller: _busquedaController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Buscar usuario',
                  hintText: 'Nombre, usuario, documento o correo',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _busquedaController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _busquedaController.clear();
                            setState(() {});
                            widget.onConsultaChanged('');
                          },
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Limpiar búsqueda',
                        ),
                ),
                onChanged: (String value) {
                  setState(() {});
                  widget.onConsultaChanged(value);
                },
              );

              if (constraints.maxWidth < 680) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    organizacion,
                    const SizedBox(height: 12),
                    busqueda,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: organizacion),
                  const SizedBox(width: 12),
                  Expanded(child: busqueda),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _MetricaAcceso(
              key: const ValueKey<String>('metrica-usuarios-total'),
              icono: Icons.groups_rounded,
              etiqueta: 'Total',
              valor: widget.usuarios.length,
            ),
            _MetricaAcceso(
              key: const ValueKey<String>('metrica-usuarios-activos'),
              icono: Icons.check_circle_rounded,
              etiqueta: 'Activos',
              valor: activos,
              color: CobroAppTheme.success,
            ),
            _MetricaAcceso(
              key: const ValueKey<String>('metrica-usuarios-inactivos'),
              icono: Icons.pause_circle_rounded,
              etiqueta: 'Inactivos',
              valor: inactivos,
              color: CobroAppTheme.danger,
            ),
          ],
        ),
        if (widget.cargando) ...<Widget>[
          const SizedBox(height: 14),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 14),
        if (!widget.cargando && widget.usuarios.isEmpty)
          EstadoVacio(
            icono: Icons.manage_accounts_outlined,
            titulo: 'Sin usuarios',
            mensaje: widget.consulta.trim().isNotEmpty ||
                    widget.organizacionSeleccionadaId != null
                ? 'No hay usuarios que coincidan con los filtros.'
                : 'No hay usuarios administrables registrados.',
          )
        else
          ...widget.usuarios.map(
            (UsuarioSuperAdminItem usuario) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _UsuarioAccesoCard(
                usuario: usuario,
                esUsuarioActual: usuario.id == widget.usuarioActualId,
                actualizando: widget.actualizandoIds.contains(usuario.id),
                onEstadoChanged: (bool activo) =>
                    _solicitarCambioEstado(usuario, activo),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _solicitarCambioEstado(
    UsuarioSuperAdminItem usuario,
    bool activo,
  ) async {
    if (usuario.id == widget.usuarioActualId) return;

    if (!activo && usuario.esAdministrador) {
      final bool? confirmado = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Desactivar administrador'),
          content: Text(
            '¿Deseas desactivar a ${usuario.nombreVisible}? '
            'Perderá el acceso a ${usuario.organizacionVisible}.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey<String>('confirmar-desactivar-admin'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: CobroAppTheme.danger,
              ),
              child: const Text('Desactivar'),
            ),
          ],
        ),
      );
      if (confirmado != true || !mounted) return;
    }

    await widget.onEstadoChanged(usuario, activo);
  }
}

class _MetricaAcceso extends StatelessWidget {
  const _MetricaAcceso({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.color,
    super.key,
  });

  final IconData icono;
  final String etiqueta;
  final int valor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final Color acento = color ?? Theme.of(context).colorScheme.primary;
    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      elevated: false,
      color: Color.alphaBlend(
        acento.withValues(alpha: clay.isDark ? 0.16 : 0.09),
        clay.surfaceHigh,
      ),
      borderColor: acento.withValues(alpha: 0.2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icono, size: 18, color: acento),
          const SizedBox(width: 8),
          Text(
            valor.toString(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: acento,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(width: 5),
          Text(
            etiqueta,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: clay.subtleText,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _UsuarioAccesoCard extends StatelessWidget {
  const _UsuarioAccesoCard({
    required this.usuario,
    required this.esUsuarioActual,
    required this.actualizando,
    required this.onEstadoChanged,
  });

  final UsuarioSuperAdminItem usuario;
  final bool esUsuarioActual;
  final bool actualizando;
  final ValueChanged<bool> onEstadoChanged;

  @override
  Widget build(BuildContext context) {
    final Color estadoColor =
        usuario.activo ? CobroAppTheme.success : CobroAppTheme.danger;
    return ClaySurface(
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                backgroundColor: estadoColor.withValues(alpha: 0.12),
                foregroundColor: estadoColor,
                child: Icon(
                  usuario.activo
                      ? Icons.person_rounded
                      : Icons.person_off_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          usuario.nombreVisible,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        if (esUsuarioActual)
                          const _EtiquetaAcceso(
                            texto: 'Eres tú',
                            color: CobroAppTheme.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '@${usuario.usuario}${usuario.correo.isEmpty ? '' : ' · ${usuario.correo}'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.clay.subtleText,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: <Widget>[
                  Text(
                    usuario.activo ? 'Activo' : 'Inactivo',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: estadoColor,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  if (actualizando)
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  else
                    Tooltip(
                      message: esUsuarioActual
                          ? 'No puedes desactivar tu propio usuario'
                          : usuario.activo
                              ? 'Desactivar usuario'
                              : 'Activar usuario',
                      child: Switch(
                        key: ValueKey<String>('estado-usuario-${usuario.id}'),
                        value: usuario.activo,
                        onChanged: esUsuarioActual ? null : onEstadoChanged,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _DatoAcceso(
                icono: Icons.apartment_rounded,
                texto: usuario.organizacionVisible,
                color: usuario.organizacionSuspendida
                    ? CobroAppTheme.danger
                    : null,
              ),
              if ((usuario.identificacion ?? '').isNotEmpty)
                _DatoAcceso(
                  icono: Icons.badge_outlined,
                  texto: usuario.identificacion!,
                ),
              if ((usuario.telefono ?? '').isNotEmpty)
                _DatoAcceso(
                  icono: Icons.phone_outlined,
                  texto: usuario.telefono!,
                ),
              if (usuario.creadoEn != null)
                _DatoAcceso(
                  icono: Icons.event_outlined,
                  texto: 'Creado ${formatDateLabel(usuario.creadoEn)}',
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: usuario.roles.isEmpty
                ? const <Widget>[
                    _EtiquetaAcceso(
                      texto: 'Sin rol',
                      color: CobroAppTheme.warning,
                    ),
                  ]
                : usuario.roles
                    .map(
                      (String rol) => _EtiquetaAcceso(
                        texto: _etiquetaRol(rol),
                        color: _colorRol(rol),
                      ),
                    )
                    .toList(growable: false),
          ),
          if (usuario.organizacionSuspendida) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'La institución está suspendida',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: CobroAppTheme.danger,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DatoAcceso extends StatelessWidget {
  const _DatoAcceso({
    required this.icono,
    required this.texto,
    this.color,
  });

  final IconData icono;
  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color acento = color ?? Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: acento.withValues(alpha: context.clay.isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icono, size: 15, color: acento),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EtiquetaAcceso extends StatelessWidget {
  const _EtiquetaAcceso({
    required this.texto,
    required this.color,
  });

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.clay.isDark ? 0.18 : 0.1),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          texto,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

String _etiquetaRol(String rol) {
  return switch (rol) {
    'SUPER_ADMIN' => 'SuperAdmin',
    'ADMINISTRADOR' => 'Administrador',
    'COBRADOR' => 'Cobrador',
    'AUDITOR' => 'Auditor',
    _ => rol,
  };
}

Color _colorRol(String rol) {
  return switch (rol) {
    'SUPER_ADMIN' => CobroAppTheme.danger,
    'ADMINISTRADOR' => CobroAppTheme.primary,
    'COBRADOR' => CobroAppTheme.success,
    'AUDITOR' => CobroAppTheme.warning,
    _ => CobroAppTheme.primary,
  };
}
