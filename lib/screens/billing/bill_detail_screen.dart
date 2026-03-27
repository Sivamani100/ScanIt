import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../constants/colors.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../utils/pdf_service.dart';
import '../../utils/share_service.dart';
import 'package:iconsax/iconsax.dart';
import '../../utils/notifications.dart';

class BillDetailScreen extends StatelessWidget {
  final Bill bill;

  const BillDetailScreen({super.key, required this.bill});

  String _formatDate(int timestamp) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  void _handleShare(BuildContext context, AppProvider provider) async {
    final shop = provider.shopSettings;
    if (shop == null) {
      ScanItNotifications.showTopSnackBar(context, 'Shop settings not found', backgroundColor: ScanBillColors.error);
      return;
    }
    
    await PdfService.shareInvoice(bill, shop, phone: bill.customerPhone);
  }

  void _handleUPI(BuildContext context, String upiUrl) async {
    final Uri url = Uri.parse(upiUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScanItNotifications.showTopSnackBar(context, 'No UPI payment apps found', backgroundColor: ScanBillColors.warning);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final shop = appProvider.shopSettings;
    
    // PRD 9.1: upi://pay?pa={ID}&pn={NAME}&am={AMT}&cu=INR&tn={INV}
    final upiUrl = shop != null && shop.upiId.isNotEmpty
      ? 'upi://pay?pa=${shop.upiId}&pn=${Uri.encodeComponent(shop.shopName)}&am=${bill.total.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent(bill.id)}'
      : '';

    return Scaffold(
      backgroundColor: ScanBillColors.background,
      appBar: AppBar(
        title: const Text('Invoice Details', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.trash, color: ScanBillColors.error),
            onPressed: () => _showDeleteDialog(context, appProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Receipt Shape Container
            Hero(
              tag: 'bill_${bill.id}',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: ScanBillColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Receipt Header
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Iconsax.tick_circle5, color: ScanBillColors.success, size: 54),
                            const SizedBox(height: 16),
                            Text('₹${bill.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: ScanBillColors.text)),
                            const Text('Transaction Successful', style: TextStyle(fontSize: 14, color: ScanBillColors.success, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      
                      const Divider(height: 1, indent: 24, endIndent: 24, color: ScanBillColors.border),
                      
                      // Receipt Details
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _buildInfoRow("Bill Number", "#${bill.billNumber}"),
                            const SizedBox(height: 12),
                            _buildInfoRow("Date & Time", _formatDate(bill.createdAt)),
                            const SizedBox(height: 12),
                            _buildInfoRow("Customer", bill.customerName ?? bill.customerPhone ?? "Guest"),
                            const SizedBox(height: 12),
                            _buildInfoRow("Payment Mode", bill.paymentMethod.name.toUpperCase()),
                          ],
                        ),
                      ),
                      
                      // Itemized List
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                        decoration: BoxDecoration(
                          color: ScanBillColors.background.withOpacity(0.5),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ITEMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ScanBillColors.textMuted, letterSpacing: 1)),
                            const SizedBox(height: 16),
                            ...bill.items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.productName} × ${item.quantity}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Text('₹${item.total.toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            )),
                            const Divider(height: 24),
                            _buildTotalRow("Subtotal", "₹${bill.subtotal.toInt()}"),
                            if (bill.gstAmount > 0) _buildTotalRow("GST (Included)", "₹${bill.gstAmount.toInt()}"),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL AMOUNT', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                Text('₹${bill.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ScanBillColors.primary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Payment QR - Always show as requested
            _buildPaymentQR(upiUrl, shop),
            const SizedBox(height: 24),
            
            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: "WhatsApp Share",
                    icon: Iconsax.send_1,
                    color: const Color(0xFF25D366),
                    onPressed: () => _handleShare(context, appProvider),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    label: "Print Receipt",
                    icon: Iconsax.printer,
                    color: ScanBillColors.text,
                    onPressed: () {
                       ScanItNotifications.showTopSnackBar(context, 'Printer integration coming soon!', backgroundColor: ScanBillColors.info);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    label: "Repeat Bill",
                    icon: Iconsax.refresh_2,
                    color: ScanBillColors.info,
                    onPressed: () {
                      appProvider.loadBillIntoCart(bill);
                      Navigator.pushNamed(context, '/new-bill');
                    },
                  ),
                ),
              ],
            ),
            
            if (bill.paymentStatus == PaymentStatus.pending && upiUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildActionButton(
                label: "Pay via App",
                icon: Iconsax.mobile,
                color: ScanBillColors.primary,
                onPressed: () => _handleUPI(context, upiUrl),
                isFullWidth: true,
              ),
            ],
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: ScanBillColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ScanBillColors.text)),
      ],
    );
  }

  Widget _buildTotalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: ScanBillColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildPaymentQR(String upiUrl, ShopSettings? shop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ScanBillColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ScanBillColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.card_receive, color: ScanBillColors.primary, size: 20),
              SizedBox(width: 8),
              Text('PAYMENT QR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 20),
          QrImageView(
            data: upiUrl,
            size: 200,
            backgroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: ScanBillColors.text),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: ScanBillColors.text),
          ),
          const SizedBox(height: 16),
          Text(shop?.upiId ?? "", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ScanBillColors.textSecondary)),
          const SizedBox(height: 4),
          const Text('Scan with any UPI App', style: TextStyle(fontSize: 12, color: ScanBillColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isFullWidth = false,
  }) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ScanBillColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Iconsax.trash, color: ScanBillColors.error),
            SizedBox(width: 12),
            Text('Delete Invoice?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('This action cannot be undone. Inventory will not be automatically restored.', style: TextStyle(color: ScanBillColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: ScanBillColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteBill(bill.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ScanBillColors.error, 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
