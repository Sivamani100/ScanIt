import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../billing/new_bill_screen.dart';
import '../billing/bill_detail_screen.dart';
import '../billing/all_bills_screen.dart';
import '../settings/settings_screen.dart';
import 'sync_error_screen.dart';
import '../../widgets/shimmer_loading.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return "Good morning,";
    if (h < 17) return "Good afternoon,";
    return "Good evening,";
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final shopName = appProvider.shopSettings?.shopName ?? "My Shop";
    
    // Logic for stats
    final today = DateTime.now();
    final todayBills = appProvider.bills.where((b) => 
      DateTime.fromMillisecondsSinceEpoch(b.createdAt).day == today.day &&
      DateTime.fromMillisecondsSinceEpoch(b.createdAt).month == today.month &&
      DateTime.fromMillisecondsSinceEpoch(b.createdAt).year == today.year
    ).toList();
    
    final todayRevenue = todayBills.where((b) => b.paymentStatus == PaymentStatus.paid).fold(0.0, (sum, b) => sum + b.total);
    final todayCustomers = todayBills.map((b) => b.customerPhone).whereType<String>().toSet().length;

    return Scaffold(
      backgroundColor: ScanBillColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await appProvider.syncData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getGreeting(), style: const TextStyle(fontSize: 14, color: ScanBillColors.textSecondary)),
                      Text(shopName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ScanBillColors.text)),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (appProvider.hasSyncErrors) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncErrorScreen()));
                          } else {
                            appProvider.syncData();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: appProvider.hasSyncErrors 
                              ? Colors.red.withOpacity(0.1) 
                              : (appProvider.userId != null ? ScanBillColors.success.withOpacity(0.1) : ScanBillColors.error.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: appProvider.hasSyncErrors ? Colors.red.withOpacity(0.3) : Colors.transparent
                            ),
                          ),
                          child: Row(
                            children: [
                              if (appProvider.isLoading) ...[
                                const SizedBox(
                                  width: 10, height: 10,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: ScanBillColors.success),
                                ),
                                const SizedBox(width: 6),
                                const Text("Syncing...", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ScanBillColors.success)),
                              ] else if (appProvider.hasSyncErrors) ...[
                                const Icon(Iconsax.warning_2, size: 14, color: Colors.red),
                                const SizedBox(width: 6),
                                const Text("Save Changes", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                              ] else ...[
                                Icon(
                                  appProvider.userId != null ? Iconsax.cloud_plus : Iconsax.cloud_cross,
                                  size: 14,
                                  color: appProvider.userId != null ? ScanBillColors.success : ScanBillColors.error,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  appProvider.userId != null ? "Cloud Synced" : "Local Only",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: appProvider.userId != null ? ScanBillColors.success : ScanBillColors.error,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: ScanBillColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ScanBillColors.border),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Iconsax.setting_2, size: 20, color: ScanBillColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // New Bill CTA
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewBillScreen())),
                child: Hero(
                  tag: 'new_bill_cta',
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ScanBillColors.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: ScanBillColors.primary.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Iconsax.flash_1, size: 28, color: Colors.white),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('New Bill', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, decoration: TextDecoration.none)),
                                Text('Scan & checkout in 60s', style: TextStyle(fontSize: 13, color: Colors.white70, decoration: TextDecoration.none)),
                              ],
                            ),
                          ],
                        ),
                        const Icon(Iconsax.arrow_right_3, size: 22, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Stats Row
              Row(
                children: [
                  Expanded(child: _AnimateIn(
                    delay: 100,
                    child: StatCard(
                      icon: Iconsax.wallet_3,
                      color: ScanBillColors.success,
                      value: _formatCurrency(todayRevenue),
                      label: "Revenue",
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _AnimateIn(
                    delay: 200,
                    child: StatCard(
                      icon: Iconsax.receipt_text,
                      color: ScanBillColors.info,
                      value: todayBills.length.toString(),
                      label: "Bills",
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _AnimateIn(
                    delay: 300,
                    child: StatCard(
                      icon: Iconsax.user_tag,
                      color: ScanBillColors.purple,
                      value: todayCustomers.toString(),
                      label: "Customers",
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ScanBillColors.text)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _AnimateIn(
                    delay: 400,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const NewBillScreen(autoScan: true)));
                      },
                      child: const QuickAction(icon: Iconsax.card_send, label: "Scan & Bill", color: ScanBillColors.primary),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _AnimateIn(
                    delay: 500,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        appProvider.setTabIndex(3); // Products tab
                      },
                      child: const QuickAction(icon: Iconsax.box, label: "Products", color: ScanBillColors.info),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _AnimateIn(
                    delay: 600,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        appProvider.setTabIndex(2); // Customers tab
                      },
                      child: const QuickAction(icon: Iconsax.user_square, label: "Customers", color: ScanBillColors.purple),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _AnimateIn(
                    delay: 700,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        appProvider.setTabIndex(1); // Insights tab
                      },
                      child: const QuickAction(icon: Iconsax.status_up, label: "Insights", color: ScanBillColors.success),
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 24),
              // Empty State (or list)
              if (appProvider.bills.isEmpty)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      const Icon(Iconsax.receipt_item, size: 44, color: ScanBillColors.border),
                      const SizedBox(height: 12),
                      const Text('No bills yet today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ScanBillColors.textSecondary)),
                      const Text('Tap "New Bill" to create your first bill', style: TextStyle(fontSize: 14, color: ScanBillColors.textMuted)),
                      const SizedBox(height: 60),
                    ],
                  ),
                )
              else 
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent Bills', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ScanBillColors.text)),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllBillsScreen())), 
                          child: const Text('See all', style: TextStyle(color: ScanBillColors.primary))
                        ),
                      ],
                    ),
                    if (appProvider.isLoading && appProvider.bills.isEmpty)
                      ...List.generate(3, (index) => const ShimmerCard())
                    else
                      ...appProvider.bills.take(5).map((bill) => Hero(
                        tag: 'bill_${bill.id}',
                        child: Material(
                          color: Colors.transparent,
                          child: BillCard(bill: bill),
                        ),
                      )),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const StatCard({super.key, required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ScanBillColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: ScanBillColors.textSecondary)),
        ],
      ),
    );
  }
}

class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const QuickAction({super.key, required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ScanBillColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ScanBillColors.text), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class BillCard extends StatelessWidget {
  final Bill bill;
  const BillCard({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(bill.createdAt);
    final timeStr = DateFormat('hh:mm a').format(date);
    final isPaid = bill.paymentStatus == PaymentStatus.paid;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BillDetailScreen(bill: bill))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ScanBillColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (isPaid ? ScanBillColors.success : ScanBillColors.warning).withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(
              isPaid ? Iconsax.tick_circle : Iconsax.receipt_2,
              size: 18,
              color: isPaid ? ScanBillColors.success : ScanBillColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.billNumber, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ScanBillColors.text)),
                Text(
                  '${bill.customerPhone ?? "Walk-in"} · $timeStr',
                  style: const TextStyle(fontSize: 12, color: ScanBillColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${bill.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ScanBillColors.text)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isPaid ? ScanBillColors.success : ScanBillColors.warning).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPaid ? "Paid" : "Pending",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isPaid ? ScanBillColors.success : ScanBillColors.warning),
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

class _AnimateIn extends StatelessWidget {
  final Widget child;
  final int delay;

  const _AnimateIn({required this.child, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
