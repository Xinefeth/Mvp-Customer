import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'gasto_detalle.dart';
import 'dashboard_page.dart';

import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const GastosOCRApp());
}

class GastosOCRApp extends StatelessWidget {
  const GastosOCRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gastos OCR Automático',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  final List<Map<String, dynamic>> _gastos = [];

  bool _procesando = false;

  // =======================================================
  // 🚀 Cargar datos desde SharedPreferences
  // =======================================================
  @override
  void initState() {
    super.initState();
    _cargarGastos();
  }

  Future<void> _cargarGastos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString("gastos");

    if (data != null) {
      final lista = jsonDecode(data) as List;
      _gastos.clear();
      _gastos.addAll(lista.map((e) => Map<String, dynamic>.from(e)));
      setState(() {});
    }
  }

  Future<void> _guardarGastos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("gastos", jsonEncode(_gastos));
  }

  // =======================================================
  // 🔍 Extraer items + total de texto OCR
  // =======================================================
  Map<String, dynamic> extraerItems(String texto) {
    final List<Map<String, dynamic>> items = [];
    double total = 0;

    final regexPrecio = RegExp(r'([0-9]+(?:[.,][0-9]{2}))');
    final prohibidas = [
      "total", "igv", "venta", "percepcion", "cnt", "vta",
      "t. x cobrar", "subtotal", "importe"
    ];

    String? ultimoNombre;

    for (var linea in texto.split('\n')) {
      final l = linea.trim();
      if (l.isEmpty) continue;

      final precios = regexPrecio.allMatches(l);

      if (precios.isNotEmpty) {
        final precioStr = precios.last.group(1)!.replaceAll(',', '.');
        final precio = double.tryParse(precioStr);

        if (precio != null && ultimoNombre != null) {
          items.add({'nombre': ultimoNombre.toUpperCase(), 'precio': precio});
          total += precio;
          ultimoNombre = null;
        }
        continue;
      }

      final lower = l.toLowerCase();
      if (!prohibidas.any((p) => lower.contains(p)) &&
          !RegExp(r'^\d').hasMatch(l)) {
        ultimoNombre = l;
      }
    }

    return {"items": items, "total": total};
  }

  // =======================================================
  // 📸 Tomar foto
  // =======================================================
  Future<void> _tomarFotoYRegistrar() async {
    final XFile? foto = await _picker.pickImage(source: ImageSource.camera);
    if (foto == null) return;
    await _procesarImagen(File(foto.path));
  }

  // =======================================================
  // 📥 Subir archivo
  // =======================================================
  Future<void> _subirArchivo() async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (selected == null) return;

    final file = File(selected.files.single.path!);

    if (file.path.endsWith(".pdf")) {
      await _procesarPDF(file);
    } else {
      await _procesarImagen(file);
    }
  }

  // =======================================================
  // 📄 Procesar PDF
  // =======================================================
  Future<void> _procesarPDF(File archivo) async {
    setState(() => _procesando = true);

    try {
      final pdf = await PdfDocument.openFile(archivo.path);
      String textoExtraido = "";

      for (int i = 1; i <= pdf.pagesCount; i++) {
        final page = await pdf.getPage(i);

        final rendered = await page.render(
          width: page.width,
          height: page.height,
        );

        final Uint8List bytes = rendered!.bytes;

        final inputImage = InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: Size(page.width.toDouble(), page.height.toDouble()),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.bgra8888,
            bytesPerRow: (page.width * 4).toInt(),
          ),
        );

        final text = await _textRecognizer.processImage(inputImage);
        textoExtraido += "\n${text.text}";

        await page.close();
      }

      await _registrarGasto(textoExtraido);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("📄 PDF procesado correctamente"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _procesando = false);
    }
  }

  // =======================================================
  // 🖼️ Procesar imagen
  // =======================================================
  Future<void> _procesarImagen(File archivo) async {
    setState(() => _procesando = true);

    try {
      final inputImage = InputImage.fromFile(archivo);
      final text = await _textRecognizer.processImage(inputImage);

      await _registrarGasto(text.text);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🖼️ Imagen procesada correctamente"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _procesando = false);
    }
  }

  // =======================================================
  // 🧾 Registrar gasto
  // =======================================================
  Future<void> _registrarGasto(String texto) async {
    final analisis = extraerItems(texto);

    final nuevo = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'descripcion': texto.split('\n').first.trim(),
      'textoCompleto': texto,
      'items': analisis['items'],
      'total': analisis['total'],
      'monto': analisis['total'] == 0
          ? "Pendiente"
          : analisis['total'].toStringAsFixed(2),
      'categoria': _clasificarGasto(texto),
      'fecha': DateTime.now().toIso8601String(),
    };

    setState(() => _gastos.insert(0, nuevo));
    await _guardarGastos();
  }

  // =======================================================
  // 🗑️ Eliminar gasto
  // =======================================================
  Future<void> _eliminarGasto(int id) async {
    setState(() {
      _gastos.removeWhere((g) => g['id'] == id);
    });

    await _guardarGastos();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🗑️ Gasto eliminado"),
        backgroundColor: Colors.red,
      ),
    );
  }

  // =======================================================
  // 🧠 Clasificación simple
  // =======================================================
  String _clasificarGasto(String t) {
    t = t.toLowerCase();
    if (t.contains('pollo') || t.contains('comida')) return '🍔 Alimentación';
    if (t.contains('uber') || t.contains('taxi')) return '🚗 Transporte';
    if (t.contains('luz') || t.contains('agua')) return '🏠 Vivienda';
    if (t.contains('farmacia') || t.contains('doctor')) return '🩺 Salud';
    if (t.contains('universidad')) return '📚 Educación';
    if (t.contains('cine') || t.contains('netflix')) return '🎉 Entretenimiento';
    if (t.contains('ropa')) return '🛍 Compras';
    if (t.contains('celular')) return '📱 Tecnología';
    return '💰 Otros';
  }

  // =======================================================
  // UI
  // =======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registro Automático de Gastos"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _procesando ? null : _subirArchivo,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DashboardPage(gastos: _gastos),
                ),
              );
            },
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _procesando ? null : _tomarFotoYRegistrar,
        icon: const Icon(Icons.camera_alt),
        label: const Text("Tomar Foto"),
      ),

      body: _procesando
          ? const Center(child: CircularProgressIndicator())
          : _gastos.isEmpty
              ? const Center(
                  child: Text(
                    "Aún no hay gastos.\nPresiona 📷 o 📄 para empezar.",
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _gastos.length,
                  itemBuilder: (_, i) {
                    final g = _gastos[i];

                    // =======================================================
                    // ⭐ CARD CUSTOM — SIEMPRE MUESTRA EL ÍCONO DE BORRAR ⭐
                    // =======================================================
                    return Card(
                      child: InkWell(
                        onTap: () => _abrirDetalle(g),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 🏷 Categoría
                              Text(
                                g['categoria'],
                                style: const TextStyle(fontSize: 22),
                              ),

                              const SizedBox(width: 12),

                              // 📄 Descripción + Total
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g['descripcion'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      "Total: S/${g['total'].toStringAsFixed(2)}",
                                      style: const TextStyle(color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),

                              // 🗑️ BORRAR
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _eliminarGasto(g['id']),
                              ),

                              // ➡️ Flecha
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  // =======================================================
  // 🌟 Abrir detalle
  // =======================================================
  Future<void> _abrirDetalle(Map<String, dynamic> gasto) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GastoDetalle(gasto: gasto)),
    );

    if (res != null) {
      final index = _gastos.indexWhere((g) => g['id'] == res['id']);
      if (index != -1) {
        setState(() => _gastos[index] = res);
        await _guardarGastos();
      }
    }
  }
}
