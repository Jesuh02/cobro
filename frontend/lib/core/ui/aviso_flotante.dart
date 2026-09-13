import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import 'clay.dart';

enum TipoMensaje { exito, advertencia, error, info }

TipoMensaje calcularTipoMensaje(String message) {
  final String normalizado = message.toLowerCase();

  if (normalizado.contains('error') ||
      normalizado.contains('no se pudo') ||
      normalizado.contains('ya existe') ||
      normalizado.contains('ya esta registrad') ||
      normalizado.contains('ya está registrad') ||
      normalizado.contains('duplicad') ||
      normalizado.contains('no tienes acceso')) {
    return TipoMensaje.error;
  }

  if (normalizado.contains('no se puede') ||
      normalizado.contains('insuficiente') ||
      normalizado.contains('faltan') ||
      normalizado.contains('necesitas') ||
      normalizado.contains('primero') ||
      normalizado.contains('obligatorio') ||
      normalizado.contains('supera') ||
      normalizado.contains('intenta') ||
      normalizado.contains('no hay')) {
    return TipoMensaje.advertencia;
  }

  if (normalizado.contains('cread') ||
      normalizado.contains('registrad') ||
      normalizado.contains('aplicad') ||
      normalizado.contains('complet')) {
    return TipoMensaje.exito;
  }

  return TipoMensaje.info;
}

class AvisoFlotante extends StatefulWidget {
  const AvisoFlotante({
    super.key,
    required this.message,
    required this.tipo,
    required this.onDismissed,
  });

  final String message;
  final TipoMensaje tipo;
  final VoidCallback onDismissed;

  @override
  State<AvisoFlotante> createState() => _AvisoFlotanteState();
}

class _AvisoFlotanteState extends State<AvisoFlotante>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AvisoEstilo estilo = AvisoEstilo.desde(
      context,
      widget.tipo,
      widget.message,
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (BuildContext context, Widget? child) {
                return Opacity(
                  opacity: _animation.value,
                  child: Transform.translate(
                    offset: Offset(0, -14 * (1 - _animation.value)),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: estilo.backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: estilo.borderColor),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: estilo.shadowColor,
                          blurRadius: 28,
                          spreadRadius: -8,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: estilo.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              estilo.icon,
                              color: estilo.accentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  estilo.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        color: estilo.titleColor,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.message,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: estilo.messageColor,
                                        fontWeight: FontWeight.w600,
                                        height: 1.22,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Tooltip(
                            message: 'Cerrar',
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 34,
                                height: 34,
                              ),
                              onPressed: widget.onDismissed,
                              icon: Icon(
                                Icons.close_rounded,
                                color: estilo.messageColor,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AvisoEstilo {
  const AvisoEstilo({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
    required this.titleColor,
    required this.messageColor,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final Color titleColor;
  final Color messageColor;

  factory AvisoEstilo.desde(
    BuildContext context,
    TipoMensaje tipo,
    String message,
  ) {
    final ClayTokens clay = context.clay;
    final String normalizado = message.toLowerCase();
    final Color base = clay.isDark ? clay.surfaceHigh : Colors.white;
    final Color accent = switch (tipo) {
      TipoMensaje.exito => CobroAppTheme.success,
      TipoMensaje.advertencia => CobroAppTheme.warning,
      TipoMensaje.error => CobroAppTheme.danger,
      TipoMensaje.info => CobroAppTheme.primary,
    };
    final String title = switch (tipo) {
      TipoMensaje.exito => 'Listo',
      TipoMensaje.advertencia => normalizado.contains('caja')
          ? 'Revisa la caja menor'
          : 'Revisa la informacion',
      TipoMensaje.error => 'No se pudo completar',
      TipoMensaje.info => 'Aviso',
    };
    final IconData icon = switch (tipo) {
      TipoMensaje.exito => Icons.check_circle_rounded,
      TipoMensaje.advertencia => Icons.account_balance_wallet_rounded,
      TipoMensaje.error => Icons.error_rounded,
      TipoMensaje.info => Icons.info_rounded,
    };

    return AvisoEstilo(
      title: title,
      icon: icon,
      accentColor: accent,
      backgroundColor: Color.alphaBlend(
        accent.withValues(alpha: clay.isDark ? 0.08 : 0.04),
        base,
      ),
      borderColor: accent.withValues(alpha: clay.isDark ? 0.34 : 0.22),
      shadowColor: clay.shadow.withValues(alpha: clay.isDark ? 0.62 : 0.22),
      titleColor: clay.text,
      messageColor: clay.subtleText,
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      radius: 12,
      padding: const EdgeInsets.all(14),
      color: context.clay.warningSurface,
      borderColor: context.clay.warningBorder,
      child: Row(
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, color: CobroAppTheme.warning),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

