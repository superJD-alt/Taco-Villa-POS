// aqui el codigo para generar el PDF del ticket de cuenta

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/cuenta_cerrada.dart';

Future<Uint8List> generateTicketPdf(CuentaCerrada cuenta) async {
  final pdf = pw.Document();
  final formatCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  // 🎯 DEBUG: Imprimir valores del descuento
  print('=== DEBUG DESCUENTO ===');
  print('descuentoAplicado: ${cuenta.descuentoAplicado}');
  print('descuentoMonto: ${cuenta.descuentoMonto}');
  print('descuentoCategoria: ${cuenta.descuentoCategoria}');
  print('descuentoRazon: ${cuenta.descuentoRazon}');
  print('totalOriginal: ${cuenta.totalOriginal}');
  print('totalCuenta: ${cuenta.totalCuenta}');
  print('=======================');

  final logoImage = await rootBundle.load('assets/images/tacoVilla2.png');
  final logoBytes = logoImage.buffer.asUint8List();

  pdf.addPage(
    pw.Page(
      pageFormat: const PdfPageFormat(
        58 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 4 * PdfPageFormat.mm,
      ),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Image(pw.MemoryImage(logoBytes), width: 90, height: 90),
            ),
            pw.SizedBox(height: 5),

            pw.Center(
              child: pw.Text(
                'TACO VILLA',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Mariano Herrera #13, Centro, 40000',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Iguala de la Independencia, Gro.',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.Center(
              child: pw.Text('México', style: const pw.TextStyle(fontSize: 8)),
            ),
            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text(
                'RFC: FOME940127132',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text(
                'Numero de celular: 733 134 3953',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),

            pw.Divider(thickness: 0.5),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'FOLIO: ${cuenta.folio ?? cuenta.id.substring(0, 8).toUpperCase()}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    'MESA: ${cuenta.numeroMesa}',
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 2),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'MESERO: ${cuenta.mesero}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    'COMENSALES: ${cuenta.comensales}',
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 2),

            pw.Text(
              'FECHA: ${DateFormat('dd/MM/yyyy HH:mm').format(cuenta.fechaCierre)}',
              style: const pw.TextStyle(fontSize: 8),
            ),

            pw.Divider(thickness: 0.5),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Cant.',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Producto',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Precio',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Total',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Divider(thickness: 0.5),

            ...cuenta.productos.map((item) {
              final cantidad = item['cantidad'] as int;
              final nombre = item['nombre'] as String;
              final precioUnitario = item['precio'] as double;
              final totalItem = (precioUnitario * cantidad);

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Container(
                        width: 25,
                        child: pw.Text(
                          '$cantidad',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.Container(
                        width: 70,
                        child: pw.Text(
                          nombre,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.Container(
                        width: 40,
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            formatCurrency.format(precioUnitario),
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                      ),
                      pw.Container(
                        width: 40,
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            formatCurrency.format(totalItem),
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (item.containsKey('nota') &&
                      (item['nota'] as String).isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 10, bottom: 2),
                      child: pw.Text(
                        'Nota: ${item['nota']}',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              );
            }).toList(),
            pw.Divider(thickness: 0.5),

            // 🔧 VERSIÓN CORREGIDA: Verificar si hay descuento con múltiples condiciones
            if (cuenta.descuentoAplicado == true &&
                cuenta.descuentoMonto != null &&
                cuenta.descuentoMonto! > 0)
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.purple),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Subtotal:', style: pw.TextStyle(fontSize: 10)),
                        pw.Text(
                          formatCurrency.format(
                            cuenta.totalOriginal ?? cuenta.totalCuenta,
                          ),
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Descuento (${cuenta.descuentoCategoria ?? 'Aplicado'}):',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.red,
                          ),
                        ),
                        pw.Text(
                          '-${formatCurrency.format(cuenta.descuentoMonto!)}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.red,
                          ),
                        ),
                      ],
                    ),
                    if (cuenta.descuentoRazon != null &&
                        cuenta.descuentoRazon!.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Text(
                          'Motivo: ${cuenta.descuentoRazon}',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (cuenta.descuentoAplicado == true &&
                cuenta.descuentoMonto != null &&
                cuenta.descuentoMonto! > 0)
              pw.SizedBox(height: 8),

            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'TOTAL: ${formatCurrency.format(cuenta.totalCuenta)}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            pw.Center(
              child: pw.Text(
                '¡GRACIAS POR SU VISITA!',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Horario de atención',
                style: const pw.TextStyle(fontSize: 6),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Miercoles a Lunes de 2:00 PM a 11:00 PM',
                style: const pw.TextStyle(fontSize: 6),
              ),
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}
