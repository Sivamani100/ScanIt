import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../../constants/colors.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../utils/notifications.dart';
import 'bill_detail_screen.dart';
import '../../utils/pdf_service.dart';
import '../../services/supabase_service.dart';
import 'scanner_screen.dart';
import 'package:iconsax/iconsax.dart';
import 'package:qr_flutter/qr_flutter.dart';

class NewBillScreen extends StatefulWidget {
  final bool autoScan;
  const NewBillScreen({super.key, this.autoScan = false});

  @override
  State<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends State<NewBillScreen> {
  final _searchController = TextEditingController();
  final _customerController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = "";
  Customer? _recognizedCustomer;
  bool _isFinalizing = false;

  @override
  void dispose() {
    _searchController.dispose();
    _customerController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Unconditionally clear the cart state for a true fresh start
      Provider.of<AppProvider>(context, listen: false).clearCart();
      
      if (widget.autoScan) {
        _scanBarcode();
      }
    });
  }

  void _scanBarcode() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => ScannerScreen()));
    if (result != null) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      appProvider.addToCartByBarcode(result);
    }
  }

  void _onCustomerPhoneChanged(String val, AppProvider provider) {
    if (val.length == 10) {
      final customer = provider.getCustomerByPhone(val);
      setState(() => _recognizedCustomer = customer);
    } else {
      setState(() => _recognizedCustomer = null);
    }
  }

  void _showCheckoutSheet() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    if (appProvider.cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CheckoutSheet(
        isFinalizing: _isFinalizing,
        initialPhone: _customerController.text.isNotEmpty ? _customerController.text : _recognizedCustomer?.phone,
        onConfirm: (phone, {amountPaid = 0, method = PaymentMethod.upi}) => _finalizeBill(phone, amountPaid: amountPaid, method: method),
      ),
    );
  }

  Future<void> _finalizeBill(String? phone, {double amountPaid = 0, PaymentMethod method = PaymentMethod.upi}) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final now = DateTime.now();
    final billId = const Uuid().v4();
    final billNumber = "INV-${now.year}${now.month.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}-${(now.microsecondsSinceEpoch % 99).toString().padLeft(2, '0')}";
    
    double subtotal = 0;
    double gstAmount = 0;
    for (var item in appProvider.cart) {
      subtotal += item.lineTotal;
      gstAmount += (item.product.price * item.quantity) * (item.product.gstPercent / 100);
    }

    final total = subtotal + gstAmount;
    final balance = total - amountPaid;

    final bill = Bill(
      id: billId,
      billNumber: billNumber,
      customerPhone: phone?.isNotEmpty == true ? phone : null,
      customerName: _recognizedCustomer?.name,
      items: appProvider.cart.map((i) => BillItem(
        productId: i.product.id,
        productName: i.product.name,
        quantity: i.quantity,
        price: i.product.price,
        gstPercent: i.product.gstPercent,
        discountPercent: i.discountPercent,
        total: i.lineTotal,
      )).toList(),
      subtotal: subtotal,
      gstAmount: gstAmount,
      discountAmount: 0,
      total: total,
      amountPaid: amountPaid,
      balanceAmount: balance,
      paymentMethod: method,
      paymentStatus: balance <= 0 ? PaymentStatus.paid : (amountPaid > 0 ? PaymentStatus.partial : PaymentStatus.pending),
      createdAt: now.millisecondsSinceEpoch,
    );

    setState(() => _isFinalizing = true);
    
    try {
      await appProvider.saveBill(bill);
      
      // PRD 1.7: Background archiving (pre-gen PDF and upload to Supabase)
      // This makes "Share" instant because the URL is already cached/up-to-date in cloud.
      if (appProvider.shopSettings != null) {
        PdfService.generateInvoicePdfBytes(bill, appProvider.shopSettings!)
           .then((bytes) => SupabaseService.uploadInvoicePdf(bytes, "invoice_${bill.billNumber}_${bill.id}.pdf"))
           .then((url) async {
             if (url.isNotEmpty && bill.id.isNotEmpty) {
               await SupabaseService.client.from('bills').update({'pdf_url': url}).eq('id', bill.id);
             }
           })
           .catchError((e) {
             debugPrint("Background archiving failed: $e");
             return ""; 
           });
      }

      if (mounted) {
        Navigator.pop(context); // Close checkout bottom sheet immediately for speed
        _showSuccessOverlay(bill);
      }
    } catch (e) {
      setState(() => _isFinalizing = false);
      // PRD 1.8: Errors are now handled silently in Provider and shown on sync status page
      debugPrint("Finalize bill error: $e");
      
      // Still show success if local save might have worked, or just let the provider handle it
      // Actually, since saveBill handles its own errors now, we only get here if local save fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Critical error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showManualItemDialog(BuildContext context, AppProvider provider) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final qtyController = TextEditingController(text: "1.0");
    bool isWeight = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ScanBillColors.background,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: MediaQuery.of(ctx).size.width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: const BoxDecoration(
                    color: ScanBillColors.primary,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: const Center(
                    child: Text(
                      'Add Loose Item',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Item Name',
                          hintText: 'e.g. Loose Sugar',
                          prefixIcon: const Icon(Iconsax.box),
                          filled: true,
                          fillColor: ScanBillColors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: priceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Price / Unit',
                                prefixText: '₹ ',
                                filled: true,
                                fillColor: ScanBillColors.surface,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: qtyController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Qty',
                                suffixText: isWeight ? 'kg' : 'pcs',
                                filled: true,
                                fillColor: ScanBillColors.surface,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _ToggleChip(
                            label: 'Weight (kg)',
                            isSelected: isWeight,
                            onTap: () => setDialogState(() => isWeight = true),
                          ),
                          const SizedBox(width: 8),
                          _ToggleChip(
                            label: 'Count (pcs)',
                            isSelected: !isWeight,
                            onTap: () => setDialogState(() => isWeight = false),
                          ),
                        ],
                      ),
                      if (isWeight) ...[
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Quick Presets', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ScanBillColors.textSecondary)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _PresetChip(label: '0.25', onTap: () => setDialogState(() => qtyController.text = "0.25")),
                            _PresetChip(label: '0.5', onTap: () => setDialogState(() => qtyController.text = "0.5")),
                            _PresetChip(label: '1.0', onTap: () => setDialogState(() => qtyController.text = "1.0")),
                            _PresetChip(label: '2.0', onTap: () => setDialogState(() => qtyController.text = "2.0")),
                            _PresetChip(label: '5.0', onTap: () => setDialogState(() => qtyController.text = "5.0")),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: ScanBillColors.textSecondary, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            if (nameController.text.isEmpty || priceController.text.isEmpty) return;
                            
                            final product = Product(
                              id: "manual_${DateTime.now().millisecondsSinceEpoch}",
                              name: nameController.text,
                              price: double.tryParse(priceController.text) ?? 0,
                              categoryId: "cat_manual",
                              categoryName: "Manual",
                              stock: 9999,
                              gstPercent: 0,
                              barcode: null,
                              createdAt: DateTime.now().millisecondsSinceEpoch,
                              updatedAt: DateTime.now().millisecondsSinceEpoch,
                              isWeightBased: isWeight,
                            );
                            
                            provider.addToCart(product);
                            provider.updateCartQuantity(product.id, double.tryParse(qtyController.text) ?? 1.0);
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ScanBillColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Add to Cart', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessOverlay(Bill bill) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.05),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, anim1, anim2) {
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (context.mounted) {
            Navigator.pop(context); // Close overlay
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (_) => BillDetailScreen(bill: bill))
            );
          }
        });
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: ScanBillColors.success,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.tick_circle, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Text('Bill Saved Successfully!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(0, -1), end: const Offset(0, 0)).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final filteredProducts = appProvider.products.where((p) => 
      p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
      (p.barcode?.contains(_searchQuery) ?? false)
    ).toList();

    // PRD 1.8: Smart Sorting - Items in cart come first
    filteredProducts.sort((a, b) {
      final aInCart = appProvider.cart.any((item) => item.product.id == a.id);
      final bInCart = appProvider.cart.any((item) => item.product.id == b.id);
      if (aInCart && !bInCart) return -1;
      if (!aInCart && bInCart) return 1;
      return 0;
    });

    return Scaffold(
      backgroundColor: ScanBillColors.background,
      appBar: AppBar(
        title: const Text('New Bill'),
        leading: IconButton(icon: const Icon(Iconsax.close_circle), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.scan),
            onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => ScannerScreen()));
              if (result == 'search') {
                _searchFocusNode.requestFocus();
              }
            },
          ),
        ],
      ),
           body: Hero(
        tag: 'new_bill_cta',
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              // Customer Recognition Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _recognizedCustomer != null ? ScanBillColors.success.withOpacity(0.1) : ScanBillColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _recognizedCustomer != null ? ScanBillColors.success : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.user_tag, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _customerController,
                          onChanged: (v) => _onCustomerPhoneChanged(v, appProvider),
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(hintText: "Enter customer phone number", border: InputBorder.none, isDense: true),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_recognizedCustomer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    'Welcome back, ${_recognizedCustomer!.name}! 🎉',
                    style: const TextStyle(fontSize: 12, color: ScanBillColors.success, fontWeight: FontWeight.bold),
                  ),
                ),

              const SizedBox(height: 12),

              // Search Bar & Manual Entry Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(color: ScanBillColors.surface, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(Iconsax.search_normal, size: 20, color: ScanBillColors.textMuted),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                onChanged: (v) => setState(() => _searchQuery = v),
                                decoration: const InputDecoration(hintText: "Search products...", border: InputBorder.none),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Iconsax.close_circle, size: 18),
                                onPressed: () => setState(() {
                                  _searchController.clear();
                                  _searchQuery = "";
                                }),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Add Loose Item / Manual Entry Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showManualItemDialog(context, appProvider),
                        icon: const Icon(Iconsax.add_square, size: 18),
                        label: const Text('Add Loose / Manual Item'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ScanBillColors.primary,
                          side: const BorderSide(color: ScanBillColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_searchQuery.length >= 2)
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredProducts.length > 5 ? 5 : filteredProducts.length,
                    itemBuilder: (ctx, i) {
                      final p = filteredProducts[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: const Icon(Iconsax.add, size: 16),
                          label: Text(p.name),
                          backgroundColor: ScanBillColors.primary.withOpacity(0.1),
                          onPressed: () {
                            appProvider.addToCart(p);
                            setState(() {
                              _searchController.clear();
                              _searchQuery = "";
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 8),
              
              // Product List
              Expanded(
                child: _searchQuery.isEmpty && appProvider.cart.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Iconsax.scan_barcode, size: 64, color: ScanBillColors.textMuted),
                          const SizedBox(height: 16),
                          const Text('Scan barcodes or search products', style: TextStyle(color: ScanBillColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredProducts.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (ctx, i) {
                        final product = filteredProducts[i];
                        return _ProductListItem(product: product);
                      },
                    ),
              ),
              // Cart Summary
              if (appProvider.cart.isNotEmpty)
                _CartSummary(onCheckout: _showCheckoutSheet),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductListItem extends StatelessWidget {
  final Product product;
  const _ProductListItem({required this.product});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final cartItem = Provider.of<AppProvider>(context).cart.firstWhere(
      (item) => item.product.id == product.id, 
      orElse: () => CartItem(product: product, quantity: 0)
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ScanBillColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text('₹${product.price} · Stock: ${product.stock}', style: const TextStyle(fontSize: 13, color: ScanBillColors.textSecondary)),
              ],
            ),
          ),
          if (cartItem.quantity == 0)
            ElevatedButton(
              onPressed: () {
                appProvider.addToCart(product);
                ScanItNotifications.showTopSnackBar(context, 'Added ${product.name} to cart', backgroundColor: ScanBillColors.success);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ScanBillColors.primary.withOpacity(0.1),
                foregroundColor: ScanBillColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Add'),
            )
          else
            Row(
              children: [
                IconButton(
                  onPressed: () => appProvider.updateCartQuantity(product.id, (cartItem.quantity - (product.isWeightBased ? 0.25 : 1.0))),
                  icon: const Icon(Iconsax.minus_cirlce, color: ScanBillColors.textSecondary),
                ),
                GestureDetector(
                  onTap: () => _showQuantityDialog(context, product, cartItem.quantity, appProvider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ScanBillColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      product.isWeightBased ? cartItem.quantity.toStringAsFixed(2) : cartItem.quantity.toInt().toString(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => appProvider.updateCartQuantity(product.id, (cartItem.quantity + (product.isWeightBased ? 0.25 : 1.0))),
                  icon: const Icon(Iconsax.add_circle, color: ScanBillColors.primary),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showQuantityDialog(BuildContext context, Product product, double currentQty, AppProvider provider) {
    final controller = TextEditingController(text: currentQty.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ScanBillColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: const BoxDecoration(
                color: ScanBillColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Center(
                child: Text(
                  'Set Quantity',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ScanBillColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      suffixText: product.isWeightBased ? 'kg' : 'pcs',
                      filled: true,
                      fillColor: ScanBillColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (product.isWeightBased)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _PresetChip(label: '0.25', onTap: () => controller.text = '0.25'),
                        _PresetChip(label: '0.5', onTap: () => controller.text = '0.5'),
                        _PresetChip(label: '1.0', onTap: () => controller.text = '1.0'),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: ScanBillColors.textSecondary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        final qty = double.tryParse(controller.text) ?? currentQty;
                        provider.updateCartQuantity(product.id, qty);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ScanBillColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutSheet extends StatefulWidget {
  final Function(String?, {double amountPaid, PaymentMethod method}) onConfirm;
  final bool isFinalizing;
  final String? initialPhone;
  const _CheckoutSheet({required this.onConfirm, this.isFinalizing = false, this.initialPhone});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _phoneController = TextEditingController();
  final _amountPaidController = TextEditingController();
  int _step = 1; // 1: Summary, 2: Phone
  PaymentMethod _paymentMethod = PaymentMethod.upi;
  bool _isPartial = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.initialPhone ?? "";
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountPaidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final total = appProvider.cart.fold(0.0, (sum, item) => sum + item.lineTotal);

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: ScanBillColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ScanBillColors.textMuted.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            
            if (_step == 1) ...[
              Text('Order Summary', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...appProvider.cart.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${item.product.name} × ${item.quantity}', style: const TextStyle(color: ScanBillColors.textSecondary)),
                    Text('₹${item.lineTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              )).toList(),
              const Divider(height: 32),
              const Text('Select Payment Method', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ScanBillColors.textSecondary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _PaymentChip(
                    label: "UPI", 
                    icon: Iconsax.wallet_1, 
                    isSelected: _paymentMethod == PaymentMethod.upi,
                    onTap: () => setState(() { _paymentMethod = PaymentMethod.upi; _isPartial = false; }),
                  ),
                  const SizedBox(width: 8),
                  _PaymentChip(
                    label: "Cash", 
                    icon: Iconsax.money_send, 
                    isSelected: _paymentMethod == PaymentMethod.cash,
                    onTap: () => setState(() { _paymentMethod = PaymentMethod.cash; _isPartial = false; }),
                  ),
                  const SizedBox(width: 8),
                  _PaymentChip(
                    label: "Credit", 
                    icon: Iconsax.timer_1, 
                    isSelected: _paymentMethod == PaymentMethod.credit,
                    onTap: () => setState(() { _paymentMethod = PaymentMethod.credit; _isPartial = false; }),
                  ),
                  const SizedBox(width: 8),
                  _PaymentChip(
                    label: "Partial", 
                    icon: Iconsax.reserve, 
                    isSelected: _isPartial,
                    onTap: () => setState(() { _isPartial = true; _paymentMethod = PaymentMethod.partial; }),
                  ),
                ],
              ),
              if (_isPartial) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _amountPaidController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "Enter amount paid now",
                    prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                    filled: true,
                    fillColor: ScanBillColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
              if (_paymentMethod == PaymentMethod.upi && !_isPartial) ...[
                const SizedBox(height: 24),
                // UPI QR Code Section
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ScanBillColors.border),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                        ),
                        child: QrImageView(
                          data: "upi://pay?pa=${appProvider.shopSettings?.upiId ?? 'demo@upi'}&pn=${appProvider.shopSettings?.shopName ?? 'BillEase Shop'}&am=${total.toStringAsFixed(2)}&cu=INR&tn=Invoice",
                          version: QrVersions.auto,
                          size: 140.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Scan & Pay with any UPI App', style: TextStyle(fontSize: 10, color: ScanBillColors.textSecondary)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _step = 2),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ScanBillColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Proceed to Customer Info →', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              const Text('Customer Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Text('Enter mobile number to share PDF invoice', style: TextStyle(color: ScanBillColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: ScanBillColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: ScanBillColors.primary.withOpacity(0.3))),
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: '91... (10 digits)', border: InputBorder.none, icon: Icon(Iconsax.call, size: 20)),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.isFinalizing ? null : () {
                    final paid = double.tryParse(_amountPaidController.text) ?? 0;
                    widget.onConfirm(
                      _phoneController.text, 
                      amountPaid: _paymentMethod == PaymentMethod.credit ? 0 : (_isPartial ? paid : total),
                      method: _paymentMethod,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ScanBillColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: widget.isFinalizing 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Generate Final Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final VoidCallback onCheckout;
  const _CartSummary({required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ScanBillColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Amount', style: TextStyle(color: ScanBillColors.textSecondary, fontSize: 13)),
                    Text(
                      '₹${Provider.of<AppProvider>(context).cart.fold(0.0, (sum, item) => sum + item.lineTotal).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ScanBillColors.primary),
                    ),
                  ],
                ),
                SizedBox(
                  width: 160,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ScanBillColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Checkout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ScanBillColors.primary : ScanBillColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? ScanBillColors.primary : ScanBillColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : ScanBillColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ScanBillColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ScanBillColors.primary.withOpacity(0.1)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: ScanBillColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? ScanBillColors.primary : ScanBillColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? ScanBillColors.primary : ScanBillColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? Colors.white : ScanBillColors.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : ScanBillColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

