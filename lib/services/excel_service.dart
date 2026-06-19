import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/database_helper.dart';
import '../services/settings_service.dart';

class ExcelService {
  static final ExcelService instance = ExcelService._();
  ExcelService._();

  Future<String> _storageFolder() async {
    final company = (await SettingsService.instance.get('company_name') ?? 'FactoryFlow').replaceAll(RegExp(r'[^\w]'), '_');
    final folder = '/storage/emulated/0/${company}_FactoryFlow_Data';
    try { await Directory(folder).create(recursive: true); return folder; } catch (_) {
      return (await getExternalStorageDirectory() ?? await getTemporaryDirectory()).path;
    }
  }

  Future<String?> _activePath() async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.query('excel_cycles', where: 'is_active=1', limit: 1);
    return r.isEmpty ? null : r.first['file_path'] as String?;
  }

  Future<void> checkAndRotate() async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.query('excel_cycles', where: 'is_active=1', limit: 1);
    if (r.isEmpty) { await _startNewCycle(db); return; }
    final end = DateTime.parse(r.first['end_date'] as String);
    if (DateTime.now().isAfter(end)) { await db.update('excel_cycles', {'is_active': 0}, where: 'is_active=1'); await _startNewCycle(db); }
  }

  Future<void> _startNewCycle(dynamic db) async {
    final company = await SettingsService.instance.get('company_name') ?? 'FactoryFlow';
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 3, 0);
    final startStr = DateFormat('dd MMM yyyy').format(start);
    final endStr = DateFormat('dd MMM yyyy').format(end);
    final fileName = '$company - $startStr - $endStr.xlsx';
    final folder = await _storageFolder();
    final filePath = '$folder/$fileName';

    final excel = Excel.createExcel();
    _initHeaders(excel);
    excel.delete('Sheet1');
    await File(filePath).writeAsBytes(excel.encode()!);

    await db.insert('excel_cycles', {
      'company_name': company, 'start_date': start.toIso8601String(),
      'end_date': end.toIso8601String(), 'file_path': filePath,
      'file_name': fileName, 'is_active': 1, 'created_at': DateTime.now().toIso8601String(),
    });
  }

  void _initHeaders(Excel excel) {
    excel['Production'].appendRow([const TextCellValue('Date'),const TextCellValue('Worker'),const TextCellValue('Product'),const TextCellValue('Size'),const TextCellValue('Qty'),const TextCellValue('Rate'),const TextCellValue('Amount'),const TextCellValue('Notes')]);
    excel['Transport'].appendRow([const TextCellValue('Date'),const TextCellValue('Transporter'),const TextCellValue('Vehicle'),const TextCellValue('Vehicle No'),const TextCellValue('Location'),const TextCellValue('Client'),const TextCellValue('Product'),const TextCellValue('Size'),const TextCellValue('Qty'),const TextCellValue('Cement'),const TextCellValue('Sand'),const TextCellValue('Sand Unit'),const TextCellValue('Grit'),const TextCellValue('Grit Unit'),const TextCellValue('Rent')]);
    excel['Purchases'].appendRow([const TextCellValue('Date'),const TextCellValue('Supplier'),const TextCellValue('Material'),const TextCellValue('Grade'),const TextCellValue('Qty'),const TextCellValue('Unit'),const TextCellValue('Rate'),const TextCellValue('Amount')]);
    excel['Invoices'].appendRow([const TextCellValue('Invoice No'),const TextCellValue('Date'),const TextCellValue('Customer'),const TextCellValue('Service'),const TextCellValue('Qty'),const TextCellValue('Unit'),const TextCellValue('Rate'),const TextCellValue('Amount'),const TextCellValue('GST%'),const TextCellValue('Total')]);
    excel['Quotations'].appendRow([const TextCellValue('Quote No'),const TextCellValue('Date'),const TextCellValue('Customer'),const TextCellValue('Service'),const TextCellValue('Qty'),const TextCellValue('Unit'),const TextCellValue('Rate'),const TextCellValue('Amount'),const TextCellValue('GST%'),const TextCellValue('Total'),const TextCellValue('Status')]);
    excel['Stock'].appendRow([const TextCellValue('Product'),const TextCellValue('Size'),const TextCellValue('Quantity')]);
  }

  Future<void> _writeToFile(String path, Excel excel) async => await File(path).writeAsBytes(excel.encode()!);
  Future<Excel?> _readFile(String path) async { final f = File(path); if (!await f.exists()) return null; return Excel.decodeBytes(await f.readAsBytes()); }

  Future<void> appendProduction(Map<String, dynamic> prod, List<Map<String, dynamic>> items) async {
    await checkAndRotate(); final path = await _activePath(); if (path == null) return;
    final excel = await _readFile(path); if (excel == null) return;
    final sheet = excel['Production'];
    for (var i in items) {
      sheet.appendRow([TextCellValue(prod['date']?.toString()??''),TextCellValue(prod['worker_name']?.toString()??''),TextCellValue(i['product_name']?.toString()??''),TextCellValue(i['size']?.toString()??''),DoubleCellValue((i['quantity'] as num).toDouble()),DoubleCellValue((i['rate'] as num).toDouble()),DoubleCellValue((i['amount'] as num).toDouble()),TextCellValue(prod['notes']?.toString()??'')]);
    }
    await _writeToFile(path, excel);
  }

  Future<void> appendTransport(Map<String, dynamic> t, List<Map<String, dynamic>> items) async {
    await checkAndRotate(); final path = await _activePath(); if (path == null) return;
    final excel = await _readFile(path); if (excel == null) return;
    final sheet = excel['Transport'];
    for (var i in items) {
      sheet.appendRow([TextCellValue(t['date']?.toString()??''),TextCellValue(t['transporter_name']?.toString()??''),TextCellValue(t['vehicle']?.toString()??''),TextCellValue(t['vehicle_number']?.toString()??''),TextCellValue(t['location']?.toString()??''),TextCellValue(t['client_name']?.toString()??''),TextCellValue(i['product_name']?.toString()??''),TextCellValue(i['size']?.toString()??''),DoubleCellValue((i['quantity'] as num).toDouble()),DoubleCellValue(((t['cement_bags']??0) as num).toDouble()),DoubleCellValue(((t['sand_qty']??0) as num).toDouble()),TextCellValue(t['sand_unit']?.toString()??''),DoubleCellValue(((t['grit_qty']??0) as num).toDouble()),TextCellValue(t['grit_unit']?.toString()??''),DoubleCellValue(((t['rent']??0) as num).toDouble())]);
    }
    await _writeToFile(path, excel);
  }

  Future<void> appendPurchase(Map<String, dynamic> p, List<Map<String, dynamic>> items) async {
    await checkAndRotate(); final path = await _activePath(); if (path == null) return;
    final excel = await _readFile(path); if (excel == null) return;
    final sheet = excel['Purchases'];
    for (var i in items) {
      sheet.appendRow([TextCellValue(p['date']?.toString()??''),TextCellValue(p['supplier_name']?.toString()??''),TextCellValue(i['material_name']?.toString()??''),TextCellValue(i['grade']?.toString()??''),DoubleCellValue((i['quantity'] as num).toDouble()),TextCellValue(i['unit']?.toString()??''),DoubleCellValue((i['rate'] as num).toDouble()),DoubleCellValue((i['amount'] as num).toDouble())]);
    }
    await _writeToFile(path, excel);
  }

  Future<void> appendInvoice(Map<String, dynamic> inv, List<Map<String, dynamic>> items) async {
    await checkAndRotate(); final path = await _activePath(); if (path == null) return;
    final excel = await _readFile(path); if (excel == null) return;
    final sheet = excel['Invoices'];
    for (var i in items) {
      sheet.appendRow([TextCellValue(inv['invoice_number']?.toString()??''),TextCellValue(inv['date']?.toString()??''),TextCellValue(inv['customer_name']?.toString()??''),TextCellValue(i['service_name']?.toString()??''),DoubleCellValue((i['quantity'] as num).toDouble()),TextCellValue(i['unit']?.toString()??''),DoubleCellValue((i['rate'] as num).toDouble()),DoubleCellValue((i['amount'] as num).toDouble()),DoubleCellValue(((inv['gst_percent']??0) as num).toDouble()),DoubleCellValue(((inv['total']??0) as num).toDouble())]);
    }
    await _writeToFile(path, excel);
  }

  Future<void> appendQuotation(Map<String, dynamic> q, List<Map<String, dynamic>> items) async {
    await checkAndRotate(); final path = await _activePath(); if (path == null) return;
    final excel = await _readFile(path); if (excel == null) return;
    final sheet = excel['Quotations'];
    for (var i in items) {
      sheet.appendRow([TextCellValue(q['quote_number']?.toString()??''),TextCellValue(q['date']?.toString()??''),TextCellValue(q['customer_name']?.toString()??''),TextCellValue(i['service_name']?.toString()??''),DoubleCellValue((i['quantity'] as num).toDouble()),TextCellValue(i['unit']?.toString()??''),DoubleCellValue((i['rate'] as num).toDouble()),DoubleCellValue((i['amount'] as num).toDouble()),DoubleCellValue(((q['gst_percent']??0) as num).toDouble()),DoubleCellValue(((q['total']??0) as num).toDouble()),TextCellValue(q['status']?.toString()??'')]);
    }
    await _writeToFile(path, excel);
  }

  Future<void> updateStockSheet() async {
    final path = await _activePath(); if (path == null) return;
    final excel = await _readFile(path); if (excel == null) return;
    final db = await DatabaseHelper.instance.database;
    excel.delete('Stock');
    final sheet = excel['Stock'];
    sheet.appendRow([const TextCellValue('Product'),const TextCellValue('Size'),const TextCellValue('Quantity')]);
    for (var r in await db.query('stock')) {
      sheet.appendRow([TextCellValue(r['product_name'].toString()),TextCellValue(r['size']?.toString()??''),DoubleCellValue((r['quantity'] as num).toDouble())]);
    }
    await _writeToFile(path, excel);
  }

  Future<List<Map<String, dynamic>>> getAllCycles() async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('excel_cycles', orderBy: 'start_date DESC');
  }

  Future<Map<String, dynamic>?> getActiveCycle() async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.query('excel_cycles', where: 'is_active=1', limit: 1);
    return r.isEmpty ? null : r.first;
  }

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    var s = await Permission.manageExternalStorage.request();
    if (s.isGranted) return true;
    s = await Permission.storage.request();
    return s.isGranted;
  }

  Future<Map<String, List<List<String>>>> readForView(String filePath) async {
    final f = File(filePath);
    if (!await f.exists()) return {};
    final excel = Excel.decodeBytes(await f.readAsBytes());
    final result = <String, List<List<String>>>{};
    for (var name in excel.tables.keys) {
      result[name] = excel.tables[name]!.rows.map((r) => r.map((c) => c?.value?.toString() ?? '').toList()).toList();
    }
    return result;
  }

  Future<List<FileSystemEntity>> scanOldFiles(String company) async {
    try {
      final safe = company.replaceAll(RegExp(r'[^\w]'), '_');
      final dir = Directory('/storage/emulated/0/${safe}_FactoryFlow_Data');
      if (!await dir.exists()) return [];
      return dir.listSync().where((f) => f.path.endsWith('.xlsx')).toList();
    } catch (_) { return []; }
  }
}
