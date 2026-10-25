export 'widgets/filtros_caja_menor.dart';
export 'widgets/movimiento_caja_item.dart';
export 'widgets/movimiento_detalle_sheet.dart';

import 'package:flutter/material.dart';

import '../../../../core/ui/page_layout.dart';
import '../../../../core/ui/skeletons.dart';
import '../../../../data/models/models.dart';
import 'widgets/movimiento_caja_item.dart';
import 'widgets/movimiento_detalle_sheet.dart';

class CajaMenorView extends StatelessWidget {
  const CajaMenorView({
    super.key,
    required this.movimientos,
    required this.hayCajaMenor,
    required this.mostrandoCargaMovimientosCaja,
    required this.cargandoMasMovimientosCaja,
    required this.puedeCrearCajaMenor,
    required this.puedeRegistrarFlujoCaja,
    required this.puedeModificarMovimientos,
    required this.puedeModificarCreditos,
    required this.puedeEliminarCreditos,
    required this.esAdministrador,
    required this.guardando,
    this.error,
    required this.onRefresh,
    required this.onNearEnd,
    required this.onCerrarCajaMenor,
    required this.onCrearCajaMenor,
    required this.onMovimientoCaja,
    required this.onModificarMovimiento,
    this.onVerDetalleMovimiento,
    this.mostrarMensaje,
    required this.buscarController,
    required this.filtros,
  });

  final List<MovimientoCaja> movimientos;
  final bool hayCajaMenor;
  final bool mostrandoCargaMovimientosCaja;
  final bool cargandoMasMovimientosCaja;
  final bool puedeCrearCajaMenor;
  final bool puedeRegistrarFlujoCaja;
  final bool puedeModificarMovimientos;
  final bool puedeModificarCreditos;
  final bool puedeEliminarCreditos;
  final bool esAdministrador;
  final bool guardando;
  final String? error;
  final Future<void> Function() onRefresh;
  final VoidCallback onNearEnd;
  final VoidCallback onCerrarCajaMenor;
  final VoidCallback onCrearCajaMenor;
  final VoidCallback onMovimientoCaja;
  final ValueChanged<MovimientoCaja> onModificarMovimiento;
  final ValueChanged<MovimientoCaja>? onVerDetalleMovimiento;
  final void Function(String)? mostrarMensaje;
  final TextEditingController buscarController;
  final Widget filtros;

  void _abrirFichaDetalle(
    BuildContext context,
    MovimientoCaja movimiento,
    bool puedeModificar,
  ) {
    if (onVerDetalleMovimiento != null) {
      onVerDetalleMovimiento!(movimiento);
      return;
    }

    mostrarMovimientoDetalleSheet(
      context: context,
      movimiento: movimiento,
      puedeModificar: puedeModificar,
      onModificar: () => onModificarMovimiento(movimiento),
      mostrarMensaje: mostrarMensaje,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool mostrarCerrar = hayCajaMenor && puedeCrearCajaMenor;
    final bool mostrarNuevaCaja = hayCajaMenor && puedeCrearCajaMenor;
    final bool mostrarMovimiento =
        hayCajaMenor ? puedeRegistrarFlujoCaja : puedeCrearCajaMenor;

    Widget construirBotonCerrar({bool compacto = false}) {
      return OutlinedButton.icon(
        onPressed: guardando ? null : onCerrarCajaMenor,
        icon: const Icon(Icons.lock_clock_rounded),
        style: compacto
            ? OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              )
            : null,
        label: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Cerrar caja', maxLines: 1),
        ),
      );
    }

    Widget construirBotonNuevaCaja({bool compacto = false}) {
      return OutlinedButton.icon(
        onPressed: guardando ? null : onCrearCajaMenor,
        icon: const Icon(Icons.account_balance_wallet_outlined),
        style: compacto
            ? OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              )
            : null,
        label: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Nueva caja menor', maxLines: 1),
        ),
      );
    }

    Widget construirBotonMovimiento({bool compacto = false}) {
      return FilledButton.icon(
        onPressed: guardando
            ? null
            : hayCajaMenor
                ? onMovimientoCaja
                : onCrearCajaMenor,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          hayCajaMenor ? 'Registrar movimiento' : 'Crear caja menor',
        ),
      );
    }

    return Pagina(
      titulo: 'Caja menor',
      error: error,
      onRefresh: onRefresh,
      onNearEnd: onNearEnd,
      acciones: <Widget>[
        if (mostrarCerrar) construirBotonCerrar(),
        if (mostrarNuevaCaja) construirBotonNuevaCaja(),
        if (mostrarMovimiento) construirBotonMovimiento(),
      ],
      accionesBuilder: (BuildContext context, bool compacto) {
        if (!compacto) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: <Widget>[
              if (mostrarCerrar) construirBotonCerrar(),
              if (mostrarNuevaCaja) construirBotonNuevaCaja(),
              if (mostrarMovimiento) construirBotonMovimiento(),
            ],
          );
        }

        if (mostrarCerrar && mostrarNuevaCaja && mostrarMovimiento) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: construirBotonCerrar(compacto: true)),
                  const SizedBox(width: 8),
                  Expanded(child: construirBotonNuevaCaja(compacto: true)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: construirBotonMovimiento(compacto: true),
              ),
            ],
          );
        }

        if (mostrarCerrar && mostrarNuevaCaja) {
          return Row(
            children: <Widget>[
              Expanded(child: construirBotonCerrar(compacto: true)),
              const SizedBox(width: 8),
              Expanded(child: construirBotonNuevaCaja(compacto: true)),
            ],
          );
        }

        if (mostrarCerrar && mostrarMovimiento) {
          return Row(
            children: <Widget>[
              Expanded(child: construirBotonCerrar(compacto: true)),
              const SizedBox(width: 8),
              Expanded(child: construirBotonMovimiento(compacto: true)),
            ],
          );
        }

        if (mostrarNuevaCaja && mostrarMovimiento) {
          return Row(
            children: <Widget>[
              Expanded(child: construirBotonNuevaCaja(compacto: true)),
              const SizedBox(width: 8),
              Expanded(child: construirBotonMovimiento(compacto: true)),
            ],
          );
        }

        if (mostrarMovimiento) {
          return SizedBox(
            width: double.infinity,
            child: construirBotonMovimiento(compacto: true),
          );
        }

        if (mostrarCerrar) {
          return SizedBox(
            width: double.infinity,
            child: construirBotonCerrar(compacto: true),
          );
        }

        if (mostrarNuevaCaja) {
          return SizedBox(
            width: double.infinity,
            child: construirBotonNuevaCaja(compacto: true),
          );
        }

        return const SizedBox.shrink();
      },
      children: <Widget>[
        TextField(
          controller: buscarController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            labelText: 'Buscar movimiento o pago',
          ),
        ),
        const SizedBox(height: 12),
        filtros,
        const SizedBox(height: 16),
        if (mostrandoCargaMovimientosCaja)
          const SkeletonListaMovimientosCaja()
        else if (movimientos.isEmpty)
          EstadoVacio(
            icono: Icons.savings_outlined,
            titulo: hayCajaMenor ? 'Sin movimientos' : 'Sin caja menor',
            mensaje: hayCajaMenor
                ? 'No hay movimientos ni pagos para mostrar.'
                : puedeCrearCajaMenor
                    ? 'Crea una caja menor para comenzar a registrar movimientos.'
                    : 'No tienes una caja menor asignada. Contacta al administrador para que cree tu caja.',
            accion:
                (hayCajaMenor ? puedeRegistrarFlujoCaja : puedeCrearCajaMenor)
                    ? FilledButton.icon(
                        onPressed: guardando
                            ? null
                            : hayCajaMenor
                                ? onMovimientoCaja
                                : onCrearCajaMenor,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(
                          hayCajaMenor
                              ? 'Registrar movimiento'
                              : 'Crear caja menor',
                        ),
                      )
                    : null,
          )
        else
          ...movimientos.map(
            (MovimientoCaja movimiento) {
              final bool esDesembolsoCredito =
                  movimiento.referenciaTabla == 'credito_desembolso';
              final bool puedeModificar = puedeModificarMovimientos &&
                  (!esDesembolsoCredito || puedeModificarCreditos);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MovimientoCajaItem(
                  movimiento: movimiento,
                  puedeModificar: puedeModificar,
                  onTap: () => _abrirFichaDetalle(context, movimiento, puedeModificar),
                  onModificar: () => onModificarMovimiento(movimiento),
                ),
              );
            },
          ),
        if (cargandoMasMovimientosCaja)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
