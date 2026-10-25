import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/chips_indicadores.dart';
import '../../../../core/ui/clay.dart';
import '../../../../core/ui/cobro_dropdown.dart';
import '../../../../core/ui/island_modal_sheet.dart';
import '../../../../data/models/models.dart';
import '../widgets/selector_cobro_ruta_buscable.dart';
import '../widgets/selector_medio_pago_buscable.dart';

/// Despliega el formulario para registrar pagos de ruta en un Modal Bottom Sheet
/// flotante (Island Sheet), coherente con el sistema de diseño y adaptado al pulgar.
Future<void> mostrarDialogoRegistrarPago({
  required BuildContext context,
  required CobroRuta cobro,
  required bool puedeAgregarCuota,
  required List<MedioPago> mediosPago,
  required List<CajaMenorCatalogo> cajasMenores,
  required List<CobroRuta> cobrosRuta,
  required Set<String> cuotasEnPago,
  required String? rutaFiltroId,
  required void Function(String) mostrarMensaje,
  required String Function(Object) mensajeError,
  required Future<void> Function(List<PagoRutaSolicitud>) onRegistrarPagos,
}) async {
  if (!puedeAgregarCuota) {
    mostrarMensaje('No tienes permiso para agregar cuota');
    return;
  }

  if (cajasMenores.isEmpty) {
    mostrarMensaje('No tienes una caja menor activa para registrar pagos');
    return;
  }

  if (mediosPago.isEmpty) {
    mostrarMensaje('No hay medios de pago registrados');
    return;
  }

  final List<CobroRuta> cobrosDisponibles = cobrosRuta
      .where(
        (CobroRuta item) =>
            item.proximaCuotaId != null &&
            item.saldo > 0.009 &&
            (rutaFiltroId == null || item.rutaId == rutaFiltroId),
      )
      .toList(growable: false);

  await mostrarIslandModalBottomSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) {
      return PagoRutaSheet(
        cobroInicial: cobro,
        mediosPago: mediosPago,
        cajasMenores: cajasMenores,
        cobrosDisponibles: cobrosDisponibles,
        cuotasEnPago: cuotasEnPago,
        mostrarMensaje: mostrarMensaje,
        mensajeError: mensajeError,
        onRegistrarPagos: onRegistrarPagos,
      );
    },
  );
}

class PagoRutaSheet extends StatefulWidget {
  const PagoRutaSheet({
    super.key,
    required this.cobroInicial,
    required this.mediosPago,
    required this.cajasMenores,
    required this.cobrosDisponibles,
    required this.cuotasEnPago,
    required this.mostrarMensaje,
    required this.mensajeError,
    required this.onRegistrarPagos,
  });

  final CobroRuta cobroInicial;
  final List<MedioPago> mediosPago;
  final List<CajaMenorCatalogo> cajasMenores;
  final List<CobroRuta> cobrosDisponibles;
  final Set<String> cuotasEnPago;
  final void Function(String) mostrarMensaje;
  final String Function(Object) mensajeError;
  final Future<void> Function(List<PagoRutaSolicitud>) onRegistrarPagos;

  @override
  State<PagoRutaSheet> createState() => _PagoRutaSheetState();
}

class _PagoRutaSheetState extends State<PagoRutaSheet> {
  late String _medioPagoCodigo;
  late String _cajaMenorSeleccionadaId;
  late final TextEditingController _observacionController;
  late final List<PagoRutaSeleccion> _seleccionados;
  bool _guardandoPago = false;
  bool _mostrarSelectorOtros = false;

  @override
  void initState() {
    super.initState();
    _medioPagoCodigo = widget.mediosPago.first.codigo;
    _cajaMenorSeleccionadaId = widget.cajasMenores.first.id;
    _observacionController = TextEditingController();
    _seleccionados = <PagoRutaSeleccion>[
      PagoRutaSeleccion(widget.cobroInicial),
    ];
  }

  @override
  void dispose() {
    _observacionController.dispose();
    for (final PagoRutaSeleccion item in _seleccionados) {
      item.montoController.dispose();
    }
    super.dispose();
  }

  void _enviarPago() {
    if (_guardandoPago) {
      return;
    }
    if (_seleccionados.isEmpty) {
      widget.mostrarMensaje('Agrega al menos un cliente');
      return;
    }

    final String? observacion = _observacionController.text.trim().isEmpty
        ? null
        : _observacionController.text.trim();
    final List<PagoRutaSolicitud> pagos = <PagoRutaSolicitud>[];

    for (final PagoRutaSeleccion item in _seleccionados) {
      final String? cuotaId = item.cuotaId;
      if (cuotaId == null || widget.cuotasEnPago.contains(cuotaId)) {
        widget.mostrarMensaje('Este pago ya se esta procesando');
        return;
      }

      final double monto;
      try {
        monto = parseMontoInput(item.montoController.text);
      } catch (error) {
        widget.mostrarMensaje(widget.mensajeError(error));
        return;
      }

      if (monto > item.cobro.saldo) {
        widget.mostrarMensaje(
          'El pago de ${item.cobro.cliente} supera el saldo',
        );
        return;
      }

      pagos.add(
        PagoRutaSolicitud(
          cuotaId: cuotaId,
          monto: monto,
          cajaMenorId: _cajaMenorSeleccionadaId,
          medioPagoCodigo: _medioPagoCodigo,
          observacion: observacion,
        ),
      );
    }

    setState(() => _guardandoPago = true);

    if (mounted) {
      Navigator.of(context).pop();
    }

    unawaited(widget.onRegistrarPagos(pagos));
  }

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final Set<String> cuotasSeleccionadas = _seleccionados
        .map((PagoRutaSeleccion item) => item.cuotaId)
        .whereType<String>()
        .toSet();

    return IslandModalSheet(
      maxHeightFactor: 0.88,
      footer: _FooterAcciones(
        guardando: _guardandoPago,
        onCancelar: () => Navigator.of(context).pop(),
        onRegistrar: _enviarPago,
      ),
      children: <Widget>[
        // Encabezado del sheet
        _HeaderPagoRuta(cobro: widget.cobroInicial),
        const SizedBox(height: 12),

        // Caja menor destino
        if (widget.cajasMenores.length > 1) ...<Widget>[
          CobroDropdownField<String>(
            labelText: 'Caja menor destino',
            prefixIcon: const Icon(Icons.point_of_sale_rounded),
            value: _cajaMenorSeleccionadaId,
            items: widget.cajasMenores
                .map(
                  (CajaMenorCatalogo c) => CobroDropdownItem<String>(
                    value: c.id,
                    label: c.nombre,
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                )
                .toList(growable: false),
            onChanged: _guardandoPago
                ? null
                : (String? value) {
                    if (value != null) {
                      setState(() => _cajaMenorSeleccionadaId = value);
                    }
                  },
          ),
          const SizedBox(height: 12),
        ] else ...<Widget>[
          _TarjetaCajaActiva(caja: widget.cajasMenores.first),
          const SizedBox(height: 12),
        ],

        // Fichas de cobro por cliente seleccionado
        ..._seleccionados.map(
          (PagoRutaSeleccion item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FichaClienteCobro(
              item: item,
              puedeQuitar: _seleccionados.length > 1,
              habilitado: !_guardandoPago,
              onQuitar: () {
                setState(() => _seleccionados.remove(item));
              },
            ),
          ),
        ),

        // Sección opcional para buscar y agregar otros clientes
        TarjetaSeccionSheet(
          titulo: 'Buscar y agregar cliente',
          icono: Icons.person_add_alt_1_rounded,
          children: <Widget>[
            if (!_mostrarSelectorOtros)
              InkWell(
                onTap: () => setState(() => _mostrarSelectorOtros = true),
                borderRadius: BorderRadius.circular(ClayRadius.control),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: 18,
                        color: CobroAppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Agregar otro cobro a este recibo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: CobroAppTheme.primary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: clay.subtleText,
                      ),
                    ],
                  ),
                ),
              )
            else ...<Widget>[
              SelectorCobroRutaBuscable(
                cobros: widget.cobrosDisponibles,
                cuotasSeleccionadas: cuotasSeleccionadas,
                enabled: !_guardandoPago,
                onSelected: (CobroRuta nuevo) {
                  if (cuotasSeleccionadas.contains(nuevo.proximaCuotaId)) {
                    return;
                  }
                  setState(() {
                    _seleccionados.add(PagoRutaSeleccion(nuevo));
                    _mostrarSelectorOtros = false;
                  });
                },
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      setState(() => _mostrarSelectorOtros = false),
                  child: const Text('Ocultar buscador'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Medio de pago y Observación
        TarjetaSeccionSheet(
          titulo: 'Medio de pago y detalles',
          icono: Icons.payment_rounded,
          children: <Widget>[
            SelectorMedioPagoBuscable(
              mediosPago: widget.mediosPago,
              medioPagoCodigo: _medioPagoCodigo,
              enabled: !_guardandoPago,
              onChanged: (String value) {
                setState(() => _medioPagoCodigo = value);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _observacionController,
              enabled: !_guardandoPago,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observacion',
                hintText: 'Nota o referencia de pago (opcional)...',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _HeaderPagoRuta extends StatelessWidget {
  const _HeaderPagoRuta({required this.cobro});

  final CobroRuta cobro;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final String cedula = (cobro.cedula ?? '').trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        CircleAvatar(
          radius: 24,
          backgroundColor: CobroAppTheme.primary.withValues(alpha: 0.14),
          child: Text(
            cobro.cliente.isEmpty
                ? '?'
                : cobro.cliente.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: CobroAppTheme.primary,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'Registrar pagos',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: CobroAppTheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                cobro.cliente,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: clay.text,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                <String>[
                  if (cedula.isNotEmpty) 'CC $cedula',
                  cobro.ruta,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: clay.subtleText,
                      fontWeight: FontWeight.w500,
                      fontSize: 11.5,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        EstadoChip(estado: cobro.estadoCobro),
      ],
    );
  }
}

class _TarjetaCajaActiva extends StatelessWidget {
  const _TarjetaCajaActiva({required this.caja});

  final CajaMenorCatalogo caja;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: clay.surfaceLow,
        borderRadius: BorderRadius.circular(ClayRadius.small),
        border: Border.all(color: clay.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.point_of_sale_rounded,
            size: 20,
            color: CobroAppTheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Caja activa destino',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: clay.subtleText,
                  ),
                ),
                Text(
                  caja.nombre,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: clay.text,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CobroAppTheme.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: CobroAppTheme.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.check_circle_rounded,
                  size: 13,
                  color: CobroAppTheme.success,
                ),
                const SizedBox(width: 4),
                Text(
                  'Abierta',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: CobroAppTheme.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FichaClienteCobro extends StatelessWidget {
  const _FichaClienteCobro({
    required this.item,
    required this.puedeQuitar,
    required this.habilitado,
    required this.onQuitar,
  });

  final PagoRutaSeleccion item;
  final bool puedeQuitar;
  final bool habilitado;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final CobroRuta cobro = item.cobro;
    final double cuotaPactada = cobro.valorCuota;
    final double saldoTotal = cobro.saldo;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: clay.surfaceLow,
        borderRadius: BorderRadius.circular(ClayRadius.small),
        border: Border.all(color: clay.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Fila cabecera del cliente
          Row(
            children: <Widget>[
              Icon(
                Icons.person_pin_circle_outlined,
                size: 18,
                color: CobroAppTheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      cobro.cliente,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: clay.text,
                      ),
                    ),
                    Text(
                      'Cuota ${cobro.proximaNumeroCuota ?? '-'} de ${cobro.numeroCuotas} · Saldo: ${formatMoney(saldoTotal)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: clay.subtleText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (puedeQuitar)
                IconButton(
                  tooltip: 'Quitar cliente',
                  onPressed: habilitado ? onQuitar : null,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Campo de monto
          TextField(
            controller: item.montoController,
            enabled: habilitado,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: 'Monto de ${cobro.cliente}',
              prefixIcon: const Icon(Icons.payments_rounded),
            ),
          ),
          const SizedBox(height: 8),

          // Chips de atajo rápido 1-Tap
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              _BotonMontoRapido(
                etiqueta: 'Cuota: ${formatMoney(cuotaPactada)}',
                onTap: habilitado
                    ? () {
                        item.montoController.text =
                            formatNumber(cobro.proximoSaldoCuota);
                      }
                    : null,
              ),
              if (saldoTotal > cuotaPactada)
                _BotonMontoRapido(
                  etiqueta: 'Liquidar: ${formatMoney(saldoTotal)}',
                  onTap: habilitado
                      ? () {
                          item.montoController.text = formatNumber(saldoTotal);
                        }
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotonMontoRapido extends StatelessWidget {
  const _BotonMontoRapido({
    required this.etiqueta,
    this.onTap,
  });

  final String etiqueta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: clay.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: CobroAppTheme.primary.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.flash_on_rounded,
                size: 12,
                color: CobroAppTheme.primary,
              ),
              const SizedBox(width: 3),
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: clay.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterAcciones extends StatelessWidget {
  const _FooterAcciones({
    required this.guardando,
    required this.onCancelar,
    required this.onRegistrar,
  });

  final bool guardando;
  final VoidCallback onCancelar;
  final VoidCallback onRegistrar;

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
            flex: 1,
            child: OutlinedButton(
              onPressed: guardando ? null : onCancelar,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ClayRadius.control),
                ),
              ),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: guardando ? null : onRegistrar,
              icon: guardando
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 17),
              label: Text(
                guardando ? 'Guardando...' : 'Registrar',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ClayRadius.control),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
