import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'clay.dart';

/// Elemento para el selector desplegable moderno [CobroDropdownField].
class CobroDropdownItem<T> {
  const CobroDropdownItem({
    required this.value,
    required this.label,
    this.key,
    this.subtitle,
    this.searchText,
    this.icon,
    this.iconColor,
    this.avatarText,
    this.leading,
    this.trailing,
  });

  final T value;
  final String label;
  final Key? key;
  final String? subtitle;
  final String? searchText;
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
    this.menuWidth,
    this.menuMaxHeight = 320,
    this.contentPadding,
    this.prefixIconConstraints,
    this.suffixIconConstraints,
    this.isDense,
    this.searchable = false,
    this.searchHintText = 'Buscar',
    this.emptyText = 'No hay resultados',
  });

  final T? value;
  final List<CobroDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final String hintText;
  final Widget? prefixIcon;
  final bool enabled;
  final double? menuWidth;
  final double menuMaxHeight;
  final EdgeInsetsGeometry? contentPadding;
  final BoxConstraints? prefixIconConstraints;
  final BoxConstraints? suffixIconConstraints;
  final bool? isDense;
  final bool searchable;
  final String searchHintText;
  final String emptyText;

  @override
  State<CobroDropdownField<T>> createState() => _CobroDropdownFieldState<T>();
}

class _CobroDropdownFieldState<T> extends State<CobroDropdownField<T>> {
  final OverlayPortalController _portalController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  final Object _regionGroupId = Object();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _cerrar() {
    if (!mounted) {
      return;
    }
    if (_portalController.isShowing) {
      _portalController.hide();
      _searchFocusNode.unfocus();
      _searchController.clear();
      setState(() {});
    }
  }

  void _alternar(bool habilitado) {
    if (!mounted || !habilitado) {
      return;
    }
    if (_portalController.isShowing) {
      _cerrar();
    } else {
      _searchController.clear();
      _portalController.show();
      if (widget.searchable) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _portalController.isShowing) {
            _searchFocusNode.requestFocus();
          }
        });
      }
      setState(() {});
    }
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
    final String consulta = _searchController.text.trim().toLowerCase();
    final List<CobroDropdownItem<T>> itemsVisibles = consulta.isEmpty
        ? widget.items
        : widget.items.where((CobroDropdownItem<T> item) {
            final String contenido = <String>[
              item.label,
              if (item.subtitle != null) item.subtitle!,
              if (item.searchText != null) item.searchText!,
            ].join(' ').toLowerCase();
            return contenido.contains(consulta);
          }).toList(growable: false);

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: (BuildContext overlayContext) {
          final RenderBox? renderBox =
              _fieldKey.currentContext?.findRenderObject() as RenderBox?;
          final Size screenSize = MediaQuery.sizeOf(overlayContext);

          final double anchoCampo = (renderBox != null && renderBox.hasSize)
              ? renderBox.size.width
              : 320.0;

          // Si widget.menuWidth es null, el menú toma exactamente el ancho del campo.
          // Si se especificó widget.menuWidth, se respeta pero sin salirse de los límites de la pantalla.
          final double anchoDeseado = widget.menuWidth ?? anchoCampo;
          final double anchoFinal = math.min(
            anchoDeseado,
            screenSize.width - 24.0,
          );

          double alturaMaxima = widget.menuMaxHeight;
          bool abrirHaciaArriba = false;
          double offsetDx = 0.0;

          if (renderBox != null && renderBox.hasSize && renderBox.attached) {
            final Offset posicionGlobal = renderBox.localToGlobal(Offset.zero);
            final double alturaCampo = renderBox.size.height;
            final double espacioAbajo =
                screenSize.height - (posicionGlobal.dy + alturaCampo) - 16.0;
            final double espacioArriba = posicionGlobal.dy - 16.0;

            // Abrir hacia arriba si no hay espacio suficiente abajo y hay más arriba
            if (espacioAbajo < 160.0 && espacioArriba > espacioAbajo) {
              abrirHaciaArriba = true;
              alturaMaxima = math.min(
                widget.menuMaxHeight,
                math.max(100.0, espacioArriba),
              );
            } else if (espacioAbajo > 0) {
              alturaMaxima = math.min(
                widget.menuMaxHeight,
                math.max(100.0, espacioAbajo),
              );
            }

            // Si el ancho deseado es mayor al campo o el campo está cercano al borde derecho,
            // desplazar horizontalmente para que nunca se desborde fuera de la pantalla
            final double bordeDerecho = posicionGlobal.dx + anchoFinal;
            final double limiteDerecho = screenSize.width - 12.0;
            if (bordeDerecho > limiteDerecho) {
              offsetDx = limiteDerecho - bordeDerecho;
            }
            if (posicionGlobal.dx + offsetDx < 12.0) {
              offsetDx = 12.0 - posicionGlobal.dx;
            }
          }

          final Alignment targetAnchor =
              abrirHaciaArriba ? Alignment.topLeft : Alignment.bottomLeft;
          final Alignment followerAnchor =
              abrirHaciaArriba ? Alignment.bottomLeft : Alignment.topLeft;
          final Offset offset = Offset(offsetDx, abrirHaciaArriba ? -4.0 : 4.0);

          return CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: targetAnchor,
            followerAnchor: followerAnchor,
            offset: offset,
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
                      minWidth: anchoFinal,
                      maxWidth: anchoFinal,
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
                        children: <Widget>[
                          if (widget.searchable)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                              child: TextField(
                                key: const ValueKey<String>(
                                  'cobro-dropdown-search',
                                ),
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: widget.searchHintText,
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                  ),
                                  suffixIcon: consulta.isEmpty
                                      ? null
                                      : IconButton(
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {});
                                            _searchFocusNode.requestFocus();
                                          },
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                          ),
                                          tooltip: 'Limpiar búsqueda',
                                        ),
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          if (itemsVisibles.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 18,
                              ),
                              child: Text(
                                widget.emptyText,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: context.clay.subtleText),
                              ),
                            ),
                          ...itemsVisibles.map((CobroDropdownItem<T> item) {
                            final bool esSeleccionado =
                                item.value == widget.value;

                            return InkWell(
                              key: item.key,
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
                                        item.avatarText!
                                            .isNotEmpty) ...<Widget>[
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: esSeleccionado
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .primaryContainer,
                                        foregroundColor: esSeleccionado
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onPrimary
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
                                            Theme.of(context)
                                                .colorScheme
                                                .primary,
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
                                                    color:
                                                        context.clay.subtleText,
                                                  ),
                                              maxLines: 2,
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
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
                prefixIconConstraints: widget.prefixIconConstraints ??
                    (widget.labelText == null
                        ? const BoxConstraints(minWidth: 28, minHeight: 28)
                        : null),
                suffixIcon: Icon(
                  abierto
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                ),
                suffixIconConstraints: widget.suffixIconConstraints ??
                    const BoxConstraints(minWidth: 26, minHeight: 26),
                isDense: widget.isDense ?? (widget.labelText == null),
                contentPadding: widget.contentPadding ??
                    (widget.labelText == null
                        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
                        : null),
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
                      radius: widget.labelText == null ? 9 : 11,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                      child: Text(
                        seleccionado.avatarText!,
                        style: TextStyle(
                          fontSize: widget.labelText == null ? 9 : 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: widget.labelText == null ? 5 : 8),
                  ] else if (seleccionado?.icon != null) ...<Widget>[
                    CircleAvatar(
                      radius: widget.labelText == null ? 9 : 11,
                      backgroundColor: (seleccionado!.iconColor ??
                              Theme.of(context).colorScheme.primary)
                          .withValues(alpha: 0.12),
                      foregroundColor: seleccionado.iconColor ??
                          Theme.of(context).colorScheme.primary,
                      child: Icon(
                        seleccionado.icon,
                        size: widget.labelText == null ? 11 : 13,
                      ),
                    ),
                    SizedBox(width: widget.labelText == null ? 5 : 8),
                  ],
                  Expanded(
                    child: Text(
                      seleccionado?.label ?? widget.hintText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: widget.labelText == null ? 12 : 14,
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
