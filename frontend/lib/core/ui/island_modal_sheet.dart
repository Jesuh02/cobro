import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import 'clay.dart';

/// Despliega un modal flotante desacoplado de los bordes físicos de la pantalla
/// (Island Bottom Sheet) con fondo transparente y sombreado suave.
Future<T?> mostrarIslandModalBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext sheetContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: builder,
  );
}

/// Chasis base reutilizable para modales flotantes (Island Sheets).
///
/// Proporciona márgenes flotantes adaptativos, límites máximos de ancho (480px)
/// y alto, manija de arrastre (drag handle), cuerpo scrolleable y footer anclado.
class IslandModalSheet extends StatelessWidget {
  const IslandModalSheet({
    super.key,
    required this.children,
    this.footer,
    this.maxWidth = 480,
    this.maxHeightFactor = 0.85,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<Widget> children;
  final Widget? footer;
  final double maxWidth;
  final double maxHeightFactor;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final Size screenSize = MediaQuery.sizeOf(context);
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final double systemBottom = MediaQuery.paddingOf(context).bottom;

    final double horizontalMargin = screenSize.width < 420 ? 10.0 : 18.0;
    final double bottomMargin = bottomInset > 0
        ? bottomInset + 8.0
        : (systemBottom > 0 ? systemBottom + 6.0 : 12.0);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalMargin,
          0,
          horizontalMargin,
          bottomMargin,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenSize.height * maxHeightFactor,
              maxWidth: maxWidth,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: clay.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: clay.border.withValues(alpha: 0.65),
                ),
                boxShadow: clay.floatingShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const DragHandleSheet(),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: contentPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ),
                  if (footer != null) footer!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Manija de arrastre visual superior para modales bottom sheet.
class DragHandleSheet extends StatelessWidget {
  const DragHandleSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 32,
          height: 3.5,
          decoration: BoxDecoration(
            color: clay.subtleText.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta seccional para agrupar información temática dentro de un modal.
class TarjetaSeccionSheet extends StatelessWidget {
  const TarjetaSeccionSheet({
    super.key,
    required this.titulo,
    required this.icono,
    required this.children,
    this.colorIcono,
  });

  final String titulo;
  final IconData icono;
  final List<Widget> children;
  final Color? colorIcono;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: clay.surfaceLow,
        borderRadius: BorderRadius.circular(ClayRadius.small),
        border: Border.all(color: clay.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icono,
                size: 15,
                color: colorIcono ?? CobroAppTheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                titulo,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: clay.text,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

/// Fila estructurada para desplegar una etiqueta y valor con botón opcional de copiado rápido.
class FilaDatoSheet extends StatelessWidget {
  const FilaDatoSheet({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.valorCopiable,
    this.icono,
    this.multiline = false,
    this.colorValor,
    this.onCopiar,
  });

  final String etiqueta;
  final String valor;
  final String? valorCopiable;
  final IconData? icono;
  final bool multiline;
  final Color? colorValor;
  final void Function(String etiqueta, String valor)? onCopiar;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;

    return Row(
      crossAxisAlignment:
          multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: <Widget>[
        if (icono != null) ...<Widget>[
          Icon(icono, size: 15, color: clay.subtleText),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                etiqueta,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: clay.subtleText,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
              ),
              const SizedBox(height: 1),
              SelectableText(
                valor,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorValor ?? clay.text,
                    ),
              ),
            ],
          ),
        ),
        if (valorCopiable != null && onCopiar != null)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 15),
            tooltip: 'Copiar $etiqueta',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              padding: EdgeInsets.zero,
            ),
            onPressed: () => onCopiar!(etiqueta, valorCopiable!),
          ),
      ],
    );
  }
}

/// Utilidad para copiar texto al portapapeles con feedback háptico y notificación.
void copiarDatoAlPortapapeles({
  required BuildContext context,
  required String etiqueta,
  required String valor,
  void Function(String)? mostrarMensaje,
}) {
  Clipboard.setData(ClipboardData(text: valor));
  HapticFeedback.selectionClick();
  final String mensaje = '$etiqueta copiado al portapapeles';
  if (mostrarMensaje != null) {
    mostrarMensaje(mensaje);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
