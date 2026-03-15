// Archivo: lib/models/cuenta_cerrada.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CuentaCerrada {
  final String id;
  final int numeroMesa;
  final String mesero;
  final int comensales;
  final DateTime fechaApertura;
  final DateTime fechaCierre;
  final List<Map<String, dynamic>> productos;
  final int totalItems;
  final double totalCuenta;
  final String? folio;

  // ✅ NUEVOS CAMPOS OPCIONALES para descuentos
  final bool? descuentoAplicado;
  final String? descuentoTipo;
  final String? descuentoCategoria;
  final double? descuentoValor;
  final double? descuentoMonto;
  final String? descuentoRazon;
  final double? totalOriginal;

  CuentaCerrada({
    required this.id,
    required this.numeroMesa,
    required this.mesero,
    required this.comensales,
    required this.fechaApertura,
    required this.fechaCierre,
    required this.productos,
    required this.totalItems,
    required this.totalCuenta,
    this.folio,
    // ✅ Parámetros opcionales para descuentos
    this.descuentoAplicado,
    this.descuentoTipo,
    this.descuentoCategoria,
    this.descuentoValor,
    this.descuentoMonto,
    this.descuentoRazon,
    this.totalOriginal,
  });

  // Convertir a Map para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numeroMesa': numeroMesa,
      'mesero': mesero,
      'comensales': comensales,
      'fechaApertura': Timestamp.fromDate(fechaApertura),
      'fechaCierre': Timestamp.fromDate(fechaCierre),
      'productos': productos,
      'totalItems': totalItems,
      'totalCuenta': totalCuenta,
      // ✅ Incluir campos de descuento si existen
      if (descuentoAplicado != null) 'descuento_aplicado': descuentoAplicado,
      if (descuentoTipo != null) 'descuento_tipo': descuentoTipo,
      if (descuentoCategoria != null) 'descuento_categoria': descuentoCategoria,
      if (descuentoValor != null) 'descuento_valor': descuentoValor,
      if (descuentoMonto != null) 'descuento_monto': descuentoMonto,
      if (descuentoRazon != null) 'descuento_razon': descuentoRazon,
      if (totalOriginal != null) 'total_original': totalOriginal,
    };
  }

  // Crear desde Map (desde Firestore)
  factory CuentaCerrada.fromMap(Map<String, dynamic> map, String documentId) {
    return CuentaCerrada(
      id: documentId,
      numeroMesa: map['numeroMesa'] ?? 0,
      mesero: map['mesero'] ?? '',
      comensales: map['comensales'] ?? 0,
      fechaApertura:
          (map['fechaApertura'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaCierre:
          (map['fechaCierre'] as Timestamp?)?.toDate() ?? DateTime.now(),
      productos: List<Map<String, dynamic>>.from(map['productos'] ?? []),
      totalItems: map['totalItems'] ?? 0,
      totalCuenta: (map['totalCuenta'] ?? 0.0).toDouble(),
      // ✅ Cargar campos de descuento si existen
      descuentoAplicado: map['descuento_aplicado'],
      descuentoTipo: map['descuento_tipo'],
      descuentoCategoria: map['descuento_categoria'],
      descuentoValor: map['descuento_valor']?.toDouble(),
      descuentoMonto: map['descuento_monto']?.toDouble(),
      descuentoRazon: map['descuento_razon'],
      totalOriginal: map['total_original']?.toDouble(),
    );
  }

  // ✅ MÉTODO ÚTIL: Crear copia con descuento
  CuentaCerrada copyWith({
    String? id,
    int? numeroMesa,
    String? mesero,
    int? comensales,
    DateTime? fechaApertura,
    DateTime? fechaCierre,
    List<Map<String, dynamic>>? productos,
    int? totalItems,
    double? totalCuenta,
    bool? descuentoAplicado,
    String? descuentoTipo,
    String? descuentoCategoria,
    double? descuentoValor,
    double? descuentoMonto,
    String? descuentoRazon,
    double? totalOriginal,
  }) {
    return CuentaCerrada(
      id: id ?? this.id,
      numeroMesa: numeroMesa ?? this.numeroMesa,
      mesero: mesero ?? this.mesero,
      comensales: comensales ?? this.comensales,
      fechaApertura: fechaApertura ?? this.fechaApertura,
      fechaCierre: fechaCierre ?? this.fechaCierre,
      productos: productos ?? this.productos,
      totalItems: totalItems ?? this.totalItems,
      totalCuenta: totalCuenta ?? this.totalCuenta,
      descuentoAplicado: descuentoAplicado ?? this.descuentoAplicado,
      descuentoTipo: descuentoTipo ?? this.descuentoTipo,
      descuentoCategoria: descuentoCategoria ?? this.descuentoCategoria,
      descuentoValor: descuentoValor ?? this.descuentoValor,
      descuentoMonto: descuentoMonto ?? this.descuentoMonto,
      descuentoRazon: descuentoRazon ?? this.descuentoRazon,
      totalOriginal: totalOriginal ?? this.totalOriginal,
    );
  }

  // ✅ GETTER: Duración formateada de la cuenta
  String get duracionFormateada {
    final duracion = fechaCierre.difference(fechaApertura);
    final horas = duracion.inHours;
    final minutos = duracion.inMinutes.remainder(60);

    if (horas > 0) {
      return '${horas}h ${minutos}min';
    } else {
      return '${minutos}min';
    }
  }

  // ✅ GETTER: Ticket promedio por comensal
  double get ticketPromedio {
    if (comensales <= 0) return totalCuenta;
    return totalCuenta / comensales;
  }

  @override
  String toString() {
    return 'CuentaCerrada(mesa: $numeroMesa, total: \$totalCuenta, descuento: ${descuentoAplicado == true ? '\$descuentoMonto' : 'N/A'})';
  }
}
