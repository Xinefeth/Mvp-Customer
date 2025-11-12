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
      debugShowCheckedModeBanner: false,
      title: 'Gastos OCR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
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

  File? _imageFile;
  String _recognizedText = '';
  String _categoria = '';
  String? _monto;
  bool _loading = false;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _takePhotoAndProcess() async {
    setState(() {
      _loading = true;
      _recognizedText = '';
      _categoria = '';
      _monto = null;
    });

    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) {
        setState(() => _loading = false);
        return;
      }

      final file = File(photo.path);
      setState(() => _imageFile = file);

      final inputImage = InputImage.fromFile(file);
      final RecognizedText recognized = await _textRecognizer.processImage(inputImage);
      final text = recognized.text;

      final clas = _clasificarGasto(text);
      final monto = _extraerMonto(text);

      setState(() {
        _recognizedText = text.trim();
        _categoria = clas;
        _monto = monto;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _recognizedText = 'Error: $e';
        _categoria = '';
        _monto = null;
      });
    }
  }

  String _clasificarGasto(String text) {
    final t = text.toLowerCase();

    final Map<String, List<String>> categorias = {
      'Alimentación': [
        'restaurante', 'menu', 'comida', 'cafe', 'cafeteria', 'pollo', 'pizza', 'burger'
      ],
      'Transporte': [
        'uber', 'taxi', 'bus', 'gasolina', 'peaje', 'moto', 'yape moto'
      ],
      'Supermercado/Mercado': [
        'supermercado', 'mercado', 'bodega', 'plaza vea', 'tottus', 'pan', 'leche', 'frutas'
      ],
      'Servicios': [
        'internet', 'luz', 'agua', 'telefono', 'movistar', 'claro'
      ],
      'Salud': [
        'farmacia', 'botica', 'clinica', 'medicina'
      ],
      'Entretenimiento': [
        'netflix', 'spotify', 'cine', 'disney', 'youtube premium'
      ],
      'Otros': [
        'otros', 'servicio', 'varios'
      ],
    };

    String mejorCategoria = 'Otros';
    int mejorScore = -1;

    categorias.forEach((cat, keywords) {
      int score = 0;
      for (final k in keywords) {
        if (t.contains(k)) score++;
      }
      if (score > mejorScore) {
        mejorScore = score;
        mejorCategoria = cat;
      }
    });

    return mejorCategoria;
  }

  String? _extraerMonto(String text) {
    final regex = RegExp(r'(s\\/?\\.\\s?\\d+[\\.,]?\\d*)|(\\b\\d+[\\.,]\\d{2}\\b)', caseSensitive: false);
    final match = regex.allMatches(text).toList();
    if (match.isEmpty) return null;
    final last = match.last.group(0)!;
    return last.replaceAll('\\n', ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gastos OCR')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _takePhotoAndProcess,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Tomar foto'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_imageFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_imageFile!, height: 220, fit: BoxFit.cover),
                ),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              Row(
                children: [
                  const Icon(Icons.category),
                  const SizedBox(width: 8),
                  Text(
                    _categoria.isEmpty ? 'Categoría: —' : 'Categoría: $_categoria',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const Icon(Icons.attach_money),
                  const SizedBox(width: 8),
                  Text('Monto: ${_monto ?? '—'}'),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Texto reconocido:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _recognizedText.isEmpty ? '—' : _recognizedText,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
