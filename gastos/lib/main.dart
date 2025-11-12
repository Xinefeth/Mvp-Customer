import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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

  Future<void> _tomarFotoYRegistrar() async {
    final XFile? foto = await _picker.pickImage(source: ImageSource.camera);
    if (foto == null) return;

    setState(() => _procesando = true);

    try {
      final inputImage = InputImage.fromFile(File(foto.path));
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      final texto = recognizedText.text;
      final monto = _extraerMonto(texto);
      final categoria = _clasificarGasto(texto);

      _gastos.insert(0, {
        'descripcion': texto.split('\n').first,
        'monto': monto ?? 'Pendiente',
        'categoria': categoria,
        'fecha': DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Gasto registrado automáticamente (${categoria})'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Error procesando imagen: $e')),
      );
    } finally {
      setState(() => _procesando = false);
    }
  }

  /// Detecta montos tipo 23.50 o 15,90
  String? _extraerMonto(String texto) {
    final regex = RegExp(r'(\d+[.,]\d{2})');
    final match = regex.firstMatch(texto.replaceAll(',', '.'));
    return match != null ? match.group(1) : null;
  }

  /// Clasifica por palabras clave
  String _clasificarGasto(String texto) {
    texto = texto.toLowerCase();
    if (texto.contains('pollo') ||
        texto.contains('comida') ||
        texto.contains('burger') ||
        texto.contains('restaurante')) {
      return '🍔 Comida';
    } else if (texto.contains('uber') ||
        texto.contains('taxi') ||
        texto.contains('gasolina') ||
        texto.contains('bus')) {
      return '🚗 Transporte';
    } else if (texto.contains('ropa') ||
        texto.contains('tienda') ||
        texto.contains('compra')) {
      return '🛍️ Compras';
    } else if (texto.contains('luz') ||
        texto.contains('agua') ||
        texto.contains('internet') ||
        texto.contains('recibo')) {
      return '💡 Servicios';
    } else {
      return '💰 Otros';
    }
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📸 Registro Automático de Gastos'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _procesando ? null : _tomarFotoYRegistrar,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Tomar Foto'),
      ),
      body: _procesando
          ? const Center(child: CircularProgressIndicator())
          : _gastos.isEmpty
              ? const Center(
                  child: Text(
                    'Aún no hay gastos registrados.\nPresiona 📷 para empezar.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _gastos.length,
                  itemBuilder: (context, index) {
                    final gasto = _gastos[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: Text(
                          gasto['categoria'],
                          style: const TextStyle(fontSize: 20),
                        ),
                        title: Text(gasto['descripcion']),
                        subtitle: Text(
                            'Monto: S/${gasto['monto']} — ${gasto['fecha'].toString().substring(0, 16)}'),
                      ),
                    );
                  },
                ),
    );
  }
}
