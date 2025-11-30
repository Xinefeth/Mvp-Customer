import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async'; // 👈 Importamos esto para usar el Timer
import 'historial_page.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'gasto_detalle.dart';
import 'dashboard_page.dart';
import 'ocr_service.dart';
import 'package:image_cropper/image_cropper.dart';
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        scaffoldBackgroundColor: const Color(0xFFF3FFF6),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      // 👇 CAMBIO PRINCIPAL: Ahora iniciamos con el SplashScreen
      home: const SplashScreen(),
    );
  }
}

// =======================================================
// ✨ NUEVA PANTALLA: SPLASH SCREEN (Bienvenida)
// =======================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // ⏱️ Esperar 3 segundos y luego ir al Menú Principal
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fondo verde oscuro para que resalte
      backgroundColor: Colors.green.shade700,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🖼️ Ícono grande (simulando logo)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(51),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Icon(
                Icons.receipt_long_rounded, // Ícono de recibo
                size: 80,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 24),
            // 📝 Título de la App
            const Text(
              "Gastos OCR",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Tu asistente financiero",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 48),
            // ⏳ Indicador de carga
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// 🏠 PANTALLA PRINCIPAL (Sin cambios lógicos)
// =======================================================
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

  Future<File?> _recortarImagen(File archivoOriginal) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: archivoOriginal.path,
      // AspectRatio: presets o libre
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recortar Recibo',
          toolbarColor: Colors.green.shade700,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Recortar Recibo',
        ),
      ],
    );

    if (croppedFile != null) {
      return File(croppedFile.path);
    }
    return null; // Si canceló el recorte
  }
  
  Future<void> _tomarFotoYRegistrar() async {
    final XFile? foto = await _picker.pickImage(source: ImageSource.camera);
    if (foto == null) return;

    // Paso intermedio: Recortar
    final File? fotoRecortada = await _recortarImagen(File(foto.path));
    
    // Si canceló recorte, no hacemos nada (o podrías procesar la original)
    if (fotoRecortada == null) return;

    await _procesarImagen(fotoRecortada);
  }

  Future<void> _subirArchivo() async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (selected == null) return;
    File file = File(selected.files.single.path!);

    // Si es imagen, ofrecemos recortar. Si es PDF, pasa directo.
    if (!file.path.endsWith(".pdf")) {
      final recortada = await _recortarImagen(file);
      if (recortada != null) {
        file = recortada;
      }
    }

    if (file.path.endsWith(".pdf")) {
      await _procesarPDF(file);
    } else {
      await _procesarImagen(file);
    }
  }

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📄 PDF procesado correctamente"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _procesarImagen(File archivo) async {
    setState(() => _procesando = true);

    try {
      final inputImage = InputImage.fromFile(archivo);
      final text = await _textRecognizer.processImage(inputImage);

      await _registrarGasto(text.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🖼️ Imagen procesada correctamente"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _registrarGasto(String texto) async {
    // Aquí usamos la nueva lógica inteligente
    final resultadoOcr = OcrService.analizarRecibo(texto);

    final nuevoGasto = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'descripcion': resultadoOcr['items'].isNotEmpty 
          ? (resultadoOcr['items'][0]['nombre'] as String) 
          : "Gasto sin nombre",
      'textoCompleto': texto,
      'items': resultadoOcr['items'],
      'total': resultadoOcr['total'],
      // Si detectó fecha en el recibo, úsala. Si no, usa la actual.
      'fecha': resultadoOcr['fecha'] != null 
          ? _parsearFechaDetectada(resultadoOcr['fecha']) // Necesitamos convertir dd/mm/yyyy a ISO
          : DateTime.now().toIso8601String(),
      'categoria': _clasificarGasto(texto),
      'monto': (resultadoOcr['total'] as double).toStringAsFixed(2),
    };

    setState(() => _gastos.insert(0, nuevoGasto));
    await _guardarGastos();
  }

  Future<void> _eliminarGasto(int id) async {
    setState(() {
      _gastos.removeWhere((g) => g['id'] == id);
    });

    await _guardarGastos();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🗑️ Gasto eliminado"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _clasificarGasto(String t) {
    t = t.toLowerCase();
    if (t.contains('pollo') || t.contains('comida')) return '🍔 Alimentación';
    if (t.contains('uber') || t.contains('taxi')) return '🚗 Transporte';
    if (t.contains('luz') || t.contains('agua')) return '🏠 Vivienda';
    if (t.contains('farmacia') || t.contains('doctor')) return '🩺 Salud';
    if (t.contains('universidad')) return '📚 Educación';
    if (t.contains('cine') || t.contains('netflix')) {
      return '🎉 Entretenimiento';
    }
    if (t.contains('ropa')) return '🛍 Compras';
    if (t.contains('celular')) return '📱 Tecnología';
    return '💰 Otros';
  }

  String _parsearFechaDetectada(String fechaStr) {
    try {
      // Asumimos formato dd/mm/yyyy
      final partes = fechaStr.split('/');
      if (partes.length == 3) {
        final dia = int.parse(partes[0]);
        final mes = int.parse(partes[1]);
        int anio = int.parse(partes[2]);
        // Corrección básica de año (ej: 23 -> 2023)
        if (anio < 100) anio += 2000;
        
        // Creamos la fecha usando la hora actual del dispositivo para la hora
        return DateTime(anio, mes, dia, DateTime.now().hour, DateTime.now().minute).toIso8601String();
      }
    } catch (e) {
      // Si falla la conversión, retornamos fecha actual
    }
    return DateTime.now().toIso8601String();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gastos OCR"), // Puedes acortar el título
        centerTitle: false, // Alineado a la izquierda para que quepan iconos
        actions: [
           // 👇 BOTÓN NUEVO: HISTORIAL / CONTROL DIARIO
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: "Control Diario",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistorialPage(
                    gastos: _gastos,
                    onEliminarGasto: _eliminarGasto, // Pasamos la función para borrar
                  ),
                ),
              ).then((_) {
                 // Al volver del historial, actualizamos la lista principal
                 // por si se borró o editó algo.
                 setState(() {}); 
              });
            },
          ),
          // 👇 Tus botones anteriores
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

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => _abrirDetalle(g),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                g['categoria'],
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(width: 12),
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
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _eliminarGasto(g['id']),
                              ),
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