// SAME IMPORTS (no change)
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';

class PdfService {
  static final PdfService instance = PdfService._();
  PdfService._();

  Future<void> generateAndShare({
    required Map<String, dynamic> doc,
    required List<Map<String, dynamic>> items,
    required bool isQuotation,
    required BuildContext context,
  }) async {
    final settings = await SettingsService.instance.getAll();
    final bytes = await _build(doc, items, settings, isQuotation);

    final docNum = isQuotation
        ? (doc['quote_number'] ?? 'QT')
        : (doc['invoice_number'] ?? 'INV');

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$docNum.pdf');
    await file.writeAsBytes(bytes);

    if (context.mounted) {
      await showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.print_rounded,
                  color: AppColors.primary),
              title: const Text('Print / Preview'),
              onTap: () async {
                Navigator.pop(ctx);
                await Printing.layoutPdf(onLayout: (_) async => bytes);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.share_rounded, color: AppColors.accent),
              title: const Text('Share'),
              onTap: () async {
                Navigator.pop(ctx);
                await Share.shareXFiles([XFile(file.path)],
                    text:
                        '${isQuotation ? "Quotation" : "Invoice"} $docNum');
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      );
    }
  }

  Future<Uint8List> _build(
    Map<String, dynamic> doc,
    List<Map<String, dynamic>> items,
    Map<String, String> s,
    bool isQ,
  ) async {
    final pdf = pw.Document();

    final orange = PdfColor.fromHex('#FF6B00');
    final darkBg = PdfColor.fromHex('#1A1A1A');
    final lightGrey = PdfColor.fromHex('#F5F5F0');
    final textDark = PdfColor.fromHex('#111111');
    final textGrey = PdfColor.fromHex('#666666');
    final green = PdfColor.fromHex('#22C55E');

    final company = s['company_name'] ?? 'FactoryFlow';
    final gst = s['gst_number'] ?? '';
    final addr = s['address'] ?? '';
    final phone = s['phone'] ?? '';
    final pt = s['payment_terms'] ?? '';
    final tc = s['terms_conditions'] ?? '';

    final docNum = isQ ? doc['quote_number'] : doc['invoice_number'];
    final custName = doc['customer_name'] ?? '';
    final custPhone = doc['customer_phone'] ?? '';

    pw.MemoryImage? logo;
    final logoPath = s['logo_path'] ?? '';
    if (logoPath.isNotEmpty) {
      try {
        final lf = File(logoPath);
        if (await lf.exists()) {
          logo = pw.MemoryImage(await lf.readAsBytes());
        }
      } catch (_) {}
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [

            // HEADER
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: darkBg,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(children: [
                    if (logo != null) ...[
                      pw.Image(logo, width: 46, height: 46),
                      pw.SizedBox(width: 12)
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(company,
                            style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white)),
                        if (addr.isNotEmpty)
                          pw.Text(addr,
                              style: pw.TextStyle(
                                  fontSize: 8, color: textGrey)),
                        if (phone.isNotEmpty)
                          pw.Text(phone,
                              style: pw.TextStyle(
                                  fontSize: 8, color: textGrey)),
                      ],
                    ),
                  ]),
                  pw.Text(docNum ?? '',
                      style: pw.TextStyle(color: PdfColors.white)),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            pw.Text('Customer: $custName'),
            if (custPhone.isNotEmpty) pw.Text('Phone: $custPhone'),

            pw.SizedBox(height: 20),

            ...items.map((e) => pw.Text(
                "${e['service_name']} - ₹${e['amount']}")),

            pw.SizedBox(height: 20),

            pw.Text("Total: ₹${doc['total']}",
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: green)),

            pw.SizedBox(height: 20),

            // PAYMENT TERMS
            if (pt.isNotEmpty) ...[
              pw.Text("Payment Terms",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(pt),
            ],

            pw.SizedBox(height: 10),

            // TERMS
            if (tc.isNotEmpty) ...[
              pw.Text("Terms & Conditions",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(tc),
            ],

            pw.Spacer(),

            pw.Center(
              child: pw.Text(
                "Thank you for your business!",
                style: pw.TextStyle(fontSize: 10, color: textGrey),
              ),
            ),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();
    return Uint8List.fromList(bytes);
  }

  String _fmtDate(dynamic d) {
    try {
      return DateFormat('dd MMM yyyy')
          .format(DateTime.parse(d.toString()));
    } catch (_) {
      return d?.toString() ?? '';
    }
  }
}
