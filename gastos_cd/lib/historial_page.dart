import 'package:flutter/material.dart';
import 'gasto_detalle.dart';

class HistorialPage extends StatefulWidget {
  final List<Map<String, dynamic>> gastos;
  final Function(int) onEliminarGasto; // Callback para eliminar desde aquí

  const HistorialPage({
    super.key,
    required this.gastos,
    required this.onEliminarGasto,
  });

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  DateTime _fechaSeleccionada = DateTime.now();

  // Filtra la lista completa para obtener solo los de la fecha seleccionada
  List<Map<String, dynamic>> get _gastosDelDia {
    return widget.gastos.where((g) {
      final fechaGasto = DateTime.parse(g['fecha']);
      return DateUtils.isSameDay(fechaGasto, _fechaSeleccionada);
    }).toList();
  }

  // Calcula el total solo del día seleccionado
  double get _totalDelDia {
    return _gastosDelDia.fold(0.0, (sum, item) {
      return sum + (item['total'] ?? 0.0);
    });
  }

  void _cambiarDia(int dias) {
    setState(() {
      _fechaSeleccionada = _fechaSeleccionada.add(Duration(days: dias));
    });
  }

  Future<void> _seleccionarFechaCalendario() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _fechaSeleccionada = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gastosFiltrados = _gastosDelDia;
    // Ordenamos para que los más recientes (hora) salgan primero
    gastosFiltrados.sort((a, b) => b['fecha'].compareTo(a['fecha']));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Control Diario"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 📅 SELECTOR DE FECHA Y RESUMEN
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: () => _cambiarDia(-1),
                    ),
                    InkWell(
                      onTap: _seleccionarFechaCalendario,
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "${_fechaSeleccionada.day}/${_fechaSeleccionada.month}/${_fechaSeleccionada.year}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      onPressed: () => _cambiarDia(1),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "Total del día: S/${_totalDelDia.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 📋 LISTA DE GASTOS DEL DÍA
          Expanded(
            child: gastosFiltrados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox,
                            size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        const Text(
                          "Sin movimientos este día",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: gastosFiltrados.length,
                    itemBuilder: (context, index) {
                      final g = gastosFiltrados[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: Text(
                              g['categoria'].toString().substring(0, 1),
                              style:
                                  TextStyle(color: Colors.green.shade800),
                            ),
                          ),
                          title: Text(g['descripcion'], maxLines: 1),
                          subtitle: Text(
                            "${g['categoria']} • ${TimeOfDay.fromDateTime(DateTime.parse(g['fecha'])).format(context)}",
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "S/${(g['total'] ?? 0).toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () {
                                  // Llamamos a la función del padre para borrar
                                  widget.onEliminarGasto(g['id']);
                                  setState(() {}); // Actualizamos vista local
                                },
                              ),
                            ],
                          ),
                          onTap: () async {
                            // Navegar al detalle (igual que en Home)
                             await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GastoDetalle(gasto: g),
                              ),
                            );
                            setState(() {}); // Recargar al volver por si editó
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}