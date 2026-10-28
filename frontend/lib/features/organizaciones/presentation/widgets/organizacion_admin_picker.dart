import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/clay.dart';
import '../../../../core/ui/cobro_dropdown.dart';
import '../../../../data/models/models.dart';

const String _todasLasInstitucionesId = '__todas_las_instituciones__';

class OrganizacionAdminPicker extends StatelessWidget {
  const OrganizacionAdminPicker({
    required this.organizaciones,
    required this.seleccionada,
    required this.onChanged,
    this.incluirTodas = false,
    this.etiquetaTodas = 'Todas las instituciones',
    this.labelText = 'Institucion',
    this.hintText = 'Buscar por nombre, correo o admin',
    super.key,
  });

  final List<OrganizacionAdmin> organizaciones;
  final OrganizacionAdmin? seleccionada;
  final ValueChanged<OrganizacionAdmin?> onChanged;
  final bool incluirTodas;
  final String etiquetaTodas;
  final String labelText;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final List<CobroDropdownItem<String>> items = <CobroDropdownItem<String>>[
      if (incluirTodas)
        CobroDropdownItem<String>(
          key: const ValueKey<String>('organizacion-picker-todas'),
          value: _todasLasInstitucionesId,
          label: etiquetaTodas,
          subtitle: 'Ver usuarios de todas las instituciones',
          icon: Icons.public_rounded,
          iconColor: CobroAppTheme.primary,
        ),
      ...organizaciones.map((OrganizacionAdmin organizacion) {
        final String detalle = <String>[
          if ((organizacion.correo ?? '').isNotEmpty) organizacion.correo!,
          if (organizacion.administradores.isNotEmpty)
            organizacion.administradores.join(', '),
        ].join(' · ');

        return CobroDropdownItem<String>(
          key: ValueKey<String>('organizacion-picker-${organizacion.id}'),
          value: organizacion.id,
          label: organizacion.nombre,
          subtitle: detalle,
          searchText: organizacion.administradores.join(' '),
          icon: organizacion.suspendida
              ? Icons.domain_disabled_rounded
              : Icons.apartment_rounded,
          iconColor: organizacion.suspendida
              ? CobroAppTheme.danger
              : CobroAppTheme.primary,
        );
      }),
    ];

    return CobroDropdownField<String>(
      value:
          seleccionada?.id ?? (incluirTodas ? _todasLasInstitucionesId : null),
      items: items,
      labelText: labelText,
      hintText: hintText,
      prefixIcon: const Icon(Icons.apartment_rounded),
      searchable: true,
      searchHintText: 'Buscar institución',
      emptyText: 'No hay instituciones con ese filtro',
      menuMaxHeight: 360,
      onChanged: (String? value) {
        if (value == null || value == _todasLasInstitucionesId) {
          onChanged(null);
          return;
        }

        for (final OrganizacionAdmin organizacion in organizaciones) {
          if (organizacion.id == value) {
            onChanged(organizacion);
            return;
          }
        }
      },
    );
  }
}

class OrganizacionAdminItem extends StatelessWidget {
  const OrganizacionAdminItem({
    required this.organizacion,
    required this.guardando,
    required this.onEditar,
    required this.onActivoChanged,
    super.key,
  });

  final OrganizacionAdmin organizacion;
  final bool guardando;
  final VoidCallback onEditar;
  final ValueChanged<bool> onActivoChanged;

  @override
  Widget build(BuildContext context) {
    final Color estadoColor =
        organizacion.suspendida ? CobroAppTheme.danger : CobroAppTheme.success;
    final String administradores = organizacion.administradores.isEmpty
        ? 'Sin administrador'
        : organizacion.administradores.join(', ');

    return ClaySurface(
      radius: 14,
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
                  organizacion.suspendida
                      ? Icons.block_rounded
                      : Icons.apartment_rounded,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      organizacion.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if ((organizacion.correo ?? '').isNotEmpty)
                          organizacion.correo!,
                        administradores,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.clay.subtleText,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                organizacion.estadoTexto,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: estadoColor,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OrganizacionDato(
                icono: Icons.payments_rounded,
                texto:
                    '${formatMoney(organizacion.montoPlan)} ${organizacion.monedaPlan}',
              ),
              OrganizacionDato(
                icono: Icons.event_available_rounded,
                texto: organizacion.accesoTexto,
              ),
              OrganizacionDato(
                icono: Icons.group_rounded,
                texto:
                    '${organizacion.usuariosActivos}/${organizacion.usuariosTotal} usuarios',
              ),
              if ((organizacion.motivoSuspension ?? '').isNotEmpty)
                OrganizacionDato(
                  icono: Icons.info_outline_rounded,
                  texto: organizacion.motivoSuspension!,
                  color: CobroAppTheme.danger,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: guardando ? null : onEditar,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    organizacion.activo ? 'Activa' : 'Suspendida',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: context.clay.subtleText,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: organizacion.activo,
                    onChanged: guardando ? null : onActivoChanged,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OrganizacionDato extends StatelessWidget {
  const OrganizacionDato({
    required this.icono,
    required this.texto,
    this.color,
    super.key,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icono, size: 16, color: acento),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.clay.text,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
