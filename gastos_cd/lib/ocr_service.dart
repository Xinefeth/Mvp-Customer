import 'dart:math';

class OcrService {
  
  /// Analiza el texto crudo y busca inteligentemente el Total, la Fecha y los Items.
  static Map<String, dynamic> analizarRecibo(String texto) {
    // 1. Limpieza inicial
    final lineas = texto.split('\n');
    double? totalDetectado;
    String? fechaDetectada;
    List<Map<String, dynamic>> items = [];
    
    // Regex para detectar precios (ej: 12.50, 1,200.00, S/ 50.00)
    final regexPrecio = RegExp(r'(?:S\/|s\/|\$|USD|EUR)?\s?(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2}))');
    
    // Regex para fechas (dd/mm/yyyy o yyyy-mm-dd)
    final regexFecha = RegExp(r'\b(\d{2}[/-]\d{2}[/-]\d{2,4})\b|\b(\d{4}[/-]\d{2}[/-]\d{2})\b');

    // Palabras clave que indican que esa línea es el TOTAL FINAL
    final keywordsTotal = ['total', 'venta total', 'importe total', 'a pagar', 'monto total'];
    
    // Palabras a ignorar (Subtotales, Vueltos, Efectivo entregado, etc.)
    final keywordsIgnorar = ['subtotal', 'op. gravada', 'igv', 'vuelto', 'cambio', 'efectivo', 'tarjeta', 'visa', 'mastercard'];

    String? ultimoNombrePosible;

    for (int i = 0; i < lineas.length; i++) {
      String linea = lineas[i].trim();
      String lineaLower = linea.toLowerCase();

      if (linea.isEmpty) continue;

      // --- A. DETECCIÓN DE FECHA ---
      if (fechaDetectada == null) {
        final matchFecha = regexFecha.firstMatch(linea);
        if (matchFecha != null) {
          // Normalizamos separadores
          fechaDetectada = (matchFecha.group(0) ?? "").replaceAll('-', '/'); 
        }
      }

      // --- B. DETECCIÓN DE TOTAL (PRIORIDAD ALTA) ---
      // Buscamos líneas que digan explícitamente "TOTAL"
      bool esLineaTotal = keywordsTotal.any((k) => lineaLower.contains(k));
      bool contieneIgnorar = keywordsIgnorar.any((k) => lineaLower.contains(k));

      final matchesPrecio = regexPrecio.allMatches(linea);

      if (matchesPrecio.isNotEmpty) {
        // Extraer el valor numérico
        String precioStr = matchesPrecio.last.group(1)!
            .replaceAll(',', '') // Quitar comas de miles (cuidado con formato europeo, asumimos latam/usa)
            .replaceAll('S/', '')
            .trim();
            
        // Si el precio tiene coma decimal en vez de punto, arreglarlo
        // (Asumimos que si hay 1 coma y son 2 decimales, es decimal)
        if (precioStr.contains(',') && !precioStr.contains('.')) {
          precioStr = precioStr.replaceAll(',', '.');
        }

        double valor = double.tryParse(precioStr) ?? 0.0;

        // ESTRATEGIA 1: Si la línea dice "TOTAL", este es el ganador probable
        if (esLineaTotal && !contieneIgnorar) {
          // A veces el OCR lee "Total .......... 50.00", el numero está en la misma linea
          totalDetectado = valor;
        } 
        // ESTRATEGIA 2: A veces dice "TOTAL" y el numero está en la SIGUIENTE línea
        else if (esLineaTotal && matchesPrecio.isEmpty && (i + 1) < lineas.length) {
             // Mirar siguiente linea
             // (Implementación simplificada: asumimos que si hay texto "Total", el numero está cerca)
        }

        // --- C. DETECCIÓN DE ITEMS (PRODUCTOS) ---
        // Solo guardamos como item si NO es una palabra reservada (Total, IGV, etc)
        // y si el valor es razonable (no es un año 2023, no es un RUC grande)
        if (!esLineaTotal && !contieneIgnorar && valor < 5000 && !lineaLower.contains('ruc') && !lineaLower.contains('tel')) {
           // Si encontramos precio, asumimos que el texto anterior era el nombre o esta linea tiene nombre
           String nombreItem = ultimoNombrePosible ?? "Item sin nombre";
           
           // Si la línea actual tiene texto largo además del precio, usamos ese texto como nombre
           String textoSinPrecio = linea.replaceAll(regexPrecio, '').trim();
           if (textoSinPrecio.length > 3) {
             nombreItem = textoSinPrecio;
           }

           items.add({
             'nombre': nombreItem.toUpperCase(),
             'precio': valor
           });
           ultimoNombrePosible = null; // Reset
        }
      } else {
        // Si no hay numero, guardamos esta linea como posible nombre del siguiente producto
        if (!esLineaTotal && !contieneIgnorar && !lineaLower.contains('ruc') && linea.length > 3) {
          ultimoNombrePosible = linea;
        }
      }
    }

    // --- D. VALIDACIÓN FINAL DEL TOTAL ---
    double sumaItems = items.fold(0, (sum, item) => sum + (item['precio'] as double));

    // Si no encontramos un "TOTAL" explícito, usamos la suma de items
    // O si el Total explícito es menor a la suma (ej: detectó mal un descuento), usamos la suma.
    double montoFinal = 0.0;

    if (totalDetectado != null && totalDetectado > 0) {
      montoFinal = totalDetectado;
    } else {
      // Intentamos buscar el número más grande encontrado en el texto (heurística de último recurso)
      // que suele ser el total en tickets simples.
      double maxPrecio = 0.0;
      for (var item in items) {
        maxPrecio = max(maxPrecio, item['precio']);
      }
      // Si la suma es parecida al maximo, es probable que la suma esté bien.
      // Pero por seguridad, si no hay etiqueta Total, la suma de items detectados es lo más seguro.
      montoFinal = sumaItems;
    }

    return {
      'items': items,
      'total': montoFinal,
      'fecha': fechaDetectada // Puede ser null
    };
  }
}