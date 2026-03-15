import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'mesa_state.dart';

class ViewTable extends StatefulWidget {
  const ViewTable({super.key});

  @override
  State<ViewTable> createState() => _ViewTableState();
}

class _ViewTableState extends State<ViewTable> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Estado de Mesas"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[300],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          // Tamaños según pantalla (igual que custom_table.dart)
          final bool isLarge = width >= 1200;
          final double anchoLargo = isLarge ? 150.0 : 120.0;
          final double anchoCuad = isLarge ? 75.0 : 65.0;
          final double anchoM6 = isLarge ? 150.0 : 130.0;
          final double anchoM5 = isLarge ? 180.0 : 150.0;
          final double alto = isLarge ? 75.0 : 65.0;

          return Stack(
            children: [
              // ── Fila 1 ────────────────────────────────────────
              Positioned(
                left: width * 0.03,
                top: height * 0.08,
                child: MesaBase(
                  cantidadPersonas: 4,
                  ancho: anchoLargo,
                  alto: alto,
                  numeroMesa: 4,
                ),
              ),
              Positioned(
                left: width * 0.33,
                top: height * 0.08,
                child: MesaBase(
                  cantidadPersonas: 4,
                  ancho: anchoCuad,
                  alto: alto,
                  numeroMesa: 3,
                ),
              ),
              Positioned(
                left: width * 0.55,
                top: height * 0.08,
                child: MesaBase(
                  cantidadPersonas: 4,
                  ancho: anchoCuad,
                  alto: alto,
                  numeroMesa: 2,
                ),
              ),
              Positioned(
                left: width * 0.75,
                top: height * 0.08,
                child: MesaBase(
                  cantidadPersonas: 4,
                  ancho: anchoCuad,
                  alto: alto,
                  numeroMesa: 1,
                ),
              ),
              // ── Fila 2 ────────────────────────────────────────
              Positioned(
                left: width * 0.03,
                top: height * 0.42,
                child: MesaBase(
                  cantidadPersonas: 4,
                  ancho: anchoLargo,
                  alto: alto,
                  numeroMesa: 7,
                ),
              ),
              Positioned(
                left: width * 0.33,
                top: height * 0.42,
                child: MesaBase(
                  cantidadPersonas: 6,
                  ancho: anchoM6,
                  alto: alto,
                  numeroMesa: 6,
                ),
              ),
              Positioned(
                left: width * 0.63,
                top: height * 0.42,
                child: MesaBase(
                  cantidadPersonas: 4,
                  ancho: anchoCuad,
                  alto: alto,
                  numeroMesa: 5,
                ),
              ),
              // ── Fila 3 ────────────────────────────────────────
              Positioned(
                left: width * 0.03,
                top: height * 0.72,
                child: MesaBase(
                  cantidadPersonas: 4,
                  ancho: anchoM5,
                  alto: alto,
                  numeroMesa: 8,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------
// 🟦 WIDGET BASE (SOLO VISUALIZACIÓN)
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

  @override
  State<MesaBase> createState() => _MesaBaseState();
}

class _MesaBaseState extends State<MesaBase> {
  final MesaState mesaState = MesaState();

  void _mostrarInformacionMesa(String? meseroDeLaMesa) {
    final bool mesaOcupada = mesaState.estaMesaOcupada(widget.numeroMesa);
    final int? comensales = mesaState.obtenerComensales(widget.numeroMesa);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              mesaOcupada ? Icons.info : Icons.check_circle,
              color: mesaOcupada ? Colors.orange : Colors.green,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text('Mesa ${widget.numeroMesa}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: mesaOcupada ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: mesaOcupada ? Colors.red : Colors.green,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    mesaOcupada ? '🔴 OCUPADA' : '🟢 DISPONIBLE',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: mesaOcupada ? Colors.red : Colors.green,
                    ),
                  ),
                  if (mesaOcupada) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),

                    // ✅ Mostrar mesero
                    if (meseroDeLaMesa != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Mesero: ${meseroDeLaMesa.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Comensales
                    if (comensales != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.group, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            '$comensales comensal${comensales != 1 ? 'es' : ''}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.chair, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Capacidad: ${widget.cantidadPersonas} personas',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            if (!mesaOcupada) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta mesa está disponible para nuevos clientes',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Usar ListenableBuilder para reaccionar a cambios
    return ListenableBuilder(
      listenable: mesaState,
      builder: (context, child) {
        final bool esCircular = widget.cantidadPersonas == 2;
        final int? comensales = mesaState.obtenerComensales(widget.numeroMesa);
        final bool estaOcupada = mesaState.estaMesaOcupada(widget.numeroMesa);
        final String? meseroDeLaMesa = mesaState.obtenerMeseroDeMesa(
          widget.numeroMesa,
        );

        return GestureDetector(
          onTap: () => _mostrarInformacionMesa(meseroDeLaMesa),
          child: esCircular
              ? _mesaCircular(comensales, estaOcupada, meseroDeLaMesa)
              : _mesaRectangular(comensales, estaOcupada, meseroDeLaMesa),
        );
      },
    );
  }

  Widget _mesaCircular(
    int? comensales,
    bool estaOcupada,
    String? meseroDeLaMesa,
  ) {
    double radio = (max(widget.ancho, widget.alto) / 2) + 30;
    double diametroTotal = (radio + 20) * 2;

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
              color: estaOcupada ? Colors.red : Colors.green,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: estaOcupada
                      ? Colors.red.withOpacity(0.4)
                      : Colors.green.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${widget.numeroMesa}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (comensales != null)
                    Text(
                      '$comensales',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
          ...List.generate(widget.cantidadPersonas, (i) {
            final angle = (2 * pi / widget.cantidadPersonas) * i - pi / 2;
            final dx = radio * cos(angle);
            final dy = radio * sin(angle);

            return Positioned(
              left: diametroTotal / 2 + dx - 15,
              top: diametroTotal / 2 + dy - 15,
              child: const CircleAvatar(
                radius: 15,
                backgroundColor: Colors.orange,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _mesaRectangular(
    int? comensales,
    bool estaOcupada,
    String? meseroDeLaMesa,
  ) {
    const double separacion = 20;
    List<Widget> comensalesWidgets = [];

    int personasPorLadoLargo = 0;
    if (widget.cantidadPersonas == 6)
      personasPorLadoLargo = 2;
    else if (widget.cantidadPersonas == 8)
      personasPorLadoLargo = 3;
    else if (widget.cantidadPersonas == 10)
      personasPorLadoLargo = 4;

    comensalesWidgets.add(_buildComensal(-widget.ancho / 2 - separacion, 0));
    for (int i = 0; i < personasPorLadoLargo; i++) {
      double x =
          (widget.ancho / (personasPorLadoLargo + 1)) * (i + 1) -
          widget.ancho / 2;
      comensalesWidgets.add(_buildComensal(x, -widget.alto / 2 - separacion));
    }
    comensalesWidgets.add(_buildComensal(widget.ancho / 2 + separacion, 0));
    for (int i = 0; i < personasPorLadoLargo; i++) {
      double x =
          (widget.ancho / (personasPorLadoLargo + 1)) * (i + 1) -
          widget.ancho / 2;
      comensalesWidgets.add(_buildComensal(x, widget.alto / 2 + separacion));
    }

    return SizedBox(
      width: widget.ancho + 120,
      height: widget.alto + 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.ancho,
            height: widget.alto,
            decoration: BoxDecoration(
              color: estaOcupada ? Colors.red : Colors.green,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: estaOcupada
                      ? Colors.red.withOpacity(0.4)
                      : Colors.green.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${widget.numeroMesa}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (comensales != null)
                    Text(
                      '$comensales',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
          ...comensalesWidgets,
        ],
      ),
    );
  }

  Widget _buildComensal(double dx, double dy) {
    return Positioned(
      left: (widget.ancho + 120) / 2 + dx - 15,
      top: (widget.alto + 120) / 2 + dy - 15,
      child: const CircleAvatar(radius: 15, backgroundColor: Colors.orange),
    );
  }
}
