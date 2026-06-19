import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../services/excel_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';
import '../../widgets/common_widgets.dart';

const Map<String, List<String>> kGrades = {
  'Cement': ['OPC 43', 'OPC 53', 'PPC', 'PSC'],
  'Sand': ['Fine', 'Coarse', 'M-Sand'],
  'Aggregate': ['10mm', '12mm'],
  'Diesel': ['-'],
  'Steel': ['Prestressed wire 3mm', 'Prestressed wire 4mm'],
  'Water': ['-'],
  'Other': ['-'],
};
const Map<String, List<String>> kUnits = {
  'Cement': ['Bag (50kg)', 'Ton', 'Kg'],
  'Sand': ['Ton', 'Kg', 'CFT'],
  'Aggregate': ['Ton', 'Kg', 'CFT'],
  'Diesel': ['Ltr'],
  'Steel': ['Ton', 'Kg'],
  'Water': ['Ltr', 'KL'],
  'Other': ['Nos', 'Kg', 'Ton', 'Ltr', 'CFT'],
};
const List<String> kMaterials = ['Cement', 'Sand', 'Aggregate', 'Diesel', 'Steel', 'Water', 'Other'];

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});
  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  List<Map<String, dynamic>> _all = [], _filtered = [];
  bool _loading = true;
  DateTime? _fs, _fe;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await DatabaseHelper.instance.database;
    final r = await db.rawQuery('SELECT p.*, GROUP_CONCAT(pi.material_name||"|"||COALESCE(pi.grade,"-")||"|"||pi.quantity||"|"||pi.unit||"|"||pi.rate, ";;") as items_str FROM purchases p LEFT JOIN purchase_items pi ON p.id=pi.purchase_id GROUP BY p.id ORDER BY p.date DESC, p.created_at DESC');
    if (mounted) setState(() { _all = r; _applyFilter(); _loading = false; });
  }

  void _applyFilter() {
    _filtered = _all.where((p) {
      if (_fs == null && _fe == null) return true;
      try { final d = DateTime.parse(p['date'].toString()); if (_fs != null && d.isBefore(_fs!)) return false; if (_fe != null && d.isAfter(_fe!.add(const Duration(days: 1)))) return false; return true; } catch (_) { return true; }
    }).toList();
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final confirm = await showConfirmDialog(context);
    if (!confirm) return;
    final db = await DatabaseHelper.instance.database;
    await db.delete('purchase_items', where: 'purchase_id=?', whereArgs: [p['id']]);
    await db.delete('purchases', where: 'id=?', whereArgs: [p['id']]);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: DateRangeFilter(onChanged: (s, e) { setState(() { _fs = s; _fe = e; _applyFilter(); }); })),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _filtered.isEmpty ? EmptyState(message: AppStrings.get('no_data'))
              : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 4, 16, 80), itemCount: _filtered.length,
                  itemBuilder: (ctx, i) => _PurchCard(p: _filtered[i],
                    onEdit: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditPurchaseScreen(existing: _filtered[i]))); _load(); },
                    onDelete: () => _delete(_filtered[i]))),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditPurchaseScreen())); _load(); },
        backgroundColor: AppColors.primary, icon: const Icon(Icons.add),
        label: Text(AppStrings.get('add_purchase'), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _PurchCard extends StatelessWidget {
  final Map<String, dynamic> p; final VoidCallback onEdit, onDelete;
  const _PurchCard({required this.p, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemsStr = p['items_str'] as String? ?? '';
    final items = itemsStr.isNotEmpty ? itemsStr.split(';;') : <String>[];
    return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [const Icon(Icons.shopping_cart_rounded, size: 16, color: AppColors.info), const SizedBox(width: 6), Text(p['supplier_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))]),
        Text(fmtDate(p['date']), style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
      ]),
      const SizedBox(height: 8),
      ...items.map((item) {
        final parts = item.split('|');
        if (parts.length < 5) return const SizedBox.shrink();
        final grade = parts[1] == '-' ? '' : ' (${parts[1]})';
        return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.info, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text('${parts[0]}$grade', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87))),
          Text('${parts[2]} ${parts[3]} @ ₹${parts[4]}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]));
      }),
      const Divider(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('₹${(p['total_amount'] as num).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.success)),
        Row(children: [
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.info), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_rounded, size: 18, color: AppColors.danger), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
        ]),
      ]),
    ])));
  }
}

class AddEditPurchaseScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const AddEditPurchaseScreen({super.key, this.existing});
  @override State<AddEditPurchaseScreen> createState() => _AddEditPurchaseScreenState();
}

class _AddEditPurchaseScreenState extends State<AddEditPurchaseScreen> {
  DateTime _date = DateTime.now();
  Map<String, dynamic>? _supplier;
  List<Map<String, dynamic>> _suppliers = [], _items = [];
  List<String> _pumps = [];
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() { super.initState(); _loadData(); if (widget.existing != null) _loadExisting(); else _addItem(); }

  Future<void> _loadData() async {
    final db = await DatabaseHelper.instance.database;
    _suppliers = await db.query('suppliers', orderBy: 'name');
    final pumps = await db.query('petrol_pumps', orderBy: 'name');
    setState(() { _pumps = pumps.map((p) => p['name'] as String).toList(); });
  }

  Future<void> _loadExisting() async {
    final e = widget.existing!;
    final db = await DatabaseHelper.instance.database;
    _date = DateTime.parse(e['date']);
    _notesCtrl.text = e['notes'] ?? '';
    final s = await db.query('suppliers', where: 'id=?', whereArgs: [e['supplier_id']]);
    if (s.isNotEmpty) setState(() => _supplier = s.first);
    final its = await db.query('purchase_items', where: 'purchase_id=?', whereArgs: [e['id']]);
    setState(() => _items = its.map((i) => {
      'material': i['material_name'], 'grade': i['grade'] ?? kGrades[i['material_name']]!.first,
      'petrol_pump': i['petrol_pump'] ?? '', 'unit': i['unit'],
      'qty_ctrl': TextEditingController(text: i['quantity'].toString()),
      'rate_ctrl': TextEditingController(text: i['rate'].toString()),
    }).toList());
  }

  void _addItem() => setState(() => _items.add({'material': 'Cement', 'grade': 'OPC 53', 'petrol_pump': '', 'unit': 'Bag (50kg)', 'qty_ctrl': TextEditingController(), 'rate_ctrl': TextEditingController()}));

  double get _total => _items.fold(0.0, (s, i) => s + (double.tryParse(i['qty_ctrl'].text) ?? 0) * (double.tryParse(i['rate_ctrl'].text) ?? 0));

  Future<void> _save() async {
    if (_supplier == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a supplier'))); return; }
    setState(() => _saving = true);
    final db = await DatabaseHelper.instance.database;
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);
    final now = DateTime.now().toIso8601String();

    if (widget.existing != null) {
      await db.delete('purchase_items', where: 'purchase_id=?', whereArgs: [widget.existing!['id']]);
      await db.update('purchases', {'date': dateStr, 'supplier_id': _supplier!['id'], 'supplier_name': _supplier!['name'], 'total_amount': _total, 'notes': _notesCtrl.text}, where: 'id=?', whereArgs: [widget.existing!['id']]);
      for (var item in _items) { final q = double.tryParse(item['qty_ctrl'].text) ?? 0; final r = double.tryParse(item['rate_ctrl'].text) ?? 0; if (q <= 0) continue; await db.insert('purchase_items', {'purchase_id': widget.existing!['id'], 'material_name': item['material'], 'grade': item['grade'], 'petrol_pump': item['petrol_pump'], 'quantity': q, 'unit': item['unit'], 'rate': r, 'amount': q * r}); }
    } else {
      final pid = await db.insert('purchases', {'date': dateStr, 'supplier_id': _supplier!['id'], 'supplier_name': _supplier!['name'], 'total_amount': _total, 'notes': _notesCtrl.text, 'created_at': now});
      for (var item in _items) { final q = double.tryParse(item['qty_ctrl'].text) ?? 0; final r = double.tryParse(item['rate_ctrl'].text) ?? 0; if (q <= 0) continue; await db.insert('purchase_items', {'purchase_id': pid, 'material_name': item['material'], 'grade': item['grade'], 'petrol_pump': item['petrol_pump'], 'quantity': q, 'unit': item['unit'], 'rate': r, 'amount': q * r}); }
      final pur = (await db.query('purchases', where: 'id=?', whereArgs: [pid])).first;
      final items = await db.query('purchase_items', where: 'purchase_id=?', whereArgs: [pid]);
      await ExcelService.instance.appendPurchase(pur, items);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing != null ? 'Edit Purchase' : AppStrings.get('add_purchase'))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppDatePicker(date: _date, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: AppDropdown<Map<String, dynamic>>(label: AppStrings.get('supplier'), value: _supplier, items: _suppliers, itemLabel: (s) => s['name'] as String, onChanged: (s) => setState(() => _supplier = s))),
          const SizedBox(width: 10),
          IconButton.filled(onPressed: () async { await _addSupplierDialog(); _loadData(); }, icon: const Icon(Icons.add, size: 20), style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(AppStrings.get('material'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add, size: 16), label: Text(AppStrings.get('add')), style: TextButton.styleFrom(foregroundColor: AppColors.primary)),
        ]),
        ..._items.asMap().entries.map((e) => _PurchItemRow(item: e.value, pumps: _pumps, onRemove: () => setState(() => _items.removeAt(e.key)), onChanged: () => setState(() {}), onAddPump: (pump) { setState(() { _pumps.add(pump); }); })),
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withOpacity(0.3))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)), Text('₹${_total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.primary))])),
        const SizedBox(height: 14),
        TextField(controller: _notesCtrl, decoration: InputDecoration(labelText: AppStrings.get('notes')), maxLines: 2),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(AppStrings.get('save')))),
        const SizedBox(height: 30),
      ])),
    );
  }

  Future<void> _addSupplierDialog() async {
    final nc = TextEditingController(), pc = TextEditingController();
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add Supplier'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nc, decoration: InputDecoration(labelText: AppStrings.get('name'))),
        const SizedBox(height: 10), TextField(controller: pc, decoration: InputDecoration(labelText: AppStrings.get('phone')), keyboardType: TextInputType.phone),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel'))),
        ElevatedButton(onPressed: () async { if (nc.text.trim().isEmpty) return; final db = await DatabaseHelper.instance.database; await db.insert('suppliers', {'name': nc.text.trim(), 'phone': pc.text.trim(), 'created_at': DateTime.now().toIso8601String()}); if (ctx.mounted) Navigator.pop(ctx); }, child: Text(AppStrings.get('save')))],
    ));
  }
}

class _PurchItemRow extends StatefulWidget {
  final Map<String, dynamic> item; final List<String> pumps;
  final VoidCallback onRemove, onChanged; final Function(String) onAddPump;
  const _PurchItemRow({required this.item, required this.pumps, required this.onRemove, required this.onChanged, required this.onAddPump});
  @override State<_PurchItemRow> createState() => _PurchItemRowState();
}

class _PurchItemRowState extends State<_PurchItemRow> {
  List<String> get _grades => kGrades[widget.item['material']] ?? ['-'];
  List<String> get _units => kUnits[widget.item['material']] ?? ['Nos'];
  bool get _isDiesel => widget.item['material'] == 'Diesel';

  @override
  Widget build(BuildContext context) {
    if (!_grades.contains(widget.item['grade'])) widget.item['grade'] = _grades.first;
    if (!_units.contains(widget.item['unit'])) widget.item['unit'] = _units.first;
    final amt = (double.tryParse(widget.item['qty_ctrl'].text) ?? 0) * (double.tryParse(widget.item['rate_ctrl'].text) ?? 0);

    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: AppColors.darkBorder), borderRadius: BorderRadius.circular(10)), child: Column(children: [
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(value: widget.item['material'], decoration: const InputDecoration(labelText: 'Material', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), items: kMaterials.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) { setState(() { widget.item['material'] = v; widget.item['grade'] = (kGrades[v] ?? ['-']).first; widget.item['unit'] = (kUnits[v] ?? ['Nos']).first; widget.item['petrol_pump'] = ''; }); widget.onChanged(); })),
        const SizedBox(width: 8),
        if (!_isDiesel) Expanded(child: DropdownButtonFormField<String>(value: widget.item['grade'], decoration: const InputDecoration(labelText: 'Grade', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), items: _grades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(), onChanged: (v) { setState(() => widget.item['grade'] = v); widget.onChanged(); })),
        if (_isDiesel) Expanded(child: Row(children: [
          Expanded(child: widget.pumps.isEmpty ? TextField(onChanged: (v) => widget.item['petrol_pump'] = v, decoration: const InputDecoration(labelText: 'Pump Name', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8))) :
            DropdownButtonFormField<String>(value: widget.pumps.contains(widget.item['petrol_pump']) ? widget.item['petrol_pump'] : null, decoration: const InputDecoration(labelText: 'Pump', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), items: widget.pumps.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) => setState(() => widget.item['petrol_pump'] = v))),
          IconButton(onPressed: () async {
            final ctrl = TextEditingController();
            await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Add Petrol Pump'), content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Pump Name')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), ElevatedButton(onPressed: () async { if (ctrl.text.trim().isEmpty) return; final db = await DatabaseHelper.instance.database; await db.insert('petrol_pumps', {'name': ctrl.text.trim(), 'created_at': DateTime.now().toIso8601String()}); widget.onAddPump(ctrl.text.trim()); if (ctx.mounted) Navigator.pop(ctx); }, child: const Text('Add'))]));
          }, icon: const Icon(Icons.add, size: 18, color: AppColors.primary), padding: EdgeInsets.zero),
        ])),
        IconButton(onPressed: widget.onRemove, icon: const Icon(Icons.close, size: 18, color: AppColors.danger), padding: EdgeInsets.zero),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(controller: widget.item['qty_ctrl'], decoration: const InputDecoration(labelText: 'Qty', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) { setState(() {}); widget.onChanged(); })),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<String>(value: widget.item['unit'], decoration: const InputDecoration(labelText: 'Unit', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) { setState(() => widget.item['unit'] = v); widget.onChanged(); })),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: widget.item['rate_ctrl'], decoration: const InputDecoration(labelText: 'Rate ₹', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) { setState(() {}); widget.onChanged(); })),
        const SizedBox(width: 8),
        SizedBox(width: 60, child: Text('₹${amt.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success, fontSize: 12), textAlign: TextAlign.right)),
      ]),
    ]));
  }
}
