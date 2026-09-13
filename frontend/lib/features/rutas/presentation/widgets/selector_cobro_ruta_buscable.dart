import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/clay.dart';
import '../../../../data/models/models.dart';

class SelectorCobroRutaBuscable extends StatefulWidget {
  const SelectorCobroRutaBuscable({
    super.key,
    required this.cobros,
    required this.cuotasSeleccionadas,
    required this.enabled,
    required this.onSelected,
  });

  final List<CobroRuta> cobros;
  final Set<String> cuotasSeleccionadas;
  final bool enabled;
  final ValueChanged<CobroRuta> onSelected;

  @override
  State<SelectorCobroRutaBuscable> createState() =>
      _SelectorCobroRutaBuscableState();
}

class _SelectorCobroRutaBuscableState extends State<SelectorCobroRutaBuscable> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _controller.addListener(_actualizarBusqueda);
  }

  @override
  void dispose() {
    _controller.removeListener(_actualizarBusqueda);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _actualizarBusqueda() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final String consulta = _controller.text.trim().toLowerCase();
    final List<CobroRuta> opciones = widget.cobros.where((CobroRuta cobro) {
      if (cobro.proximaCuotaId == null ||
          widget.cuotasSeleccionadas.contains(cobro.proximaCuotaId)) {
        return false;
      }

      if (consulta.isEmpty) {
        return true;
      }

      return cobro.cliente.toLowerCase().contains(consulta) ||
          (cobro.cedula ?? '').toLowerCase().contains(consulta) ||
          (cobro.negocio ?? '').toLowerCase().contains(consulta) ||
          cobro.ruta.toLowerCase().contains(consulta);
    }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: 'Buscar y agregar cliente',
            prefixIcon: const Icon(Icons.person_search_rounded),
            suffixIcon: _controller.text.isEmpty
                ? const Icon(Icons.list_alt_rounded)
                : IconButton(
                    tooltip: 'Limpiar busqueda',
                    onPressed: widget.enabled ? _controller.clear : null,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
          onSubmitted: (_) {
            if (widget.enabled && opciones.isNotEmpty) {
              _seleccionar(opciones.first);
            }
          },
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: clay.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: clay.border),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: opciones.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      consulta.isEmpty
                          ? 'Todos los clientes pendientes ya estan agregados'
                          : 'Sin clientes pendientes',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: clay.subtleText,
                          ),
                    ),
                  )
                : SizedBox(
                    height: math.min(
                      280.0,
                      math.max(72.0, opciones.length * 64.0),
                    ),
                    child: Scrollbar(
                      controller: _scrollController,
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        itemCount: opciones.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final CobroRuta cobro = opciones[index];
                          return ListTile(
                            dense: true,
                            enabled: widget.enabled,
                            leading: const Icon(Icons.person_add_alt_1_rounded),
                            title: Text(
                              cobro.cliente,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                if ((cobro.cedula ?? '').isNotEmpty)
                                  'CC ${cobro.cedula!}',
                                cobro.ruta,
                                'Cuota ${cobro.proximaNumeroCuota ?? '-'}',
                                formatMoney(cobro.proximoSaldoCuota),
                              ].join(' - '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: widget.enabled
                                ? () => _seleccionar(cobro)
                                : null,
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _seleccionar(CobroRuta cobro) {
    widget.onSelected(cobro);
    _controller.clear();
    _focusNode.requestFocus();
  }
}
