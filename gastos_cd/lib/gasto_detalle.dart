import 'package:flutter/material.dart';

class GastoDetalle extends StatefulWidget {
  final Map<String, dynamic> gasto;

  const GastoDetalle({super.key, required this.gasto});

  @override
  State<GastoDetalle> createState() => _GastoDetalleState();
}

class _GastoDetalleState extends State<GastoDetalle> {
  late TextEditingController descripcionCtrl;
  late TextEditingController montoCtrl;
  late TextEditingController categoriaCtrl;
  late TextEditingController textoCtrl;

  @override
  void initState() {
    super.initState();
    descripcionCtrl =
        TextEditingController(text: widget.gasto['descripcion']);
    montoCtrl = TextEditingController(text: widget.gasto['monto'].toString());
    categoriaCtrl =
        TextEditingController(text: widget.gasto['categoria']);
    textoCtrl =
        TextEditingController(text: widget.gasto['textoCompleto']);
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
              widget.gasto['descripcion'] = descripcionCtrl.text;
              widget.gasto['monto'] = montoCtrl.text;
              widget.gasto['categoria'] = categoriaCtrl.text;
              widget.gasto['textoCompleto'] = textoCtrl.text;

              Navigator.pop(context, widget.gasto);
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: descripcionCtrl,
              decoration: const InputDecoration(
                labelText: "Descripción",
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: montoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Monto S/",
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: categoriaCtrl,
              decoration: const InputDecoration(
                labelText: "Categoría",
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Texto completo de la imagen reconocida",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: textoCtrl,
              maxLines: 8,
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
