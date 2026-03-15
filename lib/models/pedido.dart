// models/pedido.dart
class Pedido {
  final String nombre;
  int cantidad;
  final double precio;

  Pedido({required this.nombre, this.cantidad = 1, required this.precio});

  double get total => cantidad * precio;
}
