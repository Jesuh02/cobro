import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'clay.dart';

/// Elemento para el selector desplegable moderno [CobroDropdownField].
class CobroDropdownItem<T> {
  const CobroDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.avatarText,
    this.leading,
    this.trailing,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final String? avatarText;
  final Widget? leading;
  final Widget? trailing;
}

/// Selector desplegable reutilizable estilizado con Material 3 (MenuAnchor).
///
/// Se despliega siempre hacia abajo del campo con esquinas redondeadas,
/// soporte para iconos, avatares, subtítulos y un indicador de selección activo.
class CobroDropdownField<T> extends StatefulWidget {
  const CobroDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelText,
    this.hintText = 'Seleccionar opcion',
    this.prefixIcon,
    this.enabled = true,
    this.menuWidth = 340,
    this.menuMaxHeight = 320,
  });

  final T? value;
  final List<CobroDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final String hintText;
  final Widget? prefixIcon;
  final bool enabled;
  final double menuWidth;
  final double menuMaxHeight;

  @override
  State<CobroDropdownField<T>> createState() => _CobroDropdownFieldState<T>();
}

class _CobroDropdownFieldState<T> extends State<CobroDropdownField<T>> {
  final OverlayPortalController _portalController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  final Object _regionGroupId = Object();

  @override
  void dispose() {
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    super.dispose();
  }

  void _cerrar() {
    if (!mounted) {
      return;
    }
    if (_portalController.isShowing) {
      _portalController.hide();
      setState(() {});
    }
  }

  void _alternar(bool habilitado) {
    if (!mounted || !habilitado) {
      return;
    }
    if (_portalController.isShowing) {
      _portalController.hide();
    } else {
      _portalController.show();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    CobroDropdownItem<T>? seleccionado;
    for (final CobroDropdownItem<T> item in widget.items) {
      if (item.value == widget.value) {
        seleccionado = item;
        break;
      }
    }

    final bool habilitado =
        widget.enabled && widget.onChanged != null && widget.items.isNotEmpty;
    final bool abierto = _portalController.isShowing;

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: (BuildContext overlayContext) {
          final RenderBox? renderBox =
              _fieldKey.currentContext?.findRenderObject() as RenderBox?;
          final double anchoCampo = renderBox != null && renderBox.hasSize
              ? renderBox.size.width
              : widget.menuWidth;

          double alturaMaxima = widget.menuMaxHeight;
          if (renderBox != null && renderBox.hasSize && renderBox.attached) {
            final Offset posicionGlobal =
                renderBox.localToGlobal(Offset.zero);
            final double espacioAbajo =
                MediaQuery.of(overlayContext).size.height -
                    (posicionGlobal.dy + renderBox.size.height) -
                    16;
            if (espacioAbajo > 0) {
              alturaMaxima =
                  math.min(widget.menuMaxHeight, math.max(120.0, espacioAbajo));
            }
          }

          return CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 4),
            child: TapRegion(
              groupId: _regionGroupId,
              onTapOutside: (_) => _cerrar(),
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.25),
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ClayRadius.control),
                    side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: anchoCampo,
                      maxWidth: math.max(anchoCampo, widget.menuWidth + 24),
                      maxHeight: alturaMaxima,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: widget.items.map((CobroDropdownItem<T> item) {
                          final bool esSeleccionado = item.value == widget.value;

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              _cerrar();
                              widget.onChanged?.call(item.value);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: esSeleccionado
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: esSeleccionado
                                    ? Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.35),
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: <Widget>[
                                  if (item.leading != null) ...<Widget>[
                                    item.leading!,
                                    const SizedBox(width: 12),
                                  ] else if (item.avatarText != null &&
                                      item.avatarText!.isNotEmpty) ...<Widget>[
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: esSeleccionado
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                      foregroundColor: esSeleccionado
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer,
                                      child: Text(
                                        item.avatarText!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ] else if (item.icon != null) ...<Widget>[
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: (item.iconColor ??
                                              Theme.of(context)
                                                  .colorScheme
                                                  .primary)
                                          .withValues(
                                            alpha: esSeleccionado ? 0.2 : 0.12,
                                          ),
                                      foregroundColor: item.iconColor ??
                                          Theme.of(context).colorScheme.primary,
                                      child: Icon(item.icon, size: 16),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Text(
                                          item.label,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: esSeleccionado
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            color: esSeleccionado
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : null,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (item.subtitle != null &&
                                            item.subtitle!.isNotEmpty)
                                          Text(
                                            item.subtitle!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  fontSize: 11,
                                                  color: context.clay.subtleText,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (item.trailing != null)
                                    item.trailing!
                                  else if (esSeleccionado)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(growable: false),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        child: TapRegion(
          groupId: _regionGroupId,
          child: InkWell(
            key: _fieldKey,
            borderRadius: BorderRadius.circular(ClayRadius.small),
            onTap: () => _alternar(habilitado),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: widget.labelText,
                prefixIcon: widget.prefixIcon,
                suffixIcon: Icon(
                  abierto
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
                enabled: habilitado,
              ),
              child: Row(
                children: <Widget>[
                  if (seleccionado?.leading != null) ...<Widget>[
                    seleccionado!.leading!,
                    const SizedBox(width: 8),
                  ] else if (seleccionado?.avatarText != null &&
                      seleccionado!.avatarText!.isNotEmpty) ...<Widget>[
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      foregroundColor: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                      child: Text(
                        seleccionado.avatarText!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else if (seleccionado?.icon != null) ...<Widget>[
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: (seleccionado!.iconColor ??
                              Theme.of(context).colorScheme.primary)
                          .withValues(alpha: 0.12),
                      foregroundColor: seleccionado.iconColor ??
                          Theme.of(context).colorScheme.primary,
                      child: Icon(seleccionado.icon, size: 13),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      seleccionado?.label ?? widget.hintText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: seleccionado == null
                            ? context.clay.subtleText
                            : null,
                      ),
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
