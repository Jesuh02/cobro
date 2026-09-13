export 'widgets/filtros_ruta.dart';
export 'widgets/selector_cobro_ruta_buscable.dart';
export 'widgets/selector_medio_pago_buscable.dart';
export 'widgets/tarjeta_cobro_ruta.dart';

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/page_layout.dart';
import '../../../../data/models/models.dart';
import '../../routes/data/api_road_router.dart';
import '../../routes/presentation/desktop_collection_route.dart';
import 'widgets/filtros_ruta.dart';
import 'widgets/tarjeta_cobro_ruta.dart';

const double desktopRouteMapBreakpoint = 1050;

CollectionMapCustomer mapCustomerFromCobro(
  CobroRuta cobro, {
  required bool canCollect,
  required bool canRoute,
}) {
  return CollectionMapCustomer(
    id: cobro.id,
    customerId: cobro.clienteId,
    creditId: cobro.id,
    name: cobro.cliente,
    identification: cobro.cedula,
    business: cobro.negocio,
    address: cobro.direccion,
    routeName: cobro.ruta,
    amountLabel: formatMoney(cobro.proximoSaldoCuota),
    installmentLabel: formatMoney(cobro.valorCuota),
    balanceLabel: formatMoney(cobro.saldo),
    dueDateLabel: formatDateLabel(cobro.proximaFechaPago),
    statusLabel: cobro.estadoCobro.etiqueta,
    statusColor: cobro.estadoCobro.color,
    canCollect: canCollect,
    canRoute: canRoute,
    isDueNow: cobro.estadoCobro == EstadoCobro.atrasado ||
        cobro.estadoCobro == EstadoCobro.pendiente,
    latitude: cobro.latitude,
    longitude: cobro.longitude,
  );
}

class RutaCobroView extends StatelessWidget {
  const RutaCobroView({
    super.key,
    required this.cobros,
    required this.cobrosBase,
    required this.buscarRutaController,
    required this.rutas,
    required this.rutaFiltroId,
    required this.filtroEstadoRuta,
    required this.cuotasEnPago,
    required this.cobrosConPagoInstantaneo,
    required this.puedeAgregarCuota,
    required this.puedeCrearCreditos,
    required this.guardando,
    required this.exportando,
    required this.hayFiltrosRuta,
    this.error,
    required this.roadRouter,
    required this.onRefresh,
    required this.onRutaChanged,
    required this.onFiltroEstadoChanged,
    required this.onExportarCobrosRuta,
    required this.onLimpiarFiltrosRuta,
    required this.onCrearCreditoModal,
    required this.onRegistrarPago,
    required this.onGuardarUbicacionCliente,
    required this.puedeRegistrarPagoRuta,
    required this.mapCustomerBuilder,
    this.breakpoint = desktopRouteMapBreakpoint,
  });

  final List<CobroRuta> cobros;
  final List<CobroRuta> cobrosBase;
  final TextEditingController buscarRutaController;
  final List<RutaCatalogo> rutas;
  final String? rutaFiltroId;
  final FiltroEstadoRuta filtroEstadoRuta;
  final Set<String> cuotasEnPago;
  final Set<String> cobrosConPagoInstantaneo;
  final bool puedeAgregarCuota;
  final bool puedeCrearCreditos;
  final bool guardando;
  final bool exportando;
  final bool hayFiltrosRuta;
  final String? error;
  final ApiRoadRouter roadRouter;
  final Future<void> Function() onRefresh;
  final ValueChanged<String?> onRutaChanged;
  final ValueChanged<FiltroEstadoRuta> onFiltroEstadoChanged;
  final VoidCallback onExportarCobrosRuta;
  final VoidCallback onLimpiarFiltrosRuta;
  final VoidCallback onCrearCreditoModal;
  final ValueChanged<CobroRuta> onRegistrarPago;
  final ValueChanged<CobroRuta> onGuardarUbicacionCliente;
  final bool Function(CobroRuta) puedeRegistrarPagoRuta;
  final CollectionMapCustomer Function(CobroRuta) mapCustomerBuilder;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    final bool mostrarMapaDesktop =
        MediaQuery.sizeOf(context).width >= breakpoint;
    final int atrasados = cobrosBase
        .where((CobroRuta cobro) => cobro.estadoCobro == EstadoCobro.atrasado)
        .length;
    final int pendientes = cobrosBase
        .where((CobroRuta cobro) => cobro.estadoCobro == EstadoCobro.pendiente)
        .length;
    final int alDia = cobrosBase
        .where((CobroRuta cobro) => cobro.estadoCobro == EstadoCobro.alDia)
        .length;
    final int pagados = cobrosBase
        .where((CobroRuta cobro) => cobro.estadoCobro == EstadoCobro.pagado)
        .length;

    final Widget filtros = FiltrosRuta(
      buscarController: buscarRutaController,
      rutas: rutas,
      rutaSeleccionadaId: rutaFiltroId,
      exportando: exportando,
      vistaMapaDesktop: mostrarMapaDesktop,
      mostrarLimpiarFiltros: hayFiltrosRuta,
      onRutaChanged: onRutaChanged,
      onExportar: onExportarCobrosRuta,
      onLimpiarFiltros: onLimpiarFiltrosRuta,
    );
    final Widget resumen = ResumenEstados(
      alDia: alDia,
      pendientes: pendientes,
      atrasados: atrasados,
      pagados: pagados,
      filtro: filtroEstadoRuta,
      onFiltroChanged: onFiltroEstadoChanged,
    );

    if (mostrarMapaDesktop) {
      final List<CollectionMapCustomer> mapCustomers =
          cobros.map(mapCustomerBuilder).toList(growable: false);
      final Map<String, CobroRuta> cobroById = <String, CobroRuta>{
        for (final CobroRuta cobro in cobros) cobro.id: cobro,
      };

      return DesktopCollectionRoute(
        header: const Encabezado(
          titulo: 'Ruta activa',
          acciones: <Widget>[],
        ),
        filters: filtros,
        summary: resumen,
        customers: mapCustomers,
        roadRouter: roadRouter,
        onRefresh: onRefresh,
        error: error == null ? null : ErrorBanner(message: error!),
        onCollect: (CollectionMapCustomer customer) {
          final CobroRuta? cobro = cobroById[customer.creditId];
          if (cobro != null && puedeRegistrarPagoRuta(cobro)) {
            onRegistrarPago(cobro);
          }
        },
        cardBuilder: (
          BuildContext context,
          CollectionMapCustomer customer,
          bool selected,
          VoidCallback onSelected,
        ) {
          final CobroRuta cobro = cobroById[customer.creditId]!;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSelected,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.all(selected ? 2 : 0),
                decoration: BoxDecoration(
                  color: selected
                      ? CobroAppTheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: selected
                        ? CobroAppTheme.primary.withValues(alpha: 0.6)
                        : Colors.transparent,
                  ),
                ),
                child: TarjetaCobroRuta(
                  cobro: cobro,
                  pagoEnProceso: cobro.proximaCuotaId != null &&
                      cuotasEnPago.contains(cobro.proximaCuotaId),
                  pagoAplicadoInstantaneo:
                      cobrosConPagoInstantaneo.contains(cobro.id),
                  onGuardarUbicacion:
                      guardando ? null : () => onGuardarUbicacionCliente(cobro),
                  onRegistrarPago: puedeRegistrarPagoRuta(cobro)
                      ? () => onRegistrarPago(cobro)
                      : null,
                ),
              ),
            ),
          );
        },
      );
    }

    return Pagina(
      titulo: 'Ruta activa',
      subtitulo: 'Cuotas pendientes desde créditos reales',
      error: error,
      onRefresh: onRefresh,
      children: <Widget>[
        filtros,
        const SizedBox(height: 14),
        resumen,
        const SizedBox(height: 16),
        if (cobros.isEmpty)
          EstadoVacio(
            icono: Icons.route_outlined,
            titulo: 'Sin cuotas por cobrar',
            mensaje: 'No hay créditos activos con saldo para el filtro actual.',
            accion: FilledButton.icon(
              onPressed: guardando || !puedeCrearCreditos
                  ? null
                  : onCrearCreditoModal,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Crear credito'),
            ),
          )
        else
          ...cobros.map(
            (CobroRuta cobro) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TarjetaCobroRuta(
                cobro: cobro,
                pagoEnProceso: cobro.proximaCuotaId != null &&
                    cuotasEnPago.contains(cobro.proximaCuotaId),
                pagoAplicadoInstantaneo:
                    cobrosConPagoInstantaneo.contains(cobro.id),
                onGuardarUbicacion:
                    guardando ? null : () => onGuardarUbicacionCliente(cobro),
                onRegistrarPago: guardando ||
                        cobro.proximaCuotaId == null ||
                        cuotasEnPago.contains(cobro.proximaCuotaId) ||
                        cobrosConPagoInstantaneo.contains(cobro.id) ||
                        !puedeAgregarCuota
                    ? null
                    : () => onRegistrarPago(cobro),
              ),
            ),
          ),
      ],
    );
  }
}
