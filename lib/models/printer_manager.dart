import '/models/welricka_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PrinterManager {
  final WelirkcaPrinterService _printer = WelirkcaPrinterService();

  String? _printerId;
  String? _printerName;
  String? _printerType;
  String? _printerAddress;

  bool _esTabletCentral = false;
  bool get esTabletCentral => _esTabletCentral;
  bool _procesandoImpresion = false;

  // Singleton
  static final PrinterManager _instance = PrinterManager._internal();
  factory PrinterManager() => _instance;
  PrinterManager._internal();

  // ════════════════════════════════════════════════════════
  // GESTIÓN DE CONFIGURACIÓN
  // ════════════════════════════════════════════════════════

  Future<void> cargarConfiguracion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _printerId = prefs.getString('printer_id');
      _printerName = prefs.getString('printer_name');
      _printerType = prefs.getString('printer_type');
      _printerAddress = prefs.getString('printer_address');

      print('📂 Configuración cargada:');
      print('   Impresora: $_printerName ($_printerType: $_printerAddress)');
    } catch (e) {
      print('❌ Error cargando configuración: $e');
    }
  }

  Future<void> guardarConexion({
    required String deviceId,
    required String deviceName,
    required String connectionType,
    required String address,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_id', deviceId);
      await prefs.setString('printer_name', deviceName);
      await prefs.setString('printer_type', connectionType);
      await prefs.setString('printer_address', address);

      _printerId = deviceId;
      _printerName = deviceName;
      _printerType = connectionType;
      _printerAddress = address;

      print('💾 Guardada: $deviceName ($connectionType: $address)');
    } catch (e) {
      print('❌ Error guardando: $e');
    }
  }

  Future<void> limpiarConexion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('printer_id');
      await prefs.remove('printer_name');
      await prefs.remove('printer_type');
      await prefs.remove('printer_address');

      _printerId = _printerName = _printerType = _printerAddress = null;
      print('🗑️ Configuración limpiada');
    } catch (e) {
      print('❌ Error limpiando: $e');
    }
  }

  void setComoTabletCentral(bool valor) {
    _esTabletCentral = valor;
    if (_esTabletCentral) {
      print("📡 Modo Central Activado: Escuchando pedidos...");
      _iniciarEscuchaDeImpresion();
    } else {
      print("💤 Modo Central Desactivado.");
    }
  }

  void _iniciarEscuchaDeImpresion() {
    print("📡 [CENTRAL] Iniciando escucha de pedidos en Firebase...");

    FirebaseFirestore.instance
        .collection('tickets_pendientes')
        .where('impreso', isEqualTo: false)
        .snapshots()
        .listen((snapshot) async {
          if (!_esTabletCentral) return;

          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data == null || _procesandoImpresion) continue;

              try {
                _procesandoImpresion = true;

                final int mesa = data['numeroMesa'] ?? 0;
                final String mesero = data['mesero'] ?? 'Sin nombre';
                final String folio = data['folio'] ?? '';
                final List<Map<String, dynamic>> productos =
                    (data['productos'] as List)
                        .map((p) => Map<String, dynamic>.from(p))
                        .toList();

                print("🆕 [CENTRAL] Pedido detectado Mesa: $mesa");

                // Marcar como impreso ANTES de imprimir
                await change.doc.reference.update({'impreso': true});

                // ✅ Separar productos
                final productosCocina = productos
                    .where((p) => p.esCocina)
                    .toList();
                final productosBarra = productos
                    .where((p) => p.esBarra)
                    .toList();

                // ✅ Ticket de COCINA
                if (productosCocina.isNotEmpty) {
                  print(
                    "🍳 Imprimiendo ticket COCINA (${productosCocina.length} productos)...",
                  );
                  final ticketCocina = _formatearTicketDestino(
                    mesa: mesa,
                    mesero: mesero,
                    folio: folio,
                    destino: 'COCINA',
                    productos: productosCocina,
                  );
                  await imprimirComanda(contenido: ticketCocina);
                  print("✅ Ticket COCINA impreso.");
                }

                // ✅ Ticket de BARRA (separado del de cocina)
                if (productosBarra.isNotEmpty) {
                  print(
                    "🍺 Imprimiendo ticket BARRA (${productosBarra.length} productos)...",
                  );
                  // Pequeña pausa entre tickets para que la impresora no se sature
                  if (productosCocina.isNotEmpty) {
                    await Future.delayed(const Duration(milliseconds: 1500));
                  }
                  final ticketBarra = _formatearTicketDestino(
                    mesa: mesa,
                    mesero: mesero,
                    folio: folio,
                    destino: 'BARRA',
                    productos: productosBarra,
                  );
                  await imprimirComanda(contenido: ticketBarra);
                  print("✅ Ticket BARRA impreso.");
                }

                print("✅ [CENTRAL] Impresión completada.");
              } catch (e) {
                print("❌ [CENTRAL] Error al imprimir: $e");
              } finally {
                _procesandoImpresion = false;
              }
            }
          }
        });
  }

  String _formatearTicketDestino({
    required int mesa,
    required String mesero,
    required String folio,
    required String destino,
    required List<Map<String, dynamic>> productos,
  }) {
    final hora = DateTime.now().toString().substring(11, 16);
    final fecha = DateTime.now().toString().substring(0, 10);

    String buffer = "================================\n";

    // Encabezado diferente según destino
    if (destino == 'COCINA') {
      buffer += "   🍳      COCINA       🍳\n";
    } else {
      buffer += "   🍺       BARRA       🍺\n";
    }

    buffer += "================================\n";
    buffer += "PEDIDO: $folio\n";
    buffer += "MESA:   $mesa\n";
    buffer += "MESERO: $mesero\n";
    buffer += "FECHA:  $fecha  $hora\n";
    buffer += "--------------------------------\n";
    buffer += "CANT  PRODUCTO\n";
    buffer += "--------------------------------\n";

    for (var p in productos) {
      final cantidad = p['cantidad'].toString().padLeft(3);
      final nombre = (p['nombre'] as String).toUpperCase();
      buffer += "$cantidad   $nombre\n";

      final nota = p['nota']?.toString() ?? '';
      if (nota.isNotEmpty) {
        buffer += "     *** NOTA: $nota ***\n";
      }
    }

    buffer += "================================\n";
    buffer +=
        "TOTAL ITEMS: ${productos.fold(0, (sum, p) => sum + (p['cantidad'] as int))}\n";
    buffer += "================================\n";

    return buffer;
  }

  // ════════════════════════════════════════════════════════
  // CONEXIÓN
  // ════════════════════════════════════════════════════════

  Future<bool> conectarBluetooth({
    required String deviceId,
    required String deviceName,
  }) async {
    try {
      final success = await _printer.connectBluetooth(deviceId);
      if (success) {
        await guardarConexion(
          deviceId: deviceId,
          deviceName: deviceName,
          connectionType: 'bluetooth',
          address: deviceId,
        );
        print('✅ Impresora configurada: $deviceName');
      }
      return success;
    } catch (e) {
      print('❌ Error conectando: $e');
      return false;
    }
  }

  Future<bool> conectarWifi({required String ipAddress}) async {
    try {
      final success = await _printer.connectWifi(ipAddress);
      if (success) {
        await guardarConexion(
          deviceId: 'wifi_$ipAddress',
          deviceName: 'WiFi - $ipAddress',
          connectionType: 'wifi',
          address: ipAddress,
        );
        print('✅ Impresora configurada: $ipAddress');
      }
      return success;
    } catch (e) {
      print('❌ Error conectando: $e');
      return false;
    }
  }

  Future<void> desconectar() async {
    try {
      await _printer.disconnect();
      await limpiarConexion();
      print('🔌 Impresora desconectada');
    } catch (e) {
      print('❌ Error desconectando: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  // RECONEXIÓN ANTES DE IMPRIMIR
  // ════════════════════════════════════════════════════════

  Future<bool> _conectarAntes() async {
    try {
      if (_printerType == null || _printerAddress == null) {
        print('❌ No hay configuración guardada');
        return false;
      }

      print('🔄 Conectando a impresora ($_printerType: $_printerAddress)...');

      try {
        await _printer.disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('⚠️ Error desconectando: $e');
      }

      final bool success = _printerType == 'bluetooth'
          ? await _printer.connectBluetooth(_printerAddress!)
          : await _printer.connectWifi(_printerAddress!);

      if (success) {
        print('✅ Conectado a impresora');
        await Future.delayed(const Duration(milliseconds: 800));
      } else {
        print('❌ No se pudo conectar');
      }

      return success;
    } catch (e) {
      print('❌ Error en _conectarAntes: $e');
      return false;
    }
  }

  Future<bool> _conectarConReintentos({int maxIntentos = 3}) async {
    for (int i = 0; i < maxIntentos; i++) {
      print('🔄 Intento ${i + 1}/$maxIntentos...');
      if (await _conectarAntes()) return true;
      if (i < maxIntentos - 1) {
        print('⏳ Esperando antes del siguiente intento...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    print('❌ Falló después de $maxIntentos intentos');
    return false;
  }

  // ════════════════════════════════════════════════════════
  // MÉTODOS DE IMPRESIÓN
  // ════════════════════════════════════════════════════════

  Future<void> imprimirComanda({required String contenido}) async {
    try {
      print('\n╔════════════════════════════════════════╗');
      print('║  🖨️  IMPRIMIENDO COMANDA               ║');
      print('╚════════════════════════════════════════╝');

      final conectado = await _conectarConReintentos(maxIntentos: 3);
      if (!conectado) {
        throw Exception(
          'No se pudo conectar a la impresora después de 3 intentos',
        );
      }

      await _printer.setPrintWidth(384);
      await _printer.setFontSize(0);
      await _printer.printText(contenido);
      await _printer.printText('\n\n\n');

      try {
        await _printer.cutPaper();
        print('✅ Papel cortado');
      } catch (e) {
        print('⚠️ No se pudo cortar: $e');
      }

      try {
        await _printer.beep();
        print('✅ Beep emitido');
      } catch (e) {
        print('⚠️ No se pudo hacer beep: $e');
      }

      print('╔════════════════════════════════════════╗');
      print('║  ✅ COMANDA IMPRESA                    ║');
      print('╚════════════════════════════════════════╝\n');
    } catch (e) {
      print('❌ Error imprimiendo: $e');
      rethrow;
    }
  }

  Future<void> imprimirTicketCuenta({required String contenido}) async {
    try {
      print('\n╔════════════════════════════════════════╗');
      print('║  🧾 IMPRIMIENDO TICKET DE CUENTA       ║');
      print('╚════════════════════════════════════════╝');

      final conectado = await _conectarAntes();
      if (!conectado) throw Exception('No se pudo conectar a la impresora');

      await _printer.setPrintWidth(384);
      await _printer.setFontSize(0);
      await _printer.printText(contenido);
      await _printer.printText('\n\n\n');

      try {
        await _printer.cutPaper();
      } catch (e) {
        print('⚠️ $e');
      }
      try {
        await _printer.beep();
      } catch (e) {
        print('⚠️ $e');
      }

      print('╔════════════════════════════════════════╗');
      print('║  ✅ TICKET IMPRESO                     ║');
      print('╚════════════════════════════════════════╝\n');
    } catch (e) {
      print('❌ Error imprimiendo ticket: $e');
      rethrow;
    }
  }

  Future<bool> imprimirDirecto(String contenido) async {
    if (!estaConectada()) return false;

    final conectado = await _conectarConReintentos(maxIntentos: 3);
    if (!conectado) return false;

    await _printer.setPrintWidth(384);
    await _printer.setFontSize(0);
    await _printer.printText(contenido);
    await _printer.printText('\n\n\n');

    try {
      await _printer.cutPaper();
      await _printer.beep();
    } catch (e) {
      print('⚠️ Error en corte/beep: $e');
    }

    return true;
  }

  Future<void> imprimirPrueba() async {
    try {
      print('🖨️ Prueba de impresión...');

      final conectado = await _conectarAntes();
      if (!conectado) throw Exception('No se pudo conectar a la impresora');

      await _printer.setPrintWidth(384);
      await _printer.setFontSize(0);

      final mensaje =
          '''
================================
    PRUEBA DE IMPRESIÓN
================================
Impresora: $_printerName
Fecha: ${DateTime.now()}
================================
✅ Si puedes leer esto,
   la impresora funciona
   correctamente.
================================
''';

      await _printer.printText(mensaje);
      await _printer.printText('\n\n\n');

      try {
        await _printer.cutPaper();
      } catch (e) {
        print('⚠️ $e');
      }
      try {
        await _printer.beep();
      } catch (e) {
        print('⚠️ $e');
      }

      print('✅ Prueba impresa');
    } catch (e) {
      print('❌ Error en prueba: $e');
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════
  // MÉTODOS AUXILIARES
  // ════════════════════════════════════════════════════════

  bool estaConectada() => _printerId != null && _printerAddress != null;

  Map<String, dynamic> getInfo() => {
    'conectada': estaConectada(),
    'id': _printerId,
    'name': _printerName,
    'type': _printerType,
    'address': _printerAddress,
  };

  Future<List<Map<String, String>>> buscarImpresoras() async {
    try {
      return await _printer.scanPrinters();
    } catch (e) {
      print('❌ Error buscando impresoras: $e');
      return [];
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// EXTENSIÓN PARA PRODUCTOS
// ═══════════════════════════════════════════════════════════════

extension ProductoExtension on Map<String, dynamic> {
  bool get esBarra {
    final tipo = (this['tipo'] as String?)?.toLowerCase() ?? '';
    if (tipo == 'bebida') return true;
    if (tipo == 'comida') return false;

    if (this['esBarra'] == true) return true;

    final categoria = (this['categoria'] as String?)?.toLowerCase() ?? '';
    return categoria.contains('cerveza') ||
        categoria.contains('aguas frescas') ||
        categoria.contains('preparados') ||
        categoria.contains('vinos') ||
        categoria.contains('mezcal y cafe') ||
        categoria.contains('refrescos') ||
        categoria.contains('bebidas');
  }

  bool get esCocina => !esBarra;
}
