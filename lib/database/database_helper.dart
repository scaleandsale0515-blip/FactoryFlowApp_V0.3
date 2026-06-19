import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;
  DatabaseHelper._();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('factoryflow_v3.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''CREATE TABLE settings(id INTEGER PRIMARY KEY AUTOINCREMENT,key TEXT UNIQUE NOT NULL,value TEXT)''');
    await db.execute('''CREATE TABLE stock(id INTEGER PRIMARY KEY AUTOINCREMENT,product_name TEXT NOT NULL,size TEXT,quantity REAL DEFAULT 0)''');
    await db.execute('''CREATE TABLE stock_adjustments(id INTEGER PRIMARY KEY AUTOINCREMENT,product_name TEXT NOT NULL,size TEXT,quantity REAL NOT NULL,type TEXT NOT NULL,reason TEXT,date TEXT NOT NULL,created_at TEXT)''');
    await db.execute('''CREATE TABLE workers(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,phone TEXT,address TEXT,created_at TEXT)''');
    await db.execute('''CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,phone TEXT,address TEXT,created_at TEXT)''');
    await db.execute('''CREATE TABLE suppliers(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,phone TEXT,address TEXT,created_at TEXT)''');
    await db.execute('''CREATE TABLE transporters(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,phone TEXT,address TEXT,default_rent REAL DEFAULT 0,created_at TEXT)''');
    await db.execute('''CREATE TABLE petrol_pumps(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,created_at TEXT)''');
    await db.execute('''CREATE TABLE production(id INTEGER PRIMARY KEY AUTOINCREMENT,date TEXT NOT NULL,worker_id INTEGER NOT NULL,worker_name TEXT NOT NULL,total_amount REAL DEFAULT 0,notes TEXT,photo_path TEXT,created_at TEXT)''');
    await db.execute('''CREATE TABLE production_items(id INTEGER PRIMARY KEY AUTOINCREMENT,production_id INTEGER NOT NULL,product_name TEXT NOT NULL,size TEXT,quantity REAL NOT NULL,rate REAL NOT NULL,amount REAL NOT NULL)''');
    await db.execute('''CREATE TABLE transport(id INTEGER PRIMARY KEY AUTOINCREMENT,date TEXT NOT NULL,transporter_id INTEGER NOT NULL,transporter_name TEXT NOT NULL,vehicle TEXT,vehicle_number TEXT,location TEXT,client_name TEXT,cement_bags INTEGER DEFAULT 0,sand_qty REAL DEFAULT 0,sand_unit TEXT DEFAULT 'Bags',grit_qty REAL DEFAULT 0,grit_unit TEXT DEFAULT 'Bags',rent REAL DEFAULT 0,notes TEXT,photo_path TEXT,created_at TEXT)''');
    await db.execute('''CREATE TABLE transport_items(id INTEGER PRIMARY KEY AUTOINCREMENT,transport_id INTEGER NOT NULL,product_name TEXT NOT NULL,size TEXT,quantity REAL NOT NULL)''');
    await db.execute('''CREATE TABLE purchases(id INTEGER PRIMARY KEY AUTOINCREMENT,date TEXT NOT NULL,supplier_id INTEGER,supplier_name TEXT NOT NULL,total_amount REAL DEFAULT 0,notes TEXT,created_at TEXT)''');
    await db.execute('''CREATE TABLE purchase_items(id INTEGER PRIMARY KEY AUTOINCREMENT,purchase_id INTEGER NOT NULL,material_name TEXT NOT NULL,grade TEXT,petrol_pump TEXT,quantity REAL NOT NULL,unit TEXT NOT NULL,rate REAL NOT NULL,amount REAL NOT NULL)''');
    await db.execute('''CREATE TABLE invoices(id INTEGER PRIMARY KEY AUTOINCREMENT,invoice_number TEXT NOT NULL,customer_id INTEGER,customer_name TEXT NOT NULL,customer_phone TEXT,date TEXT NOT NULL,subtotal REAL DEFAULT 0,gst_percent REAL DEFAULT 0,gst_amount REAL DEFAULT 0,total REAL DEFAULT 0,affect_stock INTEGER DEFAULT 1,notes TEXT,created_at TEXT)''');
    await db.execute('''CREATE TABLE invoice_items(id INTEGER PRIMARY KEY AUTOINCREMENT,invoice_id INTEGER NOT NULL,service_name TEXT NOT NULL,quantity REAL NOT NULL,unit TEXT DEFAULT 'Sq Ft',rate REAL NOT NULL,amount REAL NOT NULL)''');
    await db.execute('''CREATE TABLE quotations(id INTEGER PRIMARY KEY AUTOINCREMENT,quote_number TEXT NOT NULL,customer_id INTEGER,customer_name TEXT NOT NULL,customer_phone TEXT,date TEXT NOT NULL,subtotal REAL DEFAULT 0,gst_percent REAL DEFAULT 0,gst_amount REAL DEFAULT 0,total REAL DEFAULT 0,status TEXT DEFAULT 'Draft',notes TEXT,created_at TEXT)''');
    await db.execute('''CREATE TABLE quotation_items(id INTEGER PRIMARY KEY AUTOINCREMENT,quotation_id INTEGER NOT NULL,service_name TEXT NOT NULL,quantity REAL NOT NULL,unit TEXT DEFAULT 'Sq Ft',rate REAL NOT NULL,amount REAL NOT NULL)''');
    await db.execute('''CREATE TABLE excel_cycles(id INTEGER PRIMARY KEY AUTOINCREMENT,company_name TEXT NOT NULL,start_date TEXT NOT NULL,end_date TEXT NOT NULL,file_path TEXT NOT NULL,file_name TEXT NOT NULL,is_active INTEGER DEFAULT 0,created_at TEXT)''');

    // Default stock
    await db.insert('stock', {'product_name': 'Panel', 'size': null, 'quantity': 0});
    for (final s in ['6 ft','7 ft','8 ft','10 ft','12 ft']) {
      await db.insert('stock', {'product_name': 'Column', 'size': s, 'quantity': 0});
    }

    // Default settings
    final now = DateTime.now().toIso8601String();
    for (final e in {
      'company_name':'FactoryFlow','gst_number':'','address':'','phone':'',
      'logo_path':'','language':'en','theme':'dark',
      'storage_enabled':'true','is_activated':'false',
      'cycle_start_date': now,
      'payment_terms':'Payment shall be made as mutually agreed.\nAdvance and phase-wise payments must be cleared as scheduled.\nFinal payment is due upon delivery/completion.',
      'terms_conditions':'GST Extra, if applicable.\nTransport, unloading & installation charges as per quotation.\nClient must provide clear site access and working space.\nChanges in design, size, or quantity may result in additional charges.\nDrinking and work-related water shall be provided by the client, unless otherwise agreed.\nWork and delivery may be suspended due to payment delays.\nSubject to Ahmedabad Jurisdiction.',
    }.entries) {
      await db.insert('settings', {'key': e.key, 'value': e.value});
    }
  }

  Future<void> close() async { final db = await instance.database; db.close(); _database = null; }
}
