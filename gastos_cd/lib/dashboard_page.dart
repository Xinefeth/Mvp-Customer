import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardPage extends StatelessWidget {
  final List<Map<String, dynamic>> gastos;

  const DashboardPage({super.key, required this.gastos});

  // Total de gastos por fecha (yyyy-MM-dd)
  Map<String, double> _gastoPorFecha() {
    final Map<String, double> mapa = {};

    for (var g in gastos) {
      final fecha = g['fecha'].toString().substring(0, 10); // yyyy-MM-dd
      final total = (g['total'] ?? 0.0) as num;

      mapa[fecha] = (mapa[fecha] ?? 0) + total.toDouble();
    }
    return mapa;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _gastoPorFecha();

    // Ordenar por fecha
    final fechas = data.keys.toList()..sort();
    final valores = fechas.map((f) => data[f] ?? 0.0).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard de Gastos"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: data.isEmpty
            ? const Center(
                child: Text(
                  "Aún no hay datos para mostrar.",
                  style: TextStyle(fontSize: 14),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    "Gasto total por día",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                        child: BarChart(
                          BarChartData(
                            barGroups: List.generate(fechas.length, (i) {
                              return BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: valores[i],
                                    width: 14,
                                    borderRadius: BorderRadius.circular(6),
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              );
                            }),
                            gridData: FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    // Mostrar valores redondeados tipo 0, 50, 100...
                                    if (value == 0) {
                                      return const Text("0");
                                    }
                                    if (value % 50 == 0) {
                                      return Text(
                                        value.toInt().toString(),
                                        style: const TextStyle(fontSize: 10),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 34,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= fechas.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final f = fechas[index]; // yyyy-MM-dd
                                    final label = f.substring(5); // mm-dd
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        label,
                                        style: const TextStyle(
                                          fontSize: 10,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
