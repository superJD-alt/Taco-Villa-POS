import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/models/content_card.dart';

class Inventario extends StatefulWidget {
  const Inventario({Key? key}) : super(key: key);

  @override
  State<Inventario> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<Inventario> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ Generar siguiente código disponible
  Future<String> _generarSiguienteCodigo() async {
    try {
      // Obtener todos los documentos TACa analizar sus IDs
      final snapshot = await _firestore.collection('inventario').get();

      if (snapshot.docs.isEmpty) {
        return 'TAC-0001';
      }

      // Extraer todos los números de los códigos existentes
      final numeros = <int>[];
      final regex = RegExp(r'TAC-(\d+)');

      for (var doc in snapshot.docs) {
        final match = regex.firstMatch(doc.id);
        if (match != null) {
          numeros.add(int.tryParse(match.group(1)!) ?? 0);
        }
      }

      if (numeros.isEmpty) {
        return 'TAC-0001';
      }

      // Encontrar el número más alto y sumar 1
      numeros.sort();
      final siguienteNumero = numeros.last + 1;
      return 'TAC-${siguienteNumero.toString().padLeft(4, '0')}';
    } catch (e) {
      print('Error al generar código: $e');
      return 'TAC-0001';
    }
  }

  // ✅ Verificar si un código ya existe (verificando el ID del documento)
  Future<bool> _codigoExiste(String codigo) async {
    try {
      final codigoUpper = codigo.toUpperCase();
      final doc = await _firestore
          .collection('inventario')
          .doc(codigoUpper)
          .get();

      return doc.exists;
    } catch (e) {
      print('Error al verificar código: $e');
      return false;
    }
  }

  // Agregar producto
  void agregarProducto() async {
    // Generar código sugerido
    final codigoSugerido = await _generarSiguienteCodigo();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => ProductoDialog(
        codigoSugerido: codigoSugerido,
        onSave: (producto) async {
          try {
            // ✅ Usar el código como ID del documento
            final codigo = producto['id'] as String;
            await _firestore.collection('inventario').doc(codigo).set(producto);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Producto agregado exitosamente'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        onValidarCodigo: _codigoExiste,
      ),
    );
  }

  // Editar producto
  void editarProducto(String docId, Map<String, dynamic> productoActual) {
    showDialog(
      context: context,
      builder: (context) => ProductoDialog(
        productoActual: productoActual,
        codigoOriginalEdicion: docId, // ✅ Pasar el ID del documento
        onSave: (producto) async {
          try {
            final nuevoCodigo = producto['id'] as String;

            // ✅ Si el código cambió, eliminar el viejo y crear uno nuevo
            if (nuevoCodigo != docId) {
              // Eliminar el documento viejo
              await _firestore.collection('inventario').doc(docId).delete();
              // Crear el documento nuevo con el nuevo código como ID
              await _firestore
                  .collection('inventario')
                  .doc(nuevoCodigo)
                  .set(producto);
            } else {
              // Si el código no cambió, solo actualizar
              await _firestore
                  .collection('inventario')
                  .doc(docId)
                  .update(producto);
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Producto actualizado exitosamente'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        onValidarCodigo: _codigoExiste,
      ),
    );
  }

  // Eliminar producto
  void eliminarProducto(String docId, String nombre) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Está seguro de eliminar "$nombre"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore.collection('inventario').doc(docId).delete();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Producto eliminado'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ContentCard(
        title: 'Control de Inventario',
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar producto...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: agregarProducto,
                  icon: const Icon(Icons.add_box),
                  label: const Text('Agregar Producto'),
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
            _buildDataTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('inventario').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var productos = snapshot.data!.docs.where((doc) {
          if (_searchQuery.isEmpty) return true;
          var data = doc.data() as Map<String, dynamic>;
          return data['nombre'].toString().toLowerCase().contains(
                _searchQuery,
              ) ||
              doc.id.toLowerCase().contains(
                _searchQuery,
              ) || // ✅ Buscar por ID del documento
              data['categoria'].toString().toLowerCase().contains(_searchQuery);
        }).toList();

        if (productos.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No hay productos registrados'),
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            border: TableBorder.all(color: const Color(0xFFE2E8F0)),
            columnWidths: const {
              0: FixedColumnWidth(100),
              1: FixedColumnWidth(180),
              2: FixedColumnWidth(120),
              3: FixedColumnWidth(80),
              4: FixedColumnWidth(100),
              5: FixedColumnWidth(100),
              6: FixedColumnWidth(120),
              7: FixedColumnWidth(100),
              8: FixedColumnWidth(100),
              9: FixedColumnWidth(150),
              10: FixedColumnWidth(120),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                children: [
                  _buildTableHeader('Código'),
                  _buildTableHeader('Nombre'),
                  _buildTableHeader('Categoría'),
                  _buildTableHeader('Stock'),
                  _buildTableHeader('Stock Mín'),
                  _buildTableHeader('Precio'),
                  _buildTableHeader('Unidad'),
                  _buildTableHeader('Proveedor'),
                  _buildTableHeader('Fecha Compra'),
                  _buildTableHeader('Uso Principal'),
                  _buildTableHeader('Acciones'),
                ],
              ),
              ...productos.map((doc) {
                var producto = doc.data() as Map<String, dynamic>;
                return TableRow(
                  children: [
                    _buildTableCell(doc.id), // ✅ Usar el ID del documento
                    _buildTableCell(producto['nombre'] ?? ''),
                    _buildTableCell(producto['categoria'] ?? ''),
                    _buildTableCell(producto['stock']?.toString() ?? '0'),
                    _buildTableCell(
                      producto['stock_minimo']?.toString() ?? '0',
                    ),
                    _buildTableCell('\$${producto['precio_unitario'] ?? 0}'),
                    _buildTableCell(producto['unidad_medida'] ?? ''),
                    _buildTableCell(producto['proveedor'] ?? ''),
                    _buildTableCell(producto['fecha_compra'] ?? ''),
                    _buildTableCell(producto['uso_principal'] ?? ''),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => editarProducto(doc.id, producto),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 20,
                              color: Colors.red,
                            ),
                            onPressed: () => eliminarProducto(
                              doc.id,
                              producto['nombre'] ?? '',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(padding: const EdgeInsets.all(12), child: Text(text));
  }
}

// Dialog TACa agregar/editar productos
class ProductoDialog extends StatefulWidget {
  final Map<String, dynamic>? productoActual;
  final String? codigoSugerido;
  final String? codigoOriginalEdicion; // ✅ ID del documento al editar
  final Function(Map<String, dynamic>) onSave;
  final Future<bool> Function(String) onValidarCodigo;

  const ProductoDialog({
    Key? key,
    this.productoActual,
    this.codigoSugerido,
    this.codigoOriginalEdicion,
    required this.onSave,
    required this.onValidarCodigo,
  }) : super(key: key);

  @override
  State<ProductoDialog> createState() => _ProductoDialogState();
}

class _ProductoDialogState extends State<ProductoDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _idController;
  late TextEditingController _nombreController;
  late TextEditingController _categoriaController;
  late TextEditingController _stockController;
  late TextEditingController _stockMinimoController;
  late TextEditingController _precioController;
  late TextEditingController _unidadMedidaController;
  late TextEditingController _proveedorController;
  late TextEditingController _fechaCompraController;
  late TextEditingController _usoPrincipalController;

  // Variables de estado TACa validación
  bool _validandoCodigo = false;
  String? _errorCodigo;
  String? _codigoOriginal;

  @override
  void initState() {
    super.initState();

    // ✅ Usar el ID del documento como código original al editar
    _codigoOriginal =
        widget.codigoOriginalEdicion ?? widget.productoActual?['id'];

    _idController = TextEditingController(
      text:
          widget.codigoOriginalEdicion ??
          widget.productoActual?['id'] ??
          widget.codigoSugerido ??
          '',
    );
    _nombreController = TextEditingController(
      text: widget.productoActual?['nombre'] ?? '',
    );
    _categoriaController = TextEditingController(
      text: widget.productoActual?['categoria'] ?? '',
    );
    _stockController = TextEditingController(
      text: widget.productoActual?['stock']?.toString() ?? '0',
    );
    _stockMinimoController = TextEditingController(
      text: widget.productoActual?['stock_minimo']?.toString() ?? '0',
    );
    _precioController = TextEditingController(
      text: widget.productoActual?['precio_unitario']?.toString() ?? '0',
    );
    _unidadMedidaController = TextEditingController(
      text: widget.productoActual?['unidad_medida'] ?? '',
    );
    _proveedorController = TextEditingController(
      text: widget.productoActual?['proveedor'] ?? '',
    );
    _fechaCompraController = TextEditingController(
      text: widget.productoActual?['fecha_compra'] ?? '',
    );
    _usoPrincipalController = TextEditingController(
      text: widget.productoActual?['uso_principal'] ?? '',
    );

    // Listener TACa validar código en tiempo real
    _idController.addListener(_validarCodigoEnTiempoReal);
  }

  // Validar código mientras se escribe
  void _validarCodigoEnTiempoReal() async {
    final codigo = _idController.text.trim().toUpperCase();

    // Si está vacío, limpiar error
    if (codigo.isEmpty) {
      if (mounted) {
        setState(() {
          _errorCodigo = null;
        });
      }
      return;
    }

    // Validar formato
    final regex = RegExp(r'^TAC-\d{4}$');
    if (!regex.hasMatch(codigo)) {
      if (mounted) {
        setState(() {
          _errorCodigo = 'Formato inválido. Use: TAC-0000';
        });
      }
      return;
    }

    // Si estamos editando y es el mismo código, no validar
    if (_codigoOriginal != null && codigo == _codigoOriginal!.toUpperCase()) {
      if (mounted) {
        setState(() {
          _errorCodigo = null;
        });
      }
      return;
    }

    // Validar si existe
    setState(() {
      _validandoCodigo = true;
      _errorCodigo = null;
    });

    final existe = await widget.onValidarCodigo(codigo);

    if (mounted) {
      setState(() {
        _validandoCodigo = false;
        _errorCodigo = existe ? '❌ Este código ya existe' : null;
      });
    }
  }

  @override
  void dispose() {
    _idController.removeListener(_validarCodigoEnTiempoReal);
    _idController.dispose();
    _nombreController.dispose();
    _categoriaController.dispose();
    _stockController.dispose();
    _stockMinimoController.dispose();
    _precioController.dispose();
    _unidadMedidaController.dispose();
    _proveedorController.dispose();
    _fechaCompraController.dispose();
    _usoPrincipalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.productoActual == null ? 'Agregar Producto' : 'Editar Producto',
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _idController,
                            decoration: InputDecoration(
                              labelText: 'Código *',
                              hintText: 'TAC-0000',
                              suffixIcon: _validandoCodigo
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : _errorCodigo == null &&
                                        _idController.text.isNotEmpty
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : null,
                            ),
                            textCapitalization: TextCapitalization.characters,
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Campo requerido';
                              }
                              final regex = RegExp(r'^TAC-\d{4}$');
                              if (!regex.hasMatch(value!.toUpperCase())) {
                                return 'Formato: TAC-0000';
                              }
                              if (_errorCodigo != null) {
                                return _errorCodigo;
                              }
                              return null;
                            },
                          ),
                          if (_errorCodigo != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 12),
                              child: Text(
                                _errorCodigo!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (widget.codigoSugerido != null &&
                              widget.productoActual == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 12),
                              child: Text(
                                '💡 Código sugerido: ${widget.codigoSugerido}',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _categoriaController,
                        decoration: const InputDecoration(
                          labelText: 'Categoría *',
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Campo requerido' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockController,
                        decoration: const InputDecoration(labelText: 'Stock *'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Campo requerido';
                          if (int.tryParse(value!) == null)
                            return 'Debe ser un número';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _stockMinimoController,
                        decoration: const InputDecoration(
                          labelText: 'Stock Mínimo *',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Campo requerido';
                          if (int.tryParse(value!) == null)
                            return 'Debe ser un número';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _precioController,
                        decoration: const InputDecoration(
                          labelText: 'Precio Unitario *',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Campo requerido';
                          if (double.tryParse(value!) == null)
                            return 'Debe ser un número';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _unidadMedidaController,
                        decoration: const InputDecoration(
                          labelText: 'Unidad de Medida *',
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Campo requerido' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _proveedorController,
                  decoration: const InputDecoration(labelText: 'Proveedor *'),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fechaCompraController,
                  decoration: const InputDecoration(
                    labelText: 'Fecha de Compra (AAAA-MM-DD)',
                    hintText: '2025-01-01',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usoPrincipalController,
                  decoration: const InputDecoration(labelText: 'Uso Principal'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: (_validandoCodigo || _errorCodigo != null)
              ? null
              : () async {
                  if (_formKey.currentState!.validate()) {
                    // Validación final antes de guardar
                    final codigo = _idController.text.trim().toUpperCase();

                    // Si estamos editando y es el mismo código, permitir
                    if (_codigoOriginal == null ||
                        codigo != _codigoOriginal!.toUpperCase()) {
                      final existe = await widget.onValidarCodigo(codigo);
                      if (existe) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ El código "$codigo" ya existe'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                    }

                    widget.onSave({
                      'id': codigo,
                      'nombre': _nombreController.text,
                      'categoria': _categoriaController.text,
                      'stock': int.tryParse(_stockController.text),
                      'stock_minimo': int.tryParse(_stockMinimoController.text),
                      'precio_unitario': double.tryParse(
                        _precioController.text,
                      ),
                      'unidad_medida': _unidadMedidaController.text,
                      'proveedor': _proveedorController.text,
                      'fecha_compra': _fechaCompraController.text,
                      'uso_principal': _usoPrincipalController.text,
                    });
                    Navigator.pop(context);
                  }
                },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
