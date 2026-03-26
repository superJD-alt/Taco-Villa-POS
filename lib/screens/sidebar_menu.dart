import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SidebarMenu extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onMenuItemSelected;
  final String nombreUsuario;
  final String correoUsuario;
  final VoidCallback onLogout;

  const SidebarMenu({
    Key? key,
    required this.selectedIndex,
    required this.onMenuItemSelected,
    required this.nombreUsuario,
    required this.correoUsuario,
    required this.onLogout,
  }) : super(key: key);

  // ✅ NUEVO: Cierra sesión actualizando Firestore antes de salir
  Future<void> _handleLogout(BuildContext context) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid != null) {
        // Buscar el documento del usuario por su UID
        final query = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('uid', isEqualTo: uid)
            .get();

        if (query.docs.isNotEmpty) {
          // Marcar sesión como inactiva
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(query.docs.first.id)
              .update({'sesionActiva': false});
        }
      }
    } catch (e) {
      debugPrint('❌ Error al cerrar sesión en Firestore: $e');
    }

    // Llama al logout del widget padre (navega al login, etc.)
    onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
          // Logo/Header
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: const [
                Icon(Icons.point_of_sale, color: Colors.white, size: 32),
                SizedBox(width: 12),
                Text(
                  ' Taco Villa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF334155), height: 1),
          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildMenuItem(0, Icons.dashboard, 'Panel General'),
                _buildMenuItem(1, Icons.point_of_sale, 'Caja'),
                _buildMenuItem(2, Icons.inventory, 'Inventario'),
                _buildMenuItem(3, Icons.assessment, 'Reportes'),
                _buildMenuItem(4, Icons.people, 'Usuarios'),
                _buildMenuItem(5, Icons.shopping_bag, 'Menu'),
              ],
            ),
          ),

          // Perfil de Usuario con Menú Desplegable (Cerrar Sesión)
          _buildUserProfileMenu(context),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String title) {
    final isSelected = selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF16A34A) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () => onMenuItemSelected(index),
      ),
    );
  }

  Widget _buildUserProfileMenu(BuildContext context) {
    return PopupMenuButton<String>(
      child: Container(
        padding: const EdgeInsets.all(50),
        child: InkWell(
          child: Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFF16A34A),
                child: Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreUsuario,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Text(
                          'Opciones ',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF94A3B8),
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              correoUsuario,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: const [
              Icon(Icons.logout, color: Colors.red, size: 24),
              SizedBox(width: 16),
              Text(
                'Cerrar Sesión',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],

      // ✅ CAMBIO: antes solo llamaba onLogout(), ahora llama _handleLogout()
      onSelected: (String result) {
        if (result == 'logout') {
          _handleLogout(context);
        }
      },
    );
  }
}
