import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/cobro_dropdown.dart';
import '../../../../core/ui/page_layout.dart';
import '../../../../data/models/models.dart';

const String todasLasCajasFiltro = '__todas_las_cajas__';

class ConteoCreditosInicio {
  const ConteoCreditosInicio({
    required this.total,
    required this.activos,
    required this.inactivos,
  });

  factory ConteoCreditosInicio.fromJson(Map<String, dynamic> json) {
    return ConteoCreditosInicio(
      total: parseJsonInt(json['total']),
      activos: parseJsonInt(json['activos']),
      inactivos: parseJsonInt(json['inactivos']),
    );
  }

  const ConteoCreditosInicio.vacio()
      : total = 0,
        activos = 0,
        inactivos = 0;

  final int total;
  final int activos;
  final int inactivos;
}

class PaginaInicioPresupuesto extends StatelessWidget {
  const PaginaInicioPresupuesto({
    required this.totales,
    this.graficas,
    required this.clientesActivos,
    required this.cartera,
    required this.conteoCreditos,
    required this.creditosAtrasados,
    required this.fechaInicio,
    required this.fechaFin,
    required this.items,
    required this.cajasMenores,
    required this.buscarCajaController,
    required this.onCajaChanged,
    required this.fechaHoyActiva,
    required this.todosLosDiasActivo,
    required this.onFechaHoy,
    required this.onTodosLosDias,
    required this.onFechaDesde,
    required this.onFechaHasta,
    required this.onLimpiarFiltros,
    required this.onVerCreditos,
    required this.onVerActivos,
    required this.onVerInactivos,
    required this.onVerAtrasados,
    required this.onRefresh,
    required this.hayFiltros,
    this.cajaMenorId,
    this.fechaDesde,
    this.fechaHasta,
    this.error,
  });

  final PresupuestoTotales totales;
  final Widget? graficas;
  final int clientesActivos;
  final double cartera;
  final ConteoCreditosInicio conteoCreditos;
  final int creditosAtrasados;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final List<PresupuestoItem> items;
  final List<CajaMenorCatalogo> cajasMenores;
  final String? cajaMenorId;
  final TextEditingController buscarCajaController;
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final bool hayFiltros;
  final ValueChanged<String?> onCajaChanged;
  final bool fechaHoyActiva;
  final bool todosLosDiasActivo;
  final VoidCallback onFechaHoy;
  final VoidCallback onTodosLosDias;
  final VoidCallback onFechaDesde;
  final VoidCallback onFechaHasta;
  final VoidCallback onLimpiarFiltros;
  final VoidCallback onVerCreditos;
  final VoidCallback onVerActivos;
  final VoidCallback onVerInactivos;
  final VoidCallback onVerAtrasados;
  final Future<void> Function() onRefresh;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double horizontal = constraints.maxWidth < 520 ? 16 : 28;
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 36),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: EntradaAnimada(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            EncabezadoInicioPresupuesto(
                              fechaInicio: fechaInicio,
                              fechaFin: fechaFin,
                            ),
                            if (error != null) ...<Widget>[
                              const SizedBox(height: 16),
                              ErrorBanner(message: error!),
                            ],
                            const SizedBox(height: 22),
                            if (graficas != null) ...<Widget>[
                              const TituloSeccionPresupuesto(
                                icono: Icons.query_stats_rounded,
                                titulo: 'Panorama financiero',
                                subtitulo:
                                    'Flujo, composicion y distribucion en tiempo real',
                              ),
                              const SizedBox(height: 12),
                              graficas!,
                              const SizedBox(height: 28),
                            ],
                            FiltrosInicioPresupuesto(
                              cajasMenores: cajasMenores,
                              cajaMenorId: cajaMenorId,
                              buscarCajaController: buscarCajaController,
                              fechaDesde: fechaDesde,
                              fechaHasta: fechaHasta,
                              hayFiltros: hayFiltros,
                              onCajaChanged: onCajaChanged,
                              fechaHoyActiva: fechaHoyActiva,
                              todosLosDiasActivo: todosLosDiasActivo,
                              onFechaHoy: onFechaHoy,
                              onTodosLosDias: onTodosLosDias,
                              onFechaDesde: onFechaDesde,
                              onFechaHasta: onFechaHasta,
                              onLimpiarFiltros: onLimpiarFiltros,
                            ),
                            const SizedBox(height: 22),
                            ResumenCreditosInicio(
                              montoCreditos: totales.creditos,
                              activos: conteoCreditos.activos,
                              inactivos: conteoCreditos.inactivos,
                              atrasados: creditosAtrasados,
                              onVerCreditos: onVerCreditos,
                              onVerActivos: onVerActivos,
                              onVerInactivos: onVerInactivos,
                              onVerAtrasados: onVerAtrasados,
                            ),
                            const SizedBox(height: 28),
                            TarjetaTotalPresupuesto(
                              total: totales.presupuesto,
                            ),
                            const SizedBox(height: 28),
                            const TituloSeccionPresupuesto(
                              icono: Icons.donut_large_rounded,
                              titulo: 'Composición del presupuesto',
                              subtitulo: 'Balance actual de ingresos y salidas',
                            ),
                            const SizedBox(height: 12),
                            ComposicionPresupuesto(totales: totales),
                            const SizedBox(height: 28),
                            const TituloSeccionPresupuesto(
                              icono: Icons.insights_rounded,
                              titulo: 'Actividad',
                              subtitulo: 'Cartera y clientes vinculados',
                            ),
                            const SizedBox(height: 12),
                            ActividadPresupuesto(
                              clientesActivos: clientesActivos,
                              cartera: cartera,
                            ),
                            const SizedBox(height: 28),
                            const TituloSeccionPresupuesto(
                              icono: Icons.account_balance_wallet_rounded,
                              titulo: 'Presupuesto por caja',
                              subtitulo: 'Detalle de la caja seleccionada',
                            ),
                            const SizedBox(height: 12),
                            if (items.isEmpty)
                              const EstadoVacio(
                                icono: Icons.account_balance_wallet_outlined,
                                titulo: 'Sin datos para la caja',
                                mensaje:
                                    'Ajusta la caja o el rango de fechas para ver presupuesto.',
                              )
                            else
                              ...items.map(
                                (PresupuestoItem item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: TarjetaPresupuestoItem(item: item),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class FiltrosInicioPresupuesto extends StatelessWidget {
  const FiltrosInicioPresupuesto({
    required this.cajasMenores,
    required this.buscarCajaController,
    required this.hayFiltros,
    required this.onCajaChanged,
    required this.fechaHoyActiva,
    required this.todosLosDiasActivo,
    required this.onFechaHoy,
    required this.onTodosLosDias,
    required this.onFechaDesde,
    required this.onFechaHasta,
    required this.onLimpiarFiltros,
    this.cajaMenorId,
    this.fechaDesde,
    this.fechaHasta,
  });

  final List<CajaMenorCatalogo> cajasMenores;
  final String? cajaMenorId;
  final TextEditingController buscarCajaController;
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final bool hayFiltros;
  final ValueChanged<String?> onCajaChanged;
  final bool fechaHoyActiva;
  final bool todosLosDiasActivo;
  final VoidCallback onFechaHoy;
  final VoidCallback onTodosLosDias;
  final VoidCallback onFechaDesde;
  final VoidCallback onFechaHasta;
  final VoidCallback onLimpiarFiltros;

  @override
  Widget build(BuildContext context) {
    final bool cajaSeleccionadaVisible = cajasMenores.any(
      (CajaMenorCatalogo caja) => caja.id == cajaMenorId,
    );
    final String? value = cajaMenorId == todasLasCajasFiltro
        ? todasLasCajasFiltro
        : cajaSeleccionadaVisible
            ? cajaMenorId
            : null;

    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 250,
            child: TextField(
              controller: buscarCajaController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Buscar caja',
              ),
            ),
          ),
          SizedBox(
            width: 270,
            child: CobroDropdownField<String?>(
              key: ValueKey<String?>('inicio-caja-$value'),
              labelText: 'Caja',
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              value: value,
              hintText: 'Selecciona una caja',
              menuWidth: 270,
              items: <CobroDropdownItem<String?>>[
                const CobroDropdownItem<String?>(
                  value: todasLasCajasFiltro,
                  label: 'Todas las cajas',
                  subtitle: 'Ver movimientos globales',
                  icon: Icons.all_inbox_rounded,
                  iconColor: Color(0xFF6366F1),
                ),
                ...cajasMenores.map(
                  (CajaMenorCatalogo caja) => CobroDropdownItem<String?>(
                    value: caja.id,
                    label: caja.nombre,
                    subtitle: 'Moneda: ${caja.monedaCodigo}',
                    icon: Icons.savings_rounded,
                    iconColor: const Color(0xFF2563EB),
                  ),
                ),
              ],
              onChanged: onCajaChanged,
            ),
          ),
          OutlinedButton.icon(
            onPressed: fechaHoyActiva ? null : onFechaHoy,
            icon: const Icon(Icons.today_rounded),
            label: const Text('Hoy'),
          ),
          OutlinedButton.icon(
            onPressed: todosLosDiasActivo ? null : onTodosLosDias,
            icon: const Icon(Icons.all_inclusive_rounded),
            label: const Text('Todos los dias'),
          ),
          OutlinedButton.icon(
            onPressed: onFechaDesde,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(
              fechaDesde == null
                  ? 'Desde'
                  : 'Desde ${formatDateLabel(fechaDesde)}',
            ),
          ),
          OutlinedButton.icon(
            onPressed: onFechaHasta,
            icon: const Icon(Icons.event_available_rounded),
            label: Text(
              fechaHasta == null
                  ? 'Hasta'
                  : 'Hasta ${formatDateLabel(fechaHasta)}',
            ),
          ),
          if (hayFiltros)
            Tooltip(
              message: 'Limpiar filtros',
              child: IconButton.outlined(
                onPressed: onLimpiarFiltros,
                icon: const Icon(Icons.filter_alt_off_rounded),
              ),
            ),
        ],
      ),
    );
  }
}

class ResumenCreditosInicio extends StatelessWidget {
  const ResumenCreditosInicio({
    required this.montoCreditos,
    required this.activos,
    required this.inactivos,
    required this.atrasados,
    required this.onVerCreditos,
    required this.onVerActivos,
    required this.onVerInactivos,
    required this.onVerAtrasados,
  });

  final double montoCreditos;
  final int activos;
  final int inactivos;
  final int atrasados;
  final VoidCallback onVerCreditos;
  final VoidCallback onVerActivos;
  final VoidCallback onVerInactivos;
  final VoidCallback onVerAtrasados;

  @override
  Widget build(BuildContext context) {
    final List<AccesoCreditoInicio> accesos = <AccesoCreditoInicio>[
      AccesoCreditoInicio(
        icono: Icons.receipt_long_rounded,
        etiqueta: 'Dinero en creditos',
        valor: formatMoney(montoCreditos),
        color: CobroAppTheme.primary,
        onTap: onVerCreditos,
      ),
      AccesoCreditoInicio(
        icono: Icons.check_circle_rounded,
        etiqueta: 'Activos',
        valor: activos.toString(),
        color: CobroAppTheme.success,
        onTap: onVerActivos,
      ),
      AccesoCreditoInicio(
        icono: Icons.pause_circle_filled_rounded,
        etiqueta: 'Inactivos',
        valor: inactivos.toString(),
        color: const Color(0xFF64748B),
        onTap: onVerInactivos,
      ),
      AccesoCreditoInicio(
        icono: Icons.warning_amber_rounded,
        etiqueta: 'Atrasados',
        valor: atrasados.toString(),
        color: CobroAppTheme.danger,
        onTap: onVerAtrasados,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const TituloSeccionPresupuesto(
          icono: Icons.fact_check_rounded,
          titulo: 'Creditos',
          subtitulo: 'Estado actual y accesos directos',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columnas = constraints.maxWidth < 620 ? 2 : 4;
            const double separacion = 12;
            final double ancho =
                (constraints.maxWidth - (separacion * (columnas - 1))) /
                    columnas;

            return Wrap(
              spacing: separacion,
              runSpacing: separacion,
              children: accesos
                  .map<Widget>(
                    (AccesoCreditoInicio acceso) => SizedBox(
                      width: ancho,
                      child: TarjetaAccesoCreditoInicio(acceso: acceso),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class AccesoCreditoInicio {
  const AccesoCreditoInicio({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.color,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color color;
  final VoidCallback onTap;
}

class TarjetaAccesoCreditoInicio extends StatelessWidget {
  const TarjetaAccesoCreditoInicio({required this.acceso});

  final AccesoCreditoInicio acceso;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ver ${acceso.etiqueta}',
      child: ClaySurface(
        constraints: const BoxConstraints(minHeight: 126),
        radius: 18,
        padding: EdgeInsets.zero,
        borderColor: acceso.color.withValues(alpha: 0.24),
        color: acceso.color.withValues(alpha: 0.06),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: acceso.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      ClayIcon(
                        icon: acceso.icono,
                        color: acceso.color,
                        backgroundColor: acceso.color.withValues(alpha: 0.12),
                        size: 42,
                        iconSize: 21,
                        radius: 13,
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: acceso.color,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      acceso.valor,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    acceso.etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.clay.subtleText,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EntradaAnimada extends StatelessWidget {
  const EntradaAnimada({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool desactivarAnimaciones = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: desactivarAnimaciones
          ? Duration.zero
          : const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class EncabezadoInicioPresupuesto extends StatelessWidget {
  const EncabezadoInicioPresupuesto({
    required this.fechaInicio,
    required this.fechaFin,
  });

  final DateTime fechaInicio;
  final DateTime fechaFin;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final TextStyle? breadcrumbStyle =
        Theme.of(context).textTheme.labelMedium?.copyWith(
              color: CobroAppTheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Gestión de Presupuesto',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: clay.text,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: <Widget>[
            Text('Inicio', style: breadcrumbStyle),
            Text('•', style: TextStyle(color: clay.subtleText)),
            Text('Informe', style: breadcrumbStyle),
            Text('•', style: TextStyle(color: clay.subtleText)),
            Text('Presupuesto', style: breadcrumbStyle),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Desde el último movimiento de caja menor',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: clay.subtleText,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: <Widget>[
            Text(
              formatDateLabel(fechaInicio).toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: CobroAppTheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: clay.subtleText,
            ),
            Text(
              formatDateLabel(fechaFin).toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: CobroAppTheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class TarjetaTotalPresupuesto extends StatelessWidget {
  const TarjetaTotalPresupuesto({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final bool desactivarAnimaciones = MediaQuery.of(context).disableAnimations;
    return ClaySurface(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 194),
      radius: 24,
      padding: const EdgeInsets.all(24),
      borderColor: Colors.white.withValues(alpha: 0.3),
      clipBehavior: Clip.hardEdge,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF45A3FF),
          Color(0xFF1683F3),
          Color(0xFF0565D8),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -8,
            bottom: -36,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 172,
              color: Colors.white.withValues(alpha: 0.075),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'TOTAL PRESUPUESTO',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.84),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: total),
                    duration: desactivarAnimaciones
                        ? Duration.zero
                        : const Duration(milliseconds: 850),
                    curve: Curves.easeOutCubic,
                    builder: (
                      BuildContext context,
                      double value,
                      Widget? child,
                    ) {
                      return Text(
                        formatMoney(value),
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Caja menor + Recaudado - Créditos - Gastos',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TituloSeccionPresupuesto extends StatelessWidget {
  const TituloSeccionPresupuesto({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icono, color: CobroAppTheme.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                titulo,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitulo,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.clay.subtleText,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ComposicionPresupuesto extends StatelessWidget {
  const ComposicionPresupuesto({
    super.key,
    required this.totales,
    this.graficas,
  });

  final PresupuestoTotales totales;
  final Widget? graficas;

  @override
  Widget build(BuildContext context) {
    final List<DatoPresupuesto> datos = <DatoPresupuesto>[
      DatoPresupuesto(
        icono: Icons.savings_rounded,
        etiqueta: 'Caja menor',
        valor: formatMoney(totales.cajaMenor),
        color: CobroAppTheme.success,
      ),
      DatoPresupuesto(
        icono: Icons.payments_rounded,
        etiqueta: 'Recaudado',
        valor: formatMoney(totales.recaudado),
        color: CobroAppTheme.violet,
      ),
      DatoPresupuesto(
        icono: Icons.receipt_long_rounded,
        etiqueta: 'Gastos',
        valor: formatMoney(totales.gastos),
        color: CobroAppTheme.warning,
      ),
      DatoPresupuesto(
        icono: Icons.trending_down_rounded,
        etiqueta: 'Dinero en creditos',
        valor: formatMoney(totales.creditos),
        color: CobroAppTheme.danger,
      ),
      DatoPresupuesto(
        icono: Icons.currency_exchange_rounded,
        etiqueta: 'Refinanciados',
        valor: formatMoney(totales.valorRefinanciado),
        detalle: formatCreditsCount(totales.creditosRefinanciados),
        color: const Color(0xFF0E7490),
      ),
    ];

    return ClaySurface(
      width: double.infinity,
      radius: 18,
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 650) {
            return Column(
              children: <Widget>[
                for (int index = 0; index < datos.length; index++) ...<Widget>[
                  LineaDatoPresupuesto(dato: datos[index]),
                  if (index < datos.length - 1) const Divider(height: 22),
                ],
              ],
            );
          }

          return Column(
            children: <Widget>[
              IntrinsicHeight(
                child: Row(
                  children: <Widget>[
                    Expanded(child: LineaDatoPresupuesto(dato: datos[0])),
                    const VerticalDivider(width: 32),
                    Expanded(child: LineaDatoPresupuesto(dato: datos[1])),
                  ],
                ),
              ),
              const Divider(height: 28),
              IntrinsicHeight(
                child: Row(
                  children: <Widget>[
                    Expanded(child: LineaDatoPresupuesto(dato: datos[2])),
                    const VerticalDivider(width: 32),
                    Expanded(child: LineaDatoPresupuesto(dato: datos[3])),
                  ],
                ),
              ),
              const Divider(height: 28),
              LineaDatoPresupuesto(dato: datos[4]),
            ],
          );
        },
      ),
    );
  }
}

class LineaDatoPresupuesto extends StatelessWidget {
  const LineaDatoPresupuesto({required this.dato});

  final DatoPresupuesto dato;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        ClayIcon(
          icon: dato.icono,
          color: dato.color,
          backgroundColor: dato.color.withValues(alpha: 0.12),
          size: 46,
          iconSize: 22,
          radius: 14,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                dato.etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.clay.subtleText,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  dato.valor,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                ),
              ),
              if (dato.detalle != null) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  dato.detalle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.clay.subtleText,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
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

class ActividadPresupuesto extends StatelessWidget {
  const ActividadPresupuesto({
    required this.clientesActivos,
    required this.cartera,
  });

  final int clientesActivos;
  final double cartera;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tarjetas = <Widget>[
      TarjetaActividadPresupuesto(
        icono: Icons.groups_rounded,
        etiqueta: 'Clientes con credito',
        valor: '$clientesActivos',
        color: const Color(0xFF0E7490),
      ),
      TarjetaActividadPresupuesto(
        icono: Icons.request_quote_rounded,
        etiqueta: 'Cartera activa',
        valor: formatMoney(cartera),
        color: CobroAppTheme.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: <Widget>[
              tarjetas[0],
              const SizedBox(height: 12),
              tarjetas[1],
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: tarjetas[0]),
            const SizedBox(width: 12),
            Expanded(child: tarjetas[1]),
          ],
        );
      },
    );
  }
}

class TarjetaActividadPresupuesto extends StatelessWidget {
  const TarjetaActividadPresupuesto({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      constraints: const BoxConstraints(minHeight: 108),
      radius: 18,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: <Widget>[
          ClayIcon(
            icon: icono,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
            size: 48,
            iconSize: 23,
            radius: 15,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.clay.subtleText,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                ),
                const SizedBox(height: 5),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    valor,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
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

class DatoPresupuesto {
  const DatoPresupuesto({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.color,
    this.detalle,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color color;
  final String? detalle;
}

class TarjetaPresupuestoItem extends StatelessWidget {
  const TarjetaPresupuestoItem({required this.item});

  final PresupuestoItem item;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.cajaMenorNombre,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            item.monedaCodigo,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.clay.subtleText,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          LineaMonto(label: 'Caja menor', value: item.cajaMenor),
          LineaMonto(label: 'Recaudado', value: item.recaudado),
          LineaMonto(label: 'Gastos', value: item.gastos),
          LineaMonto(label: 'Creditos', value: item.creditos),
          LineaMonto(
            label:
                'Refinanciado (${formatCreditsCount(item.creditosRefinanciados)})',
            value: item.valorRefinanciado,
          ),
          const Divider(height: 20),
          LineaMonto(
            label: 'Presupuesto',
            value: item.presupuesto,
            destacado: true,
          ),
        ],
      ),
    );
  }
}
