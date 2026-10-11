import '../../core/utils/json_utils.dart';

class PapeleraItem {
  const PapeleraItem({
    required this.id,
    required this.fecha,
    required this.cliente,
    required this.eliminadoPor,
    this.tipo = 'CLIENTE',
    this.motivo,
    this.credito,
    this.ruta,
  });

  factory PapeleraItem.fromJson(Map<String, dynamic> json) {
    return PapeleraItem(
      id: json['id'] as String,
      fecha: DateTime.parse(json['fecha'] as String),
      tipo: json['tipo'] as String? ?? 'CLIENTE',
      motivo: json['motivo'] as String?,
      cliente: PapeleraCliente.fromJson(
        json['cliente'] as Map<String, dynamic>,
      ),
      credito: json['credito'] != null
          ? PapeleraCredito.fromJson(
              json['credito'] as Map<String, dynamic>,
            )
          : null,
      ruta: json['ruta'] != null
          ? PapeleraRuta.fromJson(json['ruta'] as Map<String, dynamic>)
          : null,
      eliminadoPor: PapeleraEliminadoPor.fromJson(
        json['eliminadoPor'] as Map<String, dynamic>,
      ),
    );
  }

  final String id;
  final DateTime fecha;
  final String tipo;
  final String? motivo;
  final PapeleraCliente cliente;
  final PapeleraCredito? credito;
  final PapeleraRuta? ruta;
  final PapeleraEliminadoPor eliminadoPor;
}

class PapeleraCliente {
  const PapeleraCliente({
    required this.id,
    required this.nombreCompleto,
    required this.documento,
    this.telefono,
    this.direccion,
    this.negocio,
  });

  factory PapeleraCliente.fromJson(Map<String, dynamic> json) {
    return PapeleraCliente(
      id: json['id'] as String,
      nombreCompleto: json['nombreCompleto'] as String,
      documento: json['documento'] as String,
      telefono: json['telefono'] as String?,
      direccion: json['direccion'] as String?,
      negocio: json['negocio'] as String?,
    );
  }

  final String id;
  final String nombreCompleto;
  final String documento;
  final String? telefono;
  final String? direccion;
  final String? negocio;
}

class PapeleraCredito {
  const PapeleraCredito({
    required this.id,
    required this.total,
    required this.totalPagar,
    required this.saldoPendiente,
    required this.monedaCodigo,
  });

  factory PapeleraCredito.fromJson(Map<String, dynamic> json) {
    return PapeleraCredito(
      id: json['id'] as String,
      total: parseJsonDouble(json['total']),
      totalPagar: parseJsonDouble(json['totalPagar']),
      saldoPendiente: parseJsonDouble(json['saldoPendiente']),
      monedaCodigo: json['monedaCodigo'] as String? ?? 'COP',
    );
  }

  final String id;
  final double total;
  final double totalPagar;
  final double saldoPendiente;
  final String monedaCodigo;
}

class PapeleraRuta {
  const PapeleraRuta({
    required this.id,
    required this.nombre,
  });

  factory PapeleraRuta.fromJson(Map<String, dynamic> json) {
    return PapeleraRuta(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
    );
  }

  final String id;
  final String nombre;
}

class PapeleraEliminadoPor {
  const PapeleraEliminadoPor({
    required this.id,
    required this.usuario,
    required this.nombreCompleto,
  });

  factory PapeleraEliminadoPor.fromJson(Map<String, dynamic> json) {
    return PapeleraEliminadoPor(
      id: json['id'] as String,
      usuario: json['usuario'] as String,
      nombreCompleto: json['nombreCompleto'] as String,
    );
  }

  final String id;
  final String usuario;
  final String nombreCompleto;
}
