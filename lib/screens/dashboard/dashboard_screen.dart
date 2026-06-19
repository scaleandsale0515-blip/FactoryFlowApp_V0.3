import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../services/stock_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';
import '../../widgets/common_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, double> _stock = {};
  Map<String, double> _today = {'production': 0, 'dispatch': 0, 'sales': 0};
  Map<String, double> _allTime = {'stock': 0, 'sales': 0, 'purchase': 0, 'transport': 0, 'worker': 0};
  String _gf = 'Month';
  List<String> _labels = [];
  List<double> _salesD = [], _purchD = [], _panelD = [], _colD = [], _transD = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await DatabaseHelper.instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final tProd = await db.rawQuery('SELECT COALESCE(SUM(pi.quantity),0) as t FROM production p JOIN production_items pi ON p.id=pi.production_id WHERE p.date=?', [today]);
    final tTrans = await db.rawQuery('SELECT COALESCE(SUM(ti.quantity),0) as t FROM transport t JOIN transport_items ti ON t.id=ti.transport_id WHERE t.date=?', [today]);
    final tSales = await db.rawQuery('SELECT COALESCE(SUM(total),0) as t FROM invoices WHERE date=?', [today]);
    final atS = await db.rawQuery('SELECT COALESCE(SUM(total),0) as t FROM invoices');
    final atP = await db.rawQuery('SELECT COALESCE(SUM(total_amount),0) as t FROM purchases');
    final atT = await db.rawQuery('SELECT COALESCE(SUM(rent),0) as t FROM transport');
    final atW = await db.rawQuery('SELECT COALESCE(SUM(total_amount),0) as t FROM production');
    final ts = await StockService.instance.getTotalStock();
    await _loadGraph(db);
    final summary = await StockService.instance.getSummary();
    if (mounted) setState(() {
      _stock = summary;
      _today = {'production': (tProd.first['t'] as num).toDouble(), 'dispatch': (tTrans.first['t'] as num).toDouble(), 'sales': (tSales.first['t'] as num).toDouble()};
      _allTime = {'stock': ts, 'sales': (atS.first['t'] as num).toDouble(), 'purchase': (atP.first['t'] as num).toDouble(), 'transport': (atT.first['t'] as num).toDouble(), 'worker': (atW.first['t'] as num).toDouble()};
      _loading = false;
    });
  }

  Future<void> _loadGraph(dynamic db) async {
    final labels = <String>[], sales = <double>[], purch = <double>[], panel = <double>[], col = <double>[], trans = <double>[];
    final count = _gf == 'Week' ? 7 : _gf == 'Year' ? 5 : 6;
    for (int i = 0; i < count; i++) {
      String label, like;
      if (_gf == 'Week') { final d = DateTime.now().subtract(Duration(days: count - 1 - i)); label = DateFormat('E').format(d); like = DateFormat('yyyy-MM-dd').format(d); }
      else if (_gf == 'Year') { final y = DateTime.now().year - (count - 1 - i); label = '$y'; like = '$y%'; }
      else { final m = DateTime(DateTime.now().year, DateTime.now().month - (count - 1 - i)); label = DateFormat('MMM').format(m); like = '${DateFormat('yyyy-MM').format(m)}%'; }
      labels.add(label);
      sales.add(((await db.rawQuery('SELECT COALESCE(SUM(total),0) as t FROM invoices WHERE date LIKE ?', [like])).first['t'] as num).toDouble());
      purch.add(((await db.rawQuery('SELECT COALESCE(SUM(total_amount),0) as t FROM purchases WHERE date LIKE ?', [like])).first['t'] as num).toDouble());
      panel.add(((await db.rawQuery('SELECT COALESCE(SUM(pi.quantity),0) as t FROM production p JOIN production_items pi ON p.id=pi.production_id WHERE pi.product_name="Panel" AND p.date LIKE ?', [like])).first['t'] as num).toDouble());
      col.add(((await db.rawQuery('SELECT COALESCE(SUM(pi.quantity),0) as t FROM production p JOIN production_items pi ON p.id=pi.production_id WHERE pi.product_name="Column" AND p.date LIKE ?', [like])).first['t'] as num).toDouble());
      trans.add(((await db.rawQuery('SELECT COALESCE(SUM(rent),0) as t FROM transport WHERE date LIKE ?', [like])).first['t'] as num).toDouble());
    }
    _labels = labels; _salesD = sales; _purchD = purch; _panelD = panel; _colD = col; _transD = trans;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    return RefreshIndicator(onRefresh: _load, color: AppColors.primary, child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle(AppStrings.get('today')),
        Row(children: [
          _TC(label: AppStrings.get('production'), value: _today['production']!.toStringAsFixed(0), unit: 'pcs', color: AppColors.accent, icon: Icons.factory_rounded),
          const SizedBox(width: 10),
          _TC(label: AppStrings.get('transport'), value: _today['dispatch']!.toStringAsFixed(0), unit: 'pcs', color: AppColors.warning, icon: Icons.local_shipping_rounded),
          const SizedBox(width: 10),
          _TC(label: AppStrings.get('billing'), value: fmtCur(_today['sales']!), unit: '', color: AppColors.success, icon: Icons.receipt_rounded),
        ]),
        const SizedBox(height: 20),
        SectionTitle(AppStrings.get('all_time_total')),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
          Row(children: [
            _AT(label: AppStrings.get('total_stock'), value: '${_allTime['stock']!.toStringAsFixed(0)} pcs', color: AppColors.primary, icon: Icons.inventory_2_rounded),
            const SizedBox(width: 10),
            _AT(label: AppStrings.get('total_sales'), value: fmtCur(_allTime['sales']!), color: AppColors.success, icon: Icons.trending_up_rounded),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _AT(label: AppStrings.get('total_purchase'), value: fmtCur(_allTime['purchase']!), color: AppColors.info, icon: Icons.shopping_cart_rounded),
            const SizedBox(width: 10),
            _AT(label: AppStrings.get('transport_cost'), value: fmtCur(_allTime['transport']!), color: AppColors.warning, icon: Icons.local_shipping_rounded),
          ]),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: _AT(label: AppStrings.get('worker_cost'), value: fmtCur(_allTime['worker']!), color: AppColors.accent, icon: Icons.people_rounded, full: true)),
        ]))),
        const SizedBox(height: 20),
        SectionTitle(AppStrings.get('total_stock')),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: _stock.entries.map((e) {
          final isLow = e.value < 50;
          return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: isLow ? AppColors.danger : AppColors.success, shape: BoxShape.circle)), const SizedBox(width: 10), Text(e.key)]),
            Row(children: [if (isLow) InfoChip(label: 'LOW', color: AppColors.danger), const SizedBox(width: 8), Text(e.value.toStringAsFixed(0), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isLow ? AppColors.danger : AppColors.primary))]),
          ]));
        }).toList()))),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          SectionTitle(AppStrings.get('overview')),
          Row(children: ['Week', 'Month', 'Year'].map((f) => GestureDetector(
            onTap: () async { setState(() => _gf = f); final db = await DatabaseHelper.instance.database; await _loadGraph(db); setState(() {}); },
            child: Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: _gf == f ? AppColors.primary.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: _gf == f ? AppColors.primary : AppColors.darkBorder)),
              child: Text(f, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _gf == f ? AppColors.primary : Colors.grey))),
          )).toList()),
        ]),
        _BC(title: 'Sales Revenue', color: AppColors.success, data: _salesD, labels: _labels, unit: '₹'),
        const SizedBox(height: 12),
        _BC(title: 'Purchase Cost', color: AppColors.info, data: _purchD, labels: _labels, unit: '₹'),
        const SizedBox(height: 12),
        _DualBC(data1: _panelD, data2: _colD, labels: _labels),
        const SizedBox(height: 12),
        _BC(title: 'Transport Cost', color: AppColors.warning, data: _transD, labels: _labels, unit: '₹'),
        const SizedBox(height: 80),
      ]),
    ));
  }
}

class _TC extends StatelessWidget {
  final String label, value, unit; final Color color; final IconData icon;
  const _TC({required this.label, required this.value, required this.unit, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 18), const SizedBox(height: 8), Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: color)), if (unit.isNotEmpty) Text(unit, style: const TextStyle(fontSize: 10, color: Colors.grey)), const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))])));
}

class _AT extends StatelessWidget {
  final String label, value; final Color color; final IconData icon; final bool full;
  const _AT({required this.label, required this.value, required this.color, required this.icon, this.full = false});
  @override
  Widget build(BuildContext context) {
    final card = Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))), child: Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)), Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color))])]));
    return full ? card : Expanded(child: card);
  }
}

class _BC extends StatelessWidget {
  final String title, unit; final Color color; final List<double> data; final List<String> labels;
  const _BC({required this.title, required this.color, required this.data, required this.labels, required this.unit});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxY = data.isEmpty ? 100.0 : (data.reduce((a, b) => a > b ? a : b) * 1.3).clamp(10.0, double.infinity);
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))]),
      const SizedBox(height: 14),
      SizedBox(height: 120, child: BarChart(BarChartData(maxY: maxY, barGroups: data.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value, color: color, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))])).toList(), gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: isDark ? Colors.white10 : Colors.black12, strokeWidth: 1)), borderData: FlBorderData(show: false), titlesData: FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) { final i = v.toInt(); return i >= 0 && i < labels.length ? Text(labels[i], style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey)) : const Text(''); }))), barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(getTooltipItem: (g, gi, rod, ri) => BarTooltipItem('${rod.toY.toStringAsFixed(0)}$unit', TextStyle(fontWeight: FontWeight.w700, color: color))))))),
    ])));
  }
}

class _DualBC extends StatelessWidget {
  final List<double> data1, data2; final List<String> labels;
  const _DualBC({required this.data1, required this.data2, required this.labels});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allV = [...data1, ...data2];
    final maxY = allV.isEmpty ? 100.0 : (allV.reduce((a, b) => a > b ? a : b) * 1.3).clamp(10.0, double.infinity);
    final groups = List.generate(data1.length, (i) => BarChartGroupData(x: i, barsSpace: 4, barRods: [BarChartRodData(toY: data1[i], color: AppColors.accent, width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))), BarChartRodData(toY: data2[i], color: AppColors.primary, width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))]));
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)), const SizedBox(width: 5), const Text('Panel', style: TextStyle(fontSize: 11, color: Colors.grey)), const SizedBox(width: 12), Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)), const SizedBox(width: 5), const Text('Column', style: TextStyle(fontSize: 11, color: Colors.grey)), const SizedBox(width: 8), const Text('Production', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))]),
      const SizedBox(height: 14),
      SizedBox(height: 120, child: BarChart(BarChartData(maxY: maxY, barGroups: groups, gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: isDark ? Colors.white10 : Colors.black12, strokeWidth: 1)), borderData: FlBorderData(show: false), titlesData: FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) { final i = v.toInt(); return i >= 0 && i < labels.length ? Text(labels[i], style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey)) : const Text(''); })))))),
    ])));
  }
}
