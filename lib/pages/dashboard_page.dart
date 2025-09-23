import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final Color primaryColor = const Color(0xFFF28C38);

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final String today = DateFormat('dd-MM').format(now);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: FutureBuilder<List<dynamic>>(
            future: ApiService.fetchPedidos(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF28C38)),
                    strokeWidth: 4.0,
                  ),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Erro ao carregar pedidos: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhum pedido encontrado.',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }

              final pedidos = snapshot.data!;

              final pedidosDoDia = pedidos.where((p) {
                final dataRaw = p["data_agendamento"]?.toString() ?? '';
                if (dataRaw.isEmpty) return false;
                String cleanedData = dataRaw;
                if (dataRaw.startsWith("'") && dataRaw.endsWith("'")) {
                  cleanedData = dataRaw.substring(1, dataRaw.length - 1);
                } else if (dataRaw.startsWith("'")) {
                  cleanedData = dataRaw.substring(1);
                }
                String formattedData = cleanedData;
                try {
                  final parsedDate = DateTime.parse(cleanedData);
                  formattedData = DateFormat('dd-MM').format(parsedDate);
                } catch (e) {
                  if (cleanedData.contains('-')) {
                    final parts = cleanedData.split('-');
                    if (parts.length == 3) {
                      formattedData = '${parts[2].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}';
                    }
                  } else if (cleanedData.contains('/')) {
                    final parts = cleanedData.split('/');
                    if (parts.length >= 2) {
                      formattedData = '${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}';
                    }
                  }
                }
                return formattedData == today;
              }).toList();

              debugPrint('Pedidos agendados para o dia ($today): ${pedidosDoDia.length}');
              for (var pedido in pedidosDoDia) {
                debugPrint('Pedido: ${pedido['id']}, Data de Agendamento: ${pedido['data_agendamento']}, '
                    'Data de Criação: ${pedido['data']}, Status: ${pedido['status']}, Subtotal: ${pedido['subTotal']}');
              }

              if (pedidosDoDia.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhum pedido agendado para o dia atual.',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }

              final pedidosValidos = pedidosDoDia.where((p) {
                final status = (p["status"] ?? '').toString().trim().toLowerCase();
                return status != "cancelado";
              }).toList();

              double totalValue = pedidosValidos.fold(0.0, (sum, p) {
                final subTotalRaw = p["subTotal"];
                double subTotal = 0.0;
                if (subTotalRaw is num) {
                  subTotal = subTotalRaw.toDouble();
                } else if (subTotalRaw is String) {
                  subTotal = double.tryParse(subTotalRaw.replaceAll(',', '.')) ?? 0.0;
                }
                return sum + subTotal;
              });

              int totalOrders = pedidosValidos.length;

              Map<String, int> slots = {
                "09:00 - 12:00": 0,
                "12:00 - 15:00": 0,
                "15:00 - 18:00": 0,
                "18:00 - 21:00": 0,
              };
              for (var p in pedidosValidos) {
                final horarioAgendamento = p["horario_agendamento"];
                if (horarioAgendamento is String && slots.containsKey(horarioAgendamento)) {
                  slots[horarioAgendamento] = (slots[horarioAgendamento] ?? 0) + 1;
                }
              }

              Map<String, int> statusCount = {
                "Saiu pra Entrega": 0,
                "Registrado": 0,
                "Concluído": 0,
                "Cancelado": 0,
              };
              for (var p in pedidosValidos) {
                final status = p["status"];
                if (status is String && statusCount.containsKey(status)) {
                  statusCount[status] = (statusCount[status] ?? 0) + 1;
                }
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetricsCard(totalValue, totalOrders),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: [
                        _buildStatusCard(statusCount, totalOrders),
                        _buildPedidosPorSlotCard(slots),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsCard(double totalValue, int totalOrders) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Valor Total do Dia", style: TextStyle(fontSize: 16, color: Colors.black87)),
                const SizedBox(height: 6),
                Text(
                  "R\$ ${totalValue.toStringAsFixed(2)}",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryColor),
                ),
              ],
            ),
            Chip(
              label: Text("$totalOrders Pedidos", style: const TextStyle(color: Colors.white, fontSize: 16)),
              backgroundColor: primaryColor,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPedidosPorSlotCard(Map<String, int> slots) {
    final maxY = slots.values.isNotEmpty ? (slots.values.reduce((a, b) => a > b ? a : b) + 2.0).toDouble() : 10.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pedidos por Slot", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < slots.length) {
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 8.0,
                              child: Text(slots.keys.elementAt(index), style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true, drawHorizontalLine: true),
                  borderData: FlBorderData(show: false),
                  barGroups: slots.entries.toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final slot = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: slot.value.toDouble(),
                          color: primaryColor,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(Map<String, int> statusCount, int totalOrders) {
    final Map<String, Color> statusColors = {
      "Saiu pra Entrega": primaryColor,
      "Registrado": Colors.blue[300]!,
      "Concluído": Colors.green,
      "Cancelado": Colors.grey[700]!,
    };

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pedidos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 1,
                  centerSpaceRadius: 50,
                  pieTouchData: PieTouchData(enabled: true),
                  sections: statusCount.entries.map((entry) {
                    final status = entry.key;
                    final count = entry.value;
                    return PieChartSectionData(
                      value: count.toDouble(),
                      title: "$count",
                      radius: 65,
                      titlePositionPercentageOffset: 0.55,
                      titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      color: statusColors[status],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: statusCount.entries.map((entry) {
                final status = entry.key;
                final count = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 14, height: 14, decoration: BoxDecoration(color: statusColors[status], borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 8),
                      Text("$status ($count)",
                          style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
