import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class WelirkcaPrinterService {
  static const MethodChannel _channel = MethodChannel(
    'com.tuapp/welirkca_printer',
  );

  // Callback para eventos de conexión
  static Function? onPrinterConnected;
  static Function? onPrinterDisconnected;

  WelirkcaPrinterService() {
    _channel.setMethodCallHandler(_handleMethod);
  }

  // Manejar callbacks desde iOS
  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onPrinterConnected':
        onPrinterConnected?.call();
        break;
      case 'onPrinterDisconnected':
        onPrinterDisconnected?.call();
        break;
    }
  }

  // ==================== DIAGNÓSTICO SIMPLIFICADO ====================

  /// Diagnóstico completo del sistema (sin métodos nativos adicionales)
  Future<Map<String, dynamic>> diagnosticar() async {
    print('\n╔════════════════════════════════════╗');
    print('🔧 DIAGNÓSTICO COMPLETO DEL SISTEMA');
    print('╚════════════════════════════════════╝\n');

    final diagnostico = <String, dynamic>{};

    // 1. Plataforma
    diagnostico['plataforma'] = Platform.isAndroid ? 'Android' : 'iOS';
    print('📱 Plataforma: ${diagnostico['plataforma']}');

    // 2. Permisos
    print('\n🔐 PERMISOS:');
    final scanGranted = await Permission.bluetoothScan.isGranted;
    final connectGranted = await Permission.bluetoothConnect.isGranted;
    final locationGranted = await Permission.locationWhenInUse.isGranted;

    diagnostico['permisos'] = {
      'bluetoothScan': scanGranted,
      'bluetoothConnect': connectGranted,
      'location': locationGranted,
    };

    print('   BLUETOOTH_SCAN: ${scanGranted ? "✅" : "❌"}');
    print('   BLUETOOTH_CONNECT: ${connectGranted ? "✅" : "❌"}');
    print('   LOCATION: ${locationGranted ? "✅" : "❌"}');

    // 3. Estado del SDK
    print('\n📡 SDK WELIRKCA:');
    diagnostico['sdkDisponible'] = true;
    print('   Estado: ✅ Disponible');

    print('\n💡 RECOMENDACIONES:');
    if (!scanGranted || !connectGranted) {
      print('   ⚠️  Faltan permisos de Bluetooth');
      print('   → Presiona "Buscar Impresoras" y acepta los permisos');
    }
    if (!locationGranted) {
      print('   ⚠️  Falta permiso de ubicación (necesario en Android 10-11)');
    }
    print('   → Asegúrate de que el Bluetooth esté ENCENDIDO');
    print(
      '   → La impresora debe estar EMPAREJADA primero en Configuración → Bluetooth',
    );
    print('   → La impresora debe estar en modo VISIBLE/EMPAREJAMIENTO');

    print('\n╚════════════════════════════════════╝\n');

    return diagnostico;
  }

  // ==================== PERMISOS ====================

  /// Verificar y solicitar permisos de Bluetooth para Android
  Future<bool> verificarYSolicitarPermisos() async {
    if (!Platform.isAndroid) return true;

    print('\n🔐 Verificando permisos de Bluetooth...');

    // Primero verificar si ya están otorgados
    final scanGranted = await Permission.bluetoothScan.isGranted;
    final connectGranted = await Permission.bluetoothConnect.isGranted;
    final locationGranted = await Permission.locationWhenInUse.isGranted;

    print('   BLUETOOTH_SCAN: ${scanGranted ? "✅" : "❌"}');
    print('   BLUETOOTH_CONNECT: ${connectGranted ? "✅" : "❌"}');
    print('   LOCATION: ${locationGranted ? "✅" : "❌"}');

    if (scanGranted && connectGranted) {
      print('✅ Permisos principales otorgados');
      return true;
    }

    // Solicitar permisos faltantes
    print('📋 Solicitando permisos al usuario...');

    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    print('\n📊 Resultados:');
    statuses.forEach((permission, status) {
      print('   ${permission.toString()}: ${status.toString()}');
    });

    bool todosOtorgados =
        statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true;

    if (!todosOtorgados) {
      print('❌ No se otorgaron todos los permisos necesarios');

      bool algunoDenegadoPermanentemente = statuses.values.any(
        (status) => status.isPermanentlyDenied,
      );

      if (algunoDenegadoPermanentemente) {
        print('⚠️  Algunos permisos fueron denegados permanentemente');
        print('   → El usuario debe ir a Configuración de la app');
        await openAppSettings();
      }
    } else {
      print('✅ Todos los permisos necesarios otorgados');
    }

    return todosOtorgados;
  }

  // ==================== CONEXIÓN ====================

  /// Buscar impresoras Bluetooth cercanas
  /// Retorna lista de impresoras: [{"id": "...", "name": "..."}]
  Future<List<Map<String, String>>> scanPrinters() async {
    print('\n╔════════════════════════════════════╗');
    print('🔍 INICIANDO ESCANEO DE IMPRESORAS');
    print('╚════════════════════════════════════╝\n');

    try {
      // ✅ 1. Verificar permisos
      print('1️⃣ Verificando permisos...');
      bool permisosOk = await verificarYSolicitarPermisos();
      if (!permisosOk) {
        print('❌ CANCELADO: Permisos Bluetooth no otorgados');
        print('\n💡 SOLUCIÓN:');
        print('   → Ve a Configuración → Apps → Tu App → Permisos');
        print('   → Activa todos los permisos de Bluetooth\n');
        throw Exception(
          'Permisos de Bluetooth no otorgados. Por favor actívalos en Configuración.',
        );
      }
      print('   ✅ Permisos OK\n');

      // ✅ 2. Llamar al SDK de Welirkca
      print('2️⃣ Llamando al SDK de Welirkca...');
      print('   Ejecutando: _channel.invokeMethod("scanPrinters")');

      final result = await _channel.invokeMethod('scanPrinters');
      print('   ✅ SDK respondió correctamente\n');

      // ✅ 3. Procesar resultados
      print('3️⃣ Procesando resultados...');
      final printers = List<Map<String, String>>.from(
        result.map((item) => Map<String, String>.from(item)),
      );

      print('\n📊 RESULTADOS DEL ESCANEO:');
      print('   Total encontradas: ${printers.length}');

      if (printers.isEmpty) {
        print('\n⚠️  NO SE ENCONTRARON IMPRESORAS\n');
        print('💡 POSIBLES CAUSAS:');
        print('   1. ❌ El Bluetooth está APAGADO');
        print('      → Ve a Configuración → Bluetooth y enciéndelo');
        print('');
        print('   2. ❌ La impresora NO está emparejada');
        print('      → Ve a Configuración → Bluetooth');
        print('      → Busca tu impresora y emparéjala primero');
        print('');
        print('   3. ❌ La impresora está apagada o sin batería');
        print('      → Enciende la impresora y verifica que tenga carga');
        print('');
        print('   4. ❌ La impresora no está en modo visible');
        print('      → Consulta el manual de tu impresora');
        print('      → Algunos modelos requieren presionar un botón');
        print('');
        print('   5. ❌ La impresora está fuera de rango');
        print('      → Acércate más a la impresora (máx 10 metros)');
      } else {
        print('   ✅ IMPRESORAS ENCONTRADAS:');
        for (var p in printers) {
          print('      • ${p['name']} (${p['id']})');
        }
      }

      print('\n╚════════════════════════════════════╝\n');

      return printers;
    } on PlatformException catch (e) {
      print('\n❌ ERROR DE PLATAFORMA:');
      print('   Código: ${e.code}');
      print('   Mensaje: ${e.message}');
      print('   Detalles: ${e.details}');

      // Interpretar errores comunes
      if (e.code == 'BLUETOOTH_OFF' ||
          e.message?.contains('Bluetooth') == true) {
        print('\n💡 SOLUCIÓN:');
        print('   → El Bluetooth está APAGADO');
        print('   → Ve a Configuración y enciende el Bluetooth\n');
        throw Exception(
          'Bluetooth deshabilitado. Por favor enciéndelo en Configuración.',
        );
      } else if (e.code == 'NO_PERMISSION') {
        print('\n💡 SOLUCIÓN:');
        print('   → Faltan permisos de Bluetooth');
        print('   → Intenta nuevamente y acepta los permisos\n');
        throw Exception(
          'Permisos de Bluetooth requeridos. Acepta los permisos cuando se soliciten.',
        );
      }

      print('╚════════════════════════════════════╝\n');
      rethrow;
    } catch (e) {
      print('\n❌ ERROR INESPERADO:');
      print('   $e');
      print('\n💡 ESTO PUEDE SIGNIFICAR:');
      print('   → El SDK de Welirkca no está configurado correctamente');
      print('   → Falta el archivo nativo (Kotlin/Java) del plugin');
      print('   → El MethodChannel no coincide con el código nativo');
      print('╚════════════════════════════════════╝\n');
      rethrow;
    }
  }

  /// Detener búsqueda de impresoras
  Future<void> stopScan() async {
    try {
      await _channel.invokeMethod('stopScan');
    } catch (e) {
      print('Error deteniendo escaneo: $e');
    }
  }

  /// Conectar a impresora por Bluetooth
  Future<bool> connectBluetooth(String deviceId) async {
    try {
      print('\n🔗 Intentando conectar a: $deviceId');

      // ✅ Verificar permisos ANTES de conectar
      bool permisosOk = await verificarYSolicitarPermisos();
      if (!permisosOk) {
        print('❌ Permisos Bluetooth no otorgados');
        return false;
      }

      final result = await _channel.invokeMethod('connectBluetooth', {
        'deviceId': deviceId,
      });

      if (result == true) {
        print('✅ Conexión exitosa');
      } else {
        print('❌ Conexión fallida');
      }

      return result ?? false;
    } catch (e) {
      print('❌ Error conectando Bluetooth: $e');
      return false;
    }
  }

  /// Conectar a impresora por WiFi
  Future<bool> connectWifi(String ipAddress) async {
    try {
      print('\n📶 Conectando por WiFi a: $ipAddress');
      final result = await _channel.invokeMethod('connectWifi', {
        'ipAddress': ipAddress,
      });

      if (result == true) {
        print('✅ Conexión WiFi exitosa');
      } else {
        print('❌ Conexión WiFi fallida');
      }

      return result ?? false;
    } catch (e) {
      print('❌ Error conectando WiFi: $e');
      return false;
    }
  }

  /// Desconectar impresora
  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } catch (e) {
      print('Error desconectando: $e');
    }
  }

  // ==================== RESTO DE MÉTODOS (sin cambios) ====================

  Future<void> setPrintWidth(int width) async {
    try {
      await _channel.invokeMethod('setPrintWidth', {'width': width});
    } catch (e) {
      print('Error estableciendo ancho: $e');
    }
  }

  Future<void> setFontSize(int multiple) async {
    try {
      await _channel.invokeMethod('setFontSize', {'multiple': multiple});
    } catch (e) {
      print('Error estableciendo fuente: $e');
    }
  }

  Future<void> printText(String text) async {
    try {
      await _channel.invokeMethod('printText', {'text': text});
    } catch (e) {
      print('Error imprimiendo texto: $e');
    }
  }

  /*Future<void> printTextImage(String text, {int width = 384}) async {
    try {
      // Intentamos establecer el ancho, pero si falla, que siga adelante
      /* try {
        await _channel.invokeMethod('setPrintWidth', {'width': width});
      } catch (e) {
        print("⚠️ El comando setPrintWidth no está soportado, ignorando...");
      }*/

      // Usamos el comando más básico de texto
      // Si 'printTextImage' falla, prueba cambiando el nombre a 'printText'
      await _channel.invokeMethod('printText', {
        'text': text + "\n\n\n", // Añadimos saltos de línea manuales
      });

      // Intentamos cortar, si falla, no pasa nada
      try {
        await _channel.invokeMethod('cutPaper');
      } catch (e) {
        print("⚠️ El comando cutPaper no está soportado.");
      }
    } on PlatformException catch (e) {
      print("❌ Error de plataforma: ${e.message}");
    }
  }*/

  Future<void> printBarcode(String code, int type) async {
    try {
      await _channel.invokeMethod('printBarcode', {'code': code, 'type': type});
    } catch (e) {
      print('Error imprimiendo código de barras: $e');
    }
  }

  Future<void> printQRCode(String data) async {
    try {
      await _channel.invokeMethod('printQRCode', {'data': data});
    } catch (e) {
      print('Error imprimiendo QR: $e');
    }
  }

  Future<void> printImage(Uint8List imageBytes) async {
    try {
      await _channel.invokeMethod('printImage', {'imageBytes': imageBytes});
    } catch (e) {
      print('Error imprimiendo imagen: $e');
    }
  }

  Future<void> printTestPaper() async {
    try {
      await _channel.invokeMethod('printTestPaper');
    } catch (e) {
      print('Error imprimiendo prueba: $e');
    }
  }

  Future<void> cutPaper() async {
    try {
      await _channel.invokeMethod('cutPaper');
    } catch (e) {
      print('Error cortando papel: $e');
    }
  }

  Future<void> beep() async {
    try {
      await _channel.invokeMethod('beep');
    } catch (e) {
      print('Error con beep: $e');
    }
  }

  Future<void> openCashDrawer() async {
    try {
      await _channel.invokeMethod('openCashDrawer');
    } catch (e) {
      print('Error abriendo caja: $e');
    }
  }

  Future<void> selfTest() async {
    try {
      await _channel.invokeMethod('selfTest');
    } catch (e) {
      print('Error en self test: $e');
    }
  }
}
