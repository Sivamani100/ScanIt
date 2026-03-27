import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';
import 'package:whatsapp_share2/whatsapp_share2.dart';

class PdfService {
  static Future<Uint8List> generateInvoicePdfBytes(Bill bill, ShopSettings shop) async {
    final pdf = pw.Document();

    // Generate UPI QR Code as an image for the PDF
    final qrValidationResult = QrValidator.validate(
      data: 'upi://pay?pa=${shop.upiId}&pn=${shop.shopName}&am=${bill.total.toStringAsFixed(2)}&cu=INR&tn=${bill.billNumber}',
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.L,
    );

    pw.MemoryImage? qrImage;
    if (qrValidationResult.status == QrValidationStatus.valid) {
      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(
        qr: qrCode,
        color: const ui.Color(0xFF000000),
        emptyColor: const ui.Color(0xFFFFFFFF),
        gapless: true,
      );
      
      final picData = await painter.toImageData(200);
      if (picData != null) {
        qrImage = pw.MemoryImage(picData.buffer.asUint8List());
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(shop.shopName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.Text(shop.shopAddress),
                      pw.Text("Phone: ${shop.phone}"),
                      if (shop.gstNumber != null) pw.Text("GST: ${shop.gstNumber}"),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("INVOICE", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      pw.Text("Bill No: ${bill.billNumber}"),
                      pw.Text("Date: ${DateTime.fromMillisecondsSinceEpoch(bill.createdAt).toString().substring(0, 16)}"),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),

              // Customer Details
              if (bill.customerPhone != null) ...[
                pw.Text("Customer: ${bill.customerName ?? 'Valued Customer'}"),
                pw.Text("Phone: ${bill.customerPhone}"),
                pw.SizedBox(height: 20),
              ],

              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _pCell("Item", isHeader: true),
                      _pCell("Price", isHeader: true),
                      _pCell("Qty", isHeader: true),
                      _pCell("Total", isHeader: true),
                    ],
                  ),
                  ...bill.items.map((item) => pw.TableRow(
                    children: [
                      _pCell(item.productName),
                      _pCell("INR ${item.price}"),
                      _pCell(item.quantity.toString()),
                      _pCell("INR ${item.total}"),
                    ],
                  )),
                ],
              ),
              pw.SizedBox(height: 20),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Subtotal: INR ${bill.subtotal}"),
                      pw.Text("GST: INR ${bill.gstAmount}"),
                      if (bill.discountAmount > 0) pw.Text("Discount: -INR ${bill.discountAmount}"),
                      pw.Divider(),
                      pw.Text("Grand Total: INR ${bill.total}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),

              // QR Code and Message
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Thank you for choosing our shop!"),
                      pw.Text("Scan to Pay using UPI"),
                      pw.SizedBox(height: 4),
                      if (qrImage != null) pw.Image(qrImage, width: 80, height: 80),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Signature"),
                      pw.SizedBox(height: 30),
                      pw.Container(width: 100, height: 1, color: PdfColors.black),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _pCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  static String _getWhatsAppMessage(String shopName, double amount, String invoiceNum, {String? pdfUrl}) {
    // Exact template requested by user
    String msg = "Thank you for visiting *$shopName*! We appreciate your business. 🙏\n\n"
        "*Bill Summary:*\n"
        "• Total: ₹${amount.toStringAsFixed(2)}\n"
        "• Invoice: #$invoiceNum\n\n";
    
    if (pdfUrl != null) {
      msg += "📥 *Download Digital Receipt:*\n$pdfUrl\n\n";
    }
    
    msg += "Have a wonderful day! 😊";
    return msg;
  }

  static Future<String?> uploadInvoice(Bill bill, ShopSettings shop) async {
    try {
      final bytes = await generateInvoicePdfBytes(bill, shop);
      final fileName = "invoice_${bill.billNumber}_${bill.id}.pdf";
      return await SupabaseService.uploadInvoicePdf(bytes, fileName);
    } catch (e) {
      debugPrint("PdfService: Failed to upload invoice: $e");
      return null;
    }
  }

  static Future<void> shareInvoice(Bill bill, ShopSettings shop, {String? phone}) async {
    final bytes = await generateInvoicePdfBytes(bill, shop);
    String? pdfUrl = bill.pdfUrl;
    
    if (pdfUrl == null) {
      // Try to upload to Supabase to archive it and get a public URL
      try {
        pdfUrl = await uploadInvoice(bill, shop);
        if (pdfUrl != null && bill.id.isNotEmpty) {
           await SupabaseService.client.from('bills').update({'pdf_url': pdfUrl}).eq('id', bill.id);
        }
      } catch (e) {
        debugPrint("Could not upload to Supabase: $e");
      }
    }

    final message = _getWhatsAppMessage(shop.shopName, bill.total, bill.billNumber, pdfUrl: pdfUrl);

    if (phone != null && phone.length >= 10) {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      final fullPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
      
      try {
        final isInstalled = await WhatsappShare.isInstalled(package: Package.whatsapp);
        
        if (isInstalled == true) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/invoice_${bill.billNumber}.pdf');
          await tempFile.writeAsBytes(bytes);
          
          await WhatsappShare.shareFile(
            text: message,
            phone: fullPhone,
            filePath: [tempFile.path],
            package: Package.whatsapp,
          );
          return; // Shared directly, done.
        }
      } catch (e) {
        debugPrint("Direct WhatsApp sharing failed: $e. Falling back to wa.me link.");
      }

      // Fallback: If direct file sharing failed but we have a phone, try wa.me link
      // Note: This won't attach the PDF file, but will open the chat with the bill summary and PDF link.
      final waUrl = Uri.parse("https://wa.me/$fullPhone?text=${Uri.encodeComponent(message)}");
      try {
        if (await canLaunchUrl(waUrl)) {
          await launchUrl(waUrl, mode: LaunchMode.externalApplication);
          return; // Opened chat directly, done.
        }
      } catch (e) {
        debugPrint("Could not launch WhatsApp chat: $e");
      }
    }

    // On Web, if we have a pdfUrl, we can also open it directly for convenience
    if (kIsWeb && pdfUrl != null) {
      launchUrl(Uri.parse(pdfUrl), mode: LaunchMode.externalApplication);
    }

    // Always show share sheet (safe for Web)
    try {
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'application/pdf', name: 'invoice_${bill.billNumber}.pdf')],
        text: message,
      );
    } catch (e) {
      debugPrint("Error sharing file: $e");
    }
  }
}
