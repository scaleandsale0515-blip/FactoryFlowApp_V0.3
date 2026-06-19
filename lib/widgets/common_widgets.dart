import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../utils/app_strings.dart';

class AppDatePicker extends StatelessWidget {
  final DateTime date;
  final Function(DateTime) onChanged;
  const AppDatePicker({super.key, required this.date, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final p = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
        if (p != null) onChanged(p);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: AppColors.darkBorder), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          const Icon(Icons.arrow_drop_down, color: Colors.grey),
        ]),
      ),
    );
  }
}

class DateRangeFilter extends StatefulWidget {
  final Function(DateTime? start, DateTime? end) onChanged;
  final DateTime? initialStart, initialEnd;
  const DateRangeFilter({super.key, required this.onChanged, this.initialStart, this.initialEnd});
  @override
  State<DateRangeFilter> createState() => _DateRangeFilterState();
}

class _DateRangeFilterState extends State<DateRangeFilter> {
  DateTime? _s, _e;
  @override
  void initState() { super.initState(); _s = widget.initialStart; _e = widget.initialEnd; }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _DBtn(label: _s != null ? DateFormat('dd MMM yy').format(_s!) : AppStrings.get('from'),
        onTap: () async { final d = await showDatePicker(context: context, initialDate: _s ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now()); if (d != null) { setState(() => _s = d); widget.onChanged(_s, _e); } })),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('→', style: TextStyle(color: Colors.grey.shade500))),
      Expanded(child: _DBtn(label: _e != null ? DateFormat('dd MMM yy').format(_e!) : AppStrings.get('to'),
        onTap: () async { final d = await showDatePicker(context: context, initialDate: _e ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now()); if (d != null) { setState(() => _e = d); widget.onChanged(_s, _e); } })),
      if (_s != null || _e != null)
        IconButton(onPressed: () { setState(() { _s = null; _e = null; }); widget.onChanged(null, null); },
          icon: const Icon(Icons.clear, size: 18, color: Colors.grey), padding: EdgeInsets.zero),
    ]);
  }
}

class _DBtn extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _DBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: AppColors.darkBorder), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [const Icon(Icons.calendar_month_rounded, size: 14, color: AppColors.primary), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 12))])));
  }
}

class AppDropdown<T> extends StatelessWidget {
  final String label; final T? value; final List<T> items;
  final String Function(T) itemLabel; final Function(T?) onChanged;
  const AppDropdown({super.key, required this.label, required this.value, required this.items, required this.itemLabel, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(labelText: label),
      hint: Text('Select $label', style: const TextStyle(color: Colors.grey, fontSize: 13)),
      items: items.map((i) => DropdownMenuItem<T>(value: i, child: Text(itemLabel(i)))).toList(),
      onChanged: onChanged,
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  const EmptyState({super.key, required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade600),
      const SizedBox(height: 16),
      Text(message, style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
    ]));
  }
}

class StatRow extends StatelessWidget {
  final String label, value; final Color? valueColor;
  const StatRow({super.key, required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600)),
      Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: valueColor)),
    ]));
  }
}

Future<bool> showConfirmDialog(BuildContext context) async {
  final r = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    title: Text(AppStrings.get('confirm_delete')),
    content: Text(AppStrings.get('delete_msg')),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.get('cancel'))),
      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: Text(AppStrings.get('delete'))),
    ],
  ));
  return r ?? false;
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(padding: const EdgeInsets.only(bottom: 8, top: 4), child: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.5, color: isDark ? Colors.white54 : Colors.grey.shade600)));
  }
}

class InfoChip extends StatelessWidget {
  final String label; final Color color;
  const InfoChip({super.key, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.4))), child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)));
  }
}

class PhotoPicker extends StatelessWidget {
  final String? path; final Function(String?) onPicked;
  const PhotoPicker({super.key, required this.path, required this.onPicked});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final r = await showModalBottomSheet<String>(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary), title: const Text('Camera'), onTap: () => Navigator.pop(ctx, 'camera')),
          ListTile(leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary), title: const Text('Gallery'), onTap: () => Navigator.pop(ctx, 'gallery')),
        ])));
        if (r != null) {
          // image_picker would be called here
          onPicked(path); // placeholder
        }
      },
      child: Container(height: 80, decoration: BoxDecoration(border: Border.all(color: AppColors.darkBorder), borderRadius: BorderRadius.circular(10)),
        child: path != null && path!.isNotEmpty
            ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(path!, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.camera_alt_rounded, color: Colors.grey, size: 22), const SizedBox(width: 8), Text(AppStrings.get('photo'), style: const TextStyle(color: Colors.grey))])),
    );
  }
}

String fmtDate(dynamic d) { try { return DateFormat('dd MMM yyyy').format(DateTime.parse(d.toString())); } catch (_) { return d?.toString() ?? ''; } }
String fmtCur(double v) { if (v >= 10000000) return '₹${(v/10000000).toStringAsFixed(2)}Cr'; if (v >= 100000) return '₹${(v/100000).toStringAsFixed(1)}L'; if (v >= 1000) return '₹${(v/1000).toStringAsFixed(1)}K'; return '₹${v.toStringAsFixed(0)}'; }
