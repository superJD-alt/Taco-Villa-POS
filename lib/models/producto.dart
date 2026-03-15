class Producto {
  final String id;
  final String nombre;
  final double precio;
  final String categoria;
  final String? imagen;
  final bool disponible;
  final int? gramos;
  final String? tipo;
  final bool requiresDoneness; // Si requiere término de cocción

  Producto({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.categoria,
    required this.imagen,
    required this.disponible,
    this.gramos,
    this.tipo,
    this.requiresDoneness = false,
  });

  // Crear desde Firestore
  factory Producto.fromFirestore(String id, Map<String, dynamic> data) {
    return Producto(
      id: id,
      nombre: data['nombre'] ?? '',
      precio: double.tryParse(data['precio'].toString()) ?? 0.0,
      categoria: data['categoria'] ?? '',
      imagen: data['url'],
      disponible: data['disponible'] ?? true,
      gramos: data['gramos'] != null
          ? int.tryParse(data['gramos'].toString())
          : null,
      tipo: data['tipo'],
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'precio': precio,
      'categoria': categoria,
      'disponible': disponible,
      if (gramos != null) 'gramos': gramos,
      if (imagen != null) 'url': imagen,
    };
  }
}
