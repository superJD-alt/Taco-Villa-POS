import 'package:flutter/material.dart';
import 'panel_general.dart';
import 'caja.dart';
import 'inventario.dart';
import 'reportes.dart';
import 'usuarios.dart';
import 'productos.dart';
import 'sidebar_menu.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PanelAdmin extends StatefulWidget {
  const PanelAdmin({super.key});

  @override
  State<PanelAdmin> createState() => _PanelAdminState();
}

class _PanelAdminState extends State<PanelAdmin> {
  int _selectedIndex = 0;
  String _rolUsuario = 'cargando';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _nombreUsuarioLogeado = 'Cargando...';
  String _correoUsuarioLogeado = 'cargando@pv.com';
  bool _isLoading = true;

  final List<String> _titles = [
    'Panel General',
    'Caja',
    'Inventario',
    'Reportes',
    'Usuarios',
    'Productos',
  ];

  final List<Widget> _screens = [
    const PanelGeneral(),
    const Caja(),
    const Inventario(),
    const Reportes(),
    const Usuarios(),
    const Productos(),
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  void _cargarDatosUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // ✅ BUSCAR por campo 'uid'
        QuerySnapshot query = await _firestore
            .collection('usuarios')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();

        String nombreDB = '';
        String rolDB = 'unknown';

        if (query.docs.isNotEmpty) {
          final userDoc = query.docs.first;
          final data = userDoc.data() as Map<String, dynamic>;
          nombreDB = data['nombre'] ?? user.email ?? 'Usuario';
          rolDB = data['rol'] ?? 'unknown';

          debugPrint('✅ Datos cargados: $nombreDB - Rol: $rolDB');
        } else {
          debugPrint('⚠️ No se encontró usuario en Firestore');
          nombreDB = user.displayName ?? user.email ?? 'Usuario';
        }

        setState(() {
          _nombreUsuarioLogeado = nombreDB;
          _correoUsuarioLogeado = user.email ?? 'sin_correo@pv.com';
          _rolUsuario = rolDB;
          _isLoading = false;
        });
      } catch (e) {
        debugPrint("❌ Error al cargar datos de Firestore: $e");
        setState(() {
          _nombreUsuarioLogeado =
              user.displayName ?? user.email ?? 'Error Nombre';
          _correoUsuarioLogeado = user.email ?? 'error@pos.com';
          _isLoading = false;
        });
      }
    } else {
      _cerrarSesionSinConfirmacion();
    }
  }

  void _onMenuItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _cerrarSesionSinConfirmacion() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPos()),
        );
      }
    } catch (e) {
      print('Error al cerrar sesión (sin confirmación): $e');
    }
  }

  Future<void> _cerrarSesion() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        debugPrint('🔄 Cerrando sesión para: ${user.email}');

        // ✅ BUSCAR el documento por campo 'uid' en lugar de por ID
        try {
          QuerySnapshot query = await _firestore
              .collection('usuarios')
              .where('uid', isEqualTo: user.uid)
              .limit(1)
              .get();

          if (query.docs.isNotEmpty) {
            // Actualizar el documento encontrado
            await query.docs.first.reference.update({
              'sesionActiva': false,
              'fechaCierreSesion': FieldValue.serverTimestamp(),
            });
            debugPrint('✅ Sesión marcada como inactiva en Firestore');
          } else {
            debugPrint(
              '⚠️ No se encontró documento en Firestore para este usuario',
            );
          }
        } catch (firestoreError) {
          debugPrint('⚠️ Error actualizando Firestore: $firestoreError');
          // Continuar con el logout aunque falle Firestore
        }
      }

      // Cerrar sesión en Authentication (SIEMPRE se ejecuta)
      await FirebaseAuth.instance.signOut();
      debugPrint('✅ Sesión cerrada en Firebase Authentication');

      if (!mounted) return;

      // Navegar al login y limpiar todo el stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPos()),
        (route) => false, // Elimina todas las rutas anteriores
      );
    } catch (e) {
      debugPrint('❌ Error al cerrar sesión: $e');

      // Aunque haya error, intentar cerrar sesión en Auth
      try {
        await FirebaseAuth.instance.signOut();
      } catch (authError) {
        debugPrint('❌ Error cerrando Authentication: $authError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );

        // Aún así, navegar al login
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPos()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String displayNombre = _isLoading
        ? 'Cargando...'
        : _nombreUsuarioLogeado;
    final String displayCorreo = _isLoading ? '...' : _correoUsuarioLogeado;

    return Scaffold(
      body: Row(
        children: [
          SidebarMenu(
            selectedIndex: _selectedIndex,
            onMenuItemSelected: _onMenuItemSelected,
            nombreUsuario: displayNombre,
            correoUsuario: displayCorreo,
            onLogout: _cerrarSesion,
          ),
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _screens[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
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
                .where('estado', isEqualTo: 'cerrada')
                .orderBy('fechaCierre', descending: true)
                .limit(1)
                .snapshots(),
            builder: (context, snapshot) {
              print(
                '🔍 DEBUG Última Caja Cerrada - ConnectionState: ${snapshot.connectionState}',
              );

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                print('❌ ERROR Caja: ${snapshot.error}');
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Error al cargar caja: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                print('⚠️ No hay cajas cerradas en la base de datos');
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
                                'No hay historial de cajas',
                                style: TextStyle(color: Color(0xFFF59E0B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aún no se han registrado cierres de caja',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              print('✅ Última caja cerrada encontrada');

              final caja =
                  snapshot.data!.docs.first.data() as Map<String, dynamic>;
              final cajaId = snapshot.data!.docs.first.id;

              print('📋 Caja ID: $cajaId');

              final fechaCierreTimestamp = caja['fechaCierre'] as Timestamp?;
              final fechaCierre =
                  fechaCierreTimestamp?.toDate() ?? DateTime.now();
              final fechaAperturaTimestamp =
                  caja['fechaApertura'] as Timestamp?;
              final fechaApertura =
                  fechaAperturaTimestamp?.toDate() ?? fechaCierre;

              final montoInicial =
                  (caja['fondo_inicial'] as num?)?.toDouble() ??
                  (caja['montoInicial'] as num?)?.toDouble() ??
                  (caja['monto_inicial'] as num?)?.toDouble() ??
                  0.0;

              final efectivoContado =
                  (caja['efectivoContado'] as num?)?.toDouble() ?? 0.0;
              final diferencia =
                  (caja['diferencia'] as num?)?.toDouble() ?? 0.0;

              // Buscar el nombre del cajero
              String nombreCajero = 'N/A';
              if (caja.containsKey('cerradoPor') &&
                  caja['cerradoPor'] != null) {
                nombreCajero = caja['cerradoPor'].toString();
              } else if (caja.containsKey('nombreCajero') &&
                  caja['nombreCajero'] != null) {
                nombreCajero = caja['nombreCajero'].toString();
              } else if (caja.containsKey('abiertoPor') &&
                  caja['abiertoPor'] != null) {
                nombreCajero = caja['abiertoPor'].toString();
              } else if (caja.containsKey('cajero') && caja['cajero'] != null) {
                nombreCajero = caja['cajero'].toString();
              }

              print('📊 Datos de última caja:');
              print('   - Cajero: $nombreCajero');
              print('   - Fecha Apertura: $fechaApertura');
              print('   - Fecha Cierre: $fechaCierre');
              print('   - Monto Inicial: $montoInicial');
              print('   - Efectivo Contado: $efectivoContado');
              print('   - Diferencia: $diferencia');

              // Calcular duración de la sesión (de apertura a cierre)
              final duracion = fechaCierre.difference(fechaApertura);
              final horas = duracion.inHours;
              final minutos = duracion.inMinutes.remainder(60);
              final duracionSesion = '${horas}h ${minutos}m';

              // Calcular ventas durante esa sesión
              return StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('movimientos_caja')
                    .where('tipo', isEqualTo: 'ingreso')
                    .snapshots(),
                builder: (context, ventasSnapshot) {
                  print(
                    '🔍 DEBUG Movimientos - ConnectionState: ${ventasSnapshot.connectionState}',
                  );

                  if (ventasSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  double totalVentas = 0;
                  int numeroTransacciones = 0;
                  double ventasEfectivo = 0;
                  double ventasTarjeta = 0;
                  double ventasTransferencia = 0;

                  if (ventasSnapshot.hasData) {
                    print(
                      '📊 Total movimientos: ${ventasSnapshot.data!.docs.length}',
                    );

                    for (var doc in ventasSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final fechaMovimiento = (data['fecha'] as Timestamp?)
                          ?.toDate();

                      // Filtrar movimientos entre apertura y cierre
                      if (fechaMovimiento != null &&
                          fechaMovimiento.isAfter(
                            fechaApertura.subtract(const Duration(seconds: 1)),
                          ) &&
                          fechaMovimiento.isBefore(
                            fechaCierre.add(const Duration(seconds: 1)),
                          )) {
                        final categoria = data['categoria'] as String?;
                        final monto =
                            (data['monto'] as num?)?.toDouble() ?? 0.0;

                        if (categoria != null &&
                            categoria.startsWith('venta_')) {
                          totalVentas += monto;
                          numeroTransacciones++;

                          if (categoria == 'venta_efectivo') {
                            ventasEfectivo += monto;
                          } else if (categoria == 'venta_tarjeta') {
                            ventasTarjeta += monto;
                          } else if (categoria == 'venta_transferencia') {
                            ventasTransferencia += monto;
                          }
                        }
                      }
                    }

                    print('💰 Ventas calculadas: $totalVentas');
                  }

                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Estado: Última Caja Cerrada
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E7FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.history, color: Color(0xFF6366F1)),
                                  SizedBox(width: 12),
                                  Text(
                                    'Última Caja Cerrada',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF6366F1),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.schedule,
                                      size: 14,
                                      color: Color(0xFF6366F1),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      duracionSesion,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF6366F1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildCajaInfoCard(
                          icon: Icons.person,
                          titulo: 'Cajero',
                          valor: nombreCajero,
                          color: const Color(0xFF3B82F6),
                        ),
                        const SizedBox(height: 12),
                        _buildCajaInfoCard(
                          icon: Icons.login,
                          titulo: 'Apertura',
                          valor: DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(fechaApertura),
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 12),
                        _buildCajaInfoCard(
                          icon: Icons.logout,
                          titulo: 'Cierre',
                          valor: DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(fechaCierre),
                          color: const Color(0xFFEF4444),
                        ),
                        const SizedBox(height: 12),
                        _buildCajaInfoCard(
                          icon: Icons.account_balance_wallet,
                          titulo: 'Monto Inicial',
                          valor:
                              "${NumberFormat('#,##0.00').format(montoInicial)}",
                          color: const Color(0xFF8B5CF6),
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 20),
                        const Text(
                          'Ventas por Método',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildMetodoPagoRow(
                          'Efectivo',
                          ventasEfectivo,
                          Icons.money,
                          const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 8),
                        _buildMetodoPagoRow(
                          'Tarjeta',
                          ventasTarjeta,
                          Icons.credit_card,
                          const Color(0xFF3B82F6),
                        ),
                        const SizedBox(height: 8),
                        _buildMetodoPagoRow(
                          'Transferencia',
                          ventasTransferencia,
                          Icons.swap_horiz,
                          const Color(0xFF8B5CF6),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Transacciones',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                '$numeroTransacciones',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Ventas',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                              Text(
                                '${NumberFormat('#,##0.00').format(totalVentas)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Efectivo Contado',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                              Text(
                                '${NumberFormat('#,##0.00').format(efectivoContado)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: diferencia == 0
                                  ? [
                                      const Color(0xFF10B981),
                                      const Color(0xFF059669),
                                    ]
                                  : diferencia > 0
                                  ? [
                                      const Color(0xFFF59E0B),
                                      const Color(0xFFD97706),
                                    ]
                                  : [
                                      const Color(0xFFEF4444),
                                      const Color(0xFFDC2626),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (diferencia == 0
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444))
                                        .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'DIFERENCIA',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${diferencia >= 0 ? '+' : ''}${NumberFormat('#,##0.00').format(diferencia)}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (diferencia != 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  diferencia > 0 ? 'Sobrante' : 'Faltante',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ],
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

  Widget _buildCajaInfoCard({
    required IconData icon,
    required String titulo,
    required String valor,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetodoPagoRow(
    String metodo,
    double monto,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            metodo,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ),
        Text(
          '\$${NumberFormat('#,##0.00').format(monto)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _titles[_selectedIndex],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
