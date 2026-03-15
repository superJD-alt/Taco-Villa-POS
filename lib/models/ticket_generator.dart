import 'package:intl/intl.dart';
import '/models/cuenta_cerrada.dart';

/// ============================================================
/// ticket_generator.dart
/// Generador de tickets compartido para toda la app.
/// Úsalo desde order.dart, view_table.dart, pedidos_activos.dart
/// o cualquier página que necesite imprimir la cuenta.
/// ============================================================

/// Genera el texto ESC/POS completo del ticket de cuenta.
///
/// [cuenta]        → Objeto CuentaCerrada con todos los datos.
/// [descuentoInfo] → Mapa con información del descuento (puede ser null).
/// [esReimpresion] → Si es true, agrega el sello "REIMPRESION" grande al inicio.
String generarTicketCuenta({
  required CuentaCerrada cuenta,
  Map<String, dynamic>? descuentoInfo,
  bool esReimpresion = false,
}) {
  final buffer = StringBuffer();
  final formatCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  // ========================================
  // SELLO DE REIMPRESION (solo si aplica)
  // ========================================
  if (esReimpresion) {
    buffer.writeln('================================');
    buffer.write('\x1B\x45\x01'); // ESC/POS: activar negrita
    buffer.write('\x1D\x21\x11'); // ESC/POS: doble ancho + doble alto
    buffer.writeln(ticketCentrar('**REIMPRESION**', ancho: 13));
    buffer.write('\x1D\x21\x00'); // volver a tamaño normal
    buffer.write('\x1B\x45\x00'); // desactivar negrita
    buffer.writeln('================================');
    buffer.writeln();
  }

  // ========================================
  // ENCABEZADO
  // ========================================
  buffer.writeln('================================');
  buffer.writeln(ticketCentrar('TACO VILLA'));
  buffer.writeln('================================');
  buffer.writeln(ticketCentrar('Mariano Herrera #13, Centro'));
  buffer.writeln(ticketCentrar('40000 Iguala de la'));
  buffer.writeln(ticketCentrar('Independencia, Gro., Mexico'));
  buffer.writeln(ticketCentrar('RFC: FOME940127132'));
  buffer.writeln(ticketCentrar('Cel: 733 134 3953'));
  buffer.writeln('================================');

  // ========================================
  // INFORMACION DE LA CUENTA
  // ========================================
  final folioCorto = cuenta.id.substring(0, 8).toUpperCase();
  buffer.writeln('FOLIO: $folioCorto  MESA: ${cuenta.numeroMesa}');
  buffer.writeln('MESERO: ${ticketSinAcentos(cuenta.mesero)}');
  buffer.writeln('COMENSALES: ${cuenta.comensales}');
  buffer.writeln(
    'FECHA: ${DateFormat('dd/MM/yyyy HH:mm').format(cuenta.fechaCierre)}',
  );
  buffer.writeln('================================');

  // ========================================
  // PRODUCTOS
  // ========================================
  buffer.writeln('Cant. Producto     Precio  Total');
  buffer.writeln('--------------------------------');

  for (var item in cuenta.productos) {
    final cantidad = item['cantidad'] as int;
    final nombre = ticketSinAcentos(item['nombre'] as String);
    final precioUnitario = (item['precio'] as num).toDouble();
    final totalItem = precioUnitario * cantidad;

    final cantStr = cantidad.toString().padRight(5);
    final precioStr = formatCurrency.format(precioUnitario);
    final totalStr = formatCurrency.format(totalItem);

    final nombreCorto = nombre.length > 12
        ? '${nombre.substring(0, 11)}.'
        : nombre;

    buffer.writeln('$cantStr$nombreCorto');
    buffer.writeln('      $precioStr x $cantidad = $totalStr');

    final nota = item['nota'] as String?;
    if (nota != null && nota.isNotEmpty) {
      final notaSinAcentos = ticketSinAcentos(nota);
      if (notaSinAcentos.length > 30) {
        buffer.writeln('  Nota: ${notaSinAcentos.substring(0, 30)}');
        buffer.writeln('        ${notaSinAcentos.substring(30)}');
      } else {
        buffer.writeln('  Nota: $notaSinAcentos');
      }
    }
  }

  buffer.writeln('--------------------------------');

  // ========================================
  // DESCUENTO (si aplica)
  // ========================================
  if (descuentoInfo != null &&
      descuentoInfo['monto_descuento'] != null &&
      (descuentoInfo['monto_descuento'] as num) > 0) {
    buffer.writeln('********************************');
    buffer.writeln('       DESCUENTO APLICADO');
    buffer.writeln('********************************');

    final subtotal = (descuentoInfo['total_original'] as num).toDouble();
    final descuento = (descuentoInfo['monto_descuento'] as num).toDouble();
    final categoria = ticketSinAcentos(
      descuentoInfo['categoria_descuento'] ?? 'Aplicado',
    );

    buffer.writeln('Subtotal:    ${formatCurrency.format(subtotal)}');
    buffer.writeln('Descuento ($categoria):');
    buffer.writeln('            -${formatCurrency.format(descuento)}');

    if (descuentoInfo['razon'] != null &&
        (descuentoInfo['razon'] as String).isNotEmpty) {
      final razon = ticketSinAcentos(descuentoInfo['razon'] as String);
      buffer.writeln('Motivo: $razon');
    }
    buffer.writeln('--------------------------------');
  }

  // ========================================
  // TOTAL FINAL — Grande con ESC/POS
  // ========================================
  buffer.writeln('================================');
  buffer.write('\x1D\x21\x11'); // doble ancho + doble alto
  buffer.writeln(ticketCentrar('TOTAL:', ancho: 13));
  buffer.writeln(
    ticketCentrar(formatCurrency.format(cuenta.totalCuenta), ancho: 13),
  );
  buffer.write('\x1D\x21\x00'); // volver a tamaño normal
  buffer.writeln('================================');
  buffer.writeln('   !GRACIAS POR SU VISITA!');
  buffer.writeln('================================');
  buffer.writeln('     Horario de atencion');
  buffer.writeln(' Miercoles a Lunes de 2:00 PM');
  buffer.writeln('         a 11:00 PM');
  buffer.writeln('================================');

  return buffer.toString();
}

// ============================================================
// Helpers internos del ticket
// Tienen prefijo "ticket" para no chocar con métodos
// que ya existan en otras clases.
// ============================================================

String ticketSinAcentos(String texto) {
  const acentos = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'Á': 'A',
    'É': 'E',
    'Í': 'I',
    'Ó': 'O',
    'Ú': 'U',
    'ñ': 'n',
    'Ñ': 'N',
    'ü': 'u',
    'Ü': 'U',
    '¿': '',
    '¡': '',
    '°': '',
  };
  String resultado = texto;
  acentos.forEach((key, value) {
    resultado = resultado.replaceAll(key, value);
  });
  return resultado;
}

String ticketCentrar(String texto, {int ancho = 32}) {
  if (texto.length >= ancho) return texto;
  final espaciosIzq = (ancho - texto.length) ~/ 2;
  return ' ' * espaciosIzq + texto;
}
