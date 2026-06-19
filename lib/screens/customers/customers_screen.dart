import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';
import '../../widgets/common_widgets.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Map<String, dynamic>> _customers = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await DatabaseHelper.instance.database;
    final c = await db.query('customers', orderBy: 'name');
    if (mounted) setState(() { _customers = c; _loading = false; });
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final confirm = await showConfirmDialog(context);
    if (!confirm) return;
    final db = await DatabaseHelper.instance.database;
    final hasInv = await db.query('invoices', where: 'customer_id=?', whereArgs: [c['id']], limit: 1);
    if (hasInv.isNotEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete — customer has invoice history')));
      return;
    }
    await db.delete('customers', where: 'id=?', whereArgs: [c['id']]);
    _load();
  }

  Future<void> _addEditDialog({Map<String, dynamic>? existing}) async {
    final nc = TextEditingController(text: existing?['name'] ?? '');
    final pc = TextEditingController(text: existing?['phone'] ?? '');
    final ac = TextEditingController(text: existing?['address'] ?? '');
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(existing != null ? AppStrings.get('edit') : 'Add Customer'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nc, decoration: InputDecoration(labelText: AppStrings.get('name'))),
        const SizedBox(height: 10),
        TextField(controller: pc, decoration: InputDecoration(labelText: AppStrings.get('phone')), keyboardType: TextInputType.phone),
        const SizedBox(height: 10),
        TextField(controller: ac, decoration: InputDecoration(labelText: AppStrings.get('address'))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel'))),
        ElevatedButton(onPressed: () async {
          if (nc.text.trim().isEmpty) return;
          final db = await DatabaseHelper.instance.database;
          final data = {'name': nc.text.trim(), 'phone': pc.text.trim(), 'address': ac.text.trim()};
          if (existing != null) { await db.update('customers', data, where: 'id=?', whereArgs: [existing['id']]); }
          else { await db.insert('customers', {...data, 'created_at': DateTime.now().toIso8601String()}); }
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: Text(AppStrings.get('save'))),
      ],
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _customers.isEmpty
              ? EmptyState(message: AppStrings.get('no_data'))
              : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), itemCount: _customers.length,
                  itemBuilder: (ctx, i) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: _customers[i]))),
                    leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.info.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.business_rounded, color: AppColors.info, size: 22)),
                    title: Text(_customers[i]['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_customers[i]['phone'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(onPressed: () => _addEditDialog(existing: _customers[i]), icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.info), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                      IconButton(onPressed: () => _delete(_customers[i]), icon: const Icon(Icons.delete_rounded, size: 18, color: AppColors.danger), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                      const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    ]),
                  ))),
      floatingActionButton: FloatingActionButton(onPressed: () => _addEditDialog(), backgroundColor: AppColors.primary, child: const Icon(Icons.add)),
    );
  }
}

class CustomerDetailScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  const CustomerDetailScreen({super.key, required this.customer});
  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  List<Map<String, dynamic>> _invoices = [];
  double _totalBusiness = 0;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db = await DatabaseHelper.instance.database;
    final invs = await db.query('invoices', where: 'customer_id=?', whereArgs: [widget.customer['id']], orderBy: 'date DESC');
    double total = 0;
    for (var inv in invs) total += (inv['total'] as num).toDouble();
    if (mounted) setState(() { _invoices = invs; _totalBusiness = total; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.customer['name'] ?? '')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                if ((widget.customer['phone'] ?? '').toString().isNotEmpty) StatRow(label: AppStrings.get('phone'), value: widget.customer['phone']),
                if ((widget.customer['address'] ?? '').toString().isNotEmpty) StatRow(label: AppStrings.get('address'), value: widget.customer['address']),
                StatRow(label: AppStrings.get('total_business'), value: '₹${_totalBusiness.toStringAsFixed(0)}', valueColor: AppColors.success),
                StatRow(label: AppStrings.get('total_invoices'), value: '${_invoices.length}'),
              ]))),
              const SizedBox(height: 16),
              if (_invoices.isEmpty) EmptyState(message: AppStrings.get('no_data'))
              else ..._invoices.map((inv) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
                title: Text(inv['invoice_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                subtitle: Text(fmtDate(inv['date']), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: Text('₹${(inv['total'] as num).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
              ))),
            ])),
    );
  }
}
