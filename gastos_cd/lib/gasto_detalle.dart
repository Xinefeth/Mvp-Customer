import 'package:flutter/material.dart';

class GastoDetalle extends StatefulWidget {
  final Map<String, dynamic> gasto;

  const GastoDetalle({super.key, required this.gasto});

  @override
  State<GastoDetalle> createState() => _GastoDetalleState();
}

class _GastoDetalleState extends State<GastoDetalle> {
  late TextEditingController descripcionCtrl;
  late TextEditingController categoriaCtrl;
  late TextEditingController textoCtrl;

  late List<Map<String, dynamic>> items;
  double total = 0;

  @override
  void initState() {
    super.initState();

    descripcionCtrl = TextEditingController(text: widget.gasto['descripcion']);
    categoriaCtrl = TextEditingController(text: widget.gasto['categoria']);
    textoCtrl = TextEditingController(text: widget.gasto['textoCompleto']);

    items = List<Map<String, dynamic>>.from(widget.gasto['items'] ?? []);
    total = widget.gasto['total'] ?? 0;

    // Aseguramos que cada item tenga controllers internos sin recrearse
    for (var item in items) {
      item['nombreCtrl'] = TextEditingController(text: item['nombre']);
      item['precioCtrl'] =
          TextEditingController(text: item['precio'].toString());
    }
  }

  void recalcularTotal() {
    total = 0;
    for (var item in items) {
      final precio = double.tryParse(item['precioCtrl'].text) ?? 0;
      total += precio;
    }
    setState(() {});
  }

  void agregarItem() {
    setState(() {
      final nuevo = {
        'nombre': '',
        'precio': 0.0,
        'nombreCtrl': TextEditingController(),
        'precioCtrl': TextEditingController(),
      };
      items.add(nuevo);
    });
  }

  void eliminarItem(int index) {
    setState(() {
      items.removeAt(index);
      recalcularTotal();
    });
  }

  @override
  void dispose() {
    descripcionCtrl.dispose();
    categoriaCtrl.dispose();
    textoCtrl.dispose();

    for (var item in items) {
      item['nombreCtrl'].dispose();
      item['precioCtrl'].dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle del Gasto"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              widget.gasto['descripcion'] = descripcionCtrl.text.trim();
              widget.gasto['categoria'] = categoriaCtrl.text.trim();
              widget.gasto['textoCompleto'] = textoCtrl.text;

              for (var item in items) {
                item['nombre'] = item['nombreCtrl'].text.trim();
                item['precio'] =
                    double.tryParse(item['precioCtrl'].text) ?? 0.0;
              }

              widget.gasto['items'] = items;
              widget.gasto['total'] = total;
              widget.gasto['monto'] = total.toStringAsFixed(2);

              Navigator.pop(context, widget.gasto);
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // 📌 ITEMS DETECTADOS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Productos / Servicios detectados",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                IconButton(
                  onPressed: agregarItem,
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                )
              ],
            ),

            const SizedBox(height: 10),

            ...List.generate(items.length, (index) {
              final item = items[index];

              return Card(
                elevation: 3,
                shadowColor: Colors.deepPurple,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Nombre
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: item['nombreCtrl'],
                              decoration: const InputDecoration(
                                labelText: "Nombre",
                              ),
                              onChanged: (_) => setState(() {
                                item['nombre'] =
                                    item['nombreCtrl'].text.trim();
                              }),
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Precio
                          Expanded(
                            child: TextField(
                              controller: item['precioCtrl'],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: "Precio",
                              ),
                              onChanged: (_) => recalcularTotal(),
                            ),
                          ),

                          IconButton(
                            onPressed: () => eliminarItem(index),
                            icon: const Icon(Icons.delete, color: Colors.red),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            // 📌 TOTAL
            Center(
              child: Text(
                "Monto total: S/${total.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // TEXTO COMPLETO
            const Text(
              "Texto completo reconocido",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: textoCtrl,
              maxLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}