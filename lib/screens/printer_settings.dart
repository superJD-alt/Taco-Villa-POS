import 'package:flutter/material.dart';
import '/models/printer_manager.dart';
import 'package:permission_handler/permission_handler.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({Key? key}) : super(key: key);

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final PrinterManager _printerManager = PrinterManager();

  List<Map<String, String>> _printers = [];
  bool _isScanning = false;

  bool _conectada = false;
  String? _printerName;

  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  Future<void> _cargarConfiguracion() async {
    await _printerManager.cargarConfiguracion();
    setState(() {
      final info = _printerManager.getInfo();
      _conectada = info['conectada'] ?? false;
      _printerName = info['name'];

      // Pre-cargar IP si era WiFi
      final address = info['address'] as String?;
      if (info['type'] == 'wifi' && address != null) {
        _ipController.text = address;
      }
    });
  }

  // ════════════════════════════════════════════════════════
  // PERMISOS BLUETOOTH
  // ════════════════════════════════════════════════════════

  Future<bool> _solicitarPermisosBluetooth() async {
    if (await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted) {
      return true;
    }

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    final todosOtorgados = statuses.values.every((status) => status.isGranted);

    if (!todosOtorgados && mounted) {
      // Verificar si fue denegado permanentemente
      final scanDenied = await Permission.bluetoothScan.isPermanentlyDenied;
      final connectDenied =
          await Permission.bluetoothConnect.isPermanentlyDenied;

      if (scanDenied || connectDenied) {
        _mostrarDialogoConfiguracion();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Se necesitan permisos de Bluetooth para buscar impresoras',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }

    return todosOtorgados;
  }

  void _mostrarDialogoConfiguracion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings, color: Colors.orange),
            SizedBox(width: 10),
            Text('Permisos Requeridos'),
          ],
        ),
        content: const Text(
          'Los permisos de Bluetooth fueron denegados permanentemente.\n\n'
          'Para usar esta función, debes habilitarlos manualmente en '
          'la configuración de la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Abrir Configuración'),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // ESCANEO Y CONEXIÓN
  // ════════════════════════════════════════════════════════

  Future<void> _scanForPrinters() async {
    final permisosOk = await _solicitarPermisosBluetooth();
    if (!permisosOk) return;

    setState(() {
      _isScanning = true;
      _printers.clear();
    });

    try {
      final printers = await _printerManager.buscarImpresoras();
      setState(() {
        _printers = printers;
        _isScanning = false;
      });

      if (_printers.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ No se encontraron impresoras. Verifica que el Bluetooth '
              'esté encendido y la impresora esté en modo emparejamiento.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_printers.length} impresora(s) encontrada(s)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al buscar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _connectBluetooth(String deviceId, String deviceName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await _printerManager.conectarBluetooth(
        deviceId: deviceId,
        deviceName: deviceName,
      );

      Navigator.pop(context);

      if (success) {
        await _cargarConfiguracion();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Conectada: $deviceName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No se pudo conectar a la impresora'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _connectWifi() async {
    final ip = _ipController.text.trim();

    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Ingresa una dirección IP'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await _printerManager.conectarWifi(ipAddress: ip);
      Navigator.pop(context);

      if (success) {
        await _cargarConfiguracion();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Conectada por WiFi: $ip'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No se pudo conectar por WiFi'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    await _printerManager.desconectar();
    await _cargarConfiguracion();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔌 Impresora desconectada'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _printTest() async {
    if (!_printerManager.estaConectada()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Conecta una impresora primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _printerManager.imprimirPrueba();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Prueba enviada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error en prueba: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Impresora'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 24),
            _buildConnectionSection(),
            const SizedBox(height: 24),
            if (_conectada) _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // ─── Tarjeta de estado ───────────────────────────────────

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              _conectada ? Icons.print : Icons.print_disabled,
              size: 64,
              color: _conectada ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _conectada ? '🟢 CONECTADA' : '🔴 DESCONECTADA',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _conectada ? Colors.green : Colors.grey,
              ),
            ),
            if (_printerName != null) ...[
              const SizedBox(height: 8),
              Text(
                _printerName!,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Sección de conexión con tabs BT / WiFi ──────────────

  Widget _buildConnectionSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              labelColor: Colors.blue.shade700,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue.shade700,
              tabs: const [
                Tab(icon: Icon(Icons.bluetooth), text: 'Bluetooth'),
                Tab(icon: Icon(Icons.wifi), text: 'WiFi'),
              ],
            ),
            SizedBox(
              height: 320,
              child: TabBarView(
                children: [_buildBluetoothTab(), _buildWiFiTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _isScanning ? null : _scanForPrinters,
            icon: _isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.search),
            label: Text(_isScanning ? 'Buscando...' : 'BUSCAR IMPRESORAS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _printers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.bluetooth_searching,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Presiona "Buscar" para escanear',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _printers.length,
                    itemBuilder: (context, index) {
                      final printer = _printers[index];
                      final isSelected =
                          printer['id'] == _printerManager.getInfo()['id'];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isSelected ? Colors.green.shade50 : null,
                        child: ListTile(
                          leading: Icon(
                            isSelected ? Icons.print : Icons.bluetooth,
                            color: isSelected ? Colors.green : Colors.blue,
                          ),
                          title: Text(
                            printer['name'] ?? 'Sin nombre',
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            printer['id'] ?? '',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => _connectBluetooth(
                            printer['id']!,
                            printer['name']!,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWiFiTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Conectar por dirección IP',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ipController,
            decoration: InputDecoration(
              labelText: 'Dirección IP',
              hintText: '192.168.1.100',
              prefixIcon: const Icon(Icons.computer),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _connectWifi,
            icon: const Icon(Icons.wifi),
            label: const Text('CONECTAR POR WiFi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Instrucciones:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '1. Asegúrate de que la impresora esté en la misma red WiFi',
                  style: TextStyle(fontSize: 12),
                ),
                SizedBox(height: 4),
                Text(
                  '2. Encuentra la IP en la configuración de red de la impresora',
                  style: TextStyle(fontSize: 12),
                ),
                SizedBox(height: 4),
                Text(
                  '3. Ingresa la dirección IP completa',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Botones de acción (solo visibles si está conectada) ──

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _printTest,
            icon: const Icon(Icons.print),
            label: const Text('IMPRIMIR PRUEBA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _disconnect,
            icon: const Icon(Icons.close),
            label: const Text('DESCONECTAR'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }
}
