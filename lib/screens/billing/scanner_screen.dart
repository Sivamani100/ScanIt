import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../constants/colors.dart';
import '../../providers/app_provider.dart';
import 'package:iconsax/iconsax.dart';
import '../management/products_screen.dart';
import '../../utils/notifications.dart';

enum ScannerMode { billing, selection }

class ScannerScreen extends StatefulWidget {
  final ScannerMode mode;
  const ScannerScreen({super.key, this.mode = ScannerMode.billing});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.upcA, BarcodeFormat.qrCode, BarcodeFormat.code128],
  );
  bool _isScanned = false;
  final Map<String, DateTime> _lastScanned = {}; // For 2-second cooldown

  @override
  Widget build(BuildContext context) {
    final scanAreaWidth = 300.0;
    final scanAreaHeight = 250.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_isScanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final code = barcode.rawValue;
                if (code != null) {
                  // PRD 1.8: Selection Mode - Direct Return
                  if (widget.mode == ScannerMode.selection) {
                    setState(() => _isScanned = true); // Prevent double pop
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context, code);
                    return;
                  }

                  // PRD 1.8: Multi-scan cooldown (2 seconds)
                  final now = DateTime.now();
                  if (_lastScanned.containsKey(code) && 
                      now.difference(_lastScanned[code]!).inSeconds < 2) {
                    continue;
                  }
                  _lastScanned[code] = now;

                  final product = Provider.of<AppProvider>(context, listen: false)
                      .getProductByBarcode(code);
                  
                  if (product != null) {
                    HapticFeedback.mediumImpact();
                    Provider.of<AppProvider>(context, listen: false).addToCart(product);
                    
                    ScanItNotifications.showTopSnackBar(context, 'Added ${product.name} to cart', backgroundColor: ScanBillColors.success);
                    // PRD 1.8: Removed Navigator.pop to allow continuous scanning
                  } else {
                    _isScanned = true; // Pause for unknown product dialog
                    _showNotFoundDialog(code);
                  }
                  break;
                }
              }
            },
          ),
          
          // Industry Level Overlay
          _buildScannerOverlay(context, scanAreaWidth, scanAreaHeight),
          
          // Header
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircularButton(
                  icon: Iconsax.close_circle,
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      widget.mode == ScannerMode.selection ? 'Scan Barcode' : 'Scan Product',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (widget.mode == ScannerMode.billing) ...[
                  // Cart Badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildCircularButton(
                        icon: Iconsax.shopping_cart,
                        onPressed: () => Navigator.pop(context), // Go back to NewBillScreen to see cart
                      ),
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Consumer<AppProvider>(
                          builder: (context, provider, child) {
                            if (provider.cart.isEmpty) return const SizedBox();
                            return Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: ScanBillColors.error, shape: BoxShape.circle),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              child: Text(
                                '${provider.cart.length}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Search Button (for non-barcode items)
                  _buildCircularButton(
                    icon: Iconsax.search_normal,
                    onPressed: () {
                      Navigator.pop(context, 'search'); // Signal to open search
                    },
                  ),
                ] else
                  _buildCircularButton(
                    icon: Iconsax.flash_1,
                    onPressed: () => _controller.toggleTorch(),
                  ),
              ],
            ),
          ),
          
          // Instruction
          Positioned(
            bottom: widget.mode == ScannerMode.selection ? 80 : 120,
            left: 40,
            right: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.scan_barcode, color: ScanBillColors.primary, size: 32),
                  const SizedBox(height: 12),
                  const Text(
                    'Align barcode within the frame',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Done Button (Only for billing mode)
          if (widget.mode == ScannerMode.billing)
            Positioned(
              bottom: 40,
              left: 60,
              right: 60,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Iconsax.tick_circle),
                label: const Text('Done Scanning', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ScanBillColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 8,
                  shadowColor: ScanBillColors.success.withOpacity(0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay(BuildContext context, double width, double height) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withOpacity(0.6),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Center(
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Corner Markers
          Center(
            child: Container(
              width: width,
              height: height,
              child: Stack(
                children: [
                  _ScannerCorner(isTop: true, isLeft: true),
                  _ScannerCorner(isTop: true, isLeft: false),
                  _ScannerCorner(isTop: false, isLeft: true),
                  _ScannerCorner(isTop: false, isLeft: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black38,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 22),
        onPressed: onPressed,
      ),
    );
  }

  void _showNotFoundDialog(String barcode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Iconsax.danger, color: ScanBillColors.warning),
            SizedBox(width: 10),
            Text('Not Found'),
          ],
        ),
        content: Text('Product with barcode "$barcode" is not in your inventory.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isScanned = false);
            },
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (_) => AddProductScreen(initialBarcode: barcode))
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: ScanBillColors.primary, foregroundColor: Colors.white),
            child: const Text('Add Product'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _ScannerCorner extends StatelessWidget {
  final bool isTop;
  final bool isLeft;
  const _ScannerCorner({required this.isTop, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? const BorderSide(color: ScanBillColors.primary, width: 4) : BorderSide.none,
            bottom: !isTop ? const BorderSide(color: ScanBillColors.primary, width: 4) : BorderSide.none,
            left: isLeft ? const BorderSide(color: ScanBillColors.primary, width: 4) : BorderSide.none,
            right: !isLeft ? const BorderSide(color: ScanBillColors.primary, width: 4) : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: isTop && isLeft ? const Radius.circular(12) : Radius.zero,
            topRight: isTop && !isLeft ? const Radius.circular(12) : Radius.zero,
            bottomLeft: !isTop && isLeft ? const Radius.circular(12) : Radius.zero,
            bottomRight: !isTop && !isLeft ? const Radius.circular(12) : Radius.circular(12),
          ),
        ),
      ),
    );
  }
}
