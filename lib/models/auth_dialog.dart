import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthDialog extends StatefulWidget {
  final String titulo;
  final String mensaje;

  const AuthDialog({super.key, required this.titulo, required this.mensaje});

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _cargando = false;
  String? _errorMensaje;

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _validarCredenciales() async {
    // Limpiar mensajes de error previos
    setState(() {
      _errorMensaje = null;
      _cargando = true;
    });

    final usuario = _usuarioController.text.trim();
    final password = _passwordController.text.trim();

    // Validar que se ingresaron los datos
    if (usuario.isEmpty || password.isEmpty) {
      setState(() {
        _errorMensaje = 'Por favor ingresa correo y contraseña';
        _cargando = false;
      });
      return;
    }

    // Validar longitud exacta
    if (usuario.length != 3) {
      setState(() {
        _errorMensaje = 'El correo debe tener exactamente 3 dígitos';
        _cargando = false;
      });
      return;
    }

    if (password.length != 6) {
      setState(() {
        _errorMensaje = 'La contraseña debe tener exactamente 6 dígitos';
        _cargando = false;
      });
      return;
    }

    try {
      // Construir el correo completo con los 3 dígitos ingresados
      final correoCompleto = '$usuario@tv.com';

      // Buscar el usuario en Firestore con el correo completo
      final QuerySnapshot usuariosSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('email', isEqualTo: correoCompleto)
          .where('rol', isEqualTo: 'Administrador')
          .limit(1)
          .get();

      if (usuariosSnapshot.docs.isEmpty) {
        setState(() {
          _errorMensaje = 'Correo no encontrado o no es administrador';
          _cargando = false;
        });
        return;
      }

      final usuarioDoc = usuariosSnapshot.docs.first;
      final datosUsuario = usuarioDoc.data() as Map<String, dynamic>;
      final passwordGuardado = datosUsuario['passwordTemporal'] as String?;
      final nombreAdmin = datosUsuario['nombre'] as String? ?? 'Administrador';

      // Validar contraseña
      if (passwordGuardado != password) {
        setState(() {
          _errorMensaje = 'Contraseña incorrecta';
          _cargando = false;
        });
        return;
      }

      // ✅ Credenciales válidas
      if (mounted) {
        Navigator.of(context).pop({
          'autorizado': true,
          'adminNombre': nombreAdmin,
          'adminId': usuario,
        });
      }
    } catch (e) {
      setState(() {
        _errorMensaje = 'Error al validar credenciales: $e';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.admin_panel_settings, color: Colors.red, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.titulo,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mensaje de advertencia
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.mensaje,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Campo de correo (3 dígitos)
            TextField(
              controller: _usuarioController,
              keyboardType: TextInputType.number,
              maxLength: 3,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: InputDecoration(
                labelText: 'Correo (3 dígitos)',
                //hintText: 'Ej: 123 (de 123@pv.com)',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                counterText: '', // Ocultar contador de caracteres
              ),
              onSubmitted: (_) => _validarCredenciales(),
            ),
            const SizedBox(height: 16),

            // Campo de contraseña (6 dígitos)
            TextField(
              controller: _passwordController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: 'Contraseña (6 dígitos)',
                hintText: 'Ej: 123456',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                counterText: '', // Ocultar contador de caracteres
              ),
              onSubmitted: (_) => _validarCredenciales(),
            ),

            // Mensaje de error
            if (_errorMensaje != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMensaje!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cargando
              ? null
              : () {
                  Navigator.of(context).pop({'autorizado': false});
                },
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _cargando ? null : _validarCredenciales,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _cargando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Autorizar'),
        ),
      ],
    );
  }
}
