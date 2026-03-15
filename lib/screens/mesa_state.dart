import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MesaState extends ChangeNotifier {
  static final MesaState _instance = MesaState._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  factory MesaState() {
    return _instance;
  }

  MesaState._internal() {
    //constructor
    // ✅ FIX: Diferir TODA la inicialización hasta después del primer frame
    Future.microtask(() async {
      _iniciarEscuchaDeMesas();
      await _cargarMesasDinamicasInicial();
      _isInitialized = true;
    });
  }

  // Mapas locales (cache)
  final Map<int, bool> _mesasOcupadas = {};
  final Map<int, String> _meserosPorMesa = {};
  final Map<int, List<Map<String, dynamic>>> _pedidosEnviadosPorMesa = {};
  final Map<int, List<Map<String, dynamic>>> _pedidosPorMesa = {};
  final Map<int, int> _comensalesPorMesa = {};
  final Map<int, String> _foliosMesa = {};

  String _meseroActual = "";
  String get meseroActual => _meseroActual;

  List<MesaDinamica> _mesasDinamicasCache = [];

  // ✅ FIX: Flag para controlar cuándo notificar
  bool _isInitialized = false;

  // ✅ NUEVO: Escuchar cambios de Firestore en tiempo real
  void _iniciarEscuchaDeMesas() {
    _firestore
        .collection('mesas_activas')
        .snapshots()
        .listen(
          (snapshot) {
            print('📄 Actualizando estado de mesas desde Firestore...');

            for (var change in snapshot.docChanges) {
              final data = change.doc.data();
              if (data == null) continue;

              final numeroMesa = int.tryParse(change.doc.id);
              if (numeroMesa == null) continue;

              if (change.type == DocumentChangeType.removed) {
                // Mesa liberada
                _mesasOcupadas.remove(numeroMesa);
                _meserosPorMesa.remove(numeroMesa);
                _comensalesPorMesa.remove(numeroMesa);
                print('🟢 Mesa $numeroMesa liberada remotamente');
              } else {
                // Mesa ocupada o actualizada
                _mesasOcupadas[numeroMesa] = data['ocupada'] ?? false;
                _meserosPorMesa[numeroMesa] = data['mesero'] ?? '';
                _comensalesPorMesa[numeroMesa] = data['comensales'] ?? 0;
                print(
                  '🔵 Mesa $numeroMesa ocupada por ${data['mesero']} (remoto)',
                );
              }
            }

            // ✅ FIX: Solo notificar si ya se inicializó
            if (_isInitialized) {
              notifyListeners();
            }
          },
          onError: (error) {
            print('❌ Error escuchando mesas: $error');
          },
        );
  }

  void establecerMesero(String nombreMesero) {
    _meseroActual = nombreMesero;
    print('👤 Mesero establecido: $_meseroActual');
    notifyListeners();
  }

  bool estaMesaOcupada(int numeroMesa) {
    return _mesasOcupadas[numeroMesa] ?? false;
  }

  List<int> obtenerMesasOcupadas() {
    return _mesasOcupadas.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
  }

  String? obtenerMeseroDeMesa(int numeroMesa) {
    return _meserosPorMesa[numeroMesa];
  }

  bool puedeAccederMesa(int numeroMesa) {
    if (!estaMesaOcupada(numeroMesa)) return true;
    return _meserosPorMesa[numeroMesa] == _meseroActual;
  }

  // ✅ MODIFICADO: Guardar en Firestore cuando se ocupa una mesa
  Future<void> ocuparMesa(int numeroMesa, int comensales) async {
    _mesasOcupadas[numeroMesa] = true;
    _comensalesPorMesa[numeroMesa] = comensales;
    _meserosPorMesa[numeroMesa] = _meseroActual;

    if (!_pedidosPorMesa.containsKey(numeroMesa)) {
      _pedidosPorMesa[numeroMesa] = [];
    }

    // ✅ Guardar en Firestore
    try {
      await _firestore
          .collection('mesas_activas')
          .doc(numeroMesa.toString())
          .set({
            'ocupada': true,
            'mesero': _meseroActual,
            'comensales': comensales,
            'fechaApertura': FieldValue.serverTimestamp(),
          });
      print('✅ Mesa $numeroMesa guardada en Firestore');
    } catch (e) {
      print('❌ Error guardando mesa en Firestore: $e');
    }

    notifyListeners();
  }

  // ✅ MODIFICADO: Eliminar de Firestore cuando se libera una mesa
  Future<void> liberarMesa(int numeroMesa) async {
    final mesero = _meserosPorMesa[numeroMesa];

    _mesasOcupadas[numeroMesa] = false;
    _pedidosPorMesa.remove(numeroMesa);
    _pedidosEnviadosPorMesa.remove(numeroMesa);
    _comensalesPorMesa.remove(numeroMesa);
    _foliosMesa.remove(numeroMesa);
    _meserosPorMesa.remove(numeroMesa);

    // ✅ Eliminar de Firestore
    try {
      await _firestore
          .collection('mesas_activas')
          .doc(numeroMesa.toString())
          .delete();
      print('✅ Mesa $numeroMesa eliminada de Firestore');
    } catch (e) {
      print('❌ Error eliminando mesa de Firestore: $e');
    }

    notifyListeners();
  }

  // --- DENTRO DE LA CLASE MesaState ---

  // Método para intentar "adueñarse" de la mesa en Firebase
  Future<bool> intentarOcuparMesa(int numeroMesa, String nombreMesero) async {
    try {
      final docRef = _firestore
          .collection('mesas_activas')
          .doc(numeroMesa.toString());
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        // Si la mesa ya está ocupada por otro mesero, denegar acceso
        if (data['ocupada'] == true && data['mesero'] != nombreMesero) {
          return false;
        }
      }

      // Si está libre o soy yo mismo, actualizo el bloqueo
      await docRef.set({
        'ocupada': true,
        'mesero': nombreMesero,
        'ultima_actividad': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print("Error al ocupar mesa: $e");
      return false;
    }
  }

  // Método para liberar la mesa (llámalo al cerrar la cuenta o salir)
  Future<void> liberarBloqueoMesa(int numeroMesa) async {
    try {
      await _firestore
          .collection('mesas_activas')
          .doc(numeroMesa.toString())
          .update({'ocupada': false, 'mesero': ''});
    } catch (e) {
      print("Error al liberar mesa: $e");
    }
  }

  // Helper para saber quién tiene la mesa (para el mensaje de error)
  String obtenerNombreOcupante(int numeroMesa) {
    return _meserosPorMesa[numeroMesa] ?? "Otro mesero";
  }

  // ... El resto de tus métodos permanecen igual ...

  List<Map<String, dynamic>> obtenerPedidosEnviados(int numeroMesa) {
    return _pedidosEnviadosPorMesa[numeroMesa] ?? [];
  }

  List<Map<String, dynamic>> obtenerPedidos(int numeroMesa) {
    return _pedidosPorMesa[numeroMesa] ?? [];
  }

  void guardarPedidos(int numeroMesa, List<Map<String, dynamic>> pedidos) {
    _pedidosPorMesa[numeroMesa] = List.from(pedidos);
    notifyListeners();
  }

  void agregarPedido(int numeroMesa, List<Map<String, dynamic>> alimentos) {
    if (!_pedidosEnviadosPorMesa.containsKey(numeroMesa)) {
      _pedidosEnviadosPorMesa[numeroMesa] = [];
    }

    final pedido = {
      "mesero": _meseroActual,
      "fecha": DateTime.now().toIso8601String(),
      "alimentos": alimentos,
    };

    _pedidosEnviadosPorMesa[numeroMesa]!.add(pedido);
    _pedidosPorMesa[numeroMesa] = [];
    notifyListeners();
  }

  int obtenerComensales(int numeroMesa) {
    return _comensalesPorMesa[numeroMesa] ?? 0;
  }

  void guardarFolioMesa(int numeroMesa, String folio) {
    _foliosMesa[numeroMesa] = folio;
    notifyListeners();
  }

  String? obtenerFolioMesa(int numeroMesa) {
    return _foliosMesa[numeroMesa];
  }

  void limpiarTodo() {
    _mesasOcupadas.clear();
    _pedidosPorMesa.clear();
    _pedidosEnviadosPorMesa.clear();
    _comensalesPorMesa.clear();
    _meserosPorMesa.clear();
    _meseroActual = "";
    notifyListeners();
  }

  Map<String, dynamic> obtenerResumenMesa(int numeroMesa) {
    final ocupada = estaMesaOcupada(numeroMesa);
    final comensales = obtenerComensales(numeroMesa);
    final pedidosLocales = obtenerPedidos(numeroMesa);
    final pedidosEnviados = obtenerPedidosEnviados(numeroMesa);
    final mesero = _meserosPorMesa[numeroMesa];

    int totalProductos = 0;
    double totalGeneral = 0.0;

    for (var pedido in pedidosLocales) {
      totalProductos += pedido['cantidad'] as int;
      totalGeneral += pedido['total'] as double;
    }

    for (var pedidoEnviado in pedidosEnviados) {
      final alimentos = pedidoEnviado['alimentos'] as List;
      for (var alimento in alimentos) {
        totalProductos += alimento['cantidad'] as int;
        totalGeneral += (alimento['precio'] * alimento['cantidad']) as double;
      }
    }

    return {
      'ocupada': ocupada,
      'comensales': comensales,
      'totalProductos': totalProductos,
      'totalGeneral': totalGeneral,
      'pedidosLocales': pedidosLocales.length,
      'pedidosEnviados': pedidosEnviados.length,
      'mesero': mesero,
      'esMesaPropia': mesero == _meseroActual,
    };
  }

  Map<String, dynamic> obtenerEstadisticasGenerales() {
    int mesasOcupadas = 0;
    int totalComensales = 0;
    double ventaTotal = 0.0;

    for (var numeroMesa in _mesasOcupadas.keys) {
      if (_mesasOcupadas[numeroMesa] == true) {
        mesasOcupadas++;
        totalComensales += obtenerComensales(numeroMesa);
        final resumen = obtenerResumenMesa(numeroMesa);
        ventaTotal += resumen['totalGeneral'] as double;
      }
    }

    return {
      'mesasOcupadas': mesasOcupadas,
      'totalComensales': totalComensales,
      'ventaTotal': ventaTotal,
    };
  }

  void eliminarProductoEnviado(
    int numeroMesa,
    String nombreProducto,
    int cantidad,
  ) {
    if (!_pedidosEnviadosPorMesa.containsKey(numeroMesa)) return;

    List<Map<String, dynamic>> pedidos = _pedidosEnviadosPorMesa[numeroMesa]!;
    bool productoEliminado = false;

    for (int i = 0; i < pedidos.length; i++) {
      var pedido = pedidos[i];
      if (pedido['alimentos'] != null) {
        List<dynamic> alimentos = List.from(pedido['alimentos']);
        alimentos.removeWhere((alimento) {
          bool coincide =
              alimento['nombre'] == nombreProducto &&
              alimento['cantidad'] == cantidad;
          if (coincide) productoEliminado = true;
          return coincide;
        });
        pedido['alimentos'] = alimentos;
      }
    }

    pedidos.removeWhere(
      (pedido) =>
          pedido['alimentos'] == null || (pedido['alimentos'] as List).isEmpty,
    );

    if (pedidos.isEmpty) {
      _pedidosEnviadosPorMesa.remove(numeroMesa);
    } else {
      _pedidosEnviadosPorMesa[numeroMesa] = pedidos;
    }

    if (productoEliminado) notifyListeners();
  }

  List<MesaDinamica> obtenerMesasDinamicas() {
    return _mesasDinamicasCache;
  }

  // ✅ FIX: Método privado que carga sin notificar (para usar en constructor)
  Future<void> _cargarMesasDinamicasInicial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mesasJson = prefs.getStringList('mesas_dinamicas') ?? [];

      _mesasDinamicasCache = mesasJson
          .map((json) => MesaDinamica.fromJson(jsonDecode(json)))
          .toList();

      print('✅ ${_mesasDinamicasCache.length} mesas dinámicas cargadas');
      // ✅ NO llamar notifyListeners() aquí durante la construcción
    } catch (e) {
      print('❌ Error cargando mesas dinámicas: $e');
      _mesasDinamicasCache = [];
    }
  }

  /// Cargar mesas dinámicas desde SharedPreferences (versión pública que sí notifica)
  Future<void> cargarMesasDinamicas() async {
    await _cargarMesasDinamicasInicial();
    notifyListeners();
  }

  /// Guardar mesa dinámica
  Future<void> guardarMesaDinamica(MesaDinamica mesa) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Obtener mesas existentes
      final mesasJson = prefs.getStringList('mesas_dinamicas') ?? [];

      // Agregar nueva mesa
      mesasJson.add(jsonEncode(mesa.toJson()));

      // Guardar
      await prefs.setStringList('mesas_dinamicas', mesasJson);

      // Actualizar cache
      _mesasDinamicasCache.add(mesa);

      print('✅ Mesa dinámica ${mesa.numeroMesa} guardada');
      notifyListeners();
    } catch (e) {
      print('❌ Error guardando mesa dinámica: $e');
    }
  }

  // ✅ NUEVO: Método para agregar mesa dinámica (wrapper más semántico)
  Future<void> agregarMesaDinamica(MesaDinamica mesa) async {
    await guardarMesaDinamica(mesa);
  }

  /// Eliminar mesa dinámica
  Future<void> eliminarMesaDinamica(int numeroMesa) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mesasJson = prefs.getStringList('mesas_dinamicas') ?? [];

      // Filtrar la mesa a eliminar
      final mesasActualizadas = mesasJson.where((json) {
        final mesa = MesaDinamica.fromJson(jsonDecode(json));
        return mesa.numeroMesa != numeroMesa;
      }).toList();

      // Guardar
      await prefs.setStringList('mesas_dinamicas', mesasActualizadas);

      // Actualizar cache
      _mesasDinamicasCache.removeWhere((m) => m.numeroMesa == numeroMesa);

      print('✅ Mesa dinámica $numeroMesa eliminada');
      notifyListeners();
    } catch (e) {
      print('❌ Error eliminando mesa dinámica: $e');
    }
  }

  /// Limpiar mesas dinámicas desocupadas (útil para limpieza al cerrar turno)
  Future<void> limpiarMesasDinamicasDesocupadas() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Filtrar solo las mesas que están ocupadas
      final mesasOcupadas = _mesasDinamicasCache
          .where((mesa) => estaMesaOcupada(mesa.numeroMesa))
          .toList();

      // Convertir a JSON
      final mesasJson = mesasOcupadas
          .map((mesa) => jsonEncode(mesa.toJson()))
          .toList();

      // Guardar solo las ocupadas
      await prefs.setStringList('mesas_dinamicas', mesasJson);

      // Actualizar cache
      final eliminadas = _mesasDinamicasCache.length - mesasOcupadas.length;
      _mesasDinamicasCache = mesasOcupadas;

      print('✅ $eliminadas mesas dinámicas desocupadas limpiadas');
      notifyListeners();
    } catch (e) {
      print('❌ Error limpiando mesas dinámicas: $e');
    }
  }

  // ✅ NUEVO: Método para obtener el estado de una mesa específica
  MesaEstado? obtenerEstadoMesa(int numeroMesa) {
    final estaOcupada = estaMesaOcupada(numeroMesa);
    if (!estaOcupada) return null;

    return MesaEstado(
      numeroMesa: numeroMesa,
      estaOcupada: estaOcupada,
      mesero: _meserosPorMesa[numeroMesa],
      comensales: _comensalesPorMesa[numeroMesa],
    );
  }
}

// ====================================================================
// ✅ CLASE PARA MESAS DINÁMICAS
// ====================================================================

class MesaDinamica {
  final int numeroMesa;
  final int cantidadPersonas;

  MesaDinamica({required this.numeroMesa, required this.cantidadPersonas});

  Map<String, dynamic> toJson() {
    return {'numeroMesa': numeroMesa, 'cantidadPersonas': cantidadPersonas};
  }

  factory MesaDinamica.fromJson(Map<String, dynamic> json) {
    return MesaDinamica(
      numeroMesa: json['numeroMesa'] as int,
      cantidadPersonas: json['cantidadPersonas'] as int,
    );
  }
}

// ====================================================================
// ✅ CLASE PARA ESTADO DE MESA
// ====================================================================

class MesaEstado {
  final int numeroMesa;
  final bool estaOcupada;
  final String? mesero;
  final int? comensales;

  MesaEstado({
    required this.numeroMesa,
    required this.estaOcupada,
    this.mesero,
    this.comensales,
  });
}
