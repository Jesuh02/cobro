import 'package:flutter/material.dart';

import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/cobro_dropdown.dart';
import '../../../../data/models/models.dart';

class PagoRutaSolicitud {
  const PagoRutaSolicitud({
    required this.cuotaId,
    required this.monto,
    required this.medioPagoCodigo,
    this.observacion,
  });

  final String cuotaId;
  final double monto;
  final String medioPagoCodigo;
  final String? observacion;
}

class PagoRutaSeleccion {
  PagoRutaSeleccion(this.cobro)
      : montoController =
            TextEditingController(text: formatNumber(cobro.proximoSaldoCuota));

  final CobroRuta cobro;
  final TextEditingController montoController;

  String? get cuotaId => cobro.proximaCuotaId;
}

class SelectorMedioPagoBuscable extends StatelessWidget {
  const SelectorMedioPagoBuscable({
    super.key,
    required this.mediosPago,
    required this.medioPagoCodigo,
    required this.enabled,
    required this.onChanged,
  });

  final List<MedioPago> mediosPago;
  final String medioPagoCodigo;
  final bool enabled;
  final ValueChanged<String> onChanged;

  static IconData iconoMedioPago(String codigo) {
    switch (codigo.toUpperCase()) {
      case 'EFECTIVO':
        return Icons.payments_rounded;
      case 'TRANSFERENCIA':
        return Icons.account_balance_rounded;
      case 'TARJETA':
        return Icons.credit_card_rounded;
      case 'BILLETERA':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  static Color colorMedioPago(String codigo) {
    switch (codigo.toUpperCase()) {
      case 'EFECTIVO':
        return const Color(0xFF10B981);
      case 'TRANSFERENCIA':
        return const Color(0xFF3B82F6);
      case 'TARJETA':
        return const Color(0xFF8B5CF6);
      case 'BILLETERA':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6366F1);
    }
  }

  static String subtituloMedioPago(String codigo, String nombre) {
    switch (codigo.toUpperCase()) {
      case 'EFECTIVO':
        return 'Dinero en efectivo';
      case 'TRANSFERENCIA':
        return 'Transferencia bancaria';
      case 'TARJETA':
        return 'Tarjeta debito o credito';
      case 'BILLETERA':
        return 'Billetera digital (Nequi, Daviplata)';
      default:
        return 'Codigo: $codigo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool codigoValido =
        mediosPago.any((MedioPago m) => m.codigo == medioPagoCodigo);
    final String? valorActual = codigoValido
        ? medioPagoCodigo
        : (mediosPago.isNotEmpty ? mediosPago.first.codigo : null);

    return CobroDropdownField<String>(
      key: ValueKey<String?>('medio-pago-$valorActual'),
      labelText: 'Medio de pago',
      hintText: 'Selecciona medio de pago',
      prefixIcon: const Icon(Icons.payment_rounded),
      value: valorActual,
      enabled: enabled && mediosPago.isNotEmpty,
      menuWidth: 440,
      items: mediosPago.map((MedioPago medio) {
        return CobroDropdownItem<String>(
          value: medio.codigo,
          label: medio.nombre,
          subtitle: subtituloMedioPago(medio.codigo, medio.nombre),
          icon: iconoMedioPago(medio.codigo),
          iconColor: colorMedioPago(medio.codigo),
        );
      }).toList(growable: false),
      onChanged: enabled
          ? (String? valor) {
              if (valor != null) {
                onChanged(valor);
              }
            }
          : null,
    );
  }
}

