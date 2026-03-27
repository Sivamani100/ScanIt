import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../../constants/colors.dart';
import '../../providers/app_provider.dart';
import '../dashboard/home_screen.dart'; // Import for the reusable BillCard widget
import 'package:flutter/services.dart';

class AllBillsScreen extends StatelessWidget {
  const AllBillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final bills = appProvider.bills;

    return Scaffold(
      backgroundColor: ScanBillColors.background,
      appBar: AppBar(
        title: const Text('All Recent Bills', style: TextStyle(color: ScanBillColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: ScanBillColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: ScanBillColors.text),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await appProvider.syncData();
          },
          child: bills.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                    const Icon(Iconsax.receipt_item, size: 44, color: ScanBillColors.border),
                    const SizedBox(height: 12),
                    const Center(child: Text('No bills found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ScanBillColors.textSecondary))),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  itemCount: bills.length,
                  itemBuilder: (context, index) {
                    return BillCard(bill: bills[index]);
                  },
                ),
        ),
      ),
    );
  }
}
