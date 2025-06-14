import 'package:basefundi/screens/dashboard.dart';
import 'package:basefundi/screens/ventas/editarventas.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';

class ModificarVentasScreen extends StatefulWidget {
  const ModificarVentasScreen({super.key});

  @override
  State<ModificarVentasScreen> createState() => _ModificarVentasScreenState();
}

class _ModificarVentasScreenState extends State<ModificarVentasScreen> {
  bool _esAdmin = false;
  bool _verificado = false;
  String _busquedaCliente = '';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _verificarPermiso();
  }

  Future<void> _verificarPermiso() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('usuarios_activos')
              .doc(user.uid)
              .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final rol = data['rol'];

        if (rol == 'Administrador') {
          setState(() {
            _esAdmin = true;
            _verificado = true;
          });
          return;
        }
      }
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permisos para modificar ventas.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 3),
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      });
    });

    setState(() {
      _verificado = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_verificado || !_esAdmin) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildFilters(),
            Expanded(child: _buildListaVentas()),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: const Center(
        child: Text(
          'Modificar Ventas',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por cliente...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _busquedaCliente = value;
              });
            },
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                });
              }
            },
            icon: const Icon(Icons.calendar_today),
            label: Text(
              _selectedDate == null
                  ? 'Filtrar por fecha'
                  : 'Filtrado: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          if (_selectedDate != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDate = null;
                });
              },
              child: const Text('Limpiar filtro de fecha'),
            ),
        ],
      ),
    );
  }

  Widget _buildListaVentas() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('ventas')
              .orderBy('fecha', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error al cargar las ventas'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final ventas = snapshot.data?.docs ?? [];

        final ventasFiltradas =
            ventas.where((venta) {
              final data = venta.data() as Map<String, dynamic>;
              final cliente = data['cliente']?.toString().toLowerCase() ?? '';
              final fecha = (data['fecha'] as Timestamp?)?.toDate();

              final coincideCliente = cliente.contains(
                _busquedaCliente.toLowerCase(),
              );

              final coincideFecha =
                  _selectedDate == null ||
                  (fecha != null &&
                      fecha.day == _selectedDate!.day &&
                      fecha.month == _selectedDate!.month &&
                      fecha.year == _selectedDate!.year);

              return coincideCliente && coincideFecha;
            }).toList();

        if (ventasFiltradas.isEmpty) {
          return const Center(
            child: Text(
              'No hay ventas registradas para modificar',
              style: TextStyle(fontSize: 16, color: Color(0xFF1E3A8A)),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: ventasFiltradas.length,
          itemBuilder: (context, index) {
            final venta = ventasFiltradas[index];
            final data = venta.data() as Map<String, dynamic>;

            final cliente = data['cliente'] ?? 'Sin nombre';
            final total = data['total'] ?? 0.0;
            final fecha = (data['fecha'] as Timestamp?)?.toDate();
            final fechaStr =
                fecha != null
                    ? DateFormat('dd/MM/yyyy hh:mm a').format(fecha)
                    : 'Fecha desconocida';

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cliente,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fechaStr,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '\$${(total as num).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Editar',
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => EditarVentaScreen(
                                          ventaId: venta.id,
                                          datosVenta: data,
                                        ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmarEliminacion(venta.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmarEliminacion(String idVenta) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: const Text(
              '¿Estás seguro de que deseas eliminar esta venta?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('ventas')
                      .doc(idVenta)
                      .delete();
                  Navigator.pop(context);
                },
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}
