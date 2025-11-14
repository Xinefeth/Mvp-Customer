import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'gasto_detalle.dart';

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
  // 🔍 EXTRAER ITEMS Y PRECIOS DETECTADOS EN EL TEXTO (MEJORADO)
  // -------------------------------------------------------------------
  Map<String, dynamic> extraerItems(String texto) {
    final List<Map<String, dynamic>> items = [];
    double total = 0;

    // Estandarizamos símbolos
    texto = texto.replaceAll('S/.', 'S/');
    texto = texto.replaceAll('S :', 'S/');
    texto = texto.replaceAll('S -', 'S/');

    final lineas = texto.split('\n');

    final regex = RegExp(
      r'(.+?)\s*(S\/|S|S:|\$)?\s*([0-9]+(?:[.,][0-9]{2,3})?)',
      caseSensitive: false,
    );

    for (var linea in lineas) {
      final l = linea.trim();
      if (l.isEmpty) continue;

      final match = regex.firstMatch(l);

      if (match != null) {
        final nombre = match.group(1)!.trim();

        // Evita nombres inválidos
        if (nombre.length < 2) continue;
        if (RegExp(r'^\d+$').hasMatch(nombre)) continue;

        var precioStr = match.group(3)!.trim();
        precioStr = precioStr.replaceAll(',', '');

        final precio = double.tryParse(precioStr);
        if (precio == null || precio == 0) continue;

        items.add({
          'nombre': nombre.toUpperCase(),
          'precio': precio,
        });

        total += precio;
      }
    }

    return {
      'items': items,
      'total': total,
    };
  }

  // -------------------------------------------------------------------
  // 📸 TOMAR FOTO Y REGISTRAR GASTO
  // -------------------------------------------------------------------
  Future<void> _tomarFotoYRegistrar() async {
    final XFile? foto = await _picker.pickImage(source: ImageSource.camera);
    if (foto == null) return;

    setState(() => _procesando = true);

    try {
      final inputImage = InputImage.fromFile(File(foto.path));
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      final texto = recognizedText.text;
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Gasto registrado automáticamente ($categoria)'),
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

  // -------------------------------------------------------------------
  // 🔢 BACKUP
  // -------------------------------------------------------------------
  String? _extraerMonto(String texto) {
    final regex = RegExp(r'(\d+[.,]\d{2})');
    final match = regex.firstMatch(texto.replaceAll(',', '.'));
    return match != null ? match.group(1) : null;
  }

  // -------------------------------------------------------------------
  // 🧠 CLASIFICADOR DE CATEGORÍAS
  // -------------------------------------------------------------------
  String _clasificarGasto(String texto) {
    texto = texto.toLowerCase();

    if (texto.contains('pollo') ||
        texto.contains('comida') ||
        texto.contains('burger') ||
        texto.contains('restaurant') ||
        texto.contains('restaurante') ||
        texto.contains('pizza') ||
        texto.contains('snack') ||
        texto.contains('supermercado')) {
      return '🍔 Alimentación';
    }

    if (texto.contains('uber') ||
        texto.contains('taxi') ||
        texto.contains('didi') ||
        texto.contains('bus') ||
        texto.contains('gasolina')) {
      return '🚗 Transporte';
    }

    if (texto.contains('luz') ||
        texto.contains('agua') ||
        texto.contains('gas') ||
        texto.contains('internet') ||
        texto.contains('alquiler')) {
      return '🏠 Vivienda';
    }

    if (texto.contains('doctor') ||
        texto.contains('farmacia') ||
        texto.contains('botica') ||
        texto.contains('clinica')) {
      return '🩺 Salud';
    }

    if (texto.contains('universidad') ||
        texto.contains('colegio') ||
        texto.contains('libro') ||
        texto.contains('curso')) {
      return '📚 Educación';
    }

    if (texto.contains('cine') ||
        texto.contains('netflix') ||
        texto.contains('hbo') ||
        texto.contains('spotify')) {
      return '🎉 Entretenimiento';
    }

    if (texto.contains('ropa') ||
        texto.contains('zapatilla') ||
        texto.contains('spa')) {
      return '🛍️ Compras personales';
    }

    if (texto.contains('laptop') ||
        texto.contains('celular') ||
        texto.contains('monitor')) {
      return '📱 Tecnología';
    }

    if (texto.contains('perro') ||
        texto.contains('gato') ||
        texto.contains('veterinaria')) {
      return '🐶 Mascotas';
    }

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
      MaterialPageRoute(
        builder: (_) => GastoDetalle(gasto: gasto),
      ),
    );

    if (resultado != null) {
      setState(() {
        final index = _gastos.indexWhere((g) => g['id'] == resultado['id']);
        if (index != -1) {
          _gastos[index] = resultado;
        }
      });
    }
  }

  // -------------------------------------------------------------------
  // 🖼️ UI LISTA DE GASTOS
  // -------------------------------------------------------------------
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
                        onTap: () => _abrirDetalle(gasto),
                        leading: Text(
                          gasto['categoria'],
                          style: const TextStyle(fontSize: 20),
                        ),
                        title: Text(gasto['descripcion']),
                        subtitle: Text(
                          'Total: S/${gasto['total'].toStringAsFixed(2)} — ${gasto['fecha'].toString().substring(0, 16)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
    );
  }
}
