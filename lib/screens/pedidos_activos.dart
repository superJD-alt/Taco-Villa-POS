import 'package:flutter/material.dart';
import 'mesa_state.dart';

class PedidosActivos extends StatefulWidget {
  const PedidosActivos({super.key});

  @override
  State<PedidosActivos> createState() => _PedidosActivosPageState();
}

class _PedidosActivosPageState extends State<PedidosActivos> {
  final mesaState = MesaState();

  @override
  Widget build(BuildContext context) {
    final mesasOcupadas = mesaState.obtenerMesasOcupadas();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos Activos'),
        backgroundColor: Colors.deepOrange,
      ),
      body: mesasOcupadas.isEmpty
          ? const Center(
              child: Text(
                'No hay mesas con pedidos activos',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: mesasOcupadas.length,
              itemBuilder: (context, index) {
                final numeroMesa = mesasOcupadas[index];
                final pedidos = mesaState.obtenerPedidosEnviados(numeroMesa);
                final comensales = mesaState.obtenerComensales(numeroMesa);

                if (pedidos.isEmpty) {
                  return const SizedBox.shrink();
                }

                // ✅ CAMBIO: Tomar el primer pedido para obtener mesero y fecha inicial
                final primerPedido = pedidos.first;
                final mesero = primerPedido["mesero"] ?? "Sin asignar";
                final fechaInicial =
                    DateTime.tryParse(primerPedido["fecha"] ?? "") ??
                    DateTime.now();

                // ✅ NUEVO: Consolidar TODOS los alimentos de TODOS los pedidos
                List<Map<String, dynamic>> todosLosAlimentos = [];
                for (var pedido in pedidos) {
                  final alimentos = pedido["alimentos"] ?? [];
                  todosLosAlimentos.addAll(
                    List<Map<String, dynamic>>.from(alimentos),
                  );
                }

                // ✅ OPCIONAL: Agrupar productos repetidos (mismo nombre y nota)
                Map<String, Map<String, dynamic>> alimentosAgrupados = {};
                for (var item in todosLosAlimentos) {
                  String key = "${item['nombre']}_${item['nota'] ?? ''}";

                  if (alimentosAgrupados.containsKey(key)) {
                    alimentosAgrupados[key]!['cantidad'] += item['cantidad'];
                  } else {
                    alimentosAgrupados[key] = {
                      'nombre': item['nombre'],
                      'cantidad': item['cantidad'],
                      'nota': item['nota'] ?? '',
                    };
                  }
                }

                final alimentosFinales = alimentosAgrupados.values.toList();

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.deepOrange.shade200,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header con mesa
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Mesa $numeroMesa',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${alimentosFinales.length} productos',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Info de mesero y comensales
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text('Mesero: $mesero'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.group,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text('Comensales: $comensales'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Inicio: ${fechaInicial.day}/${fechaInicial.month}/${fechaInicial.year} '
                                    '${fechaInicial.hour}:${fechaInicial.minute.toString().padLeft(2, '0')}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Lista de alimentos
                        const Text(
                          'Alimentos ordenados:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),

                        ...alimentosFinales.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.deepOrange.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'x${item["cantidad"]}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item["nombre"],
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if ((item["nota"] ?? "").isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            "Nota: ${item["nota"]}",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
