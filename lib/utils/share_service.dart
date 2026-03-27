import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';

class ShareService {
  static String formatBillAsText(Bill bill, ShopSettings settings) {
    final buffer = StringBuffer();
    
    buffer.writeln("*${settings.shopName}*");
    if (settings.shopAddress.isNotEmpty) buffer.writeln(settings.shopAddress);
    if (settings.phone.isNotEmpty) buffer.writeln("Ph: ${settings.phone}");
    buffer.writeln("--------------------------------");
    buffer.writeln("Bill No: ${bill.billNumber}");
    buffer.writeln("Date: ${DateTime.fromMillisecondsSinceEpoch(bill.createdAt).toString().substring(0, 16)}");
    if (bill.customerName != null) buffer.writeln("Customer: ${bill.customerName}");
    buffer.writeln("--------------------------------");
    buffer.writeln("*Items:*");
    
    for (var item in bill.items) {
      final qtyStr = item.quantity.toString().endsWith('.0') 
          ? item.quantity.toInt().toString() 
          : item.quantity.toStringAsFixed(2);
      buffer.writeln(item.productName);
      buffer.writeln("  $qtyStr x ₹${item.price} = *₹${item.total.toStringAsFixed(2)}*");
    }
    
    buffer.writeln("--------------------------------");
    buffer.writeln("*Total Amount: ₹${bill.total.toStringAsFixed(2)}*");
    if (bill.gstAmount > 0) buffer.writeln("Incl. GST: ₹${bill.gstAmount.toStringAsFixed(2)}");
    buffer.writeln("Payment: ${bill.paymentMethod.name.toUpperCase()}");
    buffer.writeln("--------------------------------");
    
    if (settings.upiId.isNotEmpty && bill.balanceAmount > 0) {
      final upiUrl = "upi://pay?pa=${settings.upiId}&pn=${Uri.encodeComponent(settings.shopName)}&am=${bill.balanceAmount.toStringAsFixed(2)}&cu=INR&tn=Invoice_${bill.billNumber}";
      buffer.writeln("\n*Pay Now via UPI:*");
      buffer.writeln(upiUrl);
    }
    
    buffer.writeln("\nThank you for shopping with us! 🙏");
    
    return buffer.toString();
  }

  static Future<void> shareToWhatsApp(String phone, String message) async {
    // Basic phone cleaning
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length == 10) cleanPhone = "91$cleanPhone";
    
    final url = "whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}";
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to web link if app isn't installed
      final webUrl = "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}";
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    }
  }
}
