import 'dart:math';
import 'package:flutter/material.dart';
import 'ordenes.dart';
import 'mesa_state.dart';
import 'package:flutter/services.dart';

class CustomTable extends StatefulWidget {
  const CustomTable({super.key});

  @override
  State<CustomTable> createState() => _CustomTableState();
}

class _CustomTableState extends State<CustomTable> {
  final MesaState mesaState = MesaState();

  // ✅ NUEVAS VARIABLES
  List<MesaDinamica> mesasDinamicas = [];
  int siguienteNumeroMesa = 15;
  bool _listenerAdded = false;

  @override
  void initState() {
    super.initState();
    _setOrientation([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _cargarMesasDinamicas();

    // ✅ FIX: Agregar el listener aquí en initState
    mesaState.addListener(_onMesaStateChanged);
    _listenerAdded = true;
  }

  @override
  void dispose() {
    mesaState.removeListener(_onMesaStateChanged);
    super.dispose();
  }

  void _onMesaStateChanged() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        mesasDinamicas = mesaState.obtenerMesasDinamicas();
      });
    });
  }

  Future<void> _setOrientation(List<DeviceOrientation> orientations) async {
    try {
      await SystemChrome.setPreferredOrientations(orientations);
      print('✅ Orientación cambiada exitosamente');
    } catch (e) {
      print('❌ Error al cambiar orientación: $e');
    }
  }

  void _cargarMesasDinamicas() {
    final mesasGuardadas = mesaState.obtenerMesasDinamicas();
    setState(() {
      mesasDinamicas = mesasGuardadas;
      if (mesasDinamicas.isNotEmpty) {
        final maxNumero = mesasDinamicas
            .map((m) => m.numeroMesa)
            .reduce((a, b) => a > b ? a : b);
        siguienteNumeroMesa = max(100, maxNumero + 1);
      }
    });
  }

  void _mostrarDialogoAgregarMesa() {
    int cantidadPersonas = 4;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.add_circle, color: Colors.blue.shade700, size: 28),
                  const SizedBox(width: 10),
                  const Text('Agregar Mesa Temporal'),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Esta mesa aparecerá al final y se puede eliminar cuando no se necesite.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.restaurant,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Mesa #$siguienteNumeroMesa',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Capacidad de la mesa:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 180,
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.5,
                          children: [2, 4, 6, 8, 10, 12].map((personas) {
                            final bool seleccionado =
                                cantidadPersonas == personas;
                            return InkWell(
                              onTap: () {
                                setDialogState(() {
                                  cantidadPersonas = personas;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: seleccionado
                                      ? Colors.blue.shade600
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: seleccionado
                                        ? Colors.blue.shade800
                                        : Colors.grey.shade300,
                                    width: seleccionado ? 3 : 2,
                                  ),
                                  boxShadow: seleccionado
                                      ? [
                                          BoxShadow(
                                            color: Colors.blue.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people,
                                      color: seleccionado
                                          ? Colors.white
                                          : Colors.grey[700],
                                      size: 28,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$personas',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: seleccionado
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _agregarMesaDinamica(cantidadPersonas);
                    Navigator.pop(dialogContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Crear Mesa'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _agregarMesaDinamica(int cantidadPersonas) {
    final nuevaMesa = MesaDinamica(
      numeroMesa: siguienteNumeroMesa,
      cantidadPersonas: cantidadPersonas,
    );

    mesaState.agregarMesaDinamica(nuevaMesa);

    setState(() {
      siguienteNumeroMesa++;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Text('Mesa #${siguienteNumeroMesa - 1} creada'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _eliminarMesaDinamica(int numeroMesa) async {
    if (mesaState.estaMesaOcupada(numeroMesa)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('Mesa Ocupada'),
            ],
          ),
          content: const Text(
            'No puedes eliminar una mesa ocupada. Cierra la cuenta primero.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Eliminar la Mesa #$numeroMesa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await mesaState.eliminarMesaDinamica(numeroMesa);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Text('Mesa #$numeroMesa eliminada'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _abrirMesa(int numeroMesa, int capacidad) async {
    final TextEditingController comensalesController = TextEditingController();

    final int? comensales = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Mesa $numeroMesa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Capacidad: $capacidad personas'),
              const SizedBox(height: 16),
              TextField(
                controller: comensalesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '¿Cuántos comensales?',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final cantidad = int.tryParse(comensalesController.text);
                if (cantidad != null && cantidad > 0 && cantidad <= capacidad) {
                  Navigator.pop(dialogContext, cantidad);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Número válido: 1-$capacidad'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Abrir Mesa'),
            ),
          ],
        );
      },
    );

    if (comensales != null) {
      mesaState.ocuparMesa(numeroMesa, comensales);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              OrderPage(numeroMesa: numeroMesa, comensales: comensales),
        ),
      );
    }
  }

  Widget _buildMesaDinamicaCard(MesaDinamica mesa) {
    final bool estaOcupada = mesaState.estaMesaOcupada(mesa.numeroMesa);
    final int? comensales = mesaState.obtenerComensales(mesa.numeroMesa);

    return GestureDetector(
      onTap: () {
        if (!estaOcupada) {
          _abrirMesa(mesa.numeroMesa, mesa.cantidadPersonas);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderPage(
                numeroMesa: mesa.numeroMesa,
                comensales: comensales ?? mesa.cantidadPersonas,
              ),
            ),
          );
        }
      },
      onLongPress: () {
        if (!estaOcupada) {
          _eliminarMesaDinamica(mesa.numeroMesa);
        }
      },
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: estaOcupada
                ? [Colors.red.shade600, Colors.red.shade800]
                : [Colors.green.shade600, Colors.green.shade800],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (estaOcupada ? Colors.red : Colors.green).withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.restaurant, color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Mesa ${mesa.numeroMesa}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people, color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${mesa.cantidadPersonas}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  if (estaOcupada && comensales != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$comensales comensales',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!estaOcupada)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  onPressed: () => _eliminarMesaDinamica(mesa.numeroMesa),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Selección de mesas"),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          if (mesasDinamicas.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_business, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${mesasDinamicas.length} temp',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoAgregarMesa,
        backgroundColor: Colors.blue.shade700,
        icon: const Icon(Icons.add),
        label: const Text('Mesa Temporal'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          final contenidoPrincipal = width >= 1200
              ? _buildLargeLandscapeLayout(width, height)
              : _buildMediumLandscapeLayout(width, height);

          // ✅ NUEVO: Incluir mesas dinámicas
          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  width: width,
                  height: height - (mesasDinamicas.isEmpty ? 0 : 180),
                  child: contenidoPrincipal,
                ),
                if (mesasDinamicas.isNotEmpty)
                  Container(
                    width: width,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.add_business,
                              color: Colors.blue.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Mesas Temporales',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: mesasDinamicas.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _buildMesaDinamicaCard(
                                  mesasDinamicas[index],
                                ),
                              );
                            },
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
    );
  }

  // 🖥️ PC (≥ 1200px)
  Widget _buildLargeLandscapeLayout(double width, double height) {
    return Stack(
      children: [
        // ── Fila 1 ──────────────────────────────────────────────
        Positioned(
          left: width * 0.03,
          top: height * 0.08,
          child: const MesaBase(
            cantidadPersonas: 4,
            ancho: 180,
            alto: 90,
            numeroMesa: 4,
          ),
        ),
        Positioned(
          left: width * 0.33,
          top: height * 0.08,
          child: const MesaBase(
            cantidadPersonas: 4,
            ancho: 90,
            alto: 90,
            numeroMesa: 3,
          ),
        ),
        Positioned(
          left: width * 0.55,
          top: height * 0.08,
          child: const MesaBase(
            cantidadPersonas: 4,
            ancho: 90,
            alto: 90,
            numeroMesa: 2,
          ),
        ),
        Positioned(
          left: width * 0.75,
          top: height * 0.08,
          child: const MesaBase(
            cantidadPersonas: 4,
            ancho: 90,
            alto: 90,
            numeroMesa: 1,
          ),
        ),
        // ── Fila 2 ──────────────────────────────────────────────
        Positioned(
          left: width * 0.03,
          top: height * 0.42,
          child: const MesaBase(
            cantidadPersonas: 4,
            ancho: 170,
            alto: 90,
            numeroMesa: 7,
          ),
        ),
        Positioned(
          left: width * 0.33,
          top: height * 0.42,
          child: const MesaBase(
            cantidadPersonas: 6,
            ancho: 180,
            alto: 90,
            numeroMesa: 6,
          ),
        ),
        Positioned(
          left: width * 0.63,
          top: height * 0.42,
          child: const MesaBase(
            cantidadPersonas: 4,
            ancho: 90,
            alto: 90,
            numeroMesa: 5,
          ),
        ),
        // ── Fila 3 ──────────────────────────────────────────────
        Positioned(
          left: width * 0.03,
          top: height * 0.72,
          child: const MesaBase(
            cantidadPersonas: 4,
            ancho: 220,
            alto: 90,
            numeroMesa: 8,
          ),
        ),
      ],
    );
  }

  // 💻 Tablet (600–1199px) — misma estructura, tablas más pequeñas
  Widget _buildMediumLandscapeLayout(double width, double height) {
    return Stack(
      children: [
        // ── Fila 1 ──────────────────────────────────────────────
        Positioned(
          left: width * 0.03,
          top: height * 0.08,
          child: const MesaBase(
            cantidadPersonas: 4,
            ancho: 150,
            alto: 75,
            numeroMesa: 7,
          ),
        ),
        Positioned(
          left: width * 0.33,
          top: height * 0.08,
          child: const MesaBase(
            cantidadPersonas: 4,
            ancho: 75,
            alto: 75,
            numeroMesa: 2,
          ),
        ),
        Positioned(
          left: width * 0.48,
          top: height * 0.08,
          child: const MesaBase(
            cantidadPersonas: 4,
            ancho: 75,
            alto: 75,
            numeroMesa: 3,
          ),
        ),
        Positioned(
          left: width * 0.63,
          top: height * 0.08,
          child: const MesaBase(
            cantidadPersonas: 4,
            ancho: 75,
            alto: 75,
            numeroMesa: 4,
          ),
        ),
        // ── Fila 2 ──────────────────────────────────────────────
        Positioned(
          left: width * 0.03,
          top: height * 0.42,
          child: const MesaBase(
            cantidadPersonas: 4,
            ancho: 140,
            alto: 75,
            numeroMesa: 6,
          ),
        ),
        Positioned(
          left: width * 0.33,
          top: height * 0.42,
          child: const MesaBase(
            cantidadPersonas: 6,
            ancho: 150,
            alto: 75,
            numeroMesa: 8,
          ),
        ),
        Positioned(
          left: width * 0.63,
          top: height * 0.42,
          child: const MesaBase(
            cantidadPersonas: 4,
            ancho: 75,
            alto: 75,
            numeroMesa: 1,
          ),
        ),
        // ── Fila 3 ──────────────────────────────────────────────
        Positioned(
          left: width * 0.03,
          top: height * 0.72,
          child: const MesaBase(
            cantidadPersonas: 4,
            ancho: 180,
            alto: 75,
            numeroMesa: 5,
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------
// 🟦 WIDGET BASE (mesa + distribución de comensales)
// ----------------------------------------------------
class MesaBase extends StatefulWidget {
  final int cantidadPersonas;
  final double ancho;
  final double alto;
  final int numeroMesa;

  const MesaBase({
    super.key,
    required this.cantidadPersonas,
    required this.ancho,
    required this.alto,
    required this.numeroMesa,
  });

  static void actualizarMesa(BuildContext context) {
    context.findAncestorStateOfType<_MesaBaseState>()?.setState(() {});
  }

  @override
  State<MesaBase> createState() => _MesaBaseState();
}

class _MesaBaseState extends State<MesaBase> {
  final MesaState mesaState = MesaState();
  String numeroSeleccionado = '';
  bool _listenerAdded = false;

  void _onMesaStateChanged() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        // Solo refrescar el widget cuando hay cambios en el estado
      });
    });
  }

  @override
  void initState() {
    super.initState();
    // ✅ FIX: Agregar listener en initState
    mesaState.addListener(_onMesaStateChanged);
    _listenerAdded = true;
  }

  @override
  void dispose() {
    mesaState.removeListener(_onMesaStateChanged);
    super.dispose();
  }

  void _mostrarTecladoComensales() {
    final bool mesaOcupada = mesaState.estaMesaOcupada(widget.numeroMesa);

    if (mesaOcupada) {
      final int comensalesActuales = mesaState.obtenerComensales(
        widget.numeroMesa,
      )!;
      _irAOrderPage(comensalesActuales);
      return;
    }

    numeroSeleccionado = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final screenSize = MediaQuery.of(context).size;
          final screenWidth = screenSize.width;
          final screenHeight = screenSize.height;

          final isSmallScreen = screenWidth < 600;
          final isMediumScreen = screenWidth >= 600 && screenWidth < 900;
          final isLargeScreen = screenWidth >= 900;
          final isLandscape = screenWidth > screenHeight;

          final dialogWidth = isSmallScreen
              ? min(screenWidth * 0.90, 380.0)
              : isMediumScreen
              ? min(screenWidth * 0.70, 450.0)
              : min(screenWidth * 0.50, 500.0);

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Container(
              width: dialogWidth,
              constraints: BoxConstraints(
                maxHeight: screenHeight * (isSmallScreen ? 0.85 : 0.75),
              ),
              padding: EdgeInsets.all(
                isSmallScreen
                    ? 16
                    : isMediumScreen
                    ? 20
                    : 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mesa ${widget.numeroMesa}',
                      style: TextStyle(
                        fontSize: isSmallScreen
                            ? 22
                            : isMediumScreen
                            ? 26
                            : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    Text(
                      'Ingresa el número de comensales',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 14 : 18,
                        horizontal: isSmallScreen ? 16 : 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                      child: Text(
                        numeroSeleccionado.isNotEmpty
                            ? numeroSeleccionado
                            : '0',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmallScreen
                              ? 32
                              : isMediumScreen
                              ? 38
                              : 42,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 14 : 20),
                    _buildTecladoNumerico(
                      setDialogState,
                      dialogWidth,
                      isSmallScreen,
                      isMediumScreen,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTecladoNumerico(
    StateSetter setDialogState,
    double dialogWidth,
    bool isSmallScreen,
    bool isMediumScreen,
  ) {
    final buttonSize = isSmallScreen
        ? min((dialogWidth - 80) / 3.5, 85.0)
        : isMediumScreen
        ? min((dialogWidth - 100) / 3.5, 95.0)
        : min((dialogWidth - 120) / 3.5, 105.0);

    return Column(
      children: [
        for (int row = 0; row < 3; row++)
          Padding(
            padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int col = 1; col <= 3; col++)
                  _buildTeclaNumero(
                    '${row * 3 + col}',
                    setDialogState,
                    buttonSize,
                  ),
              ],
            ),
          ),
        SizedBox(height: isSmallScreen ? 4 : 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTeclaBorrar(buttonSize, setDialogState),
            _buildTeclaNumero('0', setDialogState, buttonSize),
            _buildTeclaConfirmar(buttonSize),
          ],
        ),
      ],
    );
  }

  Widget _buildTeclaNumero(
    String numero,
    StateSetter setDialogState,
    double size,
  ) {
    return SizedBox(
      width: size,
      height: size * 0.85,
      child: ElevatedButton(
        onPressed: () {
          setDialogState(() {
            if (numeroSeleccionado.length < 2 &&
                !(numeroSeleccionado.isEmpty && numero == '0')) {
              numeroSeleccionado += numero;
            }
          });
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 5,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            numero,
            style: TextStyle(
              fontSize: size * 0.45,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeclaBorrar(double size, StateSetter setDialogState) {
    return SizedBox(
      width: size,
      height: size * 0.85,
      child: ElevatedButton(
        onPressed: () {
          setDialogState(() {
            if (numeroSeleccionado.isNotEmpty) {
              numeroSeleccionado = numeroSeleccionado.substring(
                0,
                numeroSeleccionado.length - 1,
              );
            }
          });
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.orange[600],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 5,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Icon(Icons.backspace_outlined, size: size * 0.45),
        ),
      ),
    );
  }

  Widget _buildTeclaConfirmar(double size) {
    return SizedBox(
      width: size,
      height: size * 0.85,
      child: ElevatedButton(
        onPressed: () {
          if (numeroSeleccionado.isNotEmpty) {
            int comensales = int.tryParse(numeroSeleccionado) ?? 0;
            if (comensales > 0) {
              mesaState.ocuparMesa(widget.numeroMesa, comensales);
              Navigator.pop(context);
              _irAOrderPage(comensales);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Debe haber al menos 1 comensal para abrir la mesa.',
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Por favor, ingresa el número de comensales.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 5,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Icon(Icons.check, size: size * 0.5),
        ),
      ),
    );
  }

  void _irAOrderPage(int comensales) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OrderPage(numeroMesa: widget.numeroMesa, comensales: comensales),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool esCircular = widget.cantidadPersonas == 2;
    final int? comensales = mesaState.obtenerComensales(widget.numeroMesa);
    final bool estaOcupada = mesaState.estaMesaOcupada(widget.numeroMesa);
    final String? meseroDeLaMesa = mesaState.obtenerMeseroDeMesa(
      widget.numeroMesa,
    );
    final bool esMesaPropia = mesaState.puedeAccederMesa(widget.numeroMesa);
    final bool esMesaDeOtroMesero = estaOcupada && !esMesaPropia;

    return GestureDetector(
      onTap: () {
        // ✅ Verificar si puede acceder antes de mostrar teclado
        if (esMesaDeOtroMesero) {
          _mostrarMensajeMesaBloqueada(meseroDeLaMesa!);
        } else {
          _mostrarTecladoComensales();
        }
      },
      child: esCircular
          ? _mesaCircular(
              comensales,
              estaOcupada,
              esMesaDeOtroMesero,
              meseroDeLaMesa,
            )
          : _mesaRectangular(
              comensales,
              estaOcupada,
              esMesaDeOtroMesero,
              meseroDeLaMesa,
            ),
    );
  }

  void _mostrarMensajeMesaBloqueada(String nombreMesero) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.lock, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Mesa Bloqueada'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Column(
                children: [
                  const Icon(Icons.person, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Esta mesa está siendo atendida por:',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nombreMesero.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Solo el mesero asignado puede acceder a esta mesa',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _mesaCircular(
    int? comensales,
    bool estaOcupada,
    bool esMesaDeOtroMesero,
    String? meseroDeLaMesa,
  ) {
    final minDimension = widget.ancho < widget.alto
        ? widget.ancho
        : widget.alto;
    final fontSize = minDimension * 0.28;
    final comensalesFontSize = fontSize * 0.70;

    final double radio = minDimension / 2;
    final double chairCenterDistance = radio + 20;
    final double sillaSize = 30;
    final double diametroTotal = 2 * (chairCenterDistance + sillaSize / 2);

    // ✅ Determinar color según estado
    Color mesaColor;
    if (esMesaDeOtroMesero) {
      mesaColor = Colors.grey[700]!;
    } else if (estaOcupada) {
      mesaColor = Colors.red[700]!;
    } else {
      mesaColor = Colors.green[600]!;
    }

    return SizedBox(
      width: diametroTotal,
      height: diametroTotal,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.ancho,
            height: widget.alto,
            decoration: BoxDecoration(
              color: mesaColor,
              borderRadius: BorderRadius.circular(widget.ancho * 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.numeroMesa}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (comensales != null)
                        Text(
                          '$comensales',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: comensalesFontSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                if (esMesaDeOtroMesero)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Colors.red,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...List.generate(widget.cantidadPersonas, (i) {
            final angle = (2 * pi / widget.cantidadPersonas) * i - pi / 2;
            final dx = chairCenterDistance * cos(angle);
            final dy = chairCenterDistance * sin(angle);

            final bool isComensalPresent = comensales != null && i < comensales;

            return Positioned(
              left: diametroTotal / 2 + dx - sillaSize / 2,
              top: diametroTotal / 2 + dy - sillaSize / 2,
              child: CircleAvatar(
                radius: sillaSize / 2,
                backgroundColor: isComensalPresent
                    ? Colors.orange
                    : Colors.grey[400],
                child: isComensalPresent
                    ? const Icon(Icons.person, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  // Reemplaza el método _mesaRectangular completo en custom_table.dart
  Widget _mesaRectangular(
    int? comensales,
    bool estaOcupada,
    bool esMesaDeOtroMesero,
    String? meseroDeLaMesa,
  ) {
    final List<Widget> comensalesWidgets = [];
    final double separacion = 20;
    final double sillaSize = 30;

    int personasPorLadoLargo = 0;
    if (widget.cantidadPersonas == 4 || widget.cantidadPersonas == 6) {
      personasPorLadoLargo = 2;
    } else if (widget.cantidadPersonas == 8) {
      personasPorLadoLargo = 3;
    } else if (widget.cantidadPersonas == 10) {
      personasPorLadoLargo = 4;
    }

    int comensalesCount = comensales ?? 0;
    int sillaIndex = 0;

    for (int i = 0; i < personasPorLadoLargo; i++) {
      double x_top =
          (widget.ancho / (personasPorLadoLargo + 1)) * (i + 1) -
          widget.ancho / 2;
      comensalesWidgets.add(
        _buildComensal(
          x_top,
          -widget.alto / 2 - separacion,
          sillaIndex++,
          comensalesCount,
          sillaSize,
        ),
      );
      double x_bottom =
          (widget.ancho / (personasPorLadoLargo + 1)) * (i + 1) -
          widget.ancho / 2;
      comensalesWidgets.add(
        _buildComensal(
          x_bottom,
          widget.alto / 2 + separacion,
          sillaIndex++,
          comensalesCount,
          sillaSize,
        ),
      );
    }

    int sillasRestantes = widget.cantidadPersonas - (personasPorLadoLargo * 2);
    if (sillasRestantes > 0) {
      comensalesWidgets.add(
        _buildComensal(
          -widget.ancho / 2 - separacion,
          0,
          sillaIndex++,
          comensalesCount,
          sillaSize,
        ),
      );
      if (sillasRestantes > 1) {
        comensalesWidgets.add(
          _buildComensal(
            widget.ancho / 2 + separacion,
            0,
            sillaIndex++,
            comensalesCount,
            sillaSize,
          ),
        );
      }
    }

    final double containerWidth =
        widget.ancho + 2 * (separacion + sillaSize / 2);
    final double containerHeight =
        widget.alto + 2 * (separacion + sillaSize / 2);
    final minDimension = widget.ancho < widget.alto
        ? widget.ancho
        : widget.alto;
    final fontSize = minDimension * 0.22;
    final comensalesFontSize = fontSize * 0.70;

    Color mesaColor;
    if (esMesaDeOtroMesero) {
      mesaColor = Colors.grey[700]!;
    } else if (estaOcupada) {
      mesaColor = Colors.red[700]!;
    } else {
      mesaColor = Colors.green[600]!;
    }

    return SizedBox(
      width: containerWidth,
      height: containerHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.ancho,
            height: widget.alto,
            decoration: BoxDecoration(
              color: mesaColor,
              borderRadius: BorderRadius.circular(minDimension * 0.075),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.numeroMesa}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (comensales != null)
                        Text(
                          '$comensales',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: comensalesFontSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                if (esMesaDeOtroMesero)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Colors.red,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...comensalesWidgets,
        ],
      ),
    );
  }

  Widget _buildComensal(
    double dx,
    double dy,
    int index,
    int comensalesCount,
    double size,
  ) {
    final bool isComensalPresent = index < comensalesCount;
    final double containerWidth = widget.ancho + 2 * (20 + 30 / 2);
    final double containerHeight = widget.alto + 2 * (20 + 30 / 2);

    return Positioned(
      left: containerWidth / 2 + dx - (size / 2),
      top: containerHeight / 2 + dy - (size / 2),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: isComensalPresent ? Colors.orange : Colors.grey[400],
        child: isComensalPresent
            ? const Icon(Icons.person, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}
