import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/clay.dart';
import '../../../../data/models/models.dart';

class PapeleraItemCard extends StatelessWidget {
  const PapeleraItemCard({
    super.key,
    required this.item,
    required this.onRestaurar,
    required this.onEliminarDefinitivo,
    required this.esAdministrador,
    this.onTap,
  });

  final PapeleraItem item;
  final VoidCallback onRestaurar;
  final VoidCallback onEliminarDefinitivo;
  final bool esAdministrador;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final bool esCredito = item.tipo == 'CREDITO';
    final Color colorTipo =
        esCredito ? Colors.orange.shade800 : Colors.redAccent.shade700;
    final Color colorFondo =
        esCredito ? Colors.orange.shade50 : Colors.red.shade50;

    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap != null
          ? () {
              HapticFeedback.lightImpact();
              onTap!();
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Fila superior: Ícono, Nombre y Badge de Tipo (sin botones invasivos que compriman el texto)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              CircleAvatar(
                radius: 20,
                backgroundColor: colorFondo.withValues(alpha: 0.15),
                child: Icon(
                  esCredito
                      ? Icons.receipt_long_rounded
                      : Icons.delete_outline_rounded,
                  color: colorTipo,
                  size: 20,
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
                        Expanded(
                          child: Text(
                            item.cliente.nombreCompleto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: clay.text,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorTipo.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(ClayRadius.small),
                            border: Border.all(
                              color: colorTipo.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            esCredito ? 'Crédito' : 'Cliente',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: colorTipo,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((item.cliente.negocio ?? '').trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.storefront_rounded,
                            size: 13,
                            color: CobroAppTheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.cliente.negocio!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: CobroAppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 3),
                    _FilaMetadatosContacto(cliente: item.cliente),
                  ],
                ),
              ),
            ],
          ),

          // Banner de crédito suspendido/eliminado si existe
          if (item.credito != null) ...<Widget>[
            const SizedBox(height: 10),
            _BannerCreditoSuspendido(
              credito: item.credito!,
              tipo: item.tipo,
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Fila inferior: Auditoría a la izquierda y acción rápida a la derecha
          Row(
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _ChipInfo(
                      icono: Icons.calendar_today_rounded,
                      texto: formatDateLabel(item.fecha),
                    ),
                    _ChipInfo(
                      icono: Icons.person_outline_rounded,
                      texto: item.eliminadoPor.nombreCompleto.split(' ').first,
                    ),
                    if (item.ruta != null)
                      _ChipInfo(
                        icono: Icons.alt_route_rounded,
                        texto: item.ruta!.nombre,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: onRestaurar,
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('Restaurar'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (esAdministrador) ...<Widget>[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onEliminarDefinitivo,
                  icon: const Icon(Icons.delete_forever_rounded, size: 18),
                  color: Theme.of(context).colorScheme.error,
                  tooltip: 'Purgar definitivamente',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FilaMetadatosContacto extends StatelessWidget {
  const _FilaMetadatosContacto({required this.cliente});

  final PapeleraCliente cliente;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final String documento = cliente.documento.trim();
    final String telefono = (cliente.telefono ?? '').trim();
    final String direccion = (cliente.direccion ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (documento.isNotEmpty || telefono.isNotEmpty)
          Row(
            children: <Widget>[
              if (documento.isNotEmpty) ...<Widget>[
                Icon(Icons.badge_outlined, size: 12, color: clay.subtleText),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    'CC $documento',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: clay.subtleText,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
              if (documento.isNotEmpty && telefono.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    '·',
                    style: TextStyle(
                      color: clay.subtleText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (telefono.isNotEmpty) ...<Widget>[
                Icon(Icons.phone_outlined, size: 12, color: clay.subtleText),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    telefono,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: clay.subtleText,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ],
          ),
        if (direccion.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Row(
            children: <Widget>[
              Icon(Icons.place_outlined, size: 12, color: clay.subtleText),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  direccion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: clay.subtleText,
                      ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BannerCreditoSuspendido extends StatelessWidget {
  const _BannerCreditoSuspendido({
    required this.credito,
    required this.tipo,
  });

  final PapeleraCredito credito;
  final String tipo;

  @override
  Widget build(BuildContext context) {
    final bool esCreditoDirecto = tipo == 'CREDITO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ClayRadius.small),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber.shade800,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  esCreditoDirecto
                      ? 'Crédito eliminado'
                      : 'Crédito activo suspendido en cadena',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.amber.shade900,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Monto: ${formatMoney(credito.total)} · Saldo: ${formatMoney(credito.saldoPendiente)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
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

class _ChipInfo extends StatelessWidget {
  const _ChipInfo({
    required this.icono,
    required this.texto,
  });

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icono, size: 12, color: clay.subtleText),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: clay.subtleText,
                  fontSize: 11,
                ),
          ),
        ),
      ],
    );
  }
}
