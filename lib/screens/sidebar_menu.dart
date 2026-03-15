import 'package:flutter/material.dart';

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
        color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
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
      // 1. EL WIDGET QUE SE MUESTRA SIEMPRE - ✅ AUMENTADO DE TAMAÑO
      child: Container(
        padding: const EdgeInsets.all(50), // ✅ Aumentado de 16 a 20
        child: InkWell(
          child: Row(
            children: [
              const CircleAvatar(
                radius: 24, // ✅ Avatar más grande (default es 20)
                backgroundColor: Color(0xFF3B82F6),
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 28, // ✅ Icono más grande
                ),
              ),
              const SizedBox(width: 14), // ✅ Más espacio
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreUsuario,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize:
                            16, // ✅ Nombre más grande (antes no tenía fontSize definido)
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(
                      height: 4,
                    ), // ✅ Espacio entre nombre y "Opciones"
                    Row(
                      children: const [
                        Text(
                          'Opciones ',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize:
                                14, // ✅ "Opciones" más grande (antes era 12)
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF94A3B8),
                          size: 20, // ✅ Icono flecha más grande (antes era 16)
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

      // 2. LAS OPCIONES QUE SE DESPLIEGAN - ✅ AUMENTADO EL TAMAÑO
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4), // ✅ Más padding
            child: Text(
              correoUsuario,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14, // ✅ Texto más grande
              ),
            ),
          ),
        ),
        const PopupMenuDivider(),

        // ✅ OPCIÓN DE CERRAR SESIÓN MÁS GRANDE
        PopupMenuItem<String>(
          value: 'logout',
          height: 60, // ✅ Altura aumentada de 48 a 60
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12, // ✅ Más padding vertical
          ),
          child: Row(
            children: const [
              Icon(
                Icons.logout,
                color: Colors.red,
                size: 24, // ✅ Icono más grande (default es 20)
              ),
              SizedBox(width: 16), // ✅ Más espacio entre icono y texto
              Text(
                'Cerrar Sesión',
                style: TextStyle(
                  fontSize: 16, // ✅ Texto más grande (default es 14)
                  fontWeight: FontWeight.w500, // ✅ Texto más grueso
                ),
              ),
            ],
          ),
        ),
      ],

      // 3. ✅ EL LISTENER QUE EJECUTA LA ACCIÓN
      onSelected: (String result) {
        if (result == 'logout') {
          // Llama a la función onLogout proporcionada por el widget padre (Dashboard)
          onLogout();
        }
      },
    );
  }
}
