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
  final MenuController _controller = MenuController();

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

    return MenuAnchor(
      controller: _controller,
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ClayRadius.control),
            side: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.5),
            ),
          ),
        ),
        elevation: const WidgetStatePropertyAll<double>(8),
        backgroundColor: WidgetStatePropertyAll<Color>(
          Theme.of(context).colorScheme.surface,
        ),
        maximumSize: WidgetStatePropertyAll<Size>(
          Size(widget.menuWidth + 24, widget.menuMaxHeight),
        ),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        ),
      ),
      builder: (
        BuildContext context,
        MenuController controller,
        Widget? child,
      ) {
        return InkWell(
          borderRadius: BorderRadius.circular(ClayRadius.small),
          onTap: habilitado
              ? () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                  setState(() {});
                }
              : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: widget.labelText,
              prefixIcon: widget.prefixIcon,
              suffixIcon: Icon(
                controller.isOpen
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
        );
      },
      menuChildren: widget.items.map((CobroDropdownItem<T> item) {
        final bool esSeleccionado = item.value == widget.value;

        return MenuItemButton(
          onPressed: () {
            widget.onChanged?.call(item.value);
          },
          style: const ButtonStyle(
            padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
              EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
          ),
          child: Container(
            width: widget.menuWidth,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: esSeleccionado
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
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
                        : Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor: esSeleccionado
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onPrimaryContainer,
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
                            Theme.of(context).colorScheme.primary)
                        .withValues(alpha: esSeleccionado ? 0.2 : 0.12),
                    foregroundColor: item.iconColor ??
                        Theme.of(context).colorScheme.primary,
                    child: Icon(item.icon, size: 16),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.subtitle != null && item.subtitle!.isNotEmpty)
                        Text(
                          item.subtitle!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
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
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}
