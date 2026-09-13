export 'aviso_flotante.dart';
export 'clay.dart';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../formatters/app_formatters.dart';
import 'aviso_flotante.dart';
import 'clay.dart';

class Pagina extends StatelessWidget {
  const Pagina({
    super.key,
    required this.titulo,
    this.subtitulo,
    required this.children,
    required this.onRefresh,
    this.error,
    this.acciones = const <Widget>[],
    this.onNearEnd,
  });

  final String titulo;
  final String? subtitulo;
  final List<Widget> children;
  final Future<void> Function() onRefresh;
  final String? error;
  final List<Widget> acciones;
  final VoidCallback? onNearEnd;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double horizontal = constraints.maxWidth < 520 ? 16 : 28;
          return NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              final ScrollMetrics metrics = notification.metrics;
              if (metrics.axis == Axis.vertical &&
                  metrics.maxScrollExtent - metrics.pixels < 720) {
                onNearEnd?.call();
              }
              return false;
            },
            child: CustomScrollView(
              slivers: <Widget>[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 32),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Encabezado(
                              titulo: titulo,
                              subtitulo: subtitulo,
                              acciones: acciones,
                            ),
                            if (error != null) ...<Widget>[
                              const SizedBox(height: 14),
                              ErrorBanner(message: error!),
                            ],
                            const SizedBox(height: 20),
                            ...children,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class Encabezado extends StatelessWidget {
  const Encabezado({
    super.key,
    required this.titulo,
    this.subtitulo,
    required this.acciones,
  });

  final String titulo;
  final String? subtitulo;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final Widget texto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          titulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: clay.text,
              ),
        ),
        if (subtitulo != null && subtitulo!.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            subtitulo!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: clay.subtleText,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ],
    );

    if (acciones.isEmpty) {
      return texto;
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compacto = constraints.maxWidth < 560;
        final Widget accionesWrap = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: acciones,
        );

        if (compacto) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              texto,
              const SizedBox(height: 12),
              accionesWrap,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: texto),
            const SizedBox(width: 12),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: accionesWrap,
              ),
            ),
          ],
        );
      },
    );
  }
}

class LineaMonto extends StatelessWidget {
  const LineaMonto({
    super.key,
    required this.label,
    required this.value,
    this.destacado = false,
  });

  final String label;
  final double value;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = destacado
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            )
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          Text(formatMoney(value), style: style),
        ],
      ),
    );
  }
}

class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      width: double.infinity,
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
      child: Column(
        children: <Widget>[
          Icon(icono, size: 38, color: CobroAppTheme.primary),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.clay.subtleText,
                ),
          ),
          if (accion != null) ...<Widget>[
            const SizedBox(height: 16),
            accion!,
          ],
        ],
      ),
    );
  }
}
