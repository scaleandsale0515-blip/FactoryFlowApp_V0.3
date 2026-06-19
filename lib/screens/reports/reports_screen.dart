import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import '../../database/database_helper.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _gf = 'Month';
  List<String> _labels = [];
  List<double> _salesD = [], _purchD = [], _panelD = [], _colD = [], _transD = [];
  bool _loading = true, _exporting = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await DatabaseHelper.instance.database;
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
    if (mounted) setState(() { _labels = labels; _salesD = sales; _purchD = purch; _panelD = panel; _colD = col; _transD = trans; _loading = false; });
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Report'];
      sheet.appendRow([const TextCellValue('Period'), const TextCellValue('Sales ₹'), const TextCellValue('Purchase ₹'), const TextCellValue('Panel Production'), const TextCellValue('Column Production'), const TextCellValue('Transport Cost ₹')]);
      for (int i = 0; i < _labels.length; i++) {
        sheet.appendRow([TextCellValue(_labels[i]), DoubleCellValue(_salesD[i]), DoubleCellValue(_purchD[i]), DoubleCellValue(_panelD[i]), DoubleCellValue(_colD[i]), DoubleCellValue(_transD[i])]);
      }
      excel.delete('Sheet1');
      final dir = await getTemporaryDirectory();
      final fileName = 'FactoryFlow_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
      final file = File('${dir.path}/$fileName');
      final encoded = excel.encode();
      if (encoded != null) { await file.writeAsBytes(encoded); await Share.shareXFiles([XFile(file.path)], text: 'FactoryFlow Report'); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: _exporting ? null : _export,
          icon: _exporting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded, size: 18),
          label: Text(_exporting ? 'Exporting...' : AppStrings.get('export_excel')),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.success, side: const BorderSide(color: AppColors.success), padding: const EdgeInsets.symmetric(vertical: 12)),
        )),
      ]),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: ['Week','Month','Year'].map((f) => GestureDetector(
        onTap: () { setState(() => _gf = f); _load(); },
        child: Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: _gf == f ? AppColors.primary.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: _gf == f ? AppColors.primary : AppColors.darkBorder)),
          child: Text(f, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _gf == f ? AppColors.primary : Colors.grey))),
      )).toList()),
      const SizedBox(height: 16),
      _Chart(title: 'Sales Revenue ₹', color: AppColors.success, data: _salesD, labels: _labels),
      const SizedBox(height: 14),
      _Chart(title: 'Purchase Cost ₹', color: AppColors.info, data: _purchD, labels: _labels),
      const SizedBox(height: 14),
      _DualChart(data1: _panelD, data2: _colD, labels: _labels),
      const SizedBox(height: 14),
      _Chart(title: 'Transport Cost ₹', color: AppColors.warning, data: _transD, labels: _labels),
      const SizedBox(height: 80),
    ]));
  }
}

class _Chart extends StatelessWidget {
  final String title; final Color color; final List<double> data; final List<String> labels;
  const _Chart({required this.title, required this.color, required this.data, required this.labels});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxY = data.isEmpty ? 100.0 : (data.reduce((a, b) => a > b ? a : b) * 1.3).clamp(10.0, double.infinity);
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))]),
      const SizedBox(height: 16),
      SizedBox(height: 150, child: BarChart(BarChartData(maxY: maxY, barGroups: data.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value, color: color, width: 18, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))])).toList(),
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: isDark ? Colors.white10 : Colors.black12, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) { final i = v.toInt(); return i >= 0 && i < labels.length ? Text(labels[i], style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey)) : const Text(''); }))),
      ))),
    ])));
  }
}

class _DualChart extends StatelessWidget {
  final List<double> data1, data2; final List<String> labels;
  const _DualChart({required this.data1, required this.data2, required this.labels});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allV = [...data1, ...data2];
    final maxY = allV.isEmpty ? 100.0 : (allV.reduce((a, b) => a > b ? a : b) * 1.3).clamp(10.0, double.infinity);
    final groups = List.generate(data1.length, (i) => BarChartGroupData(x: i, barsSpace: 4, barRods: [
      BarChartRodData(toY: data1[i], color: AppColors.accent, width: 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
      BarChartRodData(toY: data2[i], color: AppColors.primary, width: 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
    ]));
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)), const SizedBox(width: 5), const Text('Panel', style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(width: 12),
        Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)), const SizedBox(width: 5), const Text('Column', style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(width: 10), const Text('Production', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ]),
      const SizedBox(height: 16),
      SizedBox(height: 150, child: BarChart(BarChartData(maxY: maxY, barGroups: groups,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: isDark ? Colors.white10 : Colors.black12, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) { final i = v.toInt(); return i >= 0 && i < labels.length ? Text(labels[i], style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey)) : const Text(''); }))),
      ))),
    ])));
  }
}
