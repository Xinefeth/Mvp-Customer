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

      final nuevoGasto = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'descripcion': texto.split('\n').first.trim(),
        'textoCompleto': texto,
        'monto': monto ?? 'Pendiente',
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

  /// Detecta montos tipo 23.50 o 15,90
  String? _extraerMonto(String texto) {
    final regex = RegExp(r'(\d+[.,]\d{2})');
    final match = regex.firstMatch(texto.replaceAll(',', '.'));
    return match != null ? match.group(1) : null;
  }

  String _clasificarGasto(String texto) {
    texto = texto.toLowerCase();

    // 🛒 1. ALIMENTACIÓN
    if (texto.contains('pollo') ||
        texto.contains('comida') ||
        texto.contains('burger') ||
        texto.contains('restaurant') ||
        texto.contains('restaurante') ||
        texto.contains('kfc') ||
        texto.contains('bembos') ||
        texto.contains('pizza') ||
        texto.contains('subway') ||
        texto.contains('pollo a la brasa') ||
        texto.contains('fast food') ||
        texto.contains('snack') ||
        texto.contains('bebida') ||
        texto.contains('supermercado') ||
        texto.contains('tottus') ||
        texto.contains('plaza vea') ||
        texto.contains('wong') ||
        texto.contains('vivanda') ||
        texto.contains('market') ||
        texto.contains('minimarket') ||
        texto.contains('delivery') ||
        texto.contains('rapi') ||
        texto.contains('rappi') ||
        texto.contains('glovo') ||
        texto.contains('pedidos ya') ||
        texto.contains('booster')) {
      return '🍔 Alimentación';
    }

    // 🚍 2. TRANSPORTE
    if (texto.contains('uber') ||
        texto.contains('taxi') ||
        texto.contains('didi') ||
        texto.contains('cabify') ||
        texto.contains('bus') ||
        texto.contains('pasaje') ||
        texto.contains('gasolina') ||
        texto.contains('grifo') ||
        texto.contains('peaje') ||
        texto.contains('estacionamiento') ||
        texto.contains('paradero') ||
        texto.contains('mantenimiento') ||
        texto.contains('auto') ||
        texto.contains('vehículo') ||
        texto.contains('lubricentro')) {
      return '🚗 Transporte';
    }

    // 🏠 3. VIVIENDA
    if (texto.contains('alquiler') ||
        texto.contains('renta') ||
        texto.contains('departamento') ||
        texto.contains('cuarto') ||
        texto.contains('habitacion') ||
        texto.contains('luz') ||
        texto.contains('agua') ||
        texto.contains('gas') ||
        texto.contains('internet') ||
        texto.contains('claro') ||
        texto.contains('movistar') ||
        texto.contains('entel') ||
        texto.contains('cable') ||
        texto.contains('mantenimiento del hogar') ||
        texto.contains('mueble') ||
        texto.contains('electrodomestico')) {
      return '🏠 Vivienda';
    }

    // 🛡 4. SALUD
    if (texto.contains('farmacia') ||
        texto.contains('botica') ||
        texto.contains('inkafarma') ||
        texto.contains('mifarma') ||
        texto.contains('doctor') ||
        texto.contains('consulta') ||
        texto.contains('clinica') ||
        texto.contains('seguro') ||
        texto.contains('analisis') ||
        texto.contains('laboratorio') ||
        texto.contains('examen')) {
      return '🩺 Salud';
    }

    // 📚 5. EDUCACIÓN
    if (texto.contains('colegio') ||
        texto.contains('universidad') ||
        texto.contains('matrícula') ||
        texto.contains('curso') ||
        texto.contains('taller') ||
        texto.contains('diploma') ||
        texto.contains('certificación') ||
        texto.contains('libro') ||
        texto.contains('materiales')) {
      return '📚 Educación';
    }

    // 🎉 6. ENTRETENIMIENTO
    if (texto.contains('cine') ||
        texto.contains('streaming') ||
        texto.contains('netflix') ||
        texto.contains('spotify') ||
        texto.contains('disney') ||
        texto.contains('hbo') ||
        texto.contains('fiesta') ||
        texto.contains('bar') ||
        texto.contains('discoteca') ||
        texto.contains('deporte') ||
        texto.contains('gym') ||
        texto.contains('videojuego') ||
        texto.contains('steam') ||
        texto.contains('musica')) {
      return '🎉 Entretenimiento';
    }

    // 👗 7. COMPRAS PERSONALES
    if (texto.contains('ropa') ||
        texto.contains('polera') ||
        texto.contains('zapatilla') ||
        texto.contains('calzado') ||
        texto.contains('camisa') ||
        texto.contains('falda') ||
        texto.contains('cartera') ||
        texto.contains('accesorio') ||
        texto.contains('collar') ||
        texto.contains('spa') ||
        texto.contains('peluquería') ||
        texto.contains('maquillaje') ||
        texto.contains('cosmético')) {
      return '🛍️ Compras personales';
    }

    // 📱 8. TECNOLOGÍA
    if (texto.contains('app') ||
        texto.contains('software') ||
        texto.contains('suscripción') ||
        texto.contains('telefono') ||
        texto.contains('smartphone') ||
        texto.contains('audifono') ||
        texto.contains('laptop') ||
        texto.contains('monitor') ||
        texto.contains('teclado') ||
        texto.contains('mouse') ||
        texto.contains('computadora') ||
        texto.contains('celular') ||
        texto.contains('electronico')) {
      return '📱 Tecnología';
    }

    // 🐶 9. MASCOTAS
    if (texto.contains('mascota') ||
        texto.contains('perro') ||
        texto.contains('gato') ||
        texto.contains('alimento mascota') ||
        texto.contains('veterinaria') ||
        texto.contains('baño mascota') ||
        texto.contains('hueso') ||
        texto.contains('juguete mascota')) {
      return '🐶 Mascotas';
    }

    // 🧱 12. OTROS
    if (texto.contains('tramite') ||
        texto.contains('papeleta') ||
        texto.contains('multa') ||
        texto.contains('servicio') ||
        texto.contains('cargo') ||
        texto.contains('comisión') ||
        texto.contains('otros')) {
      return '📦 Otros gastos';
    }

    // Default
    return '💰 Otros';
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _abrirDetalle(Map<String, dynamic> gasto) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GastoDetalle(gasto: gasto),
      ),
    );

    // Si viene null => usuario canceló
    if (resultado != null) {
      setState(() {
        final index = _gastos.indexWhere((g) => g['id'] == resultado['id']);
        if (index != -1) {
          _gastos[index] = resultado;
        }
      });
    }
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
                        onTap: () => _abrirDetalle(gasto),
                        leading: Text(
                          gasto['categoria'],
                          style: const TextStyle(fontSize: 20),
                        ),
                        title: Text(gasto['descripcion']),
                        subtitle: Text(
                            'Monto: S/${gasto['monto']} — ${gasto['fecha'].toString().substring(0, 16)}'),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
    );
  }
}
