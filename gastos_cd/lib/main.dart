import 'dart:io';
import 'dart:typed_data';   // 👈 IMPORT correcto para Uint8List

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'gasto_detalle.dart';

// 📥 Elegir archivos (PDF / imágenes)
import 'package:file_picker/file_picker.dart';

// 📄 Render PDF con PDFX
import 'package:pdfx/pdfx.dart';


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

  // -------------------------------------------------------------------
  // 🔍 ANALIZAR TEXTO PARA EXTRAER ITEMS + PRECIOS
  // -------------------------------------------------------------------
  Map<String, dynamic> extraerItems(String texto) {
    final List<Map<String, dynamic>> items = [];
    double total = 0;

    final regexPrecio = RegExp(r'([0-9]+(?:[.,][0-9]{2}))');
    final prohibidas = [
      "total", "igv", "venta", "percepcion",
      "cnt", "vta", "t. x cobrar", "subtotal", "importe"
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
          items.add({
            'nombre': ultimoNombre.toUpperCase(),
            'precio': precio,
          });
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

    return {'items': items, 'total': total};
  }

  // -------------------------------------------------------------------
  // 📸 TOMAR FOTO Y REGISTRAR
  // -------------------------------------------------------------------
  Future<void> _tomarFotoYRegistrar() async {
    final XFile? foto = await _picker.pickImage(source: ImageSource.camera);
    if (foto == null) return;
    await _procesarImagen(File(foto.path));
  }

  // -------------------------------------------------------------------
  // 📂 SUBIR ARCHIVO PDF / IMAGEN
  // -------------------------------------------------------------------
  Future<void> _subirArchivo() async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (selected == null) return;

    final path = selected.files.single.path!;
    final file = File(path);

    if (path.endsWith(".pdf")) {
      await _procesarPDF(file);
    } else {
      await _procesarImagen(file);
    }
  }

  // -------------------------------------------------------------------
  // 📄 PROCESAR PDF COMPLETO (PDFX)
  // -------------------------------------------------------------------
Future<void> _procesarPDF(File archivo) async {
  setState(() => _procesando = true);

  try {
    final pdf = await PdfDocument.openFile(archivo.path);
    String textoExtraido = "";

    for (int page = 1; page <= pdf.pagesCount; page++) {
      final pdfPage = await pdf.getPage(page);

      // pdfx 2.6.0 usa width/height como double
      final pageImage = await pdfPage.render(
        width: pdfPage.width,
        height: pdfPage.height,
      );

      // pdfx 2.6.0 usa .bytes (Uint8List?) directamente
      final Uint8List bytes = pageImage!.bytes;

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(
            pdfPage.width.toDouble(),
            pdfPage.height.toDouble(),
          ),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: (pdfPage.width * 4).toInt(),  // convertir a int
        ),
      );

      final text = await _textRecognizer.processImage(inputImage);
      textoExtraido += "\n" + text.text;

      await pdfPage.close();
    }

    await _registrarGasto(textoExtraido);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("📄 PDF procesado correctamente"),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Error: $e")));
  } finally {
    setState(() => _procesando = false);
  }
}

  // -------------------------------------------------------------------
  // 🖼️ PROCESAR IMAGEN
  // -------------------------------------------------------------------
  Future<void> _procesarImagen(File archivo) async {
    setState(() => _procesando = true);

    try {
      final inputImage = InputImage.fromFile(archivo);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      await _registrarGasto(recognizedText.text);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🖼️ Imagen procesada correctamente"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _procesando = false);
    }
  }

  // -------------------------------------------------------------------
  // 🧾 REGISTRAR GASTO A LA LISTA
  // -------------------------------------------------------------------
  Future<void> _registrarGasto(String texto) async {
    final categoria = _clasificarGasto(texto);
    final analisis = extraerItems(texto);

    final items = analisis['items'];
    final total = analisis['total'];

    final nuevoGasto = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'descripcion': texto.split('\n').first.trim(),
      'textoCompleto': texto,
      'items': items,
      'total': total,
      'monto': total == 0 ? 'Pendiente' : total.toStringAsFixed(2),
      'categoria': categoria,
      'fecha': DateTime.now(),
    };

    setState(() => _gastos.insert(0, nuevoGasto));
  }

  // -------------------------------------------------------------------
  // 🧠 CLASIFICAR GASTO
  // -------------------------------------------------------------------
  String _clasificarGasto(String texto) {
    texto = texto.toLowerCase();
    if (texto.contains('comida') || texto.contains('pollo')) return '🍔 Alimentación';
    if (texto.contains('uber') || texto.contains('taxi')) return '🚗 Transporte';
    if (texto.contains('luz') || texto.contains('agua')) return '🏠 Vivienda';
    if (texto.contains('doctor') || texto.contains('farmacia')) return '🩺 Salud';
    if (texto.contains('universidad') || texto.contains('colegio')) return '📚 Educación';
    if (texto.contains('netflix') || texto.contains('cine')) return '🎉 Entretenimiento';
    if (texto.contains('ropa')) return '🛍 Compras';
    if (texto.contains('celular')) return '📱 Tecnología';
    return '💰 Otros';
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // 📄 ABRIR DETALLE DEL GASTO
  // -------------------------------------------------------------------
  Future<void> _abrirDetalle(Map<String, dynamic> gasto) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GastoDetalle(gasto: gasto)),
    );

    if (resultado != null) {
      final index = _gastos.indexWhere((g) => g['id'] == resultado['id']);
      if (index != -1) {
        setState(() => _gastos[index] = resultado);
      }
    }
  }

  // -------------------------------------------------------------------
  // 🖼️ UI
  // -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro Automático de Gastos'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _procesando ? null : _subirArchivo,
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
                  itemBuilder: (context, i) {
                    final g = _gastos[i];
                    return Card(
                      child: ListTile(
                        onTap: () => _abrirDetalle(g),
                        leading: Text(g['categoria'], style: const TextStyle(fontSize: 22)),
                        title: Text(g['descripcion']),
                        subtitle: Text("Total: S/${g['total'].toStringAsFixed(2)}"),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
    );
  }
}
