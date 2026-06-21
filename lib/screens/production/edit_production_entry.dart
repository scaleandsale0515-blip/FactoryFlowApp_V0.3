import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../services/stock_service.dart';
import '../../services/excel_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';
import '../../widgets/common_widgets.dart';

class EditProductionEntry extends StatefulWidget {
  final Map<String, dynamic> prod; 
  final List<Map<String, dynamic>> items;
  
  const EditProductionEntry({
    Key? key,
    required this.prod, 
    required this.items})
    : super(key: key);
  @override
  State<EditProductionEntry> createState() => _EditProductionEntryState();
}

class _EditProductionEntryState extends State<EditProductionEntry> {
  late DateTime _date;
  late List<Map<String, dynamic>> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.parse(widget.prod['date']);
    _items = widget.items.map((i) => {'product': i['product_name'], 'size': i['size'], 'qty_ctrl': TextEditingController(text: i['quantity'].toString()), 'rate_ctrl': TextEditingController(text: i['rate'].toString())}).toList();
  }
}



  
