import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../services/stock_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';
import '../../widgets/common_widgets.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _stock = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stock = await StockService.instance.getAll();
    if (mounted) setState(() { _stock = stock; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final panels = _stock.where((s) => s['product_name'] == 'Panel').toList();
    final columns = _stock.where((s) => s['product_name'] == 'Column').toList();
    final total = _stock.fold<double>(0, (s, i) => s + (i['quantity'] as num).toDouble());

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionTitle('PANEL'),
                  ...panels.map((s) => _StockTile(item: s, onAdjust: () => _showAdjust(s))),
                  const SizedBox(height: 16),
                  SectionTitle('COLUMNS'),
                  ...columns.map((s) => _StockTile(item: s, onAdjust: () => _showAdjust(s))),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(AppStrings.get('total_stock').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1)),
                      Text('${total.toStringAsFixed(0)} pcs', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.primary)),
                    ]),
                  ),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
    );
  }

  Future<void> _showAdjust(Map<String, dynamic> item) async {
    final qtyCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String type = 'add';
    final name = item['product_name'] as String;
    final size = item['size'] as String?;
    final label = size != null ? '$name ($size)' : name;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: Text(label),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Current: ${(item['quantity'] as num).toStringAsFixed(0)} pcs', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => setS(() => type = 'add'),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: type == 'add' ? AppColors.success.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: type == 'add' ? AppColors.success : AppColors.darkBorder)),
                child: Center(child: Text('+ Add', style: TextStyle(fontWeight: FontWeight.w700, color: type == 'add' ? AppColors.success : Colors.grey)))),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () => setS(() => type = 'reduce'),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: type == 'reduce' ? AppColors.danger.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: type == 'reduce' ? AppColors.danger : AppColors.darkBorder)),
                child: Center(child: Text('- Reduce', style: TextStyle(fontWeight: FontWeight.w700, color: type == 'reduce' ? AppColors.danger : Colors.grey)))),
            )),
          ]),
          const SizedBox(height: 14),
          TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel'))),
          ElevatedButton(
            onPressed: () async {
              final qty = double.tryParse(qtyCtrl.text) ?? 0;
              if (qty <= 0) return;
              await StockService.instance.manualAdjust(name, size, qty, type, reasonCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: Text(AppStrings.get('save')),
          ),
        ],
      )),
    );
  }
}

class _StockTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onAdjust;
  const _StockTile({required this.item, required this.onAdjust});

  @override
  Widget build(BuildContext context) {
    final qty = (item['quantity'] as num).toDouble();
    final isLow = qty < 50;
    final name = item['product_name'] as String;
    final size = item['size'] as String?;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: isLow ? AppColors.danger.withOpacity(0.1) : AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(name == 'Panel' ? Icons.grid_on_rounded : Icons.view_column_rounded, color: isLow ? AppColors.danger : AppColors.primary, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(size != null ? '$name ($size)' : name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            if (isLow) const Text('Low Stock', style: TextStyle(fontSize: 11, color: AppColors.danger)),
          ])),
          Text(qty.toStringAsFixed(0), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: isLow ? AppColors.danger : (isDark ? Colors.white : Colors.black87))),
          const SizedBox(width: 4),
          const Text('pcs', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          IconButton(onPressed: onAdjust, icon: const Icon(Icons.tune_rounded, size: 18, color: AppColors.primary), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
        ]),
      ),
    );
  }
}
