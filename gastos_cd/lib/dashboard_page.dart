import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // Asegúrate de tener intl en pubspec.yaml

class DashboardPage extends StatefulWidget {
  final List<Map<String, dynamic>> gastos;

  const DashboardPage({super.key, required this.gastos});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Variables para controlar la fecha que estamos viendo
  DateTime _fechaSemana = DateTime.now();
  DateTime _fechaMes = DateTime.now();

  // Presupuestos (se cargarán de memoria)
  double _presupuestoSemanal = 0;
  double _presupuestoMensual = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarPresupuestos();
  }

  Future<void> _cargarPresupuestos() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _presupuestoSemanal = prefs.getDouble('presupuesto_semanal') ?? 500.0;
      _presupuestoMensual = prefs.getDouble('presupuesto_mensual') ?? 2000.0;
    });
  }

  Future<void> _guardarPresupuesto(String key, double valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, valor);
  }

  // Lógica para obtener fechas de inicio y fin de semana (Lunes a Domingo)
  DateTime _getInicioSemana(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  DateTime _getFinSemana(DateTime date) {
    return date.add(Duration(days: DateTime.sunday - date.weekday));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Análisis Financiero"),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "Resumen Semanal"),
            Tab(text: "Resumen Mensual"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVistaSemanal(),
          _buildVistaMensual(),
        ],
      ),
    );
  }

  // ==========================================
  // VISTA SEMANAL
  // ==========================================
  Widget _buildVistaSemanal() {
    final inicio = _getInicioSemana(_fechaSemana);
    final fin = _getFinSemana(_fechaSemana);
    
    // Filtrar gastos de esta semana
    final gastosSemana = widget.gastos.where((g) {
      final fecha = DateTime.parse(g['fecha']);
      return fecha.isAfter(inicio.subtract(const Duration(seconds: 1))) && 
             fecha.isBefore(fin.add(const Duration(days: 1)));
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Navegación de Fechas
          _buildNavegadorFecha(
            titulo: "Semana del ${DateFormat('dd/MM').format(inicio)} al ${DateFormat('dd/MM').format(fin)}",
            onAnterior: () => setState(() => _fechaSemana = _fechaSemana.subtract(const Duration(days: 7))),
            onSiguiente: () => setState(() => _fechaSemana = _fechaSemana.add(const Duration(days: 7))),
          ),
          
          const SizedBox(height: 16),
          
          // Tarjeta de Presupuesto
          _buildCardPresupuesto(
            titulo: "Presupuesto Semanal",
            gastado: _calcularTotal(gastosSemana),
            limite: _presupuestoSemanal,
            onEditarLimite: () => _editarPresupuesto("Semanal", 'presupuesto_semanal'),
          ),

          const SizedBox(height: 16),

          // Estadísticas Rápidas
          _buildEstadisticasGrid(gastosSemana, 7),

          const SizedBox(height: 20),

          // Gráfico
          const Text("Tendencia Diaria", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: _buildGraficoSemanal(gastosSemana, inicio),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VISTA MENSUAL
  // ==========================================
  Widget _buildVistaMensual() {
    // Filtrar gastos de este mes
    final gastosMes = widget.gastos.where((g) {
      final fecha = DateTime.parse(g['fecha']);
      return fecha.year == _fechaMes.year && fecha.month == _fechaMes.month;
    }).toList();

    // Días en el mes para calcular promedio
    final diasEnMes = DateUtils.getDaysInMonth(_fechaMes.year, _fechaMes.month);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildNavegadorFecha(
            titulo: DateFormat('MMMM yyyy', 'es').format(_fechaMes).toUpperCase(),
            onAnterior: () => setState(() => _fechaMes = DateTime(_fechaMes.year, _fechaMes.month - 1)),
            onSiguiente: () => setState(() => _fechaMes = DateTime(_fechaMes.year, _fechaMes.month + 1)),
          ),

          const SizedBox(height: 16),

          _buildCardPresupuesto(
            titulo: "Presupuesto Mensual",
            gastado: _calcularTotal(gastosMes),
            limite: _presupuestoMensual,
            onEditarLimite: () => _editarPresupuesto("Mensual", 'presupuesto_mensual'),
          ),

          const SizedBox(height: 16),

          _buildEstadisticasGrid(gastosMes, diasEnMes),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGETS REUTILIZABLES & LÓGICA
  // ==========================================

  double _calcularTotal(List<Map<String, dynamic>> lista) {
    return lista.fold(0.0, (sum, item) => sum + (item['total'] ?? 0));
  }

  Widget _buildNavegadorFecha({required String titulo, required VoidCallback onAnterior, required VoidCallback onSiguiente}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: onAnterior),
        Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: onSiguiente),
      ],
    );
  }

  Widget _buildCardPresupuesto({
    required String titulo,
    required double gastado,
    required double limite,
    required VoidCallback onEditarLimite,
  }) {
    final porcentaje = (gastado / limite).clamp(0.0, 1.0);
    final excedido = gastado > limite;
    final colorBarra = excedido ? Colors.red : (porcentaje > 0.8 ? Colors.orange : Colors.green);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(titulo, style: const TextStyle(color: Colors.grey)),
                GestureDetector(
                  onTap: onEditarLimite,
                  child: Row(
                    children: [
                      Text("Meta: S/${limite.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 14, color: Colors.blue),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("S/${gastado.toStringAsFixed(2)}", 
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: excedido ? Colors.red : Colors.black87)
                ),
                const Spacer(),
                Text(excedido ? "¡EXCEDIDO!" : "${((1 - porcentaje) * 100).toStringAsFixed(0)}% restante",
                  style: TextStyle(color: colorBarra, fontWeight: FontWeight.bold)
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: porcentaje,
              backgroundColor: Colors.grey.shade200,
              color: colorBarra,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadisticasGrid(List<Map<String, dynamic>> lista, int diasPeriodo) {
    final total = _calcularTotal(lista);
    final promedio = total / diasPeriodo; // Promedio simple sobre días del periodo
    final cantidad = lista.length;
    final promedioTicket = cantidad > 0 ? total / cantidad : 0.0;

    return Row(
      children: [
        Expanded(child: _buildStatCard("Promedio Diario", "S/${promedio.toStringAsFixed(2)}", Icons.calendar_today)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard("Gasto Promedio", "S/${promedioTicket.toStringAsFixed(2)}", Icons.receipt)),
      ],
    );
  }

  Widget _buildStatCard(String label, String valor, IconData icono) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withAlpha(26), blurRadius: 5, offset: const Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: Colors.green),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(valor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Gráfico de Barras (Solo para semana)
  Widget _buildGraficoSemanal(List<Map<String, dynamic>> gastos, DateTime inicioSemana) {
    // Agrupar por día de la semana (0=Lunes, 6=Domingo)
    final valores = List.filled(7, 0.0);
    
    for (var g in gastos) {
      final fecha = DateTime.parse(g['fecha']);
      // Diferencia en días desde el inicio de la semana
      final index = fecha.difference(inicioSemana).inDays;
      if (index >= 0 && index < 7) {
        valores[index] += (g['total'] ?? 0.0);
      }
    }

    // Dias labels
    final diasLetras = ["L", "M", "M", "J", "V", "S", "D"];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (valores.reduce((a, b) => a > b ? a : b) * 1.2) + 10, // Escala dinámica
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(diasLetras[val.toInt()], style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: valores[i],
                color: valores[i] > (_presupuestoSemanal/7) ? Colors.orange : Colors.green.shade400, // Alerta visual simple
                width: 16,
                borderRadius: BorderRadius.circular(4),
              )
            ],
          );
        }),
      ),
    );
  }

  void _editarPresupuesto(String periodo, String key) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Definir Presupuesto $periodo"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: "S/ ", labelText: "Nuevo Límite"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null) {
                _guardarPresupuesto(key, val);
                setState(() {
                  if (periodo == "Semanal") { // Abrimos bloque {
                    _presupuestoSemanal = val;
                  } else { // Abrimos bloque {
                    _presupuestoMensual = val;
                  } // Cerramos bloques
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Guardar"),
          )
        ],
      ),
    );
  }
}