import 'package:flutter/foundation.dart';
import '/models/cuenta_cerrada.dart';
import 'package:intl/intl.dart';

class TurnoState extends ChangeNotifier {
  static final TurnoState _instance = TurnoState._internal();

  factory TurnoState() {
    return _instance;
  }

  TurnoState._internal();

  // Lista de cuentas cerradas del turno actual
  final List<CuentaCerrada> _cuentasCerradas = [];

  // Fecha de inicio del turno
  DateTime? _inicioTurno;

  // ✅ NUEVO: Getter para obtener el ID del turno actual
  String? get turnoActual {
    if (_inicioTurno == null) return null;

    // Generar ID basado en la fecha de inicio del turno
    final formatter = DateFormat('yyyyMMdd-HHmmss');
    return 'TURNO-${formatter.format(_inicioTurno!)}';
  }

  // Getter para obtener todas las cuentas
  List<CuentaCerrada> get cuentasCerradas =>
      List.unmodifiable(_cuentasCerradas);

  // Getter para fecha de inicio
  DateTime? get inicioTurno => _inicioTurno;

  // Iniciar turno (se llama automáticamente al cerrar la primera cuenta)
  void _iniciarTurno() {
    if (_inicioTurno == null) {
      _inicioTurno = DateTime.now();
      print('🔵 Turno iniciado: $turnoActual');
    }
  }

  // Agregar una cuenta cerrada
  void agregarCuentaCerrada(CuentaCerrada cuenta) {
    _iniciarTurno();
    _cuentasCerradas.add(cuenta);
    notifyListeners();

    print(
      '✅ Cuenta agregada al turno: Mesa ${cuenta.numeroMesa} - \$${cuenta.totalCuenta}',
    );
  }

  // Obtener total de ventas del turno
  double get totalVentasTurno {
    return _cuentasCerradas.fold(
      0.0,
      (sum, cuenta) => sum + cuenta.totalCuenta,
    );
  }

  // Obtener total de mesas atendidas
  int get totalMesasAtendidas {
    return _cuentasCerradas.length;
  }

  // Obtener total de comensales atendidos
  int get totalComensalesAtendidos {
    return _cuentasCerradas.fold(0, (sum, cuenta) => sum + cuenta.comensales);
  }

  // Obtener total de items vendidos
  int get totalItemsVendidos {
    return _cuentasCerradas.fold(0, (sum, cuenta) => sum + cuenta.totalItems);
  }

  // Obtener ticket promedio
  double get ticketPromedio {
    if (_cuentasCerradas.isEmpty) return 0.0;
    return totalVentasTurno / _cuentasCerradas.length;
  }

  // Obtener cuentas de un mesero específico
  List<CuentaCerrada> obtenerCuentasPorMesero(String nombreMesero) {
    return _cuentasCerradas
        .where((cuenta) => cuenta.mesero == nombreMesero)
        .toList();
  }

  // Obtener estadísticas por mesero
  Map<String, dynamic> obtenerEstadisticasMesero(String nombreMesero) {
    final cuentasMesero = obtenerCuentasPorMesero(nombreMesero);

    double totalVentas = 0.0;
    int totalMesas = cuentasMesero.length;
    int totalComensales = 0;
    int totalItems = 0;

    for (var cuenta in cuentasMesero) {
      totalVentas += cuenta.totalCuenta;
      totalComensales += cuenta.comensales;
      totalItems += cuenta.totalItems;
    }

    return {
      'totalVentas': totalVentas,
      'totalMesas': totalMesas,
      'totalComensales': totalComensales,
      'totalItems': totalItems,
      'ticketPromedio': totalMesas > 0 ? totalVentas / totalMesas : 0.0,
    };
  }

  // Obtener meseros únicos del turno
  Set<String> get meserosActivos {
    return _cuentasCerradas.map((cuenta) => cuenta.mesero).toSet();
  }

  // Obtener duración total del turno
  Duration? get duracionTurno {
    if (_inicioTurno == null) return null;
    return DateTime.now().difference(_inicioTurno!);
  }

  // Formatear duración del turno
  String get duracionTurnoFormateada {
    final duration = duracionTurno;
    if (duration == null) return '0h 0m';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  // Limpiar turno (al cerrar turno o iniciar nuevo)
  void cerrarTurno() {
    print('📊 Turno cerrado:');
    print('   ID Turno: $turnoActual');
    print('   Total ventas: \$${totalVentasTurno.toStringAsFixed(2)}');
    print('   Mesas atendidas: $totalMesasAtendidas');
    print('   Comensales: $totalComensalesAtendidos');
    print('   Duración: $duracionTurnoFormateada');

    _cuentasCerradas.clear();
    _inicioTurno = null;
    notifyListeners();
  }

  // Obtener resumen completo del turno
  Map<String, dynamic> get resumenTurno {
    return {
      'turnoId': turnoActual, // ✅ NUEVO: Agregar ID de turno al resumen
      'inicioTurno': _inicioTurno,
      'duracionTurno': duracionTurno,
      'duracionFormateada': duracionTurnoFormateada,
      'totalVentas': totalVentasTurno,
      'totalMesas': totalMesasAtendidas,
      'totalComensales': totalComensalesAtendidos,
      'totalItems': totalItemsVendidos,
      'ticketPromedio': ticketPromedio,
      'meserosActivos': meserosActivos.length,
      'cuentas': _cuentasCerradas,
    };
  }

  // Obtener productos más vendidos
  List<Map<String, dynamic>> get productosTopVendidos {
    Map<String, int> conteoProductos = {};

    for (var cuenta in _cuentasCerradas) {
      for (var producto in cuenta.productos) {
        String nombre = producto['nombre'];
        int cantidad = producto['cantidad'];
        conteoProductos[nombre] = (conteoProductos[nombre] ?? 0) + cantidad;
      }
    }

    List<Map<String, dynamic>> ranking = conteoProductos.entries
        .map((entry) => {'nombre': entry.key, 'cantidad': entry.value})
        .toList();

    ranking.sort(
      (a, b) => (b['cantidad'] as int).compareTo(a['cantidad'] as int),
    );

    return ranking.take(10).toList();
  }
}
