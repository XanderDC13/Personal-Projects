import 'package:basefundi/screens/inventarios/tablasinv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InventarioGeneralScreen extends StatefulWidget {
  const InventarioGeneralScreen({super.key});

  @override
  State<InventarioGeneralScreen> createState() =>
      _InventarioGeneralScreenState();
}

class _InventarioGeneralScreenState extends State<InventarioGeneralScreen>
    with SingleTickerProviderStateMixin {
  String searchQuery = '';

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD6EAF8),
      body: Column(
        children: [
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4682B4), Color(0xFF4682B4)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: const Center(
                  child: Text(
                    'Inventario General',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildBarraBusqueda(),
          const SizedBox(height: 8),
          Expanded(child: _buildTablaGeneral()),
        ],
      ),
    );
  }

  Widget _buildBarraBusqueda() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o código...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildTablaGeneral() {
    final historialStream =
        FirebaseFirestore.instance
            .collection('historial_inventario_general')
            .orderBy('fecha_actualizacion', descending: true)
            .snapshots();

    final ventasFuture = FirebaseFirestore.instance.collection('ventas').get();

    return FutureBuilder<QuerySnapshot>(
      future: ventasFuture,
      builder: (context, ventasSnapshot) {
        if (ventasSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (ventasSnapshot.hasError) {
          return const Center(child: Text('Error al cargar las ventas.'));
        }

        final ventasDocs = ventasSnapshot.data?.docs ?? [];
        final ventasPorProducto = <String, int>{};

        for (var venta in ventasDocs) {
          final productos = List<Map<String, dynamic>>.from(venta['productos']);
          for (var producto in productos) {
            final codigo = producto['codigo']?.toString() ?? '';
            final cantidad = (producto['cantidad'] ?? 0) as num;
            ventasPorProducto[codigo] =
                (ventasPorProducto[codigo] ?? 0) + cantidad.toInt();
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: historialStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allDocs = snapshot.data!.docs;
            final Map<String, Map<String, dynamic>> grouped = {};

            for (var doc in allDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final codigo = (data['codigo'] ?? '').toString();
              final nombre = (data['nombre'] ?? '').toString();
              final cantidad = (data['cantidad'] ?? 0) as int;
              final tipo = (data['tipo'] ?? 'entrada').toString();

              final ajusteCantidad = tipo == 'salida' ? -cantidad : cantidad;

              if (!grouped.containsKey(codigo)) {
                grouped[codigo] = {
                  'codigo': codigo,
                  'nombre': nombre,
                  'cantidad': ajusteCantidad,
                };
              } else {
                grouped[codigo]!['cantidad'] += ajusteCantidad;
              }
            }

            ventasPorProducto.forEach((codigo, cantidadVendida) {
              if (grouped.containsKey(codigo)) {
                grouped[codigo]!['cantidad'] -= cantidadVendida;
              }
            });

            final filtered =
                grouped.values.where((data) {
                  final codigo = data['codigo'].toString().toLowerCase();
                  final nombre = data['nombre'].toString().toLowerCase();
                  return searchQuery.isEmpty ||
                      codigo.contains(searchQuery) ||
                      nombre.contains(searchQuery);
                }).toList();

            if (filtered.isEmpty) {
              return const Center(
                child: Text('No hay registros para mostrar.'),
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width,
                  ),
                  child: DataTable(
                    columnSpacing: 16,
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFF4682B4),
                    ),
                    headingTextStyle: const TextStyle(color: Colors.white),
                    columns: const [
                      DataColumn(label: Text('Nombre')),
                      DataColumn(label: Text('Código')),
                      DataColumn(label: Text('Cantidad')),
                      DataColumn(label: Text('Acciones')),
                    ],
                    rows:
                        filtered.map((data) {
                          return DataRow(
                            cells: [
                              DataCell(
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => TablainvScreen(
                                              codigo: data['codigo'],
                                              nombre: data['nombre'],
                                            ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    data['nombre'],
                                    style: const TextStyle(
                                      color: Color(0xFF4682B4),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(data['codigo'])),
                              DataCell(Text(data['cantidad'].toString())),
                              DataCell(
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: 'Eliminar',
                                  onPressed: () async {
                                    final confirmar =
                                        await showDialog<bool>(
                                          context: context,
                                          builder:
                                              (_) => AlertDialog(
                                                title: const Text(
                                                  'Confirmar eliminación',
                                                ),
                                                content: Text(
                                                  '¿Estás seguro de eliminar todos los registros del producto "${data['nombre']}"?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          context,
                                                          false,
                                                        ),
                                                    child: const Text(
                                                      'Cancelar',
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          context,
                                                          true,
                                                        ),
                                                    child: const Text(
                                                      'Eliminar',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                        ) ??
                                        false;

                                    if (confirmar) {
                                      // ✅ OBTENER usuario logueado
                                      final currentUser =
                                          FirebaseAuth.instance.currentUser;
                                      if (currentUser == null) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Usuario no autenticado',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      // ✅ TRAER nombre real del usuario logueado
                                      final userDoc =
                                          await FirebaseFirestore.instance
                                              .collection('usuarios_activos')
                                              .doc(currentUser.uid)
                                              .get();

                                      final nombreUsuario =
                                          userDoc.data()?['nombre'] ??
                                          currentUser.email ??
                                          '---';

                                      // ✅ BORRAR registros
                                      final docsToDelete = snapshot.data!.docs
                                          .where(
                                            (doc) =>
                                                doc['codigo'].toString() ==
                                                data['codigo'],
                                          );

                                      for (var doc in docsToDelete) {
                                        await doc.reference.delete();
                                      }

                                      // ✅ AUDITORÍA detallada
                                      await FirebaseFirestore.instance
                                          .collection('auditoria_general')
                                          .add({
                                            'accion':
                                                'Eliminación de Inventario General',
                                            'detalle':
                                                'Producto: ${data['nombre']}, '
                                                'Cantidad eliminada: ${data['cantidad']}',
                                            'fecha': DateTime.now(),
                                            'usuario_uid': currentUser.uid,
                                            'usuario_nombre': nombreUsuario,
                                          });

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Registros eliminados correctamente.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
