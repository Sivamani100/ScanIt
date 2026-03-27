import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/app_provider.dart';
import 'package:iconsax/iconsax.dart';

class SyncErrorScreen extends StatelessWidget {
  const SyncErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final errors = appProvider.syncErrors;

    return Scaffold(
      backgroundColor: ScanBillColors.background,
      appBar: AppBar(
        title: const Text('Local Sync Status'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: ScanBillColors.text,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const Icon(Iconsax.warning_2, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Unsaved Changes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ScanBillColors.text),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Some data is currently saved only on this device. We encountered issues while backing it up to the cloud.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: ScanBillColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: errors.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.1)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Iconsax.info_circle, size: 20, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          errors[index],
                          style: const TextStyle(fontSize: 14, color: ScanBillColors.text, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      appProvider.clearSyncErrors();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: const BorderSide(color: ScanBillColors.border),
                    ),
                    child: const Text('Dismiss', style: TextStyle(color: ScanBillColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      appProvider.syncData();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ScanBillColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Retry Sync', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
