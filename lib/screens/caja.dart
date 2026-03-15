import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '/models/content_card.dart';

class Caja extends StatefulWidget {
  const Caja({Key? key}) : super(key: key);

  @override
  State<Caja> createState() => _CajaState();
}

class _CajaState extends State<Caja> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _cajaActualId;
  Map<String, dynamic>? _cajaActual;
  bool _cargando = true;

  User? _currentUser;
  String? _currentUserName;
  String? _currentUserRole;

  List<Map<String, dynamic>> _usuariosAutorizados = [];

  final NumberFormat currencyFormat = NumberFormat.currency(
    locale: 'en_MX',
    symbol: '\$',
    decimalDigits: 2,
  );

  final DateFormat dateTimeFormat = DateFormat('dd/MM/yy HH:mm');

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _cargarUsuariosAutorizados();
    _verificarCajaAbierta();
  }

  Future<void> _loadCurrentUser() async {
    debugPrint('🚀 Iniciando carga de usuario actual...');

    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser == null) {
      debugPrint('❌ No hay usuario autenticado');
      setState(() => _cargando = false);
      return;
    }

    debugPrint('👤 Usuario autenticado: ${_currentUser!.email}');
    debugPrint('🆔 UID: ${_currentUser!.uid}');

    try {
      // ✅ BUSCAR por campo 'uid' en lugar de por ID del documento
      debugPrint('🔍 Buscando en Firestore por uid: ${_currentUser!.uid}');

      QuerySnapshot query = await _firestore
          .collection('usuarios')
          .where('uid', isEqualTo: _currentUser!.uid)
          .limit(1)
          .get();

      debugPrint('📊 Documentos encontrados: ${query.docs.length}');

      if (query.docs.isNotEmpty) {
        final userDoc = query.docs.first;
        final data = userDoc.data() as Map<String, dynamic>;

        debugPrint('📄 Datos encontrados:');
        debugPrint('   - nombre: ${data['nombre']}');
        debugPrint('   - rol: ${data['rol']}');
        debugPrint('   - email: ${data['email']}');

        setState(() {
          _currentUserName =
              data['nombre'] ?? 'Cajero ID: ${_currentUser!.uid}';
          _currentUserRole = (data['rol'] as String?)?.toLowerCase();
        });

        debugPrint('✅ Usuario cargado correctamente');
        debugPrint('   - Nombre: $_currentUserName');
        debugPrint('   - Rol (minúsculas): $_currentUserRole');
      } else {
        debugPrint('⚠️ No se encontró documento con uid: ${_currentUser!.uid}');
        setState(() {
          _currentUserName = 'Cajero ID: ${_currentUser!.uid}';
          _currentUserRole = 'unknown';
        });
      }
    } catch (e) {
      debugPrint('❌ Error al cargar datos del usuario: $e');
      setState(() {
        _currentUserName = 'Error Cargando Nombre';
        _currentUserRole = 'unknown';
      });
    }
  }

  Future<void> _cargarUsuariosAutorizados() async {
    try {
      final snapshot = await _firestore
          .collection('usuarios')
          .where(
            'rol',
            whereIn: [
              'cajero',
              'administrador',
              'Cajero',
              'Administrador',
              'CAJERO',
              'ADMINISTRADOR',
            ],
          )
          .get();

      setState(() {
        _usuariosAutorizados = snapshot.docs
            .map(
              (doc) => {
                'id': doc.id,
                'nombre': doc.data()['nombre'] ?? 'Sin nombre',
                'rol': (doc.data()['rol'] as String?)?.toLowerCase() ?? '',
              },
            )
            .toList();
      });
    } catch (e) {
      print('Error al cargar usuarios: $e');
    }
  }

  Future<void> _verificarCajaAbierta() async {
    setState(() => _cargando = true);

    try {
      final snapshot = await _firestore
          .collection('cajas')
          .where('estado', isEqualTo: 'abierta')
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _cajaActualId = snapshot.docs.first.id;
          _cajaActual = snapshot.docs.first.data();
        });
      } else {
        setState(() {
          _cajaActualId = null;
          _cajaActual = null;
        });
      }
    } catch (e) {
      print('Error al verificar caja: $e');
    } finally {
      if (_currentUserName != null || _currentUser == null) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _mostrarDialogoAperturaCaja() async {
    debugPrint('==========================================');
    debugPrint('🔍 Intentando abrir caja...');
    debugPrint('   - Usuario: $_currentUserName');
    debugPrint('   - Rol: $_currentUserRole');
    debugPrint('   - UID: ${_currentUser?.uid}');
    debugPrint('==========================================');

    if (_currentUser == null || _currentUserName == null) {
      debugPrint('❌ Error: Usuario o nombre es null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Error: No se pudo cargar la información del usuario logueado.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // ✅ VALIDAR ROL (ahora en minúsculas)
    if (_currentUserRole != 'administrador' && _currentUserRole != 'cajero') {
      debugPrint('❌ Acceso denegado - Rol no autorizado: "$_currentUserRole"');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🚫 Solo administradores y cajeros pueden abrir la caja.\n'
            'Tu rol actual es: "$_currentUserRole"',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    debugPrint('✅ Acceso autorizado - Mostrando diálogo de apertura');

    final formKey = GlobalKey<FormState>();
    final fondoController = TextEditingController(text: '1000');
    String turnoSeleccionado = 'tarde';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.lock_open, color: Colors.green),
              SizedBox(width: 8),
              Text('Apertura de Caja'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                        const Icon(Icons.person, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cajero: $_currentUserName',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: turnoSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Turno',
                      prefixIcon: Icon(Icons.access_time),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'tarde', child: Text('Tarde')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => turnoSeleccionado = v!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: fondoController,
                    decoration: const InputDecoration(
                      labelText: 'Fondo Inicial',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        double.tryParse(v!) == null ? 'Monto inválido' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Abrir Caja'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final cajeroNombre = _currentUserName!;
                  final cajeroId = _currentUser!.uid;

                  Navigator.pop(context);
                  await _abrirCaja(
                    double.parse(fondoController.text),
                    cajeroNombre,
                    cajeroId,
                    turnoSeleccionado,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirCaja(
    double fondo,
    String cajeroNombre,
    String cajeroId,
    String turno,
  ) async {
    try {
      await _firestore.collection('cajas').add({
        'fecha_apertura': FieldValue.serverTimestamp(),
        'fondo_inicial': fondo,
        'cajero': cajeroNombre,
        'cajeroId': cajeroId,
        'turno': turno,
        'estado': 'abierta',
        'total_efectivo': 0.0,
        'total_tarjeta': 0.0,
        'total_transferencia': 0.0,
        'total_propinas': 0.0,
        'total_egresos': 0.0,
        'total_descuentos': 0.0,
        'efectivo_esperado': fondo,
        'notas': '',
      });

      await _verificarCajaAbierta();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✔ Caja abierta por $cajeroNombre'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ✅ NUEVO: Diálogo para aplicar descuentos
  Future<void> _mostrarDialogoDescuento() async {
    if (_cajaActualId == null) return;

    final formKey = GlobalKey<FormState>();
    final montoController = TextEditingController();
    final razonController = TextEditingController();
    String tipoDescuento = 'porcentaje'; // 'porcentaje' o 'monto_fijo'
    String categoriaDescuento = 'cortesia'; // cortesia, promocion, error, otro

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.discount, color: Colors.purple),
              SizedBox(width: 8),
              Text('Aplicar Descuento'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tipo de descuento
                  DropdownButtonFormField<String>(
                    value: tipoDescuento,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Descuento',
                      prefixIcon: Icon(Icons.percent),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'porcentaje',
                        child: Text('Porcentaje (%)'),
                      ),
                      DropdownMenuItem(
                        value: 'monto_fijo',
                        child: Text('Monto Fijo (\$)'),
                      ),
                    ],
                    onChanged: (v) => setDialogState(() => tipoDescuento = v!),
                  ),
                  const SizedBox(height: 16),

                  // Categoría del descuento
                  DropdownButtonFormField<String>(
                    value: categoriaDescuento,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'cortesia',
                        child: Text('Cortesía'),
                      ),
                      DropdownMenuItem(
                        value: 'promocion',
                        child: Text('Promoción'),
                      ),
                      DropdownMenuItem(
                        value: 'error',
                        child: Text('Corrección de Error'),
                      ),
                      DropdownMenuItem(value: 'otro', child: Text('Otro')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => categoriaDescuento = v!),
                  ),
                  const SizedBox(height: 16),

                  // Monto o porcentaje
                  TextFormField(
                    controller: montoController,
                    decoration: InputDecoration(
                      labelText: tipoDescuento == 'porcentaje'
                          ? 'Porcentaje (%)'
                          : 'Monto (\$)',
                      prefixIcon: Icon(
                        tipoDescuento == 'porcentaje'
                            ? Icons.percent
                            : Icons.attach_money,
                      ),
                      border: const OutlineInputBorder(),
                      helperText: tipoDescuento == 'porcentaje'
                          ? 'Ejemplo: 10 para 10%'
                          : 'Ejemplo: 50 para \$50',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Este campo es obligatorio';
                      }
                      final valor = double.tryParse(v);
                      if (valor == null || valor <= 0) {
                        return 'Debe ser un valor positivo';
                      }
                      if (tipoDescuento == 'porcentaje' && valor > 100) {
                        return 'El porcentaje no puede ser mayor a 100%';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Razón del descuento
                  TextFormField(
                    controller: razonController,
                    decoration: const InputDecoration(
                      labelText: 'Razón del Descuento',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(),
                      helperText: 'Explica brevemente el motivo',
                    ),
                    maxLines: 2,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Campo obligatorio' : null,
                  ),

                  const SizedBox(height: 16),

                  // Advertencia
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'El descuento se restará del efectivo esperado',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Aplicar Descuento'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  await _aplicarDescuento(
                    tipoDescuento,
                    categoriaDescuento,
                    double.parse(montoController.text),
                    razonController.text,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NUEVO: Aplicar descuento a la caja
  Future<void> _aplicarDescuento(
    String tipo,
    String categoria,
    double valor,
    String razon,
  ) async {
    if (_cajaActualId == null) return;

    try {
      // Registrar el descuento como un movimiento especial
      await _firestore.collection('movimientos_caja').add({
        'cajaId': _cajaActualId,
        'fecha': FieldValue.serverTimestamp(),
        'tipo': 'descuento',
        'categoria': categoria,
        'tipoDescuento': tipo, // 'porcentaje' o 'monto_fijo'
        'valorDescuento': valor,
        'monto': valor, // Para consistencia con otros movimientos
        'descripcion': razon,
        'cajero': _cajaActual!['cajero'],
        'aplicadoPor': _currentUserName,
      });

      // Actualizar totales de la caja
      final cajaRef = _firestore.collection('cajas').doc(_cajaActualId);

      // El descuento disminuye el efectivo esperado y se suma al total de descuentos
      await cajaRef.update({
        'total_descuentos': FieldValue.increment(valor),
        'efectivo_esperado': FieldValue.increment(-valor),
      });

      await _verificarCajaAbierta();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✔ Descuento aplicado: ${currencyFormat.format(valor)}',
            ),
            backgroundColor: Colors.purple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _mostrarDialogoMovimiento(String tipo) async {
    final formKey = GlobalKey<FormState>();
    final montoController = TextEditingController();
    final descripcionController = TextEditingController();
    String categoriaSeleccionada = tipo == 'ingreso'
        ? 'venta_efectivo'
        : 'compra_ingredientes';

    final categoriasIngreso = {
      'venta_efectivo': 'Venta en Efectivo',
      'venta_tarjeta': 'Venta con Tarjeta',
      'venta_transferencia': 'Venta por Transferencia',
      'venta_paraLlevar': 'Venta para Llevar',
      'propinas': 'Propinas',
      'otros_ingresos': 'Otros Ingresos',
    };

    final categoriasEgreso = {
      'compra_ingredientes': 'Compra de Ingredientes',
      'pago_proveedor': 'Pago a Proveedor',
      'servicios': 'Servicios (luz, agua, gas)',
      'retiro_autorizado': 'Retiro Autorizado',
      'devolucion': 'Devolución a Cliente',
      'otros_egresos': 'Otros Egresos',
    };

    final categorias = tipo == 'ingreso' ? categoriasIngreso : categoriasEgreso;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            tipo == 'ingreso' ? 'Registrar Ingreso' : 'Registrar Egreso',
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: categoriaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: categorias.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => categoriaSeleccionada = v!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: montoController,
                    decoration: const InputDecoration(
                      labelText: 'Monto',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        double.tryParse(v!) == null ? 'Monto inválido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descripcionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  await _registrarMovimiento(
                    tipo,
                    categoriaSeleccionada,
                    double.parse(montoController.text),
                    descripcionController.text,
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registrarMovimiento(
    String tipo,
    String categoria,
    double monto,
    String descripcion,
  ) async {
    if (_cajaActualId == null) return;

    try {
      await _firestore.collection('movimientos_caja').add({
        'cajaId': _cajaActualId,
        'fecha': FieldValue.serverTimestamp(),
        'tipo': tipo,
        'categoria': categoria,
        'monto': monto,
        'descripcion': descripcion,
        'cajero': _cajaActual!['cajero'],
      });

      final cajaRef = _firestore.collection('cajas').doc(_cajaActualId);

      if (tipo == 'ingreso') {
        if (categoria == 'venta_efectivo' || categoria == 'venta_paraLlevar') {
          await cajaRef.update({
            'total_efectivo': FieldValue.increment(monto),
            'efectivo_esperado': FieldValue.increment(monto),
          });
        } else if (categoria == 'venta_tarjeta') {
          await cajaRef.update({'total_tarjeta': FieldValue.increment(monto)});
        } else if (categoria == 'venta_transferencia') {
          await cajaRef.update({
            'total_transferencia': FieldValue.increment(monto),
          });
        } else if (categoria == 'propinas') {
          await cajaRef.update({'total_propinas': FieldValue.increment(monto)});
        }
      } else {
        await cajaRef.update({
          'total_egresos': FieldValue.increment(monto),
          'efectivo_esperado': FieldValue.increment(-monto),
        });
      }

      await _verificarCajaAbierta();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✔ ${tipo == 'ingreso' ? 'Ingreso' : 'Egreso'} registrado',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _mostrarDialogoCierreCaja() async {
    if (_cajaActual == null) return;

    if (_currentUser == null || _currentUserName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Error: No se pudo cargar la información del usuario logueado para el cierre.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final efectivoContadoController = TextEditingController();
    final notasController = TextEditingController();

    // ✅ Solo preseleccionar el usuario actual si existe en la lista autorizada
    final uidActual = _currentUser!.uid;
    String? usuarioCierreId =
        _usuariosAutorizados.any((u) => u['id'] == uidActual)
        ? uidActual
        : null;

    final efectivo_esperado = _cajaActual!['efectivo_esperado'] ?? 0.0;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.lock, color: Colors.red),
              SizedBox(width: 8),
              Text('Cierre de Caja'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: usuarioCierreId,
                    decoration: const InputDecoration(
                      labelText: 'Usuario que cierra',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    items: _usuariosAutorizados.map((usuario) {
                      return DropdownMenuItem<String>(
                        value: usuario['id'],
                        child: Row(
                          children: [
                            Text(usuario['nombre']),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: usuario['rol'] == 'administrador'
                                    ? Colors.purple.shade100
                                    : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                usuario['rol'].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: usuario['rol'] == 'administrador'
                                      ? Colors.purple.shade900
                                      : Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    validator: (v) =>
                        v == null ? 'Selecciona un usuario' : null,
                    onChanged: (v) => setDialogState(() => usuarioCierreId = v),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Efectivo Esperado: ${currencyFormat.format(efectivo_esperado)}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: efectivoContadoController,
                    decoration: const InputDecoration(
                      labelText: 'Efectivo Contado',
                      prefixIcon: Icon(Icons.calculate),
                      helperText: 'Contar todo el efectivo físico en caja',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        double.tryParse(v!) == null ? 'Monto inválido' : null,
                    onChanged: (v) {
                      setDialogState(() {});
                    },
                  ),
                  if (efectivoContadoController.text.isNotEmpty &&
                      double.tryParse(efectivoContadoController.text) !=
                          null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            (double.parse(efectivoContadoController.text) -
                                    efectivo_esperado) ==
                                0
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Diferencia:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            currencyFormat.format(
                              double.parse(efectivoContadoController.text) -
                                  efectivo_esperado,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color:
                                  (double.parse(
                                            efectivoContadoController.text,
                                          ) -
                                          efectivo_esperado) ==
                                      0
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: notasController,
                    decoration: const InputDecoration(
                      labelText: 'Notas / Observaciones',
                      prefixIcon: Icon(Icons.note),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.lock),
              label: const Text('Cerrar Caja'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final usuarioCierre = _usuariosAutorizados.firstWhere(
                    (u) => u['id'] == usuarioCierreId,
                    orElse: () => {'nombre': 'Desconocido'},
                  );

                  Navigator.pop(context);
                  await _cerrarCaja(
                    double.parse(efectivoContadoController.text),
                    notasController.text,
                    usuarioCierre['nombre'],
                    usuarioCierreId!,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cerrarCaja(
    double efectivoContado,
    String notas,
    String usuarioCierreNombre,
    String usuarioCierreId,
  ) async {
    if (_cajaActualId == null) return;

    try {
      final efectivo_esperado = _cajaActual!['efectivo_esperado'] ?? 0.0;
      final diferencia = efectivoContado - efectivo_esperado;

      await _firestore.collection('cajas').doc(_cajaActualId).update({
        'fechaCierre': FieldValue.serverTimestamp(),
        'estado': 'cerrada',
        'efectivoContado': efectivoContado,
        'diferencia': diferencia,
        'notas': notas,
        'cerradoPor': usuarioCierreNombre,
        'cerradoPorId': usuarioCierreId,
      });

      setState(() {
        _cajaActualId = null;
        _cajaActual = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              diferencia == 0
                  ? "✔ Caja cerrada por $usuarioCierreNombre - Sin diferencias"
                  : "✔ Caja cerrada por $usuarioCierreNombre - Diferencia: ${currencyFormat.format(diferencia)}",
            ),
            backgroundColor: diferencia == 0 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando || _currentUserName == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool cajaAbierta = _cajaActualId != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ContentCard(
        title: 'Gestión de Caja',
        child: Column(
          children: [
            _buildEstadoCaja(cajaAbierta),
            const SizedBox(height: 24),

            if (!cajaAbierta) ...[
              ElevatedButton.icon(
                onPressed: _mostrarDialogoAperturaCaja,
                icon: const Icon(Icons.lock_open),
                label: const Text('Abrir Caja'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],

            if (cajaAbierta) ...[
              _buildInfoCards(),
              const SizedBox(height: 24),

              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _mostrarDialogoMovimiento('ingreso'),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Registrar Ingreso'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _mostrarDialogoMovimiento('egreso'),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Registrar Egreso'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                  // ✅ NUEVO: Botón para aplicar descuentos
                  ElevatedButton.icon(
                    onPressed: _mostrarDialogoDescuento,
                    icon: const Icon(Icons.discount),
                    label: const Text('Aplicar Descuento'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _mostrarDialogoCierreCaja,
                    icon: const Icon(Icons.lock),
                    label: const Text('Cerrar Caja'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildMovimientosDelDia(),
            ],

            const SizedBox(height: 24),
            _buildHistorialCierres(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    Color color, {
    IconData? icon,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCards() {
    if (_cajaActual == null) return const SizedBox();

    final fondo_inicial = _cajaActual!['fondo_inicial'] ?? 0.0;
    final total_efectivo = _cajaActual!['total_efectivo'] ?? 0.0;
    final total_tarjeta = _cajaActual!['total_tarjeta'] ?? 0.0;
    final total_transferencia = _cajaActual!['total_transferencia'] ?? 0.0;
    final total_propinas = _cajaActual!['total_propinas'] ?? 0.0;
    final total_egresos = _cajaActual!['total_egresos'] ?? 0.0;
    final total_descuentos = _cajaActual!['total_descuentos'] ?? 0.0;
    final efectivo_esperado = _cajaActual!['efectivo_esperado'] ?? 0.0;

    // Ingresos totales = efectivo + tarjeta + transferencia + propinas
    final total_ingresos =
        total_efectivo + total_tarjeta + total_transferencia + total_propinas;

    return Column(
      children: [
        // ── Fila superior: Fondo Inicial | Ingresos Totales ──
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                'Fondo Inicial',
                currencyFormat.format(fondo_inicial),
                Colors.blue.shade600,
                icon: Icons.account_balance_wallet,
              ),
            ),
            Expanded(
              child: _buildInfoCard(
                'Ingresos Totales',
                currencyFormat.format(total_ingresos),
                Colors.green.shade600,
                icon: Icons.trending_up,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Fila de desglose por método de pago ──
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                'Efectivo',
                currencyFormat.format(total_efectivo),
                Colors.green.shade700,
                icon: Icons.attach_money,
              ),
            ),
            Expanded(
              child: _buildInfoCard(
                'Tarjeta',
                currencyFormat.format(total_tarjeta),
                Colors.blue.shade700,
                icon: Icons.credit_card,
              ),
            ),
            Expanded(
              child: _buildInfoCard(
                'Transferencia',
                currencyFormat.format(total_transferencia),
                Colors.purple.shade700,
                icon: Icons.account_balance,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Fila inferior: Efectivo Esperado | Egresos Totales ──
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                'Efectivo Esperado',
                currencyFormat.format(efectivo_esperado),
                Colors.red.shade600,
                icon: Icons.calculate,
              ),
            ),
            Expanded(
              child: _buildInfoCard(
                'Egresos Totales',
                currencyFormat.format(total_egresos),
                Colors.orange.shade600,
                icon: Icons.trending_down,
              ),
            ),
          ],
        ),

        // ── Descuentos (solo si hay) ──
        if (total_descuentos > 0) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Descuentos Aplicados',
                  currencyFormat.format(total_descuentos),
                  Colors.purple.shade600,
                  icon: Icons.discount,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEstadoCaja(bool abierta) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: abierta ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: abierta ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            abierta ? Icons.check_circle : Icons.cancel,
            color: abierta ? Colors.green : Colors.red,
            size: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  abierta ? 'Caja Abierta' : 'Caja Cerrada',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: abierta
                        ? Colors.green.shade900
                        : Colors.red.shade900,
                  ),
                ),
                if (abierta && _cajaActual != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Cajero: ${_cajaActual!['cajero']} - Turno: ${_cajaActual!['turno']}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovimientosDelDia() {
    if (_cajaActualId == null) {
      return const ContentCard(
        title: 'Movimientos del Día',
        child: Center(
          child: Text(
            'No hay caja abierta para registrar movimientos.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    const categoryNames = {
      'venta_efectivo': 'Venta Efectivo',
      'venta_tarjeta': 'Venta Tarjeta',
      'venta_transferencia': 'Venta Transferencia',
      'venta_paraLlevar': 'Venta Para Llevar',
      'propinas': 'Propinas',
      'otros_ingresos': 'Otros Ingresos',
      'compra_ingredientes': 'Compra Ingredientes',
      'pago_proveedor': 'Pago Proveedor',
      'servicios': 'Servicios',
      'retiro_autorizado': 'Retiro',
      'devolucion': 'Devolución',
      'otros_egresos': 'Otros Egresos',
      // ✅ NUEVO: Categorías de descuentos
      'cortesia': 'Cortesía',
      'promocion': 'Promoción',
      'error': 'Corrección',
      'otro': 'Otro Descuento',
    };

    return ContentCard(
      title: 'Movimientos del Día',
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('movimientos_caja')
            .where('cajaId', isEqualTo: _cajaActualId)
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay movimientos registrados.'));
          }

          final movimientos = snapshot.data!.docs;

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: movimientos.length,
            itemBuilder: (context, index) {
              final movimiento = movimientos[index];
              final data = movimiento.data() as Map<String, dynamic>;
              final tipo = data['tipo'] as String;
              final monto = data['monto'] ?? 0.0;
              final categoria = data['categoria'] as String;
              final descripcion = data['descripcion'] ?? 'Sin descripción';
              final fecha = (data['fecha'] as Timestamp?)?.toDate();

              // ✅ NUEVO: Manejo especial para descuentos
              final isIngreso = tipo == 'ingreso';
              final isDescuento = tipo == 'descuento';

              final color = isDescuento
                  ? Colors.purple.shade700
                  : isIngreso
                  ? Colors.green.shade700
                  : Colors.red.shade700;

              final icon = isDescuento
                  ? Icons.discount
                  : isIngreso
                  ? Icons.arrow_upward
                  : Icons.arrow_downward;

              final sign = isDescuento
                  ? '-'
                  : isIngreso
                  ? '+'
                  : '-';

              final categoryText = categoryNames[categoria] ?? categoria;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(icon, color: color),
                ),
                title: Text(
                  '$sign ${currencyFormat.format(monto)} (${isDescuento ? 'DESCUENTO - ' : ''}$categoryText)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                subtitle: Text('$descripcion\nCajero: ${data['cajero']}'),
                trailing: Text(
                  fecha != null ? dateTimeFormat.format(fecha) : '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHistorialCierres() {
    return ContentCard(
      title: 'Historial de Cierres de Caja (Cortes Anteriores)',
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('cajas')
            .where('estado', isEqualTo: 'cerrada')
            .orderBy('fechaCierre', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No hay cierres de caja registrados.'),
            );
          }

          final cierres = snapshot.data!.docs;

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cierres.length,
            itemBuilder: (context, index) {
              final cierre = cierres[index];
              final data = cierre.data() as Map<String, dynamic>;
              final fechaCierre = (data['fechaCierre'] as Timestamp?)?.toDate();
              final diferencia = data['diferencia'] ?? 0.0;
              final fondo = data['fondo_inicial'] ?? 0.0;
              final contado = data['efectivoContado'] ?? 0.0;
              final descuentos = data['total_descuentos'] ?? 0.0; // ✅ NUEVO

              final color = diferencia == 0
                  ? Colors.green
                  : diferencia > 0
                  ? Colors.orange.shade800
                  : Colors.red.shade800;
              final diffText = diferencia == 0
                  ? 'Sin diferencia'
                  : 'Diferencia: ${currencyFormat.format(diferencia)}';

              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: Icon(Icons.archive, color: color),
                  title: Text(
                    'Corte del ${fechaCierre != null ? dateTimeFormat.format(fechaCierre) : 'Fecha Desconocida'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Cajero de Apertura: ${data['cajero']}\n'
                    'Cerrado por: ${data['cerradoPor']}\n'
                    'Fondo Inicial: ${currencyFormat.format(fondo)}'
                    '${descuentos > 0 ? '\nDescuentos: ${currencyFormat.format(descuentos)}' : ''}', // ✅ NUEVO
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFormat.format(contado),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        diffText,
                        style: TextStyle(color: color, fontSize: 12),
                      ),
                    ],
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Corte seleccionado: ${cierre.id}'),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
