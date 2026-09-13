export 'widgets/calculo_credito.dart';
export 'widgets/filtros_credito.dart';
export 'widgets/formulario_credito.dart';
export 'widgets/resumen_credito_animado.dart';
export 'widgets/tarjeta_credito_registro.dart';

import 'package:flutter/material.dart';

import '../../../../core/ui/page_layout.dart';
import '../../../../core/ui/skeletons.dart';
import '../../../../data/models/models.dart';
import 'widgets/tarjeta_credito_registro.dart';

String mensajeDatosBaseCredito(Catalogos? catalogos, {required bool sinClientes}) {
  if (catalogos == null) {
    return 'No se pudieron cargar los catalogos.';
  }

  final List<String> faltantes = <String>[
    if (sinClientes) 'clientes',
    if (catalogos.monedas.isEmpty) 'monedas',
    if (catalogos.frecuenciasPago.isEmpty) 'frecuencias',
    if (catalogos.cajasMenoresActivas.isEmpty) 'caja menor activa',
  ];

  if (faltantes.isEmpty) {
    return 'Los datos base estan listos.';
  }

  return 'Faltan: ${faltantes.join(', ')}.';
}

class CreditosView extends StatelessWidget {
  const CreditosView({
    super.key,
    required this.creditos,
    required this.sinCreditosRegistrados,
    required this.mostrandoCargaInicial,
    required this.cargandoMasCreditos,
    required this.hayCreditoActivo,
    required this.listo,
    required this.faltanClientes,
    required this.puedeCrearClienteConCredito,
    required this.mensajeDatosBase,
    required this.puedeRefinanciarCreditos,
    required this.puedeCrearCreditos,
    required this.puedeModificarCreditos,
    required this.puedeEliminarCreditos,
    required this.guardando,
    this.error,
    required this.onRefresh,
    required this.onNearEnd,
    required this.onRefinanciarGeneral,
    required this.onCrearCredito,
    required this.onModificarCredito,
    required this.onEliminarCredito,
    required this.onRefinanciarCredito,
    required this.buscarController,
    required this.filtros,
  });

  final List<CreditoRegistro> creditos;
  final bool sinCreditosRegistrados;
  final bool mostrandoCargaInicial;
  final bool cargandoMasCreditos;
  final bool hayCreditoActivo;
  final bool listo;
  final bool faltanClientes;
  final bool puedeCrearClienteConCredito;
  final String mensajeDatosBase;
  final bool puedeRefinanciarCreditos;
  final bool puedeCrearCreditos;
  final bool puedeModificarCreditos;
  final bool puedeEliminarCreditos;
  final bool guardando;
  final String? error;
  final Future<void> Function() onRefresh;
  final VoidCallback onNearEnd;
  final VoidCallback onRefinanciarGeneral;
  final VoidCallback onCrearCredito;
  final ValueChanged<CreditoRegistro> onModificarCredito;
  final ValueChanged<CreditoRegistro> onEliminarCredito;
  final ValueChanged<CreditoRegistro> onRefinanciarCredito;
  final TextEditingController buscarController;
  final Widget filtros;

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Credito',
      error: error,
      onRefresh: onRefresh,
      onNearEnd: onNearEnd,
      acciones: <Widget>[
        OutlinedButton.icon(
          onPressed:
              guardando || !hayCreditoActivo || !puedeRefinanciarCreditos
                  ? null
                  : onRefinanciarGeneral,
          icon: const Icon(Icons.currency_exchange_rounded),
          label: const Text('Refinanciar'),
        ),
        FilledButton.icon(
          onPressed: guardando || !puedeCrearCreditos
              ? null
              : onCrearCredito,
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('Crear credito'),
        ),
      ],
      children: <Widget>[
        if (!mostrandoCargaInicial && !listo && sinCreditosRegistrados)
          EstadoVacio(
            icono: Icons.add_business_outlined,
            titulo: 'Faltan datos base',
            mensaje: faltanClientes && puedeCrearClienteConCredito
                ? 'Crea un cliente y registra su credito en el mismo formulario.'
                : mensajeDatosBase,
            accion: FilledButton.icon(
              onPressed: guardando || !puedeCrearCreditos
                  ? null
                  : onCrearCredito,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Añadir crédito'),
            ),
          ),
        TextField(
          controller: buscarController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            labelText: 'Buscar credito, cliente o ruta',
          ),
        ),
        const SizedBox(height: 12),
        filtros,
        const SizedBox(height: 16),
        if (mostrandoCargaInicial)
          const SkeletonListaCreditos()
        else if (creditos.isEmpty)
          EstadoVacio(
            icono: Icons.request_quote_outlined,
            titulo: 'No hay nada',
            mensaje: 'No hay creditos para mostrar con el filtro actual.',
            accion: FilledButton.icon(
              onPressed: guardando || !puedeCrearCreditos
                  ? null
                  : onCrearCredito,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Crear credito'),
            ),
          )
        else
          ...creditos.map(
            (CreditoRegistro credito) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TarjetaCreditoRegistro(
                credito: credito,
                puedeModificar: puedeModificarCreditos,
                puedeEliminar: puedeEliminarCreditos,
                onModificar: () => onModificarCredito(credito),
                onEliminar: () => onEliminarCredito(credito),
                onRefinanciar:
                    credito.activo && !guardando && puedeRefinanciarCreditos
                        ? () => onRefinanciarCredito(credito)
                        : null,
              ),
            ),
          ),
        if (cargandoMasCreditos)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
