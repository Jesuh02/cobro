part of 'home_page.dart';

class _GraficasInicio extends StatelessWidget {
  const _GraficasInicio({required this.totales});

  final PresupuestoTotales totales;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final List<Widget> graficas = <Widget>[
          _GraficaLineaPresupuesto(totales: totales),
          _GraficaAreaMovimientos(totales: totales),
          _GraficaDonaDistribucion(totales: totales),
        ];

        if (constraints.maxWidth >= 980) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < graficas.length; i++) ...<Widget>[
                Expanded(child: graficas[i]),
                if (i != graficas.length - 1) const SizedBox(width: 12),
              ],
            ],
          );
        }

        if (constraints.maxWidth >= 650) {
          return Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: graficas[0]),
                  const SizedBox(width: 12),
                  Expanded(child: graficas[1]),
                ],
              ),
              const SizedBox(height: 12),
              graficas[2],
            ],
          );
        }

        return Column(
          children: <Widget>[
            for (int i = 0; i < graficas.length; i++) ...<Widget>[
              graficas[i],
              if (i != graficas.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _GraficaLineaPresupuesto extends StatelessWidget {
  const _GraficaLineaPresupuesto({required this.totales});

  final PresupuestoTotales totales;

  @override
  Widget build(BuildContext context) {
    final List<double> actual = <double>[
      totales.cajaMenor,
      totales.cajaMenor + totales.recaudado,
      totales.cajaMenor + totales.recaudado - totales.gastos,
      totales.presupuesto,
    ];
    final List<double> referencia = <double>[
      totales.cajaMenor,
      totales.cajaMenor + totales.recaudado,
      totales.cajaMenor + totales.recaudado,
      totales.cajaMenor + totales.recaudado,
    ];
    final List<double> valores = <double>[...actual, ...referencia];
    final double maximo = math.max(1, valores.reduce(math.max).abs() * 1.18);
    final double minimoValor = valores.reduce(math.min);
    final double minimo = minimoValor < 0 ? minimoValor * 1.18 : 0;
    final ClayTokens clay = context.clay;
    final Color primary = Theme.of(context).colorScheme.primary;
    final bool desactivarAnimaciones = MediaQuery.of(context).disableAnimations;

    return _TarjetaGrafica(
      titulo: 'Flujo acumulado',
      etiqueta: 'LINEA',
      valor: _dinero(totales.presupuesto),
      detalle: 'Capital disponible',
      pie: Row(
        children: <Widget>[
          _Leyenda(color: primary, texto: 'Real'),
          const SizedBox(width: 14),
          _Leyenda(color: clay.inactiveBar, texto: 'Sin egresos'),
        ],
      ),
      child: _AnimacionInicialGrafica(
        duration: const Duration(milliseconds: 1050),
        builder: (BuildContext context, double progreso) {
          final double opacidad = _progresoSuavizado(progreso);
          return LineChart(
            LineChartData(
              minX: 0,
              maxX: 3,
              minY: minimo,
              maxY: maximo,
              clipData: const FlClipData.all(),
              borderData: FlBorderData(show: false),
              gridData: _gridData(clay),
              titlesData: _titulosEjes(
                clay: clay,
                etiquetas: const <String>[
                  'Caja',
                  'Cobros',
                  'Gastos',
                  'Creditos',
                ],
                maxY: maximo,
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: _tooltipLinea(clay),
              ),
              lineBarsData: <LineChartBarData>[
                LineChartBarData(
                  spots: _puntosAnimados(referencia, progreso),
                  isCurved: true,
                  curveSmoothness: 0.25,
                  color: clay.inactiveBar.withValues(alpha: opacidad),
                  barWidth: 2,
                  dashArray: const <int>[6, 5],
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: _puntosAnimados(actual, progreso),
                  isCurved: true,
                  curveSmoothness: 0.25,
                  color: primary.withValues(alpha: opacidad),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    getDotPainter: (spot, percent, bar, index) {
                      final double progresoPunto = _progresoEscalonado(
                        progreso,
                        index,
                        actual.length,
                      );
                      return FlDotCirclePainter(
                        radius: (index == actual.length - 1 ? 4 : 2.6) *
                            progresoPunto,
                        color: clay.chartBackground,
                        strokeColor: primary.withValues(alpha: progresoPunto),
                        strokeWidth: 2.4 * progresoPunto,
                      );
                    },
                  ),
                ),
              ],
            ),
            duration: desactivarAnimaciones || progreso < 1
                ? Duration.zero
                : const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
          );
        },
      ),
    );
  }
}

class _GraficaAreaMovimientos extends StatelessWidget {
  const _GraficaAreaMovimientos({required this.totales});

  final PresupuestoTotales totales;

  @override
  Widget build(BuildContext context) {
    final List<double> valores = <double>[
      totales.cajaMenor,
      totales.recaudado,
      totales.gastos,
      totales.creditos,
      math.max(0, totales.presupuesto),
    ];
    final double maximo = math.max(1, valores.reduce(math.max) * 1.2);
    final ClayTokens clay = context.clay;
    final Color primary = Theme.of(context).colorScheme.primary;
    final bool desactivarAnimaciones = MediaQuery.of(context).disableAnimations;

    return _TarjetaGrafica(
      titulo: 'Composicion financiera',
      etiqueta: 'AREA',
      valor: _dinero(totales.recaudado),
      detalle: 'Total recaudado',
      pie: Text(
        'Entradas, salidas y saldo',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: clay.subtleText,
              fontWeight: FontWeight.w700,
            ),
      ),
      child: _AnimacionInicialGrafica(
        duration: const Duration(milliseconds: 1100),
        builder: (BuildContext context, double progreso) {
          final double opacidad = _progresoSuavizado(progreso);
          return LineChart(
            LineChartData(
              minX: 0,
              maxX: 4,
              minY: 0,
              maxY: maximo,
              clipData: const FlClipData.all(),
              borderData: FlBorderData(show: false),
              gridData: _gridData(clay),
              titlesData: _titulosEjes(
                clay: clay,
                etiquetas: const <String>[
                  'Caja',
                  'Cobros',
                  'Gastos',
                  'Creditos',
                  'Saldo',
                ],
                maxY: maximo,
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: _tooltipLinea(clay),
              ),
              lineBarsData: <LineChartBarData>[
                LineChartBarData(
                  spots: _puntosAnimados(
                    valores,
                    progreso,
                    desfase: 0.09,
                  ),
                  isCurved: true,
                  curveSmoothness: 0.28,
                  color: primary.withValues(alpha: opacidad),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        primary.withValues(alpha: 0.34 * opacidad),
                        primary.withValues(alpha: 0.03 * opacidad),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            duration: desactivarAnimaciones || progreso < 1
                ? Duration.zero
                : const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
          );
        },
      ),
    );
  }
}

class _GraficaDonaDistribucion extends StatelessWidget {
  const _GraficaDonaDistribucion({required this.totales});

  final PresupuestoTotales totales;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final Color primary = Theme.of(context).colorScheme.primary;
    final double disponible = math.max(0, totales.presupuesto);
    final double gastos = math.max(0, totales.gastos);
    final double creditos = math.max(0, totales.creditos);
    final double total = disponible + gastos + creditos;
    final bool sinDatos = total <= 0;
    final double porcentaje = sinDatos ? 0 : disponible / total * 100;
    final List<_SegmentoDona> segmentos = sinDatos
        ? <_SegmentoDona>[
            _SegmentoDona(
              valor: 1,
              color: clay.inactiveBar,
              titulo: 'Sin datos',
            ),
          ]
        : <_SegmentoDona>[
            _SegmentoDona(
              valor: disponible,
              color: primary,
              titulo: 'Disponible',
            ),
            _SegmentoDona(
              valor: gastos,
              color: CobroAppTheme.warning,
              titulo: 'Gastos',
            ),
            _SegmentoDona(
              valor: creditos,
              color: clay.inactiveBar,
              titulo: 'Creditos',
            ),
          ]
            .where((_SegmentoDona item) => item.valor > 0)
            .toList(growable: false);
    final double totalSegmentos = segmentos.fold<double>(
      0,
      (double suma, _SegmentoDona item) => suma + item.valor,
    );
    final bool desactivarAnimaciones = MediaQuery.of(context).disableAnimations;

    return _TarjetaGrafica(
      titulo: 'Distribucion operativa',
      etiqueta: 'DONA',
      valor: '${porcentaje.toStringAsFixed(0)}%',
      detalle: 'Capital disponible',
      pie: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: segmentos
            .map(
              (_SegmentoDona item) =>
                  _Leyenda(color: item.color, texto: item.titulo),
            )
            .toList(growable: false),
      ),
      chartPadding: const EdgeInsets.symmetric(horizontal: 38, vertical: 10),
      chartOverlay: _AnimacionInicialGrafica(
        duration: const Duration(milliseconds: 950),
        builder: (BuildContext context, double progreso) {
          final double progresoSuave = _progresoSuavizado(progreso);
          return IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${(porcentaje * progresoSuave).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  Opacity(
                    opacity: progresoSuave,
                    child: Text(
                      'disponible',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: clay.subtleText,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      child: _AnimacionInicialGrafica(
        duration: const Duration(milliseconds: 950),
        builder: (BuildContext context, double progreso) {
          final double progresoSuave = _progresoSuavizado(progreso);
          return PieChart(
            PieChartData(
              startDegreeOffset: -108 + (18 * progresoSuave),
              centerSpaceRadius: 54,
              sectionsSpace: 5 * progresoSuave,
              borderData: FlBorderData(show: false),
              sections: <PieChartSectionData>[
                ...segmentos.map(
                  (_SegmentoDona item) => PieChartSectionData(
                    value: item.valor * progresoSuave,
                    color: item.color.withValues(alpha: progresoSuave),
                    radius: 14 + (6 * progresoSuave),
                    showTitle: false,
                    cornerRadius: 12 * progresoSuave,
                  ),
                ),
                PieChartSectionData(
                  value: totalSegmentos * (1 - progresoSuave),
                  color: Colors.transparent,
                  radius: 20,
                  showTitle: false,
                ),
              ],
            ),
            duration: desactivarAnimaciones || progreso < 1
                ? Duration.zero
                : const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
          );
        },
      ),
    );
  }
}

class _AnimacionInicialGrafica extends StatelessWidget {
  const _AnimacionInicialGrafica({
    required this.duration,
    required this.builder,
  });

  final Duration duration;
  final Widget Function(BuildContext context, double progreso) builder;

  @override
  Widget build(BuildContext context) {
    final bool desactivarAnimaciones = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: desactivarAnimaciones ? Duration.zero : duration,
      curve: Curves.linear,
      builder: (
        BuildContext context,
        double progreso,
        Widget? child,
      ) {
        return builder(context, progreso);
      },
    );
  }
}

class _TarjetaGrafica extends StatelessWidget {
  const _TarjetaGrafica({
    required this.titulo,
    required this.etiqueta,
    required this.valor,
    required this.detalle,
    required this.child,
    required this.pie,
    this.chartPadding = const EdgeInsets.fromLTRB(8, 12, 12, 2),
    this.chartOverlay,
  });

  final String titulo;
  final String etiqueta;
  final String valor;
  final String detalle;
  final Widget child;
  final Widget pie;
  final EdgeInsets chartPadding;
  final Widget? chartOverlay;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    return ClaySurface(
      width: double.infinity,
      height: 390,
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  titulo.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: clay.subtleText,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.45,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: clay.surfaceHigh,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: clay.border),
                ),
                child: Text(
                  etiqueta,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Flexible(
                child: Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: clay.subtleText,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: clay.chartBackground,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: clay.border.withValues(alpha: 0.7),
                ),
              ),
              child: Padding(
                padding: chartPadding,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    child,
                    if (chartOverlay != null) chartOverlay!,
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 30,
            child: Align(alignment: Alignment.centerLeft, child: pie),
          ),
        ],
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.clay.subtleText,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _SegmentoDona {
  const _SegmentoDona({
    required this.valor,
    required this.color,
    required this.titulo,
  });

  final double valor;
  final Color color;
  final String titulo;
}

List<FlSpot> _puntosAnimados(
  List<double> valores,
  double progreso, {
  double desfase = 0.12,
}) {
  return valores.asMap().entries.map((MapEntry<int, double> entry) {
    final double progresoPunto = _progresoEscalonado(
      progreso,
      entry.key,
      valores.length,
      desfase: desfase,
    );
    return FlSpot(entry.key.toDouble(), entry.value * progresoPunto);
  }).toList(growable: false);
}

double _progresoEscalonado(
  double progreso,
  int indice,
  int total, {
  double desfase = 0.12,
}) {
  final double desfaseTotal = desfase * math.max(0, total - 1);
  final double duracionPunto = math.max(0.01, 1 - desfaseTotal);
  final double progresoLocal =
      ((progreso - (indice * desfase)) / duracionPunto).clamp(0.0, 1.0);
  return Curves.easeOutCubic.transform(progresoLocal);
}

double _progresoSuavizado(double progreso) {
  return Curves.easeOutCubic.transform(progreso.clamp(0.0, 1.0));
}

FlGridData _gridData(ClayTokens clay) {
  return FlGridData(
    show: true,
    drawVerticalLine: false,
    getDrawingHorizontalLine: (double value) => FlLine(
      color: clay.border.withValues(alpha: 0.72),
      strokeWidth: 1,
      dashArray: const <int>[3, 4],
    ),
  );
}

FlTitlesData _titulosEjes({
  required ClayTokens clay,
  required List<String> etiquetas,
  required double maxY,
}) {
  final TextStyle estilo = TextStyle(
    color: clay.subtleText,
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 44,
        interval: maxY / 3,
        getTitlesWidget: (double value, TitleMeta meta) {
          if (value < 0) {
            return const SizedBox.shrink();
          }
          return SideTitleWidget(
            meta: meta,
            space: 7,
            child: Text(_numeroCompacto(value), style: estilo),
          );
        },
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        interval: 1,
        getTitlesWidget: (double value, TitleMeta meta) {
          final int index = value.round();
          if (index < 0 || index >= etiquetas.length) {
            return const SizedBox.shrink();
          }
          return SideTitleWidget(
            meta: meta,
            space: 8,
            child: Text(
              etiquetas[index],
              maxLines: 1,
              style: estilo.copyWith(fontSize: 9),
            ),
          );
        },
      ),
    ),
  );
}

LineTouchTooltipData _tooltipLinea(ClayTokens clay) {
  return LineTouchTooltipData(
    getTooltipColor: (_) => clay.surfaceHigh,
    tooltipBorder: BorderSide(color: clay.border),
    tooltipBorderRadius: BorderRadius.circular(12),
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    getTooltipItems: (List<LineBarSpot> spots) {
      return spots
          .map(
            (LineBarSpot spot) => LineTooltipItem(
              _dinero(spot.y),
              TextStyle(
                color: clay.text,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
          .toList(growable: false);
    },
  );
}

String _numeroCompacto(double value) {
  final double absoluto = value.abs();
  if (absoluto >= 1000000) {
    final int decimales = absoluto >= 10000000 ? 0 : 1;
    return '${(value / 1000000).toStringAsFixed(decimales)}M';
  }
  if (absoluto >= 1000) {
    final int decimales = absoluto >= 10000 ? 0 : 1;
    return '${(value / 1000).toStringAsFixed(decimales)}k';
  }
  return value.toStringAsFixed(0);
}
