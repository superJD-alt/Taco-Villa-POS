import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'panel_meseros.dart';
import 'panel_admin.dart';

class LoginPos extends StatefulWidget {
  const LoginPos({super.key});

  @override
  State<LoginPos> createState() => _LoginPosState();
}

class _LoginPosState extends State<LoginPos> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? errorMessage;
  bool loading = false;

  Future<void> login() async {
    final user = userController.text.trim();
    final pass = passController.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      setState(() => errorMessage = 'Por favor ingrese usuario y contraseña');
      return;
    }

    if (!RegExp(r'^\d+$').hasMatch(user) || !RegExp(r'^\d+$').hasMatch(pass)) {
      setState(() => errorMessage = 'Solo se permiten números');
      return;
    }

    final email = '$user@tv.com';

    try {
      setState(() {
        errorMessage = null;
        loading = true;
      });

      UserCredential? userCredential;

      // 1. INTENTAR LOGIN PRIMERO
      try {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: pass,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          // 2. SI NO EXISTE, CREAR CUENTA (primer login)
          userCredential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: pass,
          );
        } else {
          rethrow;
        }
      }

      // 3. YA AUTENTICADO → CONSULTAR FIRESTORE
      debugPrint('🔍 Buscando email: $email'); // 👈 agrega esto

      QuerySnapshot usuariosQuery = await _firestore
          .collection('usuarios')
          .where('email', isEqualTo: email)
          .get();

      debugPrint(
        '📄 Documentos encontrados: ${usuariosQuery.docs.length}',
      ); // 👈 y esto

      // Si no encuentra, buscar todos para ver qué hay
      if (usuariosQuery.docs.isEmpty) {
        QuerySnapshot todos = await _firestore.collection('usuarios').get();
        debugPrint('📋 Total documentos en colección: ${todos.docs.length}');
        for (var doc in todos.docs) {
          debugPrint('📌 Doc ID: ${doc.id} | Data: ${doc.data()}');
        }
        await _auth.signOut();
        setState(() => errorMessage = 'Usuario no encontrado en el sistema');
        return;
      }

      DocumentSnapshot usuarioDoc = usuariosQuery.docs.first;
      Map<String, dynamic> usuarioData =
          usuarioDoc.data() as Map<String, dynamic>;
      String usuarioId = usuarioDoc.id;

      // 4. VERIFICAR ESTADO
      if (usuarioData['estado'] != 'Activo') {
        await _auth.signOut();
        setState(
          () => errorMessage = 'Usuario inactivo. Contacte al administrador.',
        );
        return;
      }

      // 5. ACTUALIZAR FIRESTORE
      await _firestore.collection('usuarios').doc(usuarioId).update({
        'cuentaCreada': true,
        'sesionActiva': true,
        'uid': userCredential.user!.uid,
        'ultimoLogin': FieldValue.serverTimestamp(),
      });

      // 6. OBTENER ROL Y NAVEGAR
      String nombreMesero = usuarioData['nombre'] ?? "Usuario #$user";
      String userRole =
          (usuarioData['rol'] as String?)?.toLowerCase() ?? 'unknown';

      await userCredential.user!.updateDisplayName(nombreMesero);

      debugPrint('✅ Login exitoso: $nombreMesero | Rol: $userRole');

      if (!mounted) return;

      Widget destinationPage;
      switch (userRole) {
        case 'mesero':
          destinationPage = const PanelMeseros();
          break;
        case 'administrador':
          destinationPage = const PanelAdmin();
          break;
        default:
          await _auth.signOut();
          setState(() {
            errorMessage = 'Rol no válido. No se puede acceder al sistema.';
            loading = false;
          });
          return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => destinationPage),
      );
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Contraseña incorrecta';
          break;
        case 'user-disabled':
          msg = 'Usuario deshabilitado';
          break;
        default:
          msg = 'Error de autenticación: ${e.message}';
      }
      setState(() => errorMessage = msg);
      debugPrint('❌ Error Auth: ${e.code} - ${e.message}');
    } catch (e) {
      setState(() => errorMessage = 'Error inesperado: $e');
      debugPrint('❌ Error general: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final size = MediaQuery.of(context).size;
    final bool isWide = size.width > 600;

    Widget imageWidget = Padding(
      padding: const EdgeInsets.only(left: 50),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/images/tacoVilla.jpg',
          width: isWide ? size.width * 0.3 : double.infinity,
          height: isWide ? size.width * 0.3 : size.width * 0.75,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: isWide ? size.width * 0.3 : double.infinity,
              height: isWide ? size.width * 0.3 : size.width * 0.75,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(50),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.restaurant_menu,
                color: Colors.white70,
                size: 200,
              ),
            );
          },
        ),
      ),
    );

    Widget formWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            'Login',
            style: TextStyle(
              color: Colors.white,
              fontSize: isWide ? 64 : 42,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          'Usuario:',
          style: TextStyle(
            color: Colors.white,
            fontSize: isWide ? 32 : 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: userController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
            hintText: 'Ingrese su usuario (solo números)',
            hintStyle: const TextStyle(color: Colors.white54, fontSize: 18),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(
          'Contraseña:',
          style: TextStyle(
            color: Colors.white,
            fontSize: isWide ? 32 : 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: passController,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
            hintText: 'Ingrese su contraseña',
            hintStyle: const TextStyle(color: Colors.white54, fontSize: 18),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 25),

        if (errorMessage != null)
          Center(
            child: Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 16),
            ),
          ),

        const SizedBox(height: 10),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : login,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 30),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 5,
            ),
            child: loading
                ? const CircularProgressIndicator(color: Colors.black)
                : Text(
                    'Iniciar Sesión',
                    style: TextStyle(
                      fontSize: isWide ? 22 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (orientation == Orientation.landscape &&
                constraints.maxWidth > 800) {
              return Row(
                children: [
                  // Logo centrado vertical y horizontalmente en landscape
                  Expanded(
                    flex: 1,
                    child: SizedBox.expand(child: Center(child: imageWidget)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: SingleChildScrollView(child: formWidget),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              // Logo centrado en portrait: ocupa su propio espacio centrado
              return Column(
                children: [
                  // Mitad superior: solo el logo, centrado
                  SizedBox(
                    height: constraints.maxHeight * 0.45,
                    width: constraints.maxWidth,
                    child: Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 15),
                        child: imageWidget,
                      ),
                    ),
                  ),
                  // Mitad inferior: formulario con scroll
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: formWidget,
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}
