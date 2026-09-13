export 'widgets/filtros_caja_menor.dart';
export 'widgets/movimiento_caja_item.dart';

import 'package:flutter/material.dart';

import '../../../../core/ui/page_layout.dart';
import '../../../../core/ui/skeletons.dart';
import '../../../../data/models/models.dart';
import 'widgets/movimiento_caja_item.dart';

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
    required this.puedeEliminarMovimientos,
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
    required this.onEliminarMovimiento,
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
  final bool puedeEliminarMovimientos;
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
  final ValueChanged<MovimientoCaja> onEliminarMovimiento;
  final TextEditingController buscarController;
  final Widget filtros;

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Caja menor',
      error: error,
      onRefresh: onRefresh,
      onNearEnd: onNearEnd,
      acciones: <Widget>[
        if (hayCajaMenor && puedeCrearCajaMenor)
          OutlinedButton.icon(
            onPressed: guardando ? null : onCerrarCajaMenor,
            icon: const Icon(Icons.lock_clock_rounded),
            label: const Text('Cerrar caja'),
          ),
        if (hayCajaMenor && puedeCrearCajaMenor && esAdministrador)
          OutlinedButton.icon(
            onPressed: guardando ? null : onCrearCajaMenor,
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Nueva caja menor'),
          ),
        if (hayCajaMenor ? puedeRegistrarFlujoCaja : puedeCrearCajaMenor)
          FilledButton.icon(
            onPressed: guardando
                ? null
                : hayCajaMenor
                    ? onMovimientoCaja
                    : onCrearCajaMenor,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              hayCajaMenor ? 'Registrar movimiento' : 'Crear caja menor',
            ),
          ),
      ],
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MovimientoCajaItem(
                  movimiento: movimiento,
                  puedeModificar: puedeModificarMovimientos &&
                      (!esDesembolsoCredito || puedeModificarCreditos),
                  puedeEliminar: puedeEliminarMovimientos &&
                      (!esDesembolsoCredito || puedeEliminarCreditos),
                  onModificar: () => onModificarMovimiento(movimiento),
                  onEliminar: () => onEliminarMovimiento(movimiento),
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
