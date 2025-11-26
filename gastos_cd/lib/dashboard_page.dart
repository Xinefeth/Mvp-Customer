import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardPage extends StatelessWidget {
  final List<Map<String, dynamic>> gastos;

  const DashboardPage({super.key, required this.gastos});

  // Total de gastos por fecha
  Map<String, double> _gastoPorFecha() {
    final Map<String, double> mapa = {};

    for (var g in gastos) {
      final fecha = g['fecha'].toString().substring(0, 10); // yyyy-MM-dd
      final total = g['total'] ?? 0.0;

      mapa[fecha] = (mapa[fecha] ?? 0) + total;
    }
    return mapa;
  }

  @override
  Widget build(BuildContext context) {
    final data = _gastoPorFecha();
    final fechas = data.keys.toList();
    final valores = data.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("📊 Dashboard de Gastos"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Gastos por fecha",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // 📉 GRÁFICO DE BARRAS
            Expanded(
              child: BarChart(
                BarChartData(
                  barGroups: List.generate(fechas.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: valores[i],
                          width: 18,
                          color: Colors.deepPurple,
                        )
                      ],
                    );
                  }),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < fechas.length) {
                            return Text(
                              fechas[index].substring(5), // mm-dd
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text("");
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // RESUMEN
            const Text(
              "Resumen total por fecha",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 150,
              child: ListView.builder(
                itemCount: fechas.length,
                itemBuilder: (_, i) {
                  return ListTile(
                    title: Text(fechas[i]),
                    trailing:
                        Text("S/${valores[i].toStringAsFixed(2)}"),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
