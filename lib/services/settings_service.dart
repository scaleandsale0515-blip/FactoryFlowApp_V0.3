import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../utils/app_strings.dart';

class SettingsService {
  static final SettingsService instance = SettingsService._();
  SettingsService._();

  Future<String?> get(String key) async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.query('settings', where: 'key=?', whereArgs: [key]);
    if (r.isEmpty) return null;
    return r.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('settings');
    return {for (var r in rows) r['key'] as String: (r['value'] as String?) ?? ''};
  }

  Future<void> init() async { AppStrings.setLanguage(await get('language') ?? 'en'); }
  Future<bool> isActivated() async => await get('is_activated') == 'true';
  Future<void> activate() async => await set('is_activated', 'true');
  Future<bool> storageEnabled() async => await get('storage_enabled') != 'false';
}
