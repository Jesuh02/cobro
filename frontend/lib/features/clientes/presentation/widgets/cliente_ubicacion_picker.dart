import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/ui/clay.dart';
import '../../../routes/data/device_location_service.dart';

const String mensajeUbicacionCasa =
    'Ubicacion marcada. Escribe la direccion de la casa, ej: cr14 #28-26';

class ClienteUbicacionPicker extends StatefulWidget {
  const ClienteUbicacionPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final LatLng? value;
  final ValueChanged<LatLng?> onChanged;
  final bool enabled;

  @override
  State<ClienteUbicacionPicker> createState() => _ClienteUbicacionPickerState();
}

class _ClienteUbicacionPickerState extends State<ClienteUbicacionPicker> {
  bool _locating = false;

  Future<void> _useCurrentLocation() async {
    if (!widget.enabled || _locating) {
      return;
    }

    setState(() => _locating = true);
    try {
      final LatLng position =
          await const DeviceRouteLocationService().currentPosition();
      widget.onChanged(position);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(mensajeUbicacionCasa),
          ),
        );
      }
    } on RouteLocationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final LatLng? value = widget.value;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: clay.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value != null
              ? CobroAppTheme.primary.withValues(alpha: 0.35)
              : clay.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compacto = constraints.maxWidth < 420;

            final Widget iconoYTexto = Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: value != null
                        ? CobroAppTheme.primary.withValues(alpha: 0.12)
                        : clay.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      value != null
                          ? Icons.location_on_rounded
                          : Icons.location_off_outlined,
                      color: value != null
                          ? CobroAppTheme.primary
                          : clay.subtleText,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        value != null
                            ? 'Ubicación GPS registrada'
                            : 'Ubicación del cliente',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value != null
                            ? '${value.latitude.toStringAsFixed(6)}, ${value.longitude.toStringAsFixed(6)}'
                            : 'Opcional: guarda la posición GPS para la ruta de cobro.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: clay.subtleText),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final Widget acciones = value == null
                ? OutlinedButton.icon(
                    onPressed: widget.enabled && !_locating
                        ? _useCurrentLocation
                        : null,
                    icon: _locating
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(_locating ? 'Ubicando...' : 'Guardar ubicación'),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Actualizar posición GPS',
                        onPressed: widget.enabled && !_locating
                            ? _useCurrentLocation
                            : null,
                        icon: _locating
                            ? const SizedBox.square(
                                dimension: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Quitar ubicación',
                        onPressed: widget.enabled
                            ? () => widget.onChanged(null)
                            : null,
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  );

            if (compacto) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  iconoYTexto,
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: acciones,
                  ),
                ],
              );
            }

            return Row(
              children: <Widget>[
                Expanded(child: iconoYTexto),
                const SizedBox(width: 8),
                acciones,
              ],
            );
          },
        ),
      ),
    );
  }
}

