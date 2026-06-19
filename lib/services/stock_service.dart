import '../database/database_helper.dart';

class StockService {
  static final StockService instance = StockService._();
  StockService._();

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('stock', orderBy: 'product_name, size');
  }

  Future<void> addStock(String name, String? size, double qty) async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.query('stock', where: size != null ? 'product_name=? AND size=?' : 'product_name=? AND size IS NULL', whereArgs: size != null ? [name, size] : [name]);
    if (r.isEmpty) {
      await db.insert('stock', {'product_name': name, 'size': size, 'quantity': qty});
    } else {
      final cur = (r.first['quantity'] as num).toDouble();
      await db.update('stock', {'quantity': cur + qty}, where: size != null ? 'product_name=? AND size=?' : 'product_name=? AND size IS NULL', whereArgs: size != null ? [name, size] : [name]);
    }
  }

  Future<void> reduceStock(String name, String? size, double qty) async => addStock(name, size, -qty);

  Future<void> applyProduction(List<Map<String, dynamic>> items, {bool reverse = false}) async {
    for (var i in items) { final q = (i['quantity'] as num).toDouble(); reverse ? await reduceStock(i['product_name'], i['size'], q) : await addStock(i['product_name'], i['size'], q); }
  }

  Future<void> applyTransport(List<Map<String, dynamic>> items, {bool reverse = false}) async {
    for (var i in items) { final q = (i['quantity'] as num).toDouble(); reverse ? await addStock(i['product_name'], i['size'], q) : await reduceStock(i['product_name'], i['size'], q); }
  }

  Future<void> manualAdjust(String name, String? size, double qty, String type, String reason) async {
    final db = await DatabaseHelper.instance.database;
    type == 'add' ? await addStock(name, size, qty) : await reduceStock(name, size, qty);
    await db.insert('stock_adjustments', {'product_name': name, 'size': size, 'quantity': qty, 'type': type, 'reason': reason, 'date': DateTime.now().toIso8601String().split('T')[0], 'created_at': DateTime.now().toIso8601String()});
  }

  Future<Map<String, double>> getSummary() async {
    final all = await getAll();
    return {for (var s in all) (s['size'] != null ? '${s['product_name']} ${s['size']}' : s['product_name'] as String): (s['quantity'] as num).toDouble()};
  }

  Future<double> getTotalStock() async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.rawQuery('SELECT COALESCE(SUM(quantity),0) as t FROM stock');
    return (r.first['t'] as num).toDouble();
  }
}
