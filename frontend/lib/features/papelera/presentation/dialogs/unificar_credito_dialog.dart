import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/clay.dart';
import '../../../../data/models/models.dart';

Future<bool?> mostrarDialogoUnificarCreditoPapelera({
  required BuildContext context,
  required PapeleraItem item,
  required CreditoRegistro creditoActivo,
  required Future<void> Function(String frecuenciaCodigo) onConfirmarUnificar,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return _DialogoUnificarCreditoContent(
        item: item,
        creditoActivo: creditoActivo,
        onConfirmarUnificar: onConfirmarUnificar,
      );
    },
  );
}

class _DialogoUnificarCreditoContent extends StatefulWidget {
  const _DialogoUnificarCreditoContent({
    required this.item,
    required this.creditoActivo,
    required this.onConfirmarUnificar,
  });

  final PapeleraItem item;
  final CreditoRegistro creditoActivo;
  final Future<void> Function(String frecuenciaCodigo) onConfirmarUnificar;

  @override
  State<_DialogoUnificarCreditoContent> createState() =>
      _DialogoUnificarCreditoContentState();
}

class _DialogoUnificarCreditoContentState
    extends State<_DialogoUnificarCreditoContent> {
  late String _frecuenciaSeleccionada;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    // Preseleccionar por defecto la frecuencia del crédito activo vigente
    _frecuenciaSeleccionada =
        widget.creditoActivo.frecuenciaPago.nombre.trim().toUpperCase();
    if (_frecuenciaSeleccionada.isEmpty) {
      _frecuenciaSeleccionada = 'DIARIO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double saldoPapelera = widget.item.credito?.saldoPendiente ??
        widget.item.credito?.total ??
        0.0;
    final double principalActivo = widget.creditoActivo.valorPrincipal;
    final double totalUnificado = principalActivo + saldoPapelera;

    final String frecPapelera =
        widget.item.credito?.frecuencia.toUpperCase() ?? 'DIARIO';
    final String frecActiva =
        widget.creditoActivo.frecuenciaPago.nombre.toUpperCase();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      title: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CobroAppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sync_alt_rounded,
              color: CobroAppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Unificar y Refinanciar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  widget.item.cliente.nombreCompleto,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Banner informativo
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'El cliente ya posee un crédito activo. Para restaurar esta deuda se unificará automáticamente con el crédito actual.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tarjeta claymórfica con el desglose de deudas
              ClaySurface(
                radius: 14,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    _FilaDesglose(
                      etiqueta: 'Crédito Activo Actual',
                      valor: formatMoney(principalActivo),
                      badge: frecActiva,
                      colorBadge: CobroAppTheme.primary,
                    ),
                    const SizedBox(height: 10),
                    _FilaDesglose(
                      etiqueta: 'Deuda en Papelera',
                      valor: '+ ${formatMoney(saldoPapelera)}',
                      badge: frecPapelera,
                      colorBadge: Colors.orange.shade800,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Nuevo Total Consolidado',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          formatMoney(totalUnificado),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: CobroAppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Selector de frecuencia (Diario vs Semanal)
              Text(
                'Frecuencia de cobro resultante:',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(
                      value: 'DIARIO',
                      icon: Icon(Icons.calendar_view_day_rounded, size: 16),
                      label: Text('Diario'),
                    ),
                    ButtonSegment<String>(
                      value: 'SEMANAL',
                      icon: Icon(Icons.calendar_view_week_rounded, size: 16),
                      label: Text('Semanal'),
                    ),
                  ],
                  selected: <String>{_frecuenciaSeleccionada},
                  onSelectionChanged: (Set<String> seleccion) {
                    setState(() {
                      _frecuenciaSeleccionada = seleccion.first;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Nota de reinicio de plazo (Opción B)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'El plazo se reinicia a partir de hoy con la frecuencia elegida (Opción B). No se descuenta efectivo de la caja menor.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _procesando
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _procesando
              ? null
              : () async {
                  setState(() => _procesando = true);
                  try {
                    await widget.onConfirmarUnificar(_frecuenciaSeleccionada);
                    if (context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  } catch (_) {
                    if (mounted) {
                      setState(() => _procesando = false);
                    }
                  }
                },
          icon: _procesando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.sync_alt_rounded, size: 18),
          label: Text(_procesando ? 'Unificando...' : 'Unificar y Restaurar'),
        ),
      ],
    );
  }
}

class _FilaDesglose extends StatelessWidget {
  const _FilaDesglose({
    required this.etiqueta,
    required this.valor,
    required this.badge,
    required this.colorBadge,
  });

  final String etiqueta;
  final String valor;
  final String badge;
  final Color colorBadge;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                etiqueta,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colorBadge.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorBadge,
            ),
          ),
        ),
      ],
    );
  }
}
