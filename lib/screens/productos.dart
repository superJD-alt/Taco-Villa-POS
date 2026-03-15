import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/models/content_card.dart';

class Productos extends StatefulWidget {
  const Productos({Key? key}) : super(key: key);

  @override
  State<Productos> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<Productos> {
  // --- CONFIGURACIÓN DE CLOUDINARY ---
  final String _cloudinaryCloudName = 'dkhbeu0ry';
  final String _cloudinaryUploadPreset = 'pos_system';

  // --- CONTROLADORES DE ESTADO Y FIREBASE ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Controladores para el formulario de producto (CRUD)
  final _nombreController = TextEditingController();
  final _precioController = TextEditingController();
  final _categoriaController = TextEditingController();

  // Controlador para el campo 'gramos'
  final _gramosController = TextEditingController();

  // Variables para manejo de imágenes
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _imagenSeleccionada;
  String? _urlImagenActual;
  bool _subiendoImagen = false;

  // Variable de estado para búsqueda
  String _filtroBusqueda = '';

  // ID del documento si estamos editando
  String? _productoIdEnEdicion;

  // Estado para la colección activa (platillos o bebidas)
  String _collectionName = 'platillos';

  // Lista de categorías para Platillos
  final List<String> _platilloCategorias = [
    'entradas',
    'Todos',
    'cortes prime',
    'costillas',
    'ensaladas',
    'extras hamburguesas',
    'molcajetes',
    'papas rellenas',
    'para todos',
    'postres',
    'queso fundido',
    'sopas y pastas',
    'tacos',
    'volcanes',
  ];

  // Lista de categorías para Bebidas
  final List<String> _bebidaCategorias = [
    'cocteleria',
    'cerveza',
    'tequila',
    'sin alcohol',
    'brandy',
    'whisky',
    'mezcales',
    'vinos',
  ];

  String? _categoriaSeleccionada;

  // Campos de estado para los nuevos datos
  bool _disponible = true;
  String? _tipoSeseccionado;
  final List<String> _tiposDisponibles = ['platillo', 'bebida'];

  @override
  void dispose() {
    _searchController.dispose();
    _nombreController.dispose();
    _precioController.dispose();
    _categoriaController.dispose();
    _gramosController.dispose();
    super.dispose();
  }

  // Helper para obtener el título dinámico de la pantalla
  String _getCollectionTitle() {
    if (_collectionName == 'comida') {
      return 'Catálogo de Platillos';
    } else if (_collectionName == 'bebidas') {
      return 'Catálogo de Bebidas';
    }
    return 'Catálogo de Productos';
  }

  // Helper para obtener el nombre del producto en singular
  String _getProductName() {
    return _collectionName == 'comida' ? 'Platillo' : 'Bebida';
  }

  // Helper para obtener las categorías según la colección activa
  List<String> _getAvailableCategories() {
    return _collectionName == 'bebidas'
        ? _bebidaCategorias
        : _platilloCategorias;
  }

  // --- FUNCIONES DE IMAGEN ---

  Future<void> _seleccionarImagen() async {
    try {
      final XFile? imagen = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (imagen != null && mounted) {
        _imagenSeleccionada = imagen;
      }
    } catch (e) {
      print('Error al seleccionar imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<String?> _subirImagenACloudinary(XFile imagen) async {
    try {
      if (mounted) {
        setState(() => _subiendoImagen = true);
      }

      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = _cloudinaryUploadPreset;
      request.fields['folder'] = 'comida';

      if (kIsWeb) {
        final bytes = await imagen.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: imagen.name),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('file', imagen.path),
        );
      }

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonResponse = json.decode(responseString);

      if (response.statusCode == 200) {
        return jsonResponse['secure_url'] as String;
      } else {
        print('Error de Cloudinary: $jsonResponse');
        throw Exception(
          'Error al subir imagen: ${jsonResponse['error']['message']}',
        );
      }
    } catch (e) {
      print('Error al subir imagen a Cloudinary: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir imagen: ${e.toString()}')),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _subiendoImagen = false);
      }
    }
  }

  // --- FUNCIONES CRUD ---

  void _limpiarFormulario() {
    _nombreController.clear();
    _precioController.clear();
    _categoriaController.clear();
    _gramosController.clear();
    _disponible = true;
    _tipoSeseccionado = null;
    _categoriaSeleccionada = null;
    _productoIdEnEdicion = null;
    _imagenSeleccionada = null;
    _urlImagenActual = null;
  }

  // C: Crear o U: Actualizar un producto
  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;

    // Validar que se haya seleccionado una categoría
    if (_categoriaSeleccionada == null || _categoriaSeleccionada!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione una categoría'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validar que se haya seleccionado un tipo
    if (_tipoSeseccionado == null || _tipoSeseccionado!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione un tipo (platillo/bebida)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Evitar múltiples llamadas simultáneas
    if (_subiendoImagen) return;

    if (mounted) {
      setState(() => _subiendoImagen = true);
    }

    try {
      final double precio = double.parse(_precioController.text);

      // Gramos puede ser null, se parsea solo si hay texto
      final int? gramos = _gramosController.text.trim().isNotEmpty
          ? int.tryParse(_gramosController.text.trim())
          : null;

      // Si hay una nueva imagen seleccionada, subirla a Cloudinary
      String? urlImagen = _urlImagenActual;
      if (_imagenSeleccionada != null) {
        urlImagen = await _subirImagenACloudinary(_imagenSeleccionada!);
        if (urlImagen == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al subir la imagen')),
          );
          return;
        }
      }

      final Map<String, dynamic> datos = {
        'nombre': _nombreController.text.trim(),
        'precio': precio,
        'categoria': _categoriaSeleccionada,
        'url': urlImagen,
        'fechaActualizacion': FieldValue.serverTimestamp(),
        // Añadir campos de disponible, gramos y tipo
        'disponible': _disponible,
        'gramos': gramos,
        'tipo': _tipoSeseccionado,
      };

      if (_productoIdEnEdicion == null) {
        // CREAR (C) - Colección dinámica
        await _firestore.collection(_collectionName).add(datos);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_getProductName()} creado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // ACTUALIZAR (U) - Colección dinámica
        await _firestore
            .collection(_collectionName)
            .doc(_productoIdEnEdicion)
            .update(datos);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_getProductName()} actualizado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      _limpiarFormulario();
    } catch (e) {
      print('Error al guardar producto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _subiendoImagen = false);
      }
    }
  }

  // D: Eliminar un producto
  Future<void> _eliminarProducto(String productId) async {
    // Confirmación antes de eliminar
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Está seguro de eliminar este ${_getProductName().toLowerCase()}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      // Colección dinámica
      await _firestore.collection(_collectionName).doc(productId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_getProductName()} eliminado'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print('Error al eliminar producto: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: ${e.toString()}')),
      );
    }
  }

  // --- DIÁLOGOS Y NAVEGACIÓN ---

  void nuevoProducto() {
    _limpiarFormulario();
    _mostrarDialogoProducto(
      titulo: 'Nuevo ${_getProductName()}',
      onGuardar: _guardarProducto,
    );
  }

  void editarProducto(DocumentSnapshot doc) {
    _productoIdEnEdicion = doc.id;
    final data = doc.data() as Map<String, dynamic>;

    // Rellenar controladores con datos existentes
    _nombreController.text = data['nombre'] ?? '';
    _precioController.text = (data['precio'] ?? 0.0).toString();

    // FIX: Validación de Categoría cargada vs Categorías disponibles
    final String? loadedCategory = data['categoria'] as String?;
    final availableCategories = _getAvailableCategories();

    if (loadedCategory != null &&
        availableCategories.contains(loadedCategory)) {
      _categoriaSeleccionada = loadedCategory;
    } else {
      // Si la categoría no es válida para la colección actual, la reiniciamos.
      _categoriaSeleccionada = null;
    }

    _urlImagenActual = data['url'];
    _imagenSeleccionada = null;

    // Cargar los campos adicionales para edición
    _disponible = data['disponible'] as bool? ?? true;
    _gramosController.text = (data['gramos'] ?? '').toString();
    if (data['gramos'] == null || data['gramos'] == 0) {
      _gramosController.text = '';
    }
    _tipoSeseccionado = data['tipo'] as String?;

    _mostrarDialogoProducto(
      titulo: 'Editar ${_getProductName()}',
      onGuardar: _guardarProducto,
    );
  }

  void _mostrarDialogoProducto({
    required String titulo,
    required Future<void> Function() onGuardar,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
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
                      // SECCIÓN DE IMAGEN
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: _buildVistaPreviewImagen(),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _seleccionarImagen();
                          // Solo actualizar el diálogo, NO el widget principal
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.image),
                        label: Text(
                          _imagenSeleccionada != null ||
                                  _urlImagenActual != null
                              ? 'Cambiar Imagen'
                              : 'Seleccionar Imagen',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // CAMPOS DE TEXTO
                      TextFormField(
                        controller: _nombreController,
                        decoration: InputDecoration(
                          labelText: 'Nombre *',
                          prefixIcon: Icon(
                            _collectionName == 'comida'
                                ? Icons.restaurant_menu
                                : Icons.local_bar,
                          ),
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'Ingrese un nombre' : null,
                      ),
                      const SizedBox(height: 12),

                      // DROPDOWN DE CATEGORÍA
                      DropdownButtonFormField<String>(
                        value: _categoriaSeleccionada,
                        decoration: const InputDecoration(
                          labelText: 'Categoría *',
                          prefixIcon: Icon(Icons.category),
                        ),
                        // Usa la lista dinámica de categorías (Platillos o Bebidas)
                        items: _getAvailableCategories().map((categoria) {
                          return DropdownMenuItem(
                            value: categoria,
                            child: Text(categoria),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            _categoriaSeleccionada = value;
                          });
                        },
                        validator: (v) =>
                            v == null ? 'Seleccione una categoría' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _precioController,
                        decoration: const InputDecoration(
                          labelText: 'Precio *',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            v!.isEmpty || double.tryParse(v) == null
                            ? 'Precio inválido'
                            : null,
                      ),

                      const SizedBox(height: 16),

                      // DROPDOWN DE TIPO
                      DropdownButtonFormField<String>(
                        value: _tipoSeseccionado,
                        decoration: const InputDecoration(
                          labelText: 'Tipo (Platillo/Bebida) *',
                          prefixIcon: Icon(Icons.restaurant),
                        ),
                        items: _tiposDisponibles.map((tipo) {
                          return DropdownMenuItem(
                            value: tipo,
                            child: Text(tipo),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            _tipoSeseccionado = value;
                          });
                        },
                        validator: (v) =>
                            v == null ? 'Seleccione el tipo de producto' : null,
                      ),
                      const SizedBox(height: 12),

                      // GRAMOS (Opcional)
                      TextFormField(
                        controller: _gramosController,
                        decoration: const InputDecoration(
                          labelText: 'Gramos (Opcional)',
                          prefixIcon: Icon(Icons.fitness_center),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            v!.isNotEmpty && int.tryParse(v) == null
                            ? 'Gramos inválidos (debe ser un número entero)'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // DISPONIBLE (Switch)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Disponible',
                            style: TextStyle(fontSize: 16),
                          ),
                          Switch(
                            value: _disponible,
                            onChanged: (bool value) {
                              setDialogState(() {
                                _disponible = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _subiendoImagen
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _limpiarFormulario();
                        },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: _subiendoImagen
                      ? null
                      : () async {
                          await onGuardar();
                          // Actualizar el diálogo después de guardar
                          if (mounted) {
                            setDialogState(() {});
                          }
                        },
                  child: _subiendoImagen
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Guardando...'),
                          ],
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildVistaPreviewImagen() {
    if (_imagenSeleccionada != null) {
      if (kIsWeb) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(_imagenSeleccionada!.path, fit: BoxFit.cover),
        );
      } else {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(_imagenSeleccionada!.path), fit: BoxFit.cover),
        );
      }
    }

    if (_urlImagenActual != null && _urlImagenActual!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _urlImagenActual!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
            );
          },
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
          SizedBox(height: 8),
          Text('Sin imagen', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // Widget selector de colecciones
  Widget _buildCollectionSelector(String title, String collection) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          if (mounted) {
            setState(() {
              _collectionName = collection;
              _filtroBusqueda = '';
              _searchController.clear();
              // FIX: Reiniciar la categoría seleccionada para evitar el error de aserción al cambiar de vista
              _categoriaSeleccionada = null;
            });
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _collectionName == collection
              ? Colors.blueAccent
              : Colors.grey[300],
          foregroundColor: _collectionName == collection
              ? Colors.white
              : Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: _collectionName == collection ? 5 : 0,
        ),
        child: Text(title, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  // --- WIDGETS DE VISTA ---

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ContentCard(
        // Título dinámico
        title: _getCollectionTitle(),
        child: Column(
          children: [
            // Selectores de Colección
            Row(
              children: [
                _buildCollectionSelector('Comida', 'comida'),
                const SizedBox(width: 16),
                _buildCollectionSelector('Bebidas', 'bebidas'),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      if (mounted) {
                        setState(() {
                          _filtroBusqueda = value.toLowerCase();
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o categoría...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: nuevoProducto,
                  icon: const Icon(Icons.add_box),
                  // Etiqueta dinámica
                  label: Text('Nuevo ${_getProductName()}'),
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
            _buildProductsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsGrid() {
    return StreamBuilder<QuerySnapshot>(
      // Colección dinámica
      stream: _firestore.collection(_collectionName).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final productosDocs = snapshot.data!.docs;

        final documentosFiltrados = productosDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final nombreProducto = (data['nombre'] as String? ?? '')
              .toLowerCase();
          final categoriaProducto = (data['categoria'] as String? ?? '')
              .toLowerCase();
          return nombreProducto.contains(_filtroBusqueda) ||
              categoriaProducto.contains(_filtroBusqueda);
        }).toList();

        if (documentosFiltrados.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                _filtroBusqueda.isEmpty
                    ? 'No hay ${_getProductName().toLowerCase()}s registrados.'
                    : 'No se encontraron ${_getProductName().toLowerCase()}s con "${_searchController.text}".',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.7,
          ),
          itemCount: documentosFiltrados.length,
          itemBuilder: (context, index) {
            final doc = documentosFiltrados[index];
            final data = doc.data() as Map<String, dynamic>;

            return _buildProductCard(
              doc,
              data['nombre'] ?? 'Sin nombre',
              (double.tryParse(data['precio'].toString()) ?? 0.0)
                  .toStringAsFixed(2),
              data['categoria'] ?? 'Sin categoría',
              data['url'],
            );
          },
        );
      },
    );
  }

  Widget _buildProductCard(
    DocumentSnapshot doc,
    String name,
    String precio,
    String categoria,
    String? imageUrl,
  ) {
    final data = doc.data() as Map<String, dynamic>;

    // Obtener 'disponible' con comprobación de tipo segura
    final rawDisponible = data['disponible'];
    final disponible = rawDisponible is bool ? rawDisponible : true;

    // Obtener 'tipo' con comprobación de tipo segura
    final rawTipo = data['tipo'];
    final tipo = rawTipo is String ? rawTipo : 'platillo';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        // Aplicar borde rojo si no está disponible
        border: Border.all(
          color: disponible
              ? const Color(0xFFE2E8F0)
              : Colors.red.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // SECCIÓN DE IMAGEN (Envuelta en Stack para el overlay de "No Disponible")
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[100],
                              child: Center(
                                // Usar icono basado en el tipo
                                child: Icon(
                                  tipo == 'bebida'
                                      ? Icons.local_bar
                                      : Icons.restaurant_menu,
                                  size: 60,
                                  color: const Color(0xFF3B82F6),
                                ),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[100],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[100],
                          child: Center(
                            // Usar icono basado en el tipo
                            child: Icon(
                              tipo == 'bebida'
                                  ? Icons.local_bar
                                  : Icons.restaurant_menu,
                              size: 60,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                ),
                // Overlay de "NO DISPONIBLE"
                if (!disponible)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'NO DISPONIBLE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // SECCIÓN DE INFORMACIÓN
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre del platillo
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Categoría
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        categoria,
                        style: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Precio
                    Text(
                      '\$$precio',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Botones de Acción
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => editarProducto(doc),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text(
                              'Editar',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              side: const BorderSide(color: Colors.blue),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _eliminarProducto(doc.id),
                            icon: const Icon(Icons.delete, size: 16),
                            label: const Text(
                              'Borrar',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
