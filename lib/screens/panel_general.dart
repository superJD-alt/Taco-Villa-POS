import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PanelGeneral extends StatefulWidget {
  const PanelGeneral({Key? key}) : super(key: key);

  @override
  State<PanelGeneral> createState() => _PanelGeneralState();
}

class _PanelGeneralState extends State<PanelGeneral> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarjetas principales de métricas
            _buildMetricasHoy(),
            const SizedBox(height: 24),
            // Secciones inferiores
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildVentasRecientes(),
                      const SizedBox(height: 24),
                      _tarjetaInventarioBajo(),
                      _buildCuentasAbiertas(),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(flex: 1, child: _buildEstadoCaja()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Tarjetas principales de métricas
  Widget _buildMetricasHoy() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('movimientos_caja')
          .where('tipo', isEqualTo: 'ingreso')
          .where(
            'fecha',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_getStartOfDay()),
            isLessThan: Timestamp.fromDate(_getEndOfDay()),
          )
          .snapshots(),
      builder: (context, ventasSnapshot) {
        double ventasHoy = 0;
        int ticketsGenerados = 0;

        if (ventasSnapshot.hasData) {
          for (var doc in ventasSnapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final categoria = data['categoria'] as String?;

            if (categoria != null && categoria.startsWith('venta_')) {
              ventasHoy += (data['monto'] as num?)?.toDouble() ?? 0.0;
              ticketsGenerados++;
            }
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('usuarios')
              .where('sesionActiva', isEqualTo: true)
              .where(
                'rol',
                whereIn: ['Mesero', 'Cajero'],
              ) // ⭐ CAMBIÉ DE minúsculas a mayúsculas
              .snapshots(),
          builder: (context, personalSnapshot) {
            int personalActivo = personalSnapshot.data?.docs.length ?? 0;

            return StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('platillos').snapshots(),
              builder: (context, productosSnapshot) {
                int totalProductos = productosSnapshot.data?.docs.length ?? 0;

                return Row(
                  children: [
                    _buildMetricCard(
                      'Ventas Hoy',
                      '\$${NumberFormat('#,##0.00').format(ventasHoy)}',
                      Icons.attach_money,
                      const Color(0xFF10B981),
                      ventasSnapshot.hasData,
                    ),
                    const SizedBox(width: 16),
                    _buildMetricCard(
                      'Personal Activo',
                      '$personalActivo',
                      Icons.people,
                      const Color(0xFF3B82F6),
                      personalSnapshot.hasData,
                    ),
                    const SizedBox(width: 16),
                    _buildMetricCard(
                      'Productos Vendidos',
                      '$totalProductos',
                      Icons.shopping_bag,
                      const Color(0xFFF59E0B),
                      productosSnapshot.hasData,
                    ),
                    const SizedBox(width: 16),
                    _buildMetricCard(
                      'Tickets Generados',
                      '$ticketsGenerados',
                      Icons.receipt_long,
                      const Color(0xFF8B5CF6),
                      ventasSnapshot.hasData,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _tarjetaInventarioBajo() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inventario')
          .where('stock', isLessThanOrEqualTo: 5)
          .orderBy(
            'stock',
            descending: false,
          ) // Ordenar por menor stock primero
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final productosBajos = snapshot.data!.docs;

        if (productosBajos.isEmpty) {
          return const SizedBox(); // No mostrar nada si todo está bien
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con alerta
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Inventario Bajo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${productosBajos.length} producto(s) requieren atención',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Lista de productos con bajo stock
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: productosBajos.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final producto =
                      productosBajos[index].data() as Map<String, dynamic>;
                  final nombre = producto['nombre'] ?? 'Producto sin nombre';
                  final stock = (producto['stock'] as num?)?.toInt() ?? 0;
                  final unidad = producto['unidad'] ?? 'unidades';
                  final categoria = producto['categoria'] ?? 'Sin categoría';

                  // Color según nivel de stock
                  Color stockColor;
                  Color stockBgColor;
                  IconData stockIcon;

                  if (stock == 0) {
                    stockColor = Colors.red;
                    stockBgColor = Colors.red.shade50;
                    stockIcon = Icons.error;
                  } else if (stock <= 2) {
                    stockColor = Colors.orange.shade700;
                    stockBgColor = Colors.orange.shade50;
                    stockIcon = Icons.warning;
                  } else {
                    stockColor = Colors.yellow.shade700;
                    stockBgColor = Colors.yellow.shade50;
                    stockIcon = Icons.info;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // Icono de alerta
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: stockBgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(stockIcon, color: stockColor, size: 20),
                        ),

                        const SizedBox(width: 12),

                        // Información del producto
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombre,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                categoria,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Stock disponible
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: stockBgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: stockColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$stock',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: stockColor,
                                ),
                              ),
                              Text(
                                unidad,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: stockColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Botón para ver el inventario completo (opcional)
              if (productosBajos.length > 5)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () {
                        // Navegar a la pantalla de inventario
                      },
                      icon: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: const Text('Ver inventario completo'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isLoaded,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            isLoaded
                ? Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  )
                : const SizedBox(
                    height: 28,
                    width: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
          ],
        ),
      ),
    );
  }

  // Ventas Recientes basado en movimientos_caja
  Widget _buildVentasRecientes() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ventas Recientes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('movimientos_caja')
                .where('tipo', isEqualTo: 'ingreso')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              // Filtrar solo ventas y ordenar
              final docs = snapshot.data!.docs.where((doc) {
                final categoria =
                    (doc.data() as Map<String, dynamic>)['categoria']
                        as String?;
                return categoria != null && categoria.startsWith('venta_');
              }).toList();

              docs.sort((a, b) {
                final fechaA =
                    (a.data() as Map<String, dynamic>)['fecha'] as Timestamp?;
                final fechaB =
                    (b.data() as Map<String, dynamic>)['fecha'] as Timestamp?;
                if (fechaA == null && fechaB == null) return 0;
                if (fechaA == null) return 1;
                if (fechaB == null) return -1;
                return fechaB.compareTo(fechaA);
              });

              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      'No hay ventas registradas',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                );
              }

              final ventasRecientes = docs.take(5).toList();

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ventasRecientes.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data =
                      ventasRecientes[index].data() as Map<String, dynamic>;
                  final categoria = data['categoria'] ?? '';
                  final monto = (data['monto'] as num?)?.toDouble() ?? 0.0;
                  final descripcion = data['descripcion'] ?? '';
                  final timestamp = data['fecha'] as Timestamp?;
                  final fecha = timestamp?.toDate() ?? DateTime.now();
                  final cajero = data['cajero'] ?? 'Desconocido';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.receipt,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    title: Text(
                      _formatearCategoria(categoria),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (descripcion.isNotEmpty)
                          Text(
                            descripcion,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          'Cajero: $cajero • ${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      '\$${NumberFormat('#,##0.00').format(monto)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatearCategoria(String categoria) {
    switch (categoria) {
      case 'venta_efectivo':
        return 'Venta en Efectivo';
      case 'venta_tarjeta':
        return 'Venta con Tarjeta';
      case 'venta_transferencia':
        return 'Venta por Transferencia';
      default:
        return categoria.replaceAll('_', ' ').toUpperCase();
    }
  }

  Widget _buildEstadoCaja() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Estado de Caja',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          const Divider(height: 1),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('cajas')
                .where('estado', isEqualTo: 'abierta')
                .limit(1)
                .snapshots(),
            builder: (context, snapshot) {
              // Mientras carga
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              // Si hay error
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }

              // Si no hay caja abierta
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFFF59E0B)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No hay caja abierta',
                                style: TextStyle(color: Color(0xFFF59E0B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Aquí puedes navegar a la pantalla de abrir caja
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Abrir Caja'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Obtener los datos de la caja
              final cajaDoc = snapshot.data!.docs.first;
              final caja = cajaDoc.data() as Map<String, dynamic>;

              // 🔍 DEBUG: Imprimir todos los campos de la caja
              print('=== DATOS DE CAJA ===');
              print('Campos disponibles: ${caja.keys.toList()}');
              print('Datos completos: $caja');
              print('====================');

              // ✅ Extraer información con los nombres correctos del archivo caja.dart
              final nombreCajero = caja['cajero'] ?? 'Usuario desconocido';

              final fondoInicial =
                  (caja['fondo_inicial'] as num?)?.toDouble() ?? 0.0;
              final totalEfectivo =
                  (caja['total_efectivo'] as num?)?.toDouble() ?? 0.0;
              final totalTarjeta =
                  (caja['total_tarjeta'] as num?)?.toDouble() ?? 0.0;
              final totalTransferencia =
                  (caja['total_transferencia'] as num?)?.toDouble() ?? 0.0;
              final totalPropinas =
                  (caja['total_propinas'] as num?)?.toDouble() ?? 0.0;
              final totalEgresos =
                  (caja['total_egresos'] as num?)?.toDouble() ?? 0.0;

              // Calcular monto actual en caja
              final montoActual =
                  fondoInicial +
                  totalEfectivo +
                  totalTarjeta +
                  totalTransferencia +
                  totalPropinas -
                  totalEgresos;

              // Obtener fecha de apertura
              final timestamp = caja['fecha_apertura'] as Timestamp?;
              final fechaApertura = timestamp?.toDate() ?? DateTime.now();

              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Estado: Caja Abierta
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF10B981)),
                          SizedBox(width: 12),
                          Text(
                            'Caja Abierta',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Usuario que abrió la caja
                    _buildCajaDetailRow('Cajero', nombreCajero),
                    const SizedBox(height: 12),

                    // Hora de apertura
                    _buildCajaDetailRow(
                      'Hora de Apertura',
                      DateFormat('HH:mm a').format(fechaApertura),
                    ),
                    const SizedBox(height: 12),

                    // Fecha de apertura
                    _buildCajaDetailRow(
                      'Fecha',
                      DateFormat('dd/MM/yyyy').format(fechaApertura),
                    ),

                    const SizedBox(height: 12),

                    // Fondo inicial
                    _buildCajaDetailRow(
                      'Fondo Inicial',
                      '${NumberFormat('#,##0.00').format(fondoInicial)}',
                    ),

                    const Divider(height: 32),

                    // Monto actual en caja (total)
                    _buildCajaDetailRow(
                      'Total en Caja',
                      '${NumberFormat('#,##0.00').format(montoActual)}',
                      isTotal: true,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCajaDetailRow(
    String label,
    String value, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            color: const Color(0xFF64748B),
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: isTotal ? const Color(0xFF10B981) : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  // Cuentas Abiertas (Mesas)
  Widget _buildCuentasAbiertas() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cuentas Abiertas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Ver todas'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('cuentas')
                .where('estado', isEqualTo: 'abierta')
                .orderBy('fechaApertura', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              // 💡 CORRECCIÓN: Usar connectionState.waiting para el loader
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              // 💡 CORRECCIÓN: Manejar errores explícitamente si existen
              if (snapshot.hasError) {
                // Idealmente, aquí imprimirías snapshot.error para ver el problema de Firebase
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Error al cargar cuentas. Revisa la consola.'),
                  ),
                );
              }

              if (snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      'No hay cuentas abiertas',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final cuenta =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              cuenta['mesa']?.toString() ?? 'N/A',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Folio: ${cuenta['folio'] ?? 'N/A'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${cuenta['comensales'] ?? 0} comensales',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.restaurant_menu,
                                    size: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${cuenta['items'] ?? 0} items',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Mesero: ${cuenta['nombreMesero'] ?? 'N/A'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Abierta',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // Funciones auxiliares para fechas
  DateTime _getStartOfDay() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 0, 0, 0);
  }

  DateTime _getEndOfDay() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }
}
