import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/clay.dart';
import '../../../../core/ui/cobro_dropdown.dart';
import '../../../../core/ui/modal_layouts.dart';
import '../../../../data/models/models.dart';
import 'resumen_credito_animado.dart';

String etiquetaCliente(Cliente cliente) {
  final String cedula = cliente.cedula?.trim() ?? '';
  if (cedula.isEmpty) {
    return cliente.nombreCompleto;
  }

  return '${cliente.nombreCompleto} - CC $cedula';
}

class ClienteOpcionCredito extends StatelessWidget {
  const ClienteOpcionCredito({super.key, required this.cliente});

  final Cliente cliente;

  @override
  Widget build(BuildContext context) {
    final List<String> detalles = <String>[
      if ((cliente.cedula ?? '').isNotEmpty) 'CC ${cliente.cedula!}',
      if ((cliente.nombreComercial ?? '').isNotEmpty) cliente.nombreComercial!,
      if ((cliente.telefono ?? '').isNotEmpty) cliente.telefono!,
    ];

    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 18,
          backgroundColor: CobroAppTheme.primary.withValues(alpha: 0.12),
          foregroundColor: CobroAppTheme.primary,
          child: Text(
            cliente.nombreCompleto.isEmpty
                ? '?'
                : cliente.nombreCompleto.substring(0, 1).toUpperCase(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                cliente.nombreCompleto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (detalles.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  detalles.join(' - '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.clay.subtleText,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SelectorClienteCredito extends StatefulWidget {
  const SelectorClienteCredito({
    super.key,
    required this.clientes,
    required this.clienteId,
    required this.enabled,
    required this.onChanged,
  });

  final List<Cliente> clientes;
  final String? clienteId;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  State<SelectorClienteCredito> createState() => _SelectorClienteCreditoState();
}

class _SelectorClienteCreditoState extends State<SelectorClienteCredito> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _textoSeleccionado());
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant SelectorClienteCredito oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clienteId == oldWidget.clienteId) {
      return;
    }

    if (widget.clienteId == null && _focusNode.hasFocus) {
      return;
    }

    _controller.text = _textoSeleccionado();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Cliente? clienteSeleccionado = _clientePorId(widget.clienteId);

    return RawAutocomplete<Cliente>(
      textEditingController: _controller,
      focusNode: _focusNode,
      displayStringForOption: etiquetaCliente,
      optionsBuilder: (TextEditingValue value) {
        final String texto = value.text.trim();
        final String consulta = texto.toLowerCase();
        if (consulta.isEmpty ||
            (clienteSeleccionado != null &&
                texto == etiquetaCliente(clienteSeleccionado))) {
          return widget.clientes;
        }

        return widget.clientes.where((Cliente cliente) {
          final String nombre = cliente.nombreCompleto.toLowerCase();
          final String cedula = (cliente.cedula ?? '').toLowerCase();
          final String negocio = (cliente.nombreComercial ?? '').toLowerCase();
          return nombre.contains(consulta) ||
              cedula.contains(consulta) ||
              negocio.contains(consulta);
        });
      },
      onSelected: (Cliente cliente) => widget.onChanged(cliente.id),
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController controller,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: 'Cliente',
            hintText: 'Buscar por nombre o cedula',
            prefixIcon: const Icon(Icons.person_search_rounded),
            suffixIcon: widget.enabled
                ? const Icon(Icons.arrow_drop_down_rounded)
                : const Icon(Icons.lock_rounded),
          ),
          onTap: () {
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            );
          },
          onChanged: (String value) {
            final String texto = value.trim();
            final bool mantieneSeleccion = clienteSeleccionado != null &&
                texto == etiquetaCliente(clienteSeleccionado);
            if (widget.clienteId != null &&
                (texto.isEmpty || !mantieneSeleccion)) {
              widget.onChanged(null);
            }
          },
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<Cliente> onSelected,
        Iterable<Cliente> options,
      ) {
        final List<Cliente> opciones = options.toList(growable: false);
        final double ancho = math.min(
          520,
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
                          'No hay clientes con ese nombre o cedula',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: opciones.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final Cliente cliente = opciones[index];
                          return InkWell(
                            onTap: () => onSelected(cliente),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: ClienteOpcionCredito(cliente: cliente),
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

  Cliente? _clientePorId(String? id) {
    if (id == null) {
      return null;
    }

    for (final Cliente cliente in widget.clientes) {
      if (cliente.id == id) {
        return cliente;
      }
    }

    return null;
  }

  String _textoSeleccionado() {
    final Cliente? cliente = _clientePorId(widget.clienteId);
    return cliente == null ? '' : etiquetaCliente(cliente);
  }
}

class SelectorClientesCreditoMultiple extends StatefulWidget {
  const SelectorClientesCreditoMultiple({
    super.key,
    required this.clientes,
    required this.clientesSeleccionadosIds,
    required this.enabled,
    required this.onChanged,
  });

  final List<Cliente> clientes;
  final Set<String> clientesSeleccionadosIds;
  final bool enabled;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<SelectorClientesCreditoMultiple> createState() =>
      _SelectorClientesCreditoMultipleState();
}

class _SelectorClientesCreditoMultipleState
    extends State<SelectorClientesCreditoMultiple> {
  late final TextEditingController _buscarController;

  @override
  void initState() {
    super.initState();
    _buscarController = TextEditingController();
    _buscarController.addListener(_refrescar);
  }

  @override
  void dispose() {
    _buscarController.removeListener(_refrescar);
    _buscarController.dispose();
    super.dispose();
  }

  void _refrescar() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Cliente> clientesFiltrados = _clientesFiltrados();
    final int seleccionados = widget.clientesSeleccionadosIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: _buscarController,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: 'Clientes',
            hintText: 'Buscar por nombre o cedula',
            prefixIcon: const Icon(Icons.person_search_rounded),
            suffixIcon: seleccionados == 0
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Chip(
                      label: Text('$seleccionados'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
            suffixIconConstraints: const BoxConstraints(minWidth: 44),
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: clientesFiltrados.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No hay clientes con ese nombre o cedula',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: clientesFiltrados.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final Cliente cliente = clientesFiltrados[index];
                      final bool seleccionado =
                          widget.clientesSeleccionadosIds.contains(cliente.id);
                      return InkWell(
                        onTap: widget.enabled
                            ? () => _alternarCliente(cliente.id)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Row(
                            children: <Widget>[
                              Checkbox(
                                value: seleccionado,
                                onChanged: widget.enabled
                                    ? (_) => _alternarCliente(cliente.id)
                                    : null,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: ClienteOpcionCredito(cliente: cliente),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  List<Cliente> _clientesFiltrados() {
    final String consulta = _buscarController.text.trim().toLowerCase();
    if (consulta.isEmpty) {
      return widget.clientes;
    }

    return widget.clientes.where((Cliente cliente) {
      final String nombre = cliente.nombreCompleto.toLowerCase();
      final String cedula = (cliente.cedula ?? '').toLowerCase();
      final String negocio = (cliente.nombreComercial ?? '').toLowerCase();
      return nombre.contains(consulta) ||
          cedula.contains(consulta) ||
          negocio.contains(consulta);
    }).toList(growable: false);
  }

  void _alternarCliente(String clienteId) {
    final Set<String> actualizados =
        Set<String>.of(widget.clientesSeleccionadosIds);
    if (!actualizados.add(clienteId)) {
      actualizados.remove(clienteId);
    }
    widget.onChanged(actualizados);
  }
}

class MontosClientesCredito extends StatelessWidget {
  const MontosClientesCredito({
    super.key,
    required this.clientes,
    required this.clientesSeleccionadosIds,
    required this.enabled,
    required this.controllerForCliente,
  });

  final List<Cliente> clientes;
  final Set<String> clientesSeleccionadosIds;
  final bool enabled;
  final TextEditingController Function(String clienteId) controllerForCliente;

  @override
  Widget build(BuildContext context) {
    final List<Cliente> seleccionados = clientes
        .where(
          (Cliente cliente) => clientesSeleccionadosIds.contains(cliente.id),
        )
        .toList(growable: false);

    if (seleccionados.isEmpty) {
      return InputDecorator(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.request_quote_rounded),
          labelText: 'Monto por cliente',
        ),
        child: Text(
          'Selecciona al menos un cliente',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.clay.subtleText,
              ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Monto por cliente',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        ...seleccionados.map(
          (Cliente cliente) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MontoClienteCreditoItem(
              cliente: cliente,
              controller: controllerForCliente(cliente.id),
              enabled: enabled,
            ),
          ),
        ),
      ],
    );
  }
}

class MontoClienteCreditoItem extends StatelessWidget {
  const MontoClienteCreditoItem({
    super.key,
    required this.cliente,
    required this.controller,
    required this.enabled,
  });

  final Cliente cliente;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget clienteInfo = ClienteOpcionCredito(cliente: cliente);
        final Widget monto = TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monto',
            prefixIcon: Icon(Icons.request_quote_rounded),
          ),
        );

        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              clienteInfo,
              const SizedBox(height: 8),
              monto,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: clienteInfo),
            const SizedBox(width: 12),
            SizedBox(width: 220, child: monto),
          ],
        );
      },
    );
  }
}

class FormularioCredito extends StatelessWidget {
  const FormularioCredito({
    super.key,
    required this.clientes,
    required this.rutas,
    required this.monedas,
    required this.frecuencias,
    required this.cajasMenores,
    required this.clienteId,
    required this.rutaId,
    required this.monedaCodigo,
    required this.frecuenciaPagoId,
    required this.cajaMenorId,
    required this.fechaInicio,
    required this.omitirDomingos,
    required this.valorController,
    required this.interesController,
    required this.plazoController,
    required this.observacionController,
    required this.guardando,
    required this.onClienteChanged,
    required this.onRutaChanged,
    required this.onMonedaChanged,
    required this.onFrecuenciaChanged,
    required this.onCajaMenorChanged,
    required this.onFechaChanged,
    required this.onOmitirDomingosChanged,
    required this.onCrear,
    this.usarSuperficie = true,
    this.accionLabel = 'Crear credito',
    this.clienteBloqueado = false,
    this.monedaBloqueada = false,
    this.clientesSeleccionadosIds = const <String>{},
    this.valorClienteController,
    this.onClientesSeleccionadosChanged,
  });

  final List<Cliente> clientes;
  final List<RutaCatalogo> rutas;
  final List<Moneda> monedas;
  final List<FrecuenciaPago> frecuencias;
  final List<CajaMenorCatalogo> cajasMenores;
  final String? clienteId;
  final String? rutaId;
  final String? monedaCodigo;
  final int? frecuenciaPagoId;
  final String? cajaMenorId;
  final DateTime fechaInicio;
  final bool omitirDomingos;
  final TextEditingController valorController;
  final Set<String> clientesSeleccionadosIds;
  final TextEditingController Function(String clienteId)?
      valorClienteController;
  final TextEditingController interesController;
  final TextEditingController plazoController;
  final TextEditingController observacionController;
  final bool guardando;
  final ValueChanged<String?> onClienteChanged;
  final ValueChanged<Set<String>>? onClientesSeleccionadosChanged;
  final ValueChanged<String?> onRutaChanged;
  final ValueChanged<String?> onMonedaChanged;
  final ValueChanged<int?> onFrecuenciaChanged;
  final ValueChanged<String?> onCajaMenorChanged;
  final ValueChanged<DateTime> onFechaChanged;
  final ValueChanged<bool> onOmitirDomingosChanged;
  final VoidCallback onCrear;
  final bool usarSuperficie;
  final String accionLabel;
  final bool clienteBloqueado;
  final bool monedaBloqueada;

  @override
  Widget build(BuildContext context) {
    final bool seleccionarVariosClientes =
        onClientesSeleccionadosChanged != null && !clienteBloqueado;
    final Widget contenido = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (seleccionarVariosClientes)
          SelectorClientesCreditoMultiple(
            clientes: clientes,
            clientesSeleccionadosIds: clientesSeleccionadosIds,
            enabled: !guardando,
            onChanged: onClientesSeleccionadosChanged!,
          )
        else
          SelectorClienteCredito(
            clientes: clientes,
            clienteId: clienteId,
            enabled: !guardando && !clienteBloqueado,
            onChanged: onClienteChanged,
          ),
        const SizedBox(height: 12),
        CobroDropdownField<String?>(
          key: ValueKey<String?>('ruta-$rutaId'),
          labelText: 'Ruta',
          prefixIcon: const Icon(Icons.route_rounded),
          value: rutaId,
          hintText: 'Automatica',
          enabled: !guardando,
          items: <CobroDropdownItem<String?>>[
            const CobroDropdownItem<String?>(
              value: null,
              label: 'Automatica',
              subtitle: 'Asignacion automatica segun cliente',
              icon: Icons.auto_mode_rounded,
              iconColor: Color(0xFF6366F1),
            ),
            ...rutas.map(
              (RutaCatalogo ruta) => CobroDropdownItem<String?>(
                value: ruta.id,
                label: ruta.nombre,
                icon: Icons.alt_route_rounded,
                iconColor: const Color(0xFF3B82F6),
              ),
            ),
          ],
          onChanged: guardando ? null : onRutaChanged,
        ),
        const SizedBox(height: 12),
        DosColumnas(
          left: CobroDropdownField<String>(
            key: ValueKey<String?>('moneda-$monedaCodigo'),
            labelText: 'Moneda',
            prefixIcon: const Icon(Icons.attach_money_rounded),
            value: monedaCodigo,
            enabled: !guardando && !monedaBloqueada,
            menuWidth: 280,
            items: monedas
                .map(
                  (Moneda moneda) => CobroDropdownItem<String>(
                    value: moneda.codigo,
                    label: moneda.codigo,
                    subtitle:
                        moneda.nombre != moneda.codigo ? moneda.nombre : null,
                    icon: Icons.monetization_on_rounded,
                    iconColor: const Color(0xFF10B981),
                  ),
                )
                .toList(growable: false),
            onChanged: guardando || monedaBloqueada ? null : onMonedaChanged,
          ),
          right: CobroDropdownField<int>(
            key: ValueKey<String>('frecuencia-$frecuenciaPagoId'),
            labelText: 'Frecuencia',
            prefixIcon: const Icon(Icons.event_repeat_rounded),
            value: frecuenciaPagoId,
            enabled: !guardando,
            menuWidth: 280,
            items: frecuencias
                .map(
                  (FrecuenciaPago frecuencia) => CobroDropdownItem<int>(
                    value: frecuencia.id,
                    label: frecuencia.nombre,
                    subtitle: frecuencia.diasIntervalo > 1
                        ? 'Cada ${frecuencia.diasIntervalo} dias'
                        : 'Cobro diario',
                    icon: Icons.update_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                  ),
                )
                .toList(growable: false),
            onChanged: guardando ? null : onFrecuenciaChanged,
          ),
        ),
        const SizedBox(height: 12),
        CobroDropdownField<String?>(
          key: ValueKey<String?>('caja-$cajaMenorId'),
          labelText: 'Caja menor',
          prefixIcon: const Icon(Icons.savings_rounded),
          value: cajaMenorId,
          enabled: !guardando,
          items: cajasMenores
              .map(
                (CajaMenorCatalogo caja) => CobroDropdownItem<String?>(
                  value: caja.id,
                  label: caja.nombre,
                  subtitle: 'Moneda: ${caja.monedaCodigo}',
                  icon: Icons.savings_rounded,
                  iconColor: const Color(0xFF2563EB),
                ),
              )
              .toList(growable: false),
          onChanged: guardando ? null : onCajaMenorChanged,
        ),
        const SizedBox(height: 12),
        if (seleccionarVariosClientes) ...<Widget>[
          MontosClientesCredito(
            clientes: clientes,
            clientesSeleccionadosIds: clientesSeleccionadosIds,
            enabled: !guardando,
            controllerForCliente: valorClienteController!,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: interesController,
            enabled: !guardando,
            readOnly: true,
            enableInteractiveSelection: false,
            decoration: const InputDecoration(
              labelText: 'Interes %',
              prefixIcon: Icon(Icons.percent_rounded),
            ),
          ),
        ] else
          DosColumnas(
            left: TextField(
              controller: valorController,
              enabled: !guardando,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor principal',
                prefixIcon: Icon(Icons.request_quote_rounded),
              ),
            ),
            right: TextField(
              controller: interesController,
              enabled: !guardando,
              readOnly: true,
              enableInteractiveSelection: false,
              decoration: const InputDecoration(
                labelText: 'Interés %',
                prefixIcon: Icon(Icons.percent_rounded),
              ),
            ),
          ),
        const SizedBox(height: 12),
        DosColumnas(
          left: TextField(
            controller: plazoController,
            enabled: !guardando,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Plazo días',
              prefixIcon: Icon(Icons.date_range_rounded),
            ),
          ),
          right: OutlinedButton.icon(
            onPressed: guardando
                ? null
                : () async {
                    final DateTime? selected = await showDatePicker(
                      context: context,
                      initialDate: fechaInicio,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (selected != null) {
                      onFechaChanged(selected);
                    }
                  },
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(formatDateLabel(fechaInicio)),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: omitirDomingos,
          onChanged: guardando ? null : onOmitirDomingosChanged,
          title: const Text('Omitir domingos'),
          secondary: const Icon(Icons.weekend_rounded),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        if (!seleccionarVariosClientes) ...<Widget>[
          ResumenCreditoAnimado(
            valorController: valorController,
            interesController: interesController,
            plazoController: plazoController,
            frecuencias: frecuencias,
            frecuenciaPagoId: frecuenciaPagoId,
            fechaInicio: fechaInicio,
            omitirDomingos: omitirDomingos,
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: observacionController,
          enabled: !guardando,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Observación',
            prefixIcon: Icon(Icons.notes_rounded),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: guardando ? null : onCrear,
            icon: guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(accionLabel),
          ),
        ),
      ],
    );

    if (!usarSuperficie) {
      return contenido;
    }

    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: contenido,
    );
  }
}

class CamposCreditoSinCliente extends StatelessWidget {
  const CamposCreditoSinCliente({
    super.key,
    required this.rutas,
    required this.monedas,
    required this.frecuencias,
    required this.cajasMenores,
    required this.rutaId,
    required this.monedaCodigo,
    required this.frecuenciaPagoId,
    required this.cajaMenorId,
    required this.fechaInicio,
    required this.omitirDomingos,
    required this.valorController,
    required this.interesController,
    required this.plazoController,
    required this.observacionController,
    required this.guardando,
    required this.onRutaChanged,
    required this.onMonedaChanged,
    required this.onFrecuenciaChanged,
    required this.onCajaMenorChanged,
    required this.onFechaChanged,
    required this.onOmitirDomingosChanged,
  });

  final List<RutaCatalogo> rutas;
  final List<Moneda> monedas;
  final List<FrecuenciaPago> frecuencias;
  final List<CajaMenorCatalogo> cajasMenores;
  final String? rutaId;
  final String? monedaCodigo;
  final int? frecuenciaPagoId;
  final String? cajaMenorId;
  final DateTime fechaInicio;
  final bool omitirDomingos;
  final TextEditingController valorController;
  final TextEditingController interesController;
  final TextEditingController plazoController;
  final TextEditingController observacionController;
  final bool guardando;
  final ValueChanged<String?> onRutaChanged;
  final ValueChanged<String?> onMonedaChanged;
  final ValueChanged<int?> onFrecuenciaChanged;
  final ValueChanged<String?> onCajaMenorChanged;
  final ValueChanged<DateTime> onFechaChanged;
  final ValueChanged<bool> onOmitirDomingosChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CobroDropdownField<String?>(
          key: ValueKey<String?>('nuevo-cliente-modal-ruta-$rutaId'),
          labelText: 'Ruta',
          prefixIcon: const Icon(Icons.route_rounded),
          value: rutaId,
          hintText: 'Automatica',
          enabled: !guardando,
          items: <CobroDropdownItem<String?>>[
            const CobroDropdownItem<String?>(
              value: null,
              label: 'Automatica',
              subtitle: 'Asignacion automatica segun cliente',
              icon: Icons.auto_mode_rounded,
              iconColor: Color(0xFF6366F1),
            ),
            ...rutas.map(
              (RutaCatalogo ruta) => CobroDropdownItem<String?>(
                value: ruta.id,
                label: ruta.nombre,
                icon: Icons.alt_route_rounded,
                iconColor: const Color(0xFF3B82F6),
              ),
            ),
          ],
          onChanged: guardando ? null : onRutaChanged,
        ),
        const SizedBox(height: 12),
        DosColumnas(
          left: CobroDropdownField<String>(
            key: ValueKey<String?>('nuevo-cliente-modal-moneda-$monedaCodigo'),
            labelText: 'Moneda',
            prefixIcon: const Icon(Icons.attach_money_rounded),
            value: monedaCodigo,
            enabled: !guardando,
            menuWidth: 280,
            items: monedas
                .map(
                  (Moneda moneda) => CobroDropdownItem<String>(
                    value: moneda.codigo,
                    label: moneda.codigo,
                    subtitle:
                        moneda.nombre != moneda.codigo ? moneda.nombre : null,
                    icon: Icons.monetization_on_rounded,
                    iconColor: const Color(0xFF10B981),
                  ),
                )
                .toList(growable: false),
            onChanged: guardando ? null : onMonedaChanged,
          ),
          right: CobroDropdownField<int>(
            key: ValueKey<String>(
              'nuevo-cliente-modal-frecuencia-$frecuenciaPagoId',
            ),
            labelText: 'Frecuencia',
            prefixIcon: const Icon(Icons.event_repeat_rounded),
            value: frecuenciaPagoId,
            enabled: !guardando,
            menuWidth: 280,
            items: frecuencias
                .map(
                  (FrecuenciaPago frecuencia) => CobroDropdownItem<int>(
                    value: frecuencia.id,
                    label: frecuencia.nombre,
                    subtitle: frecuencia.diasIntervalo > 1
                        ? 'Cada ${frecuencia.diasIntervalo} dias'
                        : 'Cobro diario',
                    icon: Icons.update_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                  ),
                )
                .toList(growable: false),
            onChanged: guardando ? null : onFrecuenciaChanged,
          ),
        ),
        const SizedBox(height: 12),
        CobroDropdownField<String?>(
          key: ValueKey<String?>('nuevo-cliente-modal-caja-$cajaMenorId'),
          labelText: 'Caja menor',
          prefixIcon: const Icon(Icons.savings_rounded),
          value: cajaMenorId,
          enabled: !guardando,
          items: cajasMenores
              .map(
                (CajaMenorCatalogo caja) => CobroDropdownItem<String?>(
                  value: caja.id,
                  label: caja.nombre,
                  subtitle: 'Moneda: ${caja.monedaCodigo}',
                  icon: Icons.savings_rounded,
                  iconColor: const Color(0xFF2563EB),
                ),
              )
              .toList(growable: false),
          onChanged: guardando ? null : onCajaMenorChanged,
        ),
        const SizedBox(height: 12),
        DosColumnas(
          left: TextField(
            controller: valorController,
            enabled: !guardando,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Valor principal',
              prefixIcon: Icon(Icons.request_quote_rounded),
            ),
          ),
          right: TextField(
            controller: interesController,
            enabled: !guardando,
            readOnly: true,
            enableInteractiveSelection: false,
            decoration: const InputDecoration(
              labelText: 'Interes %',
              prefixIcon: Icon(Icons.percent_rounded),
            ),
          ),
        ),
        const SizedBox(height: 12),
        DosColumnas(
          left: TextField(
            controller: plazoController,
            enabled: !guardando,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Plazo dias',
              prefixIcon: Icon(Icons.date_range_rounded),
            ),
          ),
          right: OutlinedButton.icon(
            onPressed: guardando
                ? null
                : () async {
                    final DateTime? selected = await showDatePicker(
                      context: context,
                      initialDate: fechaInicio,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (selected != null) {
                      onFechaChanged(selected);
                    }
                  },
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(formatDateLabel(fechaInicio)),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: omitirDomingos,
          onChanged: guardando ? null : onOmitirDomingosChanged,
          title: const Text('Omitir domingos'),
          secondary: const Icon(Icons.weekend_rounded),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        ResumenCreditoAnimado(
          valorController: valorController,
          interesController: interesController,
          plazoController: plazoController,
          frecuencias: frecuencias,
          frecuenciaPagoId: frecuenciaPagoId,
          fechaInicio: fechaInicio,
          omitirDomingos: omitirDomingos,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: observacionController,
          enabled: !guardando,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Observacion',
            prefixIcon: Icon(Icons.notes_rounded),
          ),
        ),
      ],
    );
  }
}
