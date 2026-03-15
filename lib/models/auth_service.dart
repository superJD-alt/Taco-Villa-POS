import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Verifica credenciales usando Firebase Authentication
  static Future<Map<String, dynamic>?> verificarCredencialesAdmin(
    String email,
    String password,
  ) async {
    try {
      print('🔐 === VERIFICANDO CREDENCIALES ===');
      print('🔐 Email: "$email"');

      // 1. Guardar usuario actual (si existe)
      final User? usuarioActual = _auth.currentUser;

      // 2. Intentar autenticar con las credenciales proporcionadas
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Autenticación exitosa: ${userCredential.user?.uid}');

      // 3. Verificar que el usuario sea administrador en Firestore
      final docSnapshot = await _firestore
          .collection('usuarios')
          .doc(userCredential.user!.uid)
          .get();

      if (!docSnapshot.exists) {
        print('❌ Usuario no encontrado en Firestore');

        // Restaurar sesión anterior si existía
        if (usuarioActual != null) {
          await _auth.signOut();
          // Aquí podrías re-autenticar al usuario anterior si guardaste sus credenciales
        }

        return null;
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      final String rol = (data['rol'] ?? '').toString().toLowerCase();

      print('👤 Rol del usuario: "$rol"');

      if (rol != 'administrador') {
        print('❌ El usuario no es administrador');

        // Restaurar sesión anterior si existía
        if (usuarioActual != null) {
          await _auth.signOut();
        }

        return null;
      }

      print('✅ ¡USUARIO ADMINISTRADOR VERIFICADO!');

      // Restaurar sesión anterior si existía (opcional)
      // En un sistema POS, probablemente quieras mantener la sesión del mesero
      if (usuarioActual != null &&
          usuarioActual.uid != userCredential.user!.uid) {
        await _auth.signOut();
        // Aquí podrías re-autenticar al usuario anterior
      }

      return {
        'id': userCredential.user!.uid,
        'nombre': data['nombre'] ?? 'Admin',
        'email': data['email'] ?? email,
        'rol': data['rol'],
      };
    } on FirebaseAuthException catch (e) {
      print('❌ Error de autenticación: ${e.code}');

      switch (e.code) {
        case 'user-not-found':
          print('❌ No existe usuario con ese email');
          break;
        case 'wrong-password':
          print('❌ Contraseña incorrecta');
          break;
        case 'invalid-email':
          print('❌ Email inválido');
          break;
        case 'user-disabled':
          print('❌ Usuario deshabilitado');
          break;
        default:
          print('❌ Error: ${e.message}');
      }

      return null;
    } catch (e) {
      print('❌ Error inesperado: $e');
      return null;
    }
  }

  /// Obtiene la lista de administradores
  static Future<List<Map<String, dynamic>>> obtenerAdministradores() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('usuarios')
          .get();

      final admins = snapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String rol = (data['rol'] ?? '').toString().toLowerCase();
            return rol == 'administrador';
          })
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'nombre': data['nombre'] ?? 'Sin nombre',
              'email': data['email'] ?? 'Sin email',
              'rol': data['rol'],
            };
          })
          .toList();

      print('📋 Total de administradores: ${admins.length}');
      return admins;
    } catch (e) {
      print('❌ Error al obtener administradores: $e');
      return [];
    }
  }
}
