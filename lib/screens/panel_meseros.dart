import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login.dart';
import 'pedidos_activos.dart';
import 'view_table.dart';
import 'custom_table.dart';
import 'resumen_turno.dart';
import 'printer_settings.dart';
import '/models/printer_manager.dart';

class PanelMeseros extends StatefulWidget {
  const PanelMeseros({super.key});

  @override
  State<PanelMeseros> createState() => _PanelMeserosState();
}

class _PanelMeserosState extends State<PanelMeseros> {
  String nombreMesero = 'Cargando...';

  final PrinterManager _printerManager = PrinterManager();
  bool _impresorasConfiguradas = false;
  bool _esTabletCentral = false;
  bool get esTabletCentral =>
      _esTabletCentral; // Este es el "getter" para leerla desde fuera
  bool _procesandoImpresion = false;

  // Variable local para que el switch se mueva visualmente
  bool _esCentral = false;

  @override
  void initState() {
    super.initState();
    obtenerNombreMesero();
    _verificarImpresoras();
    _esCentral = _printerManager.esTabletCentral;
  }

  Future<void> _verificarImpresoras() async {
    await _printerManager.cargarConfiguracion();
    if (mounted) {
      setState(() {
        _impresorasConfiguradas = _printerManager.estaConectada();
      });
    }
  }

  Future<void> obtenerNombreMesero() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          nombreMesero = doc['nombre'] ?? 'Mesero';
        });
      } else {
        setState(() {
          nombreMesero = user.displayName ?? 'Mesero';
        });
      }
    } else {
      setState(() {
        nombreMesero = 'Invitado';
      });
    }
  }

  Future<void> _cerrarSesion() async {
    final bool? confirmacion = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que deseas cerrar la sesión?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('CERRAR SESIÓN'),
            ),
          ],
        );
      },
    );

    if (confirmacion == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginPos()),
          );
        }
      } catch (e) {
        print('Error al cerrar sesión: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al cerrar sesión: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Meseros'),
        backgroundColor: Colors.indigoAccent,
        foregroundColor: Colors.white,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.print, size: 28),
                tooltip: _impresorasConfiguradas
                    ? 'Impresoras configuradas'
                    : 'Configurar impresoras',
                onPressed: () async {
                  // Navegar a la configuración
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrinterSettingsPage(),
                    ),
                  );
                  // Verificar estado al regresar
                  _verificarImpresoras();
                },
              ),
              // Indicador de estado (punto verde/rojo)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _impresorasConfiguradas ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),

          // ✅ OPCIONAL: Agregar botón de info
          if (!_impresorasConfiguradas)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Información importante',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        SizedBox(width: 12),
                        Text('Impresoras no configuradas'),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '⚠️ Necesitas configurar ambas impresoras antes de usar el sistema:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 12),
                        Text('• Impresora A: Comandas de Cocina'),
                        Text('• Impresora B: Comandas de Barra + Cuentas'),
                        SizedBox(height: 16),
                        Text(
                          'Toca el ícono de impresora para configurarlas.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('ENTENDIDO'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PrinterSettingsPage(),
                            ),
                          ).then((_) => _verificarImpresoras());
                        },
                        icon: const Icon(Icons.settings),
                        label: const Text('CONFIGURAR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          // ✅ Determinar si es pantalla pequeña, mediana o grande
          bool isSmallScreen = constraints.maxWidth < 600;
          bool isMediumScreen =
              constraints.maxWidth >= 600 && constraints.maxWidth < 1200;
          bool isLargeScreen = constraints.maxWidth >= 1200;

          return Container(
            color: Colors.grey.shade50,
            child: SafeArea(
              child: Column(
                children: [
                  // ✅ Contenido principal con scroll
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16 : 40,
                        vertical: 40,
                      ),
                      child: Column(
                        children: [
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            // Cambia de color si está activo para dar feedback visual claro
                            color: _esCentral
                                ? Colors.blue.shade50
                                : Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: SwitchListTile(
                                title: const Text(
                                  "Modo: Central de Impresión",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  _esCentral
                                      ? "Esta tablet está imprimiendo los pedidos de todos."
                                      : "Activa esto solo en la tablet conectada a la impresora.",
                                  style: const TextStyle(fontSize: 12),
                                ),
                                secondary: Icon(
                                  Icons.print,
                                  color: _esCentral ? Colors.blue : Colors.grey,
                                ),
                                value: _esCentral,
                                onChanged: (bool value) {
                                  setState(() {
                                    _esCentral = value;
                                    // Llamamos al manager para que empiece o deje de escuchar Firebase
                                    _printerManager.setComoTabletCentral(value);
                                  });

                                  // Mensaje de confirmación
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        value
                                            ? "✅ Servidor de impresión activo"
                                            : "ℹ️ Servidor desactivado",
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          const Divider(),
                          // 🔹 Saludo al mesero
                          _buildGreeting(isSmallScreen),

                          // ✅ OPCIONAL: Mensaje de advertencia si no hay impresoras
                          if (!_impresorasConfiguradas) ...[
                            const SizedBox(height: 20),
                            _buildPrinterWarning(isSmallScreen),
                          ],

                          SizedBox(height: isSmallScreen ? 30 : 40),

                          // 🔹 Botones principales (Nuevo pedido, Pedidos activos, Mesas)
                          _buildMainButtons(
                            constraints,
                            isSmallScreen,
                            isMediumScreen,
                          ),

                          SizedBox(height: isSmallScreen ? 40 : 60),

                          // 🔹 Botón Resumen del turno
                          _buildLargeActionButton(
                            context,
                            title: 'Resumen del turno',
                            color: Colors.orange,
                            page: const ResumenTurno(),
                            isSmallScreen: isSmallScreen,
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // ✅ Botones fijos en la parte inferior (responsivos)
                  _buildBottomButtons(
                    constraints,
                    isSmallScreen,
                    isMediumScreen,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ NUEVO MÉTODO: Banner de advertencia de impresoras
  Widget _buildPrinterWarning(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 2),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: isSmallScreen ? 32 : 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ Impresoras no configuradas',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configura las impresoras de Cocina y Barra para enviar comandas',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 13,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrinterSettingsPage(),
                ),
              );
              _verificarImpresoras();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16,
                vertical: isSmallScreen ? 8 : 12,
              ),
            ),
            child: Text(
              'CONFIGURAR',
              style: TextStyle(fontSize: isSmallScreen ? 11 : 13),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Widget para el saludo (responsivo)
  Widget _buildGreeting(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigoAccent.shade400, Colors.indigoAccent.shade700],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigoAccent.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.waving_hand,
            size: isSmallScreen ? 32 : 40,
            color: Colors.white,
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              'Hola, $nombreMesero',
              style: TextStyle(
                fontSize: isSmallScreen ? 20 : 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Botones principales (responsivos según tamaño de pantalla)
  Widget _buildMainButtons(
    BoxConstraints constraints,
    bool isSmallScreen,
    bool isMediumScreen,
  ) {
    // Definir tamaño de iconos según pantalla
    double iconSize = isSmallScreen
        ? 120
        : isMediumScreen
        ? 180
        : 250;

    if (isSmallScreen) {
      // 📱 Pantallas pequeñas: 1 columna
      return Column(
        children: [
          _buildMainMenuButton(
            context,
            title: 'Nuevo pedido',
            icon: Icons.add,
            color: Colors.green,
            page: const CustomTable(),
            iconSize: iconSize,
          ),
          const SizedBox(height: 20),
          _buildMainMenuButton(
            context,
            title: 'Pedidos activos',
            icon: Icons.restaurant,
            color: Colors.blue,
            page: const PedidosActivos(),
            iconSize: iconSize,
          ),
          const SizedBox(height: 20),
          _buildMainMenuButton(
            context,
            title: 'Mesas',
            icon: Icons.table_restaurant,
            color: Colors.yellow,
            page: const ViewTable(),
            iconSize: iconSize,
          ),
        ],
      );
    } else {
      // 💻 Pantallas medianas y grandes: 3 columnas
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildMainMenuButton(
              context,
              title: 'Nuevo pedido',
              icon: Icons.add,
              color: Colors.green,
              page: const CustomTable(),
              iconSize: iconSize,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _buildMainMenuButton(
              context,
              title: 'Pedidos activos',
              icon: Icons.restaurant,
              color: Colors.blue,
              page: const PedidosActivos(),
              iconSize: iconSize,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _buildMainMenuButton(
              context,
              title: 'Mesas',
              icon: Icons.table_restaurant,
              color: Colors.yellow,
              page: const ViewTable(),
              iconSize: iconSize,
            ),
          ),
        ],
      );
    }
  }

  // ✅ Botones inferiores (responsivos)
  Widget _buildBottomButtons(
    BoxConstraints constraints,
    bool isSmallScreen,
    bool isMediumScreen,
  ) {
    if (isSmallScreen) {
      // 📱 Pantallas pequeñas: botones apilados verticalmente
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _cerrarSesion,
                icon: const Icon(Icons.logout, size: 24),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // 💻 Pantallas medianas y grandes: botones horizontales
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMediumScreen ? 24 : 40,
          vertical: 20,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Botón Cerrar sesión
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: ElevatedButton.icon(
                  onPressed: _cerrarSesion,
                  icon: const Icon(Icons.logout, size: 24),
                  label: Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      fontSize: isMediumScreen ? 16 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMediumScreen ? 24 : 40,
                      vertical: isMediumScreen ? 16 : 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  // Widget para los 3 botones grandes superiores (con tamaño de icono ajustable)
  Widget _buildMainMenuButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget page,
    required double iconSize,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1, // Mantener proporción cuadrada
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => page),
              );
            },
            label: const Text(''),
            icon: Icon(icon, size: iconSize),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              side: const BorderSide(color: Colors.black, width: 8.0),
              padding: const EdgeInsets.all(20),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void setComoTabletCentral(bool valor) {
    _esTabletCentral = valor; // Guardamos el cambio
    if (_esTabletCentral) {
      print("📡 TEST: Intentando iniciar escucha en Firebase...");
      _iniciarEscuchaDeImpresion(); // <--- Arranca el motor
    } else {
      print("💤 Modo Central Desactivado.");
      // Aquí podrías agregar lógica para detener la escucha si fuera necesario
    }
  }

  void _iniciarEscuchaDeImpresion() {
    FirebaseFirestore.instance
        .collection('tickets_pendientes')
        .where('impreso', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          // Aquí va la lógica de impresión que ya tienes
          print("🔔 Cambio detectado en Firebase!");
        });
  }
}

// Widget para el botón de resumen del turno
Widget _buildLargeActionButton(
  BuildContext context, {
  required String title,
  required Color color,
  required Widget page,
  required bool isSmallScreen,
}) {
  return SizedBox(
    width: isSmallScreen ? double.infinity : null,
    child: ElevatedButton(
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 40 : 80,
          vertical: isSmallScreen ? 16 : 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 6,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: isSmallScreen ? 18 : 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
