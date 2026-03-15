import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/models/content_card.dart';

class Usuarios extends StatefulWidget {
  const Usuarios({Key? key}) : super(key: key);

  @override
  State<Usuarios> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<Usuarios> {
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _codigoUsuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  String _rolSeleccionado = 'Cajero';
  String _estadoSeleccionado = 'Activo';
  bool _isFirebaseInitialized = false;
  bool _isEditMode = false;
  String? _userIdEnEdicion;

  final List<String> rolesDisponibles = [
    'Administrador',
    'Cajero',
    'Mesero',
    'Cocinero',
  ];

  final List<String> estadosDisponibles = ['Activo', 'Inactivo'];

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    try {
      _firestore = FirebaseFirestore.instance;
      _auth = FirebaseAuth.instance;
      setState(() {
        _isFirebaseInitialized = true;
      });
    } catch (e) {
      print('Error inicializando Firebase: $e');
      setState(() {
        _isFirebaseInitialized = false;
      });
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _codigoUsuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _limpiarFormulario() {
    _nombreController.clear();
    _codigoUsuarioController.clear();
    _passwordController.clear();
    _rolSeleccionado = 'Cajero';
    _estadoSeleccionado = 'Activo';
    _isEditMode = false;
    _userIdEnEdicion = null;
  }

  // ✅ CREAR USUARIO DIRECTAMENTE EN FIRESTORE (sin afectar sesión del admin)
  Future<void> _crearUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      _mostrarCargando(context);

      // Construir el email completo con @pv.com
      final codigoUsuario = _codigoUsuarioController.text.trim();
      final emailCompleto = '$codigoUsuario@pv.com';

      // Verificar si el email ya existe
      final existeEmail = await _firestore!
          .collection('usuarios')
          .where('email', isEqualTo: emailCompleto)
          .get();

      if (existeEmail.docs.isNotEmpty) {
        Navigator.of(context).pop();
        _mostrarSnackBar(
          'El código de usuario ya está registrado',
          Colors.orange,
        );
        return;
      }

      // Crear usuario en Firestore con contraseña temporal
      final docRef = await _firestore!.collection('usuarios').add({
        'nombre': _nombreController.text.trim(),
        'email': emailCompleto, // ✅ Email completo con @pv.com
        'passwordTemporal': _passwordController.text,
        'rol': _rolSeleccionado,
        'estado': _estadoSeleccionado,
        'sesionActiva': false,
        'emailVerificado': false,
        'cuentaCreada': false,
        'fechaCreacion': FieldValue.serverTimestamp(),
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });

      Navigator.of(context).pop();
      Navigator.of(context).pop();

      _mostrarDialogoInstrucciones(codigoUsuario, _passwordController.text);

      _limpiarFormulario();
    } catch (e) {
      Navigator.of(context).pop();
      _mostrarSnackBar('Error al crear usuario: $e', Colors.red);
    }
  }

  void _mostrarDialogoInstrucciones(String codigoUsuario, String password) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Usuario Creado'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'El usuario ha sido registrado exitosamente.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                '🔧 Credenciales de acceso:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Usuario: $codigoUsuario',
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Contraseña: $password',
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Email generado: $codigoUsuario@pv.com',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '⚠️ IMPORTANTE:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Guarde estas credenciales\n'
                '2. Para iniciar sesión, use solo el código de usuario (números)\n'
                '3. Al primer login, la cuenta se activará automáticamente',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ✅ SOLICITAR CONTRASEÑA DEL ADMINISTRADOR
  Future<String?> _solicitarPasswordAdmin() async {
    final passwordController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock, color: Colors.orange),
              SizedBox(width: 8),
              Text('Verificación de Administrador'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para crear un nuevo usuario, confirme su contraseña de administrador:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña de administrador',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    Navigator.of(context).pop(value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                passwordController.dispose();
                Navigator.of(context).pop(null);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final password = passwordController.text;
                passwordController.dispose();
                if (password.isEmpty) {
                  _mostrarSnackBar(
                    'Debe ingresar la contraseña',
                    Colors.orange,
                  );
                  return;
                }
                Navigator.of(context).pop(password);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  // ✅ ACTUALIZAR USUARIO (Solo Firestore, email no se puede cambiar fácilmente)
  Future<void> _actualizarUsuario() async {
    if (!_formKey.currentState!.validate() || _userIdEnEdicion == null) return;

    try {
      _mostrarCargando(context);

      // Preparar datos para actualizar
      Map<String, dynamic> datosActualizar = {
        'nombre': _nombreController.text.trim(),
        'rol': _rolSeleccionado,
        'estado': _estadoSeleccionado,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      };

      // Actualizar en Firestore
      await _firestore!
          .collection('usuarios')
          .doc(_userIdEnEdicion)
          .update(datosActualizar);

      Navigator.of(context).pop(); // Cerrar loading
      Navigator.of(context).pop(); // Cerrar diálogo

      _mostrarSnackBar('Usuario actualizado exitosamente', Colors.blue);
      _limpiarFormulario();
    } catch (e) {
      Navigator.of(context).pop(); // Cerrar loading
      _mostrarSnackBar('Error al actualizar usuario: $e', Colors.red);
    }
  }

  // ✅ ELIMINAR USUARIO DE AUTHENTICATION Y FIRESTORE
  Future<void> _eliminarUsuario(String userId, String nombre) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Está seguro de eliminar a $nombre?'),
              const SizedBox(height: 8),
              const Text(
                '⚠️ Esta acción eliminará el usuario de Authentication y Firestore',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nota: Necesitas Cloud Functions para eliminar de Authentication',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Cerrar diálogo de confirmación

                try {
                  _mostrarCargando(context);

                  // Eliminar de Firestore
                  await _firestore!.collection('usuarios').doc(userId).delete();

                  // ⚠️ Para eliminar de Authentication necesitas Cloud Functions
                  // Por ahora solo eliminamos de Firestore

                  Navigator.of(context).pop(); // Cerrar loading

                  _mostrarSnackBar(
                    'Usuario eliminado de Firestore. Para eliminar de Authentication usa Cloud Functions.',
                    Colors.orange,
                  );
                } catch (e) {
                  Navigator.of(context).pop(); // Cerrar loading
                  _mostrarSnackBar('Error al eliminar usuario: $e', Colors.red);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  // ✅ REENVIAR EMAIL DE VERIFICACIÓN
  Future<void> _reenviarEmailVerificacion(String userId, String email) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reenviar verificación'),
          content: Text('¿Reenviar email de verificación a $email?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                _mostrarSnackBar(
                  'Funcionalidad disponible solo con Cloud Functions',
                  Colors.orange,
                );

                // Nota: Reenviar email de verificación requiere que el usuario esté autenticado
                // o usar Cloud Functions
              },
              child: const Text('Reenviar'),
            ),
          ],
        );
      },
    );
  }

  // ✅ VER DETALLES DE USUARIO
  void _verDetallesUsuario(String userId, Map<String, dynamic> usuario) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('Detalles del Usuario'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetalleItem('Nombre', usuario['nombre'] ?? 'N/A'),
                const Divider(),
                _buildDetalleItem('Email', usuario['email'] ?? 'N/A'),
                const Divider(),
                _buildDetalleItem('Rol', usuario['rol'] ?? 'N/A'),
                const Divider(),
                _buildDetalleItem('Estado', usuario['estado'] ?? 'N/A'),
                const Divider(),
                _buildDetalleItem(
                  'Email Verificado',
                  usuario['emailVerificado'] == true ? 'Sí' : 'No',
                  color: usuario['emailVerificado'] == true
                      ? Colors.green
                      : Colors.orange,
                ),
                const Divider(),
                _buildDetalleItem(
                  'Sesión Activa',
                  usuario['sesionActiva'] == true ? 'Sí' : 'No',
                ),
                const Divider(),
                _buildDetalleItem(
                  'Fecha Creación',
                  _formatearFecha(usuario['fechaCreacion']),
                ),
                const Divider(),
                _buildDetalleItem(
                  'Última Actualización',
                  _formatearFecha(usuario['fechaActualizacion']),
                ),
              ],
            ),
          ),
          actions: [
            if (usuario['emailVerificado'] != true)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _reenviarEmailVerificacion(userId, usuario['email'] ?? '');
                },
                icon: const Icon(Icons.email, size: 18),
                label: const Text('Reenviar verificación'),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                editarUsuario(userId, usuario);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Editar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetalleItem(String label, String valor, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      final fecha = (timestamp as Timestamp).toDate();
      return '${fecha.day.toString().padLeft(2, '0')}/'
          '${fecha.month.toString().padLeft(2, '0')}/'
          '${fecha.year} '
          '${fecha.hour.toString().padLeft(2, '0')}:'
          '${fecha.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  void _mostrarDialogoExito(String titulo, String mensaje) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(width: 8),
              Expanded(child: Text(titulo)),
            ],
          ),
          content: Text(mensaje),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  void nuevoUsuario() {
    _limpiarFormulario();
    _isEditMode = false;
    _mostrarDialogoUsuario(titulo: 'Nuevo Usuario', onGuardar: _crearUsuario);
  }

  void editarUsuario(String userId, Map<String, dynamic> usuario) {
    _isEditMode = true;
    _userIdEnEdicion = userId;
    _nombreController.text = usuario['nombre'] ?? '';

    // Extraer solo el código del usuario (parte antes del @)
    final emailCompleto = usuario['email'] ?? '';
    final codigoUsuario = emailCompleto.split('@').first;
    _codigoUsuarioController.text = codigoUsuario;

    _rolSeleccionado = rolesDisponibles.contains(usuario['rol'])
        ? usuario['rol']
        : 'Cajero';

    _estadoSeleccionado = estadosDisponibles.contains(usuario['estado'])
        ? usuario['estado']
        : 'Activo';

    _mostrarDialogoUsuario(
      titulo: 'Editar Usuario',
      onGuardar: _actualizarUsuario,
    );
  }

  void _mostrarDialogoUsuario({
    required String titulo,
    required Future<void> Function() onGuardar,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(titulo),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor ingrese el nombre';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _codigoUsuarioController,
                        decoration: InputDecoration(
                          labelText: 'Código de Usuario',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.badge),
                          enabled: !_isEditMode,
                          helperText: _isEditMode
                              ? 'El código no se puede cambiar'
                              : 'Solo números (ej: 001, 123, 456)',
                          suffixText: '@pv.com',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor ingrese el código de usuario';
                          }
                          if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
                            return 'Solo se permiten números';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      if (!_isEditMode) // Solo mostrar contraseña al crear
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock),
                            helperText: 'Mínimo 6 caracteres (solo números)',
                          ),
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese la contraseña';
                            }
                            if (value.length < 6) {
                              return 'Mínimo 6 caracteres';
                            }
                            if (!RegExp(r'^\d+$').hasMatch(value)) {
                              return 'Solo se permiten números';
                            }
                            return null;
                          },
                        ),
                      if (!_isEditMode) const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _rolSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Rol',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge),
                        ),
                        items: rolesDisponibles
                            .map(
                              (rol) => DropdownMenuItem(
                                value: rol,
                                child: Text(rol),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            _rolSeleccionado = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _estadoSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Estado',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.toggle_on),
                        ),
                        items: estadosDisponibles
                            .map(
                              (estado) => DropdownMenuItem(
                                value: estado,
                                child: Text(estado),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            _estadoSeleccionado = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _limpiarFormulario();
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: onGuardar,
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarCargando(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  void _mostrarSnackBar(String mensaje, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: color,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ContentCard(
        title: 'Gestión de Usuarios',
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Administrar usuarios del sistema',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                ElevatedButton.icon(
                  onPressed: nuevoUsuario,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Nuevo Usuario'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    elevation: 5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildUserTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTable() {
    if (!_isFirebaseInitialized || _firestore == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore!
          .collection('usuarios')
          .orderBy('fechaCreacion', descending: true)
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
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No hay usuarios registrados',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return Table(
          border: TableBorder.all(color: const Color(0xFFE2E8F0)),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(2.5),
            2: FlexColumnWidth(1.5),
            3: FlexColumnWidth(1.2),
            4: FlexColumnWidth(1.5),
            5: FlexColumnWidth(2),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
              children: [
                _buildTableHeader('Nombre'),
                _buildTableHeader('Email'),
                _buildTableHeader('Rol'),
                _buildTableHeader('Estado'),
                _buildTableHeader('Verificado'),
                _buildTableHeader('Acciones'),
              ],
            ),
            ...snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final userId = doc.id;
              final emailVerificado = data['emailVerificado'] == true;

              return TableRow(
                children: [
                  _buildTableCell(data['nombre'] ?? 'Sin nombre'),
                  _buildTableCell(data['email'] ?? 'Sin email'),
                  _buildTableCell(data['rol'] ?? 'Sin rol'),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Chip(
                      label: Text(
                        data['estado'] ?? 'Inactivo',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: data['estado'] == 'Activo'
                          ? Colors.green[100]
                          : Colors.grey[300],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          emailVerificado ? Icons.check_circle : Icons.warning,
                          size: 20,
                          color: emailVerificado ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          emailVerificado ? 'Sí' : 'No',
                          style: TextStyle(
                            fontSize: 12,
                            color: emailVerificado
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility, size: 20),
                          onPressed: () => _verDetallesUsuario(userId, data),
                          tooltip: 'Ver detalles',
                          color: Colors.blue,
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => editarUsuario(userId, data),
                          tooltip: 'Editar',
                          color: Colors.orange,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () => _eliminarUsuario(
                            userId,
                            data['nombre'] ?? 'Usuario',
                          ),
                          tooltip: 'Eliminar',
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }

  // ✅ LISTENER PARA ACTUALIZAR ESTADO DE VERIFICACIÓN DE EMAIL
  void _iniciarListenerVerificacionEmail() {
    _auth!.authStateChanges().listen((User? user) {
      if (user != null && mounted) {
        // Actualizar estado de verificación en Firestore
        _firestore!
            .collection('usuarios')
            .doc(user.uid)
            .update({
              'emailVerificado': user.emailVerified,
              'cuentaCreada': true,
            })
            .catchError((e) {
              print('Error actualizando verificación: $e');
            });
      }
    });
  }
}
