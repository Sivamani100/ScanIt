import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/app_provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../widgets/shimmer_loading.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  String _timeRange = "Weekly"; // Today, Weekly, Monthly

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    
    if (appProvider.isLoading) {
      return const _InsightsSkeleton();
    }

    final topProducts = appProvider.topProducts;
    final List<double> chartData;
    if (_timeRange == "Today") {
      chartData = appProvider.dailyHourlySalesData;
    } else if (_timeRange == "Monthly") {
      chartData = appProvider.monthlyDaySalesData;
    } else {
      chartData = appProvider.weeklySalesData;
    }

    return Scaffold(
      backgroundColor: ScanBillColors.background,
      appBar: AppBar(
        title: const Text('Business Insights'),
        backgroundColor: ScanBillColors.surface,
        foregroundColor: ScanBillColors.text,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionTitle("Performance Overview"),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: ScanBillColors.surface, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _timeRange,
                      icon: const Icon(Iconsax.arrow_down_1, size: 14),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ScanBillColors.primary),
                      items: ["Today", "Weekly", "Monthly"].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (val) => setState(() => _timeRange = val!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _InsightCard(label: "Revenue", value: "₹${appProvider.todayRevenue.toInt()}", icon: Iconsax.moneys, color: ScanBillColors.success)),
                const SizedBox(width: 12),
                Expanded(child: _InsightCard(label: "Avg Bill", value: "₹${appProvider.averageBillValue.toInt()}", icon: Iconsax.receipt_2, color: ScanBillColors.info)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _InsightCard(label: "Bills", value: "${appProvider.todayBillCount}", icon: Iconsax.document_text, color: ScanBillColors.purple)),
                const SizedBox(width: 12),
                Expanded(child: _InsightCard(label: "Stock items", value: "${appProvider.products.length}", icon: Iconsax.box, color: ScanBillColors.warning)),
              ],
            ),
            const SizedBox(height: 24),
            
            // Sales Chart
            Container(
              height: 260,
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ScanBillColors.surface, 
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('$_timeRange Revenue Trend', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 24),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (chartData.isEmpty || chartData.every((e) => e == 0) ? 1000 : chartData.reduce((a, b) => a > b ? a : b)) * 1.2,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '₹${rod.toY.toInt()}',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                String text = "";
                                if (_timeRange == "Today") {
                                  if (value % 6 == 0) text = "${value.toInt()}h";
                                } else if (_timeRange == "Monthly") {
                                  if (value % 7 == 0 || value == chartData.length - 1) text = "${value.toInt() + 1}";
                                } else {
                                  const days = ["M", "T", "W", "T", "F", "S", "S"];
                                  if (value.toInt() >= 0 && value.toInt() < 7) text = days[value.toInt()];
                                }
                                
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(text, style: const TextStyle(color: ScanBillColors.textMuted, fontWeight: FontWeight.bold, fontSize: 10)),
                                );
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(chartData.length, (i) => BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: chartData[i],
                              color: i == chartData.length - 1 ? ScanBillColors.primary : ScanBillColors.primary.withOpacity(0.3),
                              width: chartData.length > 20 ? 6 : (chartData.length > 10 ? 10 : 16),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        )),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            const _SectionTitle("Top Selling Products"),
            const SizedBox(height: 12),
            if (topProducts.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Add some bills to see trends', style: TextStyle(color: ScanBillColors.textMuted)),
              ))
            else
              ...topProducts.entries.map((e) => _ProductRank(
                name: e.key, 
                count: e.value, 
                revenue: 0, // We only tracked count in topProducts map for simplicity
              )).toList(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ScanBillColors.text));
}

class _InsightCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InsightCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ScanBillColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: ScanBillColors.textSecondary)),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double height;
  final String label;
  final bool isPrimary;
  const _Bar({required this.height, required this.label, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 20,
          height: height,
          decoration: BoxDecoration(
            color: isPrimary ? ScanBillColors.primary : ScanBillColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: ScanBillColors.textMuted)),
      ],
    );
  }
}

class _ProductRank extends StatelessWidget {
  final String name;
  final int count;
  final double revenue;
  const _ProductRank({required this.name, required this.count, required this.revenue});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ScanBillColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('$count units sold', style: const TextStyle(fontSize: 12, color: ScanBillColors.textSecondary)),
          ]),
          if (revenue > 0) Text('₹${revenue.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: ScanBillColors.primary)),
        ],
      ),
    );
  }
}

class _InsightsSkeleton extends StatelessWidget {
  const _InsightsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScanBillColors.background,
      appBar: AppBar(title: const ShimmerLoading.rectangular(height: 18, width: 120), backgroundColor: ScanBillColors.surface, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Row(children: [
              Expanded(child: ShimmerLoading.rectangular(height: 80)),
              SizedBox(width: 12),
              Expanded(child: ShimmerLoading.rectangular(height: 80)),
            ]),
            const SizedBox(height: 12),
            const Row(children: [
              Expanded(child: ShimmerLoading.rectangular(height: 80)),
              SizedBox(width: 12),
              Expanded(child: ShimmerLoading.rectangular(height: 80)),
            ]),
            const SizedBox(height: 24),
            const ShimmerLoading.rectangular(height: 220, shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24)))),
            const SizedBox(height: 24),
            ...List.generate(3, (i) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: ShimmerLoading.rectangular(height: 60),
            )),
          ],
        ),
      ),
    );
  }
}
