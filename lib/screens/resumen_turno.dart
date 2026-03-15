import 'package:flutter/material.dart';
import 'turno_state.dart';
import '/models/cuenta_cerrada.dart';
import 'mesa_state.dart';
import 'pdf_generator.dart';
import '/models/printer_manager.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '/models/ticket_generator.dart';

class ResumenTurno extends StatefulWidget {
  const ResumenTurno({super.key});

  @override
  State<ResumenTurno> createState() => _ResumenTurnoPageState();
}

class _ResumenTurnoPageState extends State<ResumenTurno> {
  final turnoState = TurnoState();
  final mesaState = MesaState();
  final PrinterManager _printerManager = PrinterManager();

  @override
  Widget build(BuildContext context) {
    final cuentas = turnoState.cuentasCerradas;
    final resumen = turnoState.resumenTurno;
    final meseroActual = mesaState.meseroActual;

    // Filtrar cuentas del mesero actual
    //final cuentasMesero = turnoState.obtenerCuentasPorMesero(meseroActual);
    final estadisticasMesero = turnoState.obtenerEstadisticasMesero(
      meseroActual,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen del Turno'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // Botón para cerrar turno
          if (cuentas.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Cerrar turno',
              onPressed: () => _confirmarCierreTurno(context),
            ),
        ],
      ),
      body: cuentas.isEmpty
          ? _buildEmptyState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarjetas de resumen general
                  _buildResumenCards(resumen),

                  const SizedBox(height: 24),

                  // Resumen del mesero actual
                  _buildResumenMesero(meseroActual, estadisticasMesero),

                  const SizedBox(height: 24),

                  // Lista de todas las cuentas
                  _buildSeccionTitulo('Todas las Cuentas Cerradas'),
                  const SizedBox(height: 12),
                  _buildListaCuentas(cuentas),

                  const SizedBox(height: 24),

                  // Productos más vendidos
                  _buildProductosTopVendidos(),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 100,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay cuentas cerradas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las cuentas aparecerán aquí cuando\nse procesen desde el sistema de pedidos',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCards(Map<String, dynamic> resumen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen General',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Total Ventas',
              '\$${resumen['totalVentas'].toStringAsFixed(2)}',
              Icons.attach_money,
              Colors.green,
            ),
            _buildStatCard(
              'Mesas Atendidas',
              '${resumen['totalMesas']}',
              Icons.table_restaurant,
              Colors.blue,
            ),
            _buildStatCard(
              'Comensales',
              '${resumen['totalComensales']}',
              Icons.group,
              Colors.orange,
            ),
            _buildStatCard(
              'Ticket Promedio',
              '\$${resumen['ticketPromedio'].toStringAsFixed(2)}',
              Icons.receipt,
              Colors.purple,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Info de duración del turno
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.shade200, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, color: Colors.indigo.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Duración del turno:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                ],
              ),
              Text(
                resumen['duracionFormateada'] ?? '0h 0m',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String titulo,
    String valor,
    IconData icono,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, color: color, size: 36),
          const SizedBox(height: 8),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenMesero(String mesero, Map<String, dynamic> stats) {
    if (mesero.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mis Estadísticas',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade400, Colors.teal.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.white, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    mesero,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white54, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMeseroStat(
                    'Ventas',
                    '\$${stats['totalVentas'].toStringAsFixed(2)}',
                  ),
                  _buildMeseroStat('Mesas', '${stats['totalMesas']}'),
                  _buildMeseroStat('Comensales', '${stats['totalComensales']}'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMeseroStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildSeccionTitulo(String titulo) {
    return Text(
      titulo,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildListaCuentas(List<CuentaCerrada> cuentas) {
    // Ordenar por fecha más reciente primero
    final cuentasOrdenadas = List<CuentaCerrada>.from(cuentas)
      ..sort((a, b) => b.fechaCierre.compareTo(a.fechaCierre));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cuentasOrdenadas.length,
      itemBuilder: (context, index) {
        final cuenta = cuentasOrdenadas[index];
        return _buildCuentaCard(cuenta);
      },
    );
  }

  Widget _buildCuentaCard(CuentaCerrada cuenta) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade200, width: 2),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${cuenta.numeroMesa}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.blue,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              'Mesa ${cuenta.numeroMesa}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            Text(
              '\$${cuenta.totalCuenta.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.green,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Mesero: ${cuenta.mesero}'),
            Text('Comensales: ${cuenta.comensales}'),
            Text(
              'Cerrada: ${_formatearHora(cuenta.fechaCierre)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Productos:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                ...cuenta.productos.map((producto) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'x${producto['cantidad']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            producto['nombre'],
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          '\$${(producto['precio'] * producto['cantidad']).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Duración: ${cuenta.duracionFormateada}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'Ticket promedio: \$${cuenta.ticketPromedio.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${cuenta.totalItems} items',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                // ✅ BOTONES DE ACCIÓN PARA REIMPRIMIR
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _reimprimirTicket(cuenta),
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text('Reimprimir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _verTicketCompleto(cuenta),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('Ver Detalle'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductosTopVendidos() {
    final topProductos = turnoState.productosTopVendidos;

    if (topProductos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSeccionTitulo('Top 10 Productos Más Vendidos'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade300, width: 2),
          ),
          child: Column(
            children: topProductos.asMap().entries.map((entry) {
              final index = entry.key;
              final producto = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: index < 3 ? Colors.amber : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: index < 3 ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        producto['nombre'],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${producto['cantidad']} vendidos',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ✅ MÉTODO PARA REIMPRIMIR DIRECTAMENTE A LA IMPRESORA DE BARRA/TICKETS
  Future<void> _reimprimirTicket(CuentaCerrada cuenta) async {
    try {
      await _printerManager.cargarConfiguracion();

      if (!_printerManager.estaConectada()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠️ La impresora de tickets/barra no está configurada',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // ✅ Reconstruir descuentoInfo desde los campos de CuentaCerrada
      Map<String, dynamic>? descuentoInfo;
      if (cuenta.descuentoAplicado == true &&
          cuenta.descuentoMonto != null &&
          cuenta.descuentoMonto! > 0) {
        descuentoInfo = {
          'monto_descuento': cuenta.descuentoMonto,
          'total_original': cuenta.totalOriginal ?? cuenta.totalCuenta,
          'categoria_descuento': cuenta.descuentoCategoria ?? 'Aplicado',
          'tipo_descuento': cuenta.descuentoTipo ?? 'porcentaje',
          'valor_descuento': cuenta.descuentoValor ?? 0,
          'razon': cuenta.descuentoRazon ?? '',
        };
      }

      // ✅ Usar el generador compartido con sello de REIMPRESION
      final contenidoTicket = generarTicketCuenta(
        cuenta: cuenta,
        descuentoInfo: descuentoInfo,
        esReimpresion: true,
      );

      if (mounted) Navigator.pop(context);

      // ✅ Usar imprimirTicketCuenta igual que order.dart
      await _printerManager.imprimirTicketCuenta(contenido: contenidoTicket);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Ticket de Mesa ${cuenta.numeroMesa} enviado a imprimir',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al reimprimir: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ✅ MÉTODO PARA VER TICKET COMPLETO CON VISTA PREVIA
  Future<void> _verTicketCompleto(CuentaCerrada cuenta) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      final pdfBytes = await generateTicketPdf(cuenta);
      if (mounted) Navigator.pop(context);
      if (mounted) {
        await _mostrarDialogoTicketReimpresion(pdfBytes, cuenta);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar ticket: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ MÉTODO PARA MOSTRAR DIÁLOGO CON VISTA PREVIA DEL TICKET
  Future<void> _mostrarDialogoTicketReimpresion(
    Uint8List pdfBytes,
    CuentaCerrada cuenta,
  ) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Center(
            child: Column(
              children: [
                Text(
                  'Ticket Mesa ${cuenta.numeroMesa}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(cuenta.fechaCierre),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: 600,
            height: 700,
            child: PdfPreview(
              build: (format) => pdfBytes,
              allowPrinting: true,
              allowSharing: true,
              maxPageWidth: 700,
              pdfFileName:
                  'Ticket_Mesa_${cuenta.numeroMesa}_${cuenta.fechaCierre.millisecondsSinceEpoch}.pdf',
              canChangeOrientation: false,
              canChangePageFormat: false,
              actions: [
                PdfPreviewAction(
                  icon: const Icon(Icons.print),
                  onPressed: (context, build, pageFormat) async {
                    final pdfBytes = await build(pageFormat);
                    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cerrar', style: TextStyle(fontSize: 16)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  String _formatearHora(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year} '
        '${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  void _confirmarCierreTurno(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('⚠️ Cerrar Turno'),
          content: const Text(
            'Esto eliminará todas las cuentas del resumen actual.\n\n'
            '¿Estás seguro de que deseas cerrar el turno?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                turnoState.cerrarTurno();
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Turno cerrado correctamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cerrar Turno'),
            ),
          ],
        );
      },
    );
  }
}
