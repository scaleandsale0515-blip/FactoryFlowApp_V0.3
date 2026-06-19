import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';
import '../../widgets/common_widgets.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});
  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Map<String, dynamic>> _suppliers = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await DatabaseHelper.instance.database;
    final s = await db.query('suppliers', orderBy: 'name');
    if (mounted) setState(() { _suppliers = s; _loading = false; });
  }

  Future<void> _delete(Map<String, dynamic> s) async {
    final confirm = await showConfirmDialog(context);
    if (!confirm) return;
    final db = await DatabaseHelper.instance.database;
    final hasP = await db.query('purchases', where: 'supplier_id=?', whereArgs: [s['id']], limit: 1);
    if (hasP.isNotEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete — supplier has purchase history')));
      return;
    }
    await db.delete('suppliers', where: 'id=?', whereArgs: [s['id']]);
    _load();
  }

  Future<void> _addEditDialog({Map<String, dynamic>? existing}) async {
    final nc = TextEditingController(text: existing?['name'] ?? '');
    final pc = TextEditingController(text: existing?['phone'] ?? '');
    final ac = TextEditingController(text: existing?['address'] ?? '');
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(existing != null ? AppStrings.get('edit') : 'Add Supplier'),
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
          if (existing != null) { await db.update('suppliers', data, where: 'id=?', whereArgs: [existing['id']]); }
          else { await db.insert('suppliers', {...data, 'created_at': DateTime.now().toIso8601String()}); }
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
          : _suppliers.isEmpty
              ? EmptyState(message: AppStrings.get('no_data'))
              : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), itemCount: _suppliers.length,
                  itemBuilder: (ctx, i) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
                    leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.local_shipping_outlined, color: AppColors.warning, size: 22)),
                    title: Text(_suppliers[i]['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_suppliers[i]['phone'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(onPressed: () => _addEditDialog(existing: _suppliers[i]), icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.info), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                      IconButton(onPressed: () => _delete(_suppliers[i]), icon: const Icon(Icons.delete_rounded, size: 18, color: AppColors.danger), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                    ]),
                  ))),
      floatingActionButton: FloatingActionButton(onPressed: () => _addEditDialog(), backgroundColor: AppColors.primary, child: const Icon(Icons.add)),
    );
  }
}
