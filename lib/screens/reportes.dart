import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '/models/content_card.dart';
import '/models/cuenta_cerrada.dart';
import 'pdf_generator.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';

typedef ReportData = Map<String, dynamic>;

class Reportes extends StatefulWidget {
  const Reportes({Key? key}) : super(key: key);

  @override
  State<Reportes> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<Reportes> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NumberFormat currencyFormat = NumberFormat.currency(
    locale: 'es_US',
    symbol: '\$',
  );
  String _selectedPeriod = 'daily';
  DateTime _selectedDate = DateTime.now();
  late DateTime _startDate;
  late DateTime _endDate;
  Future<ReportData>? _reportFuture;

  @override
  void initState() {
    super.initState();
    _calculateAndSetRange(_selectedDate, _selectedPeriod);
    _reportFuture = _fetchReports();
  }

  void _calculateAndSetRange(DateTime date, String period) {
    DateTime start;
    DateTime end;
    final dateOnly = DateTime(date.year, date.month, date.day);
    if (period == 'daily') {
      start = dateOnly;
      end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    } else if (period == 'weekly') {
      int weekday = dateOnly.weekday;
      start = dateOnly.subtract(Duration(days: weekday - 1));
      end = start.add(const Duration(days: 6));
      end = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    } else if (period == 'monthly') {
      start = DateTime(date.year, date.month, 1);
      DateTime nextMonth = DateTime(date.year, date.month + 1, 1);
      end = nextMonth.subtract(const Duration(milliseconds: 1));
    } else {
      start = dateOnly;
      end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    }
    setState(() {
      _startDate = start;
      _endDate = end;
      _selectedDate = date;
    });
  }

  DateTime? _parseStringToDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('⚠️ Error parseando fecha: $value - $e');
        return null;
      }
    }
    return null;
  }

  Future<ReportData> _fetchReports() async {
    print('🔍 DEBUG: Iniciando consulta de reportes');
    print('📅 DEBUG: Rango de fechas: $_startDate a $_endDate');

    final cajasSnapshot = await _firestore
        .collection('cajas')
        .where('fechaCierre', isGreaterThanOrEqualTo: _startDate)
        .where('fechaCierre', isLessThanOrEqualTo: _endDate)
        .where('estado', isEqualTo: 'cerrada')
        .get();
    double totalDiferenciaCajas = 0.0;
    double totalEfectivoContado = 0.0;
    final List<Map<String, dynamic>> cierres = [];
    for (var doc in cajasSnapshot.docs) {
      final data = doc.data();
      totalDiferenciaCajas += (data['diferencia'] as num?)?.toDouble() ?? 0.0;
      totalEfectivoContado +=
          (data['efectivoContado'] as num?)?.toDouble() ?? 0.0;

      // 🎯 CORRECCIÓN APLICADA: Convertir a DateTime
      final fechaCierreTimestamp = data['fechaCierre'] as Timestamp?;
      final fechaCierreDateTime = fechaCierreTimestamp?.toDate();

      cierres.add({
        ...data,
        'id': doc.id,
        'fechaCierre': fechaCierreDateTime, // 👈 Guardar el DateTime
      });
    }

    final movimientosSnapshot = await _firestore
        .collection('movimientos_caja')
        .where('fecha', isGreaterThanOrEqualTo: _startDate)
        .where('fecha', isLessThanOrEqualTo: _endDate)
        .get();
    double totalIngresosMovimientos = 0.0;
    double totalEgresosMovimientos = 0.0;
    for (var doc in movimientosSnapshot.docs) {
      final data = doc.data();
      final monto = (data['monto'] as num?)?.toDouble() ?? 0.0;
      if (data['tipo'] == 'ingreso') {
        totalIngresosMovimientos += monto;
      } else if (data['tipo'] == 'egreso') {
        totalEgresosMovimientos += monto;
      }
    }

    // --- SECCIÓN DE VENTAS (CORREGIDA) ---
    // 1. Agregar filtro de fecha.
    final ventasSnapshot = await _firestore
        .collection('cuentasCerradas')
        .where('fechaCierre', isGreaterThanOrEqualTo: _startDate)
        .where('fechaCierre', isLessThanOrEqualTo: _endDate)
        .get();

    double totalVentasBruto = 0.0;
    int totalProductosVendidos = 0;
    final List<Map<String, dynamic>> tickets = [];

    for (var doc in ventasSnapshot.docs) {
      final data = doc.data();

      // 2. LÓGICA DE AGREGACIÓN DE VENTAS (AGREGADA)
      // Usamos 'total_original' (snake_case) basado en el contexto de tu BD.
      final totalOriginal = (data['total_original'] as num?)?.toDouble() ?? 0.0;
      totalVentasBruto += totalOriginal;

      final productos = List<Map<String, dynamic>>.from(
        data['productos'] ?? [],
      );
      for (var item in productos) {
        totalProductosVendidos += (item['cantidad'] as num?)?.toInt() ?? 0;
      }

      final fechaCierreTimestamp = data['fechaCierre'] as Timestamp?;
      final fechaCierreDateTime = fechaCierreTimestamp?.toDate();

      tickets.add({
        ...data,
        'id': doc.id,
        'fechaCierre': fechaCierreDateTime, // 👈 Importante
      });
    }

    // --- SECCIÓN DE DESCUENTOS (CORREGIDA) ---
    // 3. Mover la consulta de descuentos fuera del bucle de ventas.
    final descuentosSnapshot = await _firestore
        .collection('movimientos_caja')
        .where('fecha', isGreaterThanOrEqualTo: _startDate)
        .where('fecha', isLessThanOrEqualTo: _endDate)
        .where('tipo', isEqualTo: 'descuento')
        .get();

    double totalDescuentos = 0.0;
    Map<String, double> descuentosPorCategoria = {};
    Map<String, int> conteoDescuentosPorCategoria = {};
    final List<Map<String, dynamic>> descuentos = [];

    for (var doc in descuentosSnapshot.docs) {
      final data = doc.data();
      final monto = (data['monto'] as num?)?.toDouble() ?? 0.0;
      final categoria = data['categoria'] as String? ?? 'otro';

      totalDescuentos += monto;

      descuentosPorCategoria[categoria] =
          (descuentosPorCategoria[categoria] ?? 0.0) + monto;
      conteoDescuentosPorCategoria[categoria] =
          (conteoDescuentosPorCategoria[categoria] ?? 0) + 1;

      descuentos.add({
        ...data,
        'id': doc.id,
        'fecha': (data['fecha'] as Timestamp?)?.toDate(),
      });
    }

    descuentos.sort(
      (a, b) => (b['fecha'] as DateTime).compareTo(a['fecha'] as DateTime),
    );
    // ------------------------------------------

    final comandasSnapshot = await _firestore
        .collection('ordenesCocina')
        .where('horaComanda', isGreaterThanOrEqualTo: _startDate)
        .where('horaComanda', isLessThanOrEqualTo: _endDate)
        .get();
    // ... (El resto del código de Comandas está bien)
    final List<Map<String, dynamic>> comandas = [];
    int totalComandasCocina = 0;
    int totalComandasBarra = 0;
    int totalProductosComandasCocina = 0;
    int totalProductosComandasBarra = 0;
    Map<String, int> comandasPorEstado = {
      'pendiente': 0,
      'preparando': 0,
      'completada': 0,
      'cancelada': 0,
    };
    for (var doc in comandasSnapshot.docs) {
      final data = doc.data();
      final destino = data['destino'] ?? 'cocina';
      final estado = data['estado'] ?? 'pendiente';
      final totalProductos = (data['totalProductos'] as num?)?.toInt() ?? 0;
      if (destino == 'cocina') {
        totalComandasCocina++;
        totalProductosComandasCocina += totalProductos;
      } else if (destino == 'barra') {
        totalComandasBarra++;
        totalProductosComandasBarra += totalProductos;
      }
      comandasPorEstado[estado] = (comandasPorEstado[estado] ?? 0) + 1;
      comandas.add({
        ...data,
        'id': doc.id,
        'horaComanda': (data['horaComanda'] as Timestamp?)?.toDate(),
      });
    }
    comandas.sort(
      (a, b) => (b['horaComanda'] as DateTime).compareTo(
        a['horaComanda'] as DateTime,
      ),
    );

    return {
      'cajasCerradas': cajasSnapshot.docs.length,
      'totalDiferenciaCajas': totalDiferenciaCajas,
      'totalEfectivoContado': totalEfectivoContado,
      'cierres': cierres,
      'totalIngresosMovimientos': totalIngresosMovimientos,
      'totalEgresosMovimientos': totalEgresosMovimientos,
      'totalVentasBruto': totalVentasBruto,
      'numTickets': tickets.length,
      'totalProductosVendidos': totalProductosVendidos,
      'tickets': tickets,
      'comandas': comandas,
      'numComandas': comandas.length,
      'totalComandasCocina': totalComandasCocina,
      'totalComandasBarra': totalComandasBarra,
      'totalProductosComandasCocina': totalProductosComandasCocina,
      'totalProductosComandasBarra': totalProductosComandasBarra,
      'comandasPorEstado': comandasPorEstado,
      'startDate': _startDate,
      'endDate': _endDate,
      'totalDescuentos': totalDescuentos,
      'descuentosPorCategoria': descuentosPorCategoria,
      'conteoDescuentosPorCategoria': conteoDescuentosPorCategoria,
      'descuentos': descuentos,
      'numDescuentos': descuentos.length,
    };
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _calculateAndSetRange(picked, _selectedPeriod);
        _reportFuture = _fetchReports();
      });
    }
  }

  String _formatRange() {
    final DateFormat formatter = DateFormat('dd MMM yyyy', 'es');
    if (_selectedPeriod == 'daily') {
      return 'Día: ${formatter.format(_startDate)}';
    } else if (_selectedPeriod == 'weekly') {
      return 'Semana: ${formatter.format(_startDate)} - ${formatter.format(_endDate)}';
    } else if (_selectedPeriod == 'monthly') {
      final monthFormatter = DateFormat('MMMM yyyy', 'es');
      return 'Mes: ${monthFormatter.format(_startDate)}';
    }
    return 'Rango Desconocido';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: 16),
          _buildDateRangeHeader(),
          const SizedBox(height: 24),
          ContentCard(
            title: 'Resultados del Reporte',
            child: FutureBuilder<ReportData>(
              future: _reportFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Error al cargar los datos: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No hay datos para este período.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }
                final data = snapshot.data!;
                return _buildReportContent(data);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ChoiceChip(
            label: const Text('Diario'),
            selected: _selectedPeriod == 'daily',
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedPeriod = 'daily';
                  _calculateAndSetRange(_selectedDate, 'daily');
                  _reportFuture = _fetchReports();
                });
              }
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Semanal'),
            selected: _selectedPeriod == 'weekly',
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedPeriod = 'weekly';
                  _calculateAndSetRange(_selectedDate, 'weekly');
                  _reportFuture = _fetchReports();
                });
              }
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Mensual'),
            selected: _selectedPeriod == 'monthly',
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedPeriod = 'monthly';
                  _calculateAndSetRange(_selectedDate, 'monthly');
                  _reportFuture = _fetchReports();
                });
              }
            },
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => _selectDate(context),
            icon: const Icon(Icons.calendar_today),
            label: const Text('Cambiar Fecha Inicial'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeHeader() {
    return Center(
      child: Text(
        _formatRange(),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade800,
        ),
      ),
    );
  }

  Widget _buildReportContent(ReportData data) {
    return Column(
      children: [
        _buildGeneralSummary(data),
        const SizedBox(height: 32),

        // ✅ AGREGAR ESTAS DOS NUEVAS SECCIONES:
        _buildDescuentosSummary(data),
        const SizedBox(height: 32),
        _buildDescuentosDetalle(data),
        const SizedBox(height: 32),

        // ... resto de secciones existentes ...
        _buildComandasSummary(data),
        const SizedBox(height: 32),
        _buildComandasList(data),
        const SizedBox(height: 32),
        _buildTicketsList(data),
        const SizedBox(height: 32),
        _buildCajasCerradas(data),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildComandasSummary(ReportData data) {
    final totalComandasCocina = data['totalComandasCocina'] ?? 0;
    final totalComandasBarra = data['totalComandasBarra'] ?? 0;
    final totalProductosCocina = data['totalProductosComandasCocina'] ?? 0;
    final totalProductosBarra = data['totalProductosComandasBarra'] ?? 0;
    final comandasPorEstado =
        data['comandasPorEstado'] as Map<String, int>? ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumen de Comandas',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Divider(),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummaryCard(
                'Comandas Cocina',
                '$totalComandasCocina',
                const Color(0xFFF97316),
              ),
              _buildSummaryCard(
                'Comandas Barra',
                '$totalComandasBarra',
                const Color(0xFF0EA5E9),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummaryCard(
                'Productos Cocina',
                '$totalProductosCocina',
                const Color(0xFFFB923C),
              ),
              _buildSummaryCard(
                'Productos Barra',
                '$totalProductosBarra',
                const Color(0xFF38BDF8),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummaryCard(
                'Pendientes',
                '${comandasPorEstado['pendiente'] ?? 0}',
                const Color(0xFFDC2626),
              ),
              _buildSummaryCard(
                'Preparando',
                '${comandasPorEstado['preparando'] ?? 0}',
                const Color(0xFFF59E0B),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummaryCard(
                'Completadas',
                '${comandasPorEstado['completada'] ?? 0}',
                const Color(0xFF22C55E),
              ),
              _buildSummaryCard(
                'Canceladas',
                '${comandasPorEstado['cancelada'] ?? 0}',
                const Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComandasList(ReportData data) {
    final comandas = data['comandas'] as List<Map<String, dynamic>>? ?? [];
    final displayComandas = comandas.take(20).toList();
    return ContentCard(
      title: 'Comandas Enviadas (${comandas.length})',
      child: comandas.isEmpty
          ? const Center(
              child: Text('No se encontraron comandas en este período.'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayComandas.length,
                  itemBuilder: (context, index) {
                    final comanda = displayComandas[index];
                    final fecha = comanda['horaComanda'] as DateTime?;
                    final destino = comanda['destino'] ?? 'cocina';
                    final estado = comanda['estado'] ?? 'pendiente';
                    final mesa = (comanda['numeroMesa'] as num?)?.toInt() ?? 0;
                    final totalProductos =
                        (comanda['totalProductos'] as num?)?.toInt() ?? 0;
                    final productos =
                        comanda['productos'] as List<dynamic>? ?? [];
                    Color destinoColor = destino == 'cocina'
                        ? Colors.orange
                        : Colors.blue;
                    Color estadoColor;
                    IconData estadoIcon;
                    switch (estado) {
                      case 'completada':
                        estadoColor = Colors.green;
                        estadoIcon = Icons.check_circle;
                        break;
                      case 'preparando':
                        estadoColor = Colors.amber;
                        estadoIcon = Icons.hourglass_empty;
                        break;
                      case 'cancelada':
                        estadoColor = Colors.red;
                        estadoIcon = Icons.cancel;
                        break;
                      default:
                        estadoColor = Colors.grey;
                        estadoIcon = Icons.schedule;
                    }
                    return Column(
                      children: [
                        ExpansionTile(
                          leading: Icon(
                            destino == 'cocina'
                                ? Icons.restaurant_menu
                                : Icons.local_bar,
                            color: destinoColor,
                            size: 32,
                          ),
                          title: Row(
                            children: [
                              Text(
                                'Comanda #${comanda['id'].toString().substring(0, 10)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: destinoColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: destinoColor),
                                ),
                                child: Text(
                                  destino.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: destinoColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Mesa $mesa • ${comanda['mesero'] ?? 'N/A'}\n${fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(fecha) : 'N/A'}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Icon(estadoIcon, color: estadoColor, size: 20),
                              Text(
                                estado.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: estadoColor,
                                ),
                              ),
                              Text(
                                '$totalProductos items',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Container(
                              color: Colors.grey.shade50,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Productos:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...productos.map((producto) {
                                    final prod =
                                        producto as Map<String, dynamic>;
                                    final cantidad =
                                        (prod['cantidad'] as num?)?.toInt() ??
                                        1;
                                    final precio =
                                        (prod['precio'] as num?)?.toDouble() ??
                                        0.0;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: destinoColor.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '$cantidad',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: destinoColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  prod['nombre'] ?? '',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (prod['nota'] != null &&
                                                    (prod['nota'] as String)
                                                        .isNotEmpty)
                                                  Text(
                                                    'Nota: ${prod['nota']}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            currencyFormat.format(precio),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (index < displayComandas.length - 1)
                          const Divider(height: 1),
                      ],
                    );
                  },
                ),
                if (comandas.length > displayComandas.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Center(
                      child: Text(
                        '...Mostrando las primeras ${displayComandas.length} de ${comandas.length} comandas.',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        shadowColor: color.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.2), width: 1),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.08), color.withOpacity(0.03)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralSummary(ReportData data) {
    final totalVentasBruto = data['totalVentasBruto'] ?? 0.0;
    final totalIngresosMovimientos = data['totalIngresosMovimientos'] ?? 0.0;
    final totalEgresosMovimientos = data['totalEgresosMovimientos'] ?? 0.0;
    final totalDiferenciaCajas = data['totalDiferenciaCajas'] ?? 0.0;
    final totalEfectivoContado = data['totalEfectivoContado'] ?? 0.0;
    final gananciaBrutaEstimada =
        totalVentasBruto + totalIngresosMovimientos - totalEgresosMovimientos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumen de Indicadores',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Divider(),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummaryCard(
                'Ventas Brutas',
                currencyFormat.format(totalVentasBruto),
                const Color(0xFF10B981),
              ),
              _buildSummaryCard(
                'Ganancia Estimada',
                currencyFormat.format(gananciaBrutaEstimada),
                const Color(0xFF3B82F6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummaryCard(
                'Egresos Totales',
                currencyFormat.format(totalEgresosMovimientos),
                const Color(0xFFEF4444),
              ),
              _buildSummaryCard(
                'Total Efectivo Contado',
                currencyFormat.format(totalEfectivoContado),
                const Color(0xFF8B5CF6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummaryCard(
                'Total Diferencia Cajas',
                currencyFormat.format(totalDiferenciaCajas),
                totalDiferenciaCajas == 0
                    ? const Color(0xFF6B7280)
                    : const Color(0xFFF59E0B),
              ),
              _buildSummaryCard(
                'Tickets Generados',
                '${data['numTickets']}',
                const Color(0xFF14B8A6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummaryCard(
                'Total Descuentos',
                currencyFormat.format(data['totalDescuentos'] ?? 0.0),
                const Color(0xFF9333EA), // Purple
              ),
              _buildSummaryCard(
                'Ventas Netas',
                currencyFormat.format(
                  (data['totalVentasBruto'] ?? 0.0) -
                      (data['totalDescuentos'] ?? 0.0),
                ),
                const Color(0xFF059669), // Green
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescuentosSummary(ReportData data) {
    final descuentosPorCategoria =
        data['descuentosPorCategoria'] as Map<String, double>? ?? {};
    final conteoDescuentos =
        data['conteoDescuentosPorCategoria'] as Map<String, int>? ?? {};
    final totalDescuentos = data['totalDescuentos'] ?? 0.0;
    final numDescuentos = data['numDescuentos'] ?? 0;

    // Mapeo de nombres de categorías
    const categoriasNombres = {
      'cortesia': '🎁 Cortesía',
      'promocion': '🎉 Promoción',
      'error_servicio': '😔 Error Servicio',
      'error_cocina': '🍳 Error Cocina',
      'cliente_frecuente': '⭐ Cliente Frecuente',
      'otro': '📝 Otro',
    };

    // Colores por categoría
    const categoriasColores = {
      'cortesia': Color(0xFF8B5CF6),
      'promocion': Color(0xFF10B981),
      'error_servicio': Color(0xFFEF4444),
      'error_cocina': Color(0xFFF59E0B),
      'cliente_frecuente': Color(0xFF3B82F6),
      'otro': Color(0xFF6B7280),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Resumen de Descuentos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.purple.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.discount, size: 18, color: Colors.purple.shade700),
                  const SizedBox(width: 6),
                  Text(
                    '$numDescuentos descuentos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(),

        // Total de descuentos (destacado)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade50, Colors.purple.shade100],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade300, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.monetization_on,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'TOTAL EN DESCUENTOS',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                currencyFormat.format(totalDescuentos),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
              ),
            ],
          ),
        ),

        // Descuentos por categoría
        if (descuentosPorCategoria.isNotEmpty) ...[
          const Text(
            'Por Categoría',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          ...descuentosPorCategoria.entries.map((entry) {
            final categoria = entry.key;
            final monto = entry.value;
            final conteo = conteoDescuentos[categoria] ?? 0;
            final nombreCategoria = categoriasNombres[categoria] ?? categoria;
            final color = categoriasColores[categoria] ?? Colors.grey;
            final porcentaje = totalDescuentos > 0
                ? (monto / totalDescuentos * 100)
                : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: color.withOpacity(0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '$conteo',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombreCategoria,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${porcentaje.toStringAsFixed(1)}% del total',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            currencyFormat.format(monto),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Barra de progreso
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: porcentaje / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ] else ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(
                    Icons.discount_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No hay descuentos en este período',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 🔹 PASO 5: Agregar lista detallada de descuentos
  // Agrega este NUEVO MÉTODO después de _buildDescuentosSummary():

  Widget _buildDescuentosDetalle(ReportData data) {
    final descuentos = data['descuentos'] as List<Map<String, dynamic>>? ?? [];
    final displayDescuentos = descuentos.take(30).toList();

    const categoriasNombres = {
      'cortesia': '🎁 Cortesía',
      'promocion': '🎉 Promoción',
      'error_servicio': '😔 Error Servicio',
      'error_cocina': '🍳 Error Cocina',
      'cliente_frecuente': '⭐ Cliente Frecuente',
      'otro': '📝 Otro',
    };

    const categoriasColores = {
      'cortesia': Color(0xFF8B5CF6),
      'promocion': Color(0xFF10B981),
      'error_servicio': Color(0xFFEF4444),
      'error_cocina': Color(0xFFF59E0B),
      'cliente_frecuente': Color(0xFF3B82F6),
      'otro': Color(0xFF6B7280),
    };

    return ContentCard(
      title: 'Detalle de Descuentos (${descuentos.length})',
      child: descuentos.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.discount_outlined,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No se aplicaron descuentos en este período',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayDescuentos.length,
                  itemBuilder: (context, index) {
                    final descuento = displayDescuentos[index];
                    final fecha = descuento['fecha'] as DateTime?;
                    final monto =
                        (descuento['monto'] as num?)?.toDouble() ?? 0.0;
                    final categoria =
                        descuento['categoria'] as String? ?? 'otro';
                    final descripcion =
                        descuento['descripcion'] ?? 'Sin descripción';
                    final mesa = descuento['mesa'] ?? 'N/A';
                    final cajero = descuento['cajero'] ?? 'N/A';
                    final tipoDescuento =
                        descuento['tipoDescuento'] ?? 'monto_fijo';
                    final valorDescuento =
                        (descuento['valorDescuento'] as num?)?.toDouble() ??
                        0.0;
                    final totalOriginal = (descuento['totalOriginal'] as num?)
                        ?.toDouble();
                    final totalConDescuento =
                        (descuento['totalConDescuento'] as num?)?.toDouble();

                    final nombreCategoria =
                        categoriasNombres[categoria] ?? categoria;
                    final color = categoriasColores[categoria] ?? Colors.grey;

                    return Column(
                      children: [
                        ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color.withOpacity(0.7), color],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.discount,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nombreCategoria,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Mesa $mesa • $cajero',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  fecha != null
                                      ? DateFormat(
                                          'dd/MM/yyyy HH:mm',
                                        ).format(fecha)
                                      : 'N/A',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '- ${currencyFormat.format(monto)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: color,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tipoDescuento == 'porcentaje'
                                      ? '${valorDescuento.toStringAsFixed(0)}%'
                                      : 'Fijo',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.grey.shade50,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Descripción
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.description,
                                          color: color,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            descripcion,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Desglose financiero
                                  if (totalOriginal != null &&
                                      totalConDescuento != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: color.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          _buildDetalleRow(
                                            'Total Original:',
                                            currencyFormat.format(
                                              totalOriginal,
                                            ),
                                            Colors.black87,
                                          ),
                                          const SizedBox(height: 4),
                                          _buildDetalleRow(
                                            'Descuento:',
                                            '- ${currencyFormat.format(monto)}',
                                            Colors.red,
                                          ),
                                          const Divider(height: 16),
                                          _buildDetalleRow(
                                            'Total Final:',
                                            currencyFormat.format(
                                              totalConDescuento,
                                            ),
                                            Colors.green.shade700,
                                            isBold: true,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (index < displayDescuentos.length - 1)
                          Divider(height: 1, color: Colors.grey.shade300),
                      ],
                    );
                  },
                ),
                if (descuentos.length > displayDescuentos.length)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Mostrando ${displayDescuentos.length} de ${descuentos.length} descuentos',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildDetalleRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTicketsList(ReportData data) {
    final tickets = data['tickets'] as List<Map<String, dynamic>>? ?? [];
    tickets.sort((a, b) {
      final fechaA = _parseStringToDateTime(a['fechaCierre']);
      final fechaB = _parseStringToDateTime(b['fechaCierre']);
      if (fechaA == null || fechaB == null) return 0;
      return fechaB.compareTo(fechaA);
    });
    final displayTickets = tickets.take(50).toList();
    return ContentCard(
      title: 'Cuentas Cerradas / Tickets (${tickets.length})',
      child: tickets.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No se encontraron tickets en este período.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTicketsQuickStats(tickets),
                const SizedBox(height: 16),
                const Divider(),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayTickets.length,
                  itemBuilder: (context, index) {
                    final ticket = displayTickets[index];
                    return _buildTicketItem(
                      ticket,
                      index,
                      displayTickets.length,
                    );
                  },
                ),
                if (tickets.length > displayTickets.length)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            'Mostrando ${displayTickets.length} de ${tickets.length} tickets',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Función de exportación próximamente',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.download),
                            label: const Text('Exportar todos los tickets'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildTicketsQuickStats(List<Map<String, dynamic>> tickets) {
    double totalVentas = 0;
    int totalProductos = 0;
    double promedioTicket = 0;
    int totalComensales = 0;
    for (var ticket in tickets) {
      totalVentas += (ticket['totalCuenta'] as num?)?.toDouble() ?? 0.0;
      totalProductos += (ticket['totalItems'] as num?)?.toInt() ?? 0;
      totalComensales += (ticket['comensales'] as num?)?.toInt() ?? 0;
    }
    if (tickets.isNotEmpty) {
      promedioTicket = totalVentas / tickets.length;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildQuickStatItem(
                  'Total Ventas',
                  currencyFormat.format(totalVentas),
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildQuickStatItem(
                  'Promedio/Ticket',
                  currencyFormat.format(promedioTicket),
                  Icons.analytics,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildQuickStatItem(
                  'Total Productos',
                  '$totalProductos',
                  Icons.shopping_cart,
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildQuickStatItem(
                  'Total Comensales',
                  '$totalComensales',
                  Icons.people,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTicketItem(
    Map<String, dynamic> ticket,
    int index,
    int totalDisplay,
  ) {
    final fecha = ticket['fechaCierre'] as DateTime?;
    final totalCuenta = (ticket['totalCuenta'] as num?)?.toDouble() ?? 0.0;
    final totalItems = (ticket['totalItems'] as num?)?.toInt() ?? 0;
    final comensales = (ticket['comensales'] as num?)?.toInt() ?? 0;
    final numeroMesa = (ticket['numeroMesa'] as num?)?.toInt() ?? 0;
    final mesero = ticket['mesero'] ?? 'N/A';
    final fechaApertura =
        _parseStringToDateTime(ticket['fechaApertura']) ?? fecha;
    String duracion = '';
    if (fechaApertura != null && fecha != null) {
      final diferencia = fecha.difference(fechaApertura);
      final horas = diferencia.inHours;
      final minutos = diferencia.inMinutes % 60;
      duracion = horas > 0 ? '${horas}h ${minutos}m' : '${minutos}m';
    }
    final cuentaCerrada = CuentaCerrada(
      id: ticket['id'],
      numeroMesa: numeroMesa,
      mesero: mesero,
      comensales: comensales,
      fechaApertura: fechaApertura ?? DateTime.now(),
      fechaCierre: fecha ?? DateTime.now(),
      productos: List<Map<String, dynamic>>.from(ticket['productos'] ?? []),
      totalItems: totalItems,
      totalCuenta: totalCuenta,
    );
    return Column(
      children: [
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$numeroMesa',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Mesa',
                  style: TextStyle(color: Colors.white, fontSize: 8),
                ),
              ],
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ticket #${ticket['id'].toString().substring(0, 8)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          mesero,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.group,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$comensales',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  fecha != null
                      ? DateFormat('dd/MM/yyyy HH:mm').format(fecha)
                      : 'N/A',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (duracion.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      duracion,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing: SizedBox(
            width: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(totalCuenta),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green.shade700,
                      ),
                    ),
                    Text(
                      '$totalItems items',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          children: [_buildTicketDetails(cuentaCerrada)],
        ),
        if (index < totalDisplay - 1)
          Divider(height: 1, color: Colors.grey.shade300),
      ],
    );
  }

  Widget _buildTicketDetails(CuentaCerrada ticket) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID: ${ticket.id.substring(0, 12)}...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Apertura: ${DateFormat('dd/MM HH:mm').format(ticket.fechaApertura)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Cierre: ${DateFormat('dd/MM HH:mm').format(ticket.fechaCierre)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _verTicketCompleto(ticket),
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('Ver PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Productos:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Divider(),
          ...ticket.productos.map((producto) {
            final cantidad = (producto['cantidad'] as num?)?.toInt() ?? 1;
            final nombre = producto['nombre'] ?? '';
            final precio = (producto['precio'] as num?)?.toDouble() ?? 0.0;
            final nota = producto['nota'] ?? '';
            final total = precio * cantidad;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '$cantidad',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombre,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${currencyFormat.format(precio)} c/u',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        currencyFormat.format(total),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  if (nota.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 42, top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.note,
                              size: 14,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              nota,
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          const Divider(thickness: 2),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Items:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${ticket.totalItems}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      currencyFormat.format(ticket.totalCuenta),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                // Botones de acción para reimprimir
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _verTicketCompleto(ticket),
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
                  icon: Icon(Icons.print),
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

  Widget _buildCajasCerradas(ReportData data) {
    final cierres = data['cierres'] as List<Map<String, dynamic>>? ?? [];
    return ContentCard(
      title: 'Detalle de Cierres de Caja (${cierres.length})',
      child: cierres.isEmpty
          ? const Center(child: Text('No hay cierres de caja en este período.'))
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cierres.length,
              itemBuilder: (context, index) {
                final cierre = cierres[index];
                final diferencia =
                    (cierre['diferencia'] as num?)?.toDouble() ?? 0.0;

                // ✅ CORRECCIÓN: Usar _parseStringToDateTime para manejar cualquier tipo
                final fechaCierre = _parseStringToDateTime(
                  cierre['fechaCierre'],
                );

                final fondoInicial =
                    (cierre['fondo_inicial'] as num?)?.toDouble() ?? 0.0;
                final efectivoContado =
                    (cierre['efectivoContado'] as num?)?.toDouble() ?? 0.0;
                final color = diferencia == 0
                    ? Colors.green
                    : diferencia > 0
                    ? Colors.orange
                    : Colors.red;
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.lock_clock, color: color),
                      title: Text(
                        'Cierre por ${cierre['cerradoPor'] ?? 'N/A'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Fondo: ${currencyFormat.format(fondoInicial)} - Efectivo Contado: ${currencyFormat.format(efectivoContado)}',
                      ),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Diferencia',
                            style: TextStyle(fontSize: 12, color: color),
                          ),
                          Text(
                            currencyFormat.format(diferencia),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: color,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 0),
                            child: Text(
                              fechaCierre != null
                                  ? DateFormat(
                                      'dd/MM HH:mm',
                                    ).format(fechaCierre)
                                  : '',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (index < cierres.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                );
              },
            ),
    );
  }
}
