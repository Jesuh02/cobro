import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/clay.dart';
import '../../../../data/models/models.dart';

class OrganizacionAdminPicker extends StatelessWidget {
  const OrganizacionAdminPicker({
    required this.organizaciones,
    required this.controller,
    required this.focusNode,
    required this.seleccionada,
    required this.onChanged,
  });

  final List<OrganizacionAdmin> organizaciones;
  final TextEditingController controller;
  final FocusNode focusNode;
  final OrganizacionAdmin? seleccionada;
  final ValueChanged<OrganizacionAdmin?> onChanged;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<OrganizacionAdmin>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (OrganizacionAdmin option) => option.nombre,
      optionsBuilder: (TextEditingValue value) {
        final String texto = value.text.trim();
        final String consulta = texto.toLowerCase();
        if (consulta.isEmpty ||
            (seleccionada != null && texto == seleccionada!.nombre)) {
          return organizaciones;
        }

        return organizaciones.where((OrganizacionAdmin organizacion) {
          final String nombre = organizacion.nombre.toLowerCase();
          final String correo = (organizacion.correo ?? '').toLowerCase();
          final String administradores =
              organizacion.administradores.join(' ').toLowerCase();
          return nombre.contains(consulta) ||
              correo.contains(consulta) ||
              administradores.contains(consulta);
        });
      },
      onSelected: onChanged,
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController controller,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Institucion',
            hintText: 'Buscar por nombre, correo o admin',
            prefixIcon: Icon(Icons.apartment_rounded),
            suffixIcon: Icon(Icons.arrow_drop_down_rounded),
          ),
          onTap: () {
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            );
          },
          onChanged: (String value) {
            final String texto = value.trim();
            final bool mantieneSeleccion =
                seleccionada != null && texto == seleccionada!.nombre;
            if (seleccionada != null && !mantieneSeleccion) {
              onChanged(null);
            }
          },
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<OrganizacionAdmin> onSelected,
        Iterable<OrganizacionAdmin> options,
      ) {
        final List<OrganizacionAdmin> opciones =
            options.toList(growable: false);
        final double ancho = math.min(
          460,
          math.max(0, MediaQuery.sizeOf(context).width - 32),
        );

        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: ancho,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: opciones.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No hay instituciones con ese filtro',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: opciones.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final OrganizacionAdmin organizacion =
                              opciones[index];
                          final String detalle = [
                            if ((organizacion.correo ?? '').isNotEmpty)
                              organizacion.correo!,
                            if (organizacion.administradores.isNotEmpty)
                              organizacion.administradores.join(', '),
                          ].join(' · ');

                          return InkWell(
                            onTap: () => onSelected(organizacion),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: CobroAppTheme.primary
                                        .withValues(alpha: 0.12),
                                    foregroundColor: CobroAppTheme.primary,
                                    child: const Icon(
                                      Icons.apartment_rounded,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Text(
                                          organizacion.nombre,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        if (detalle.isNotEmpty)
                                          Text(
                                            detalle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      context.clay.subtleText,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        );
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
