import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import 'package:iconsax/iconsax.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _upiController = TextEditingController();

  void _complete() {
    if (_nameController.text.isNotEmpty && _upiController.text.isNotEmpty) {
      Provider.of<AppProvider>(context, listen: false).saveShopSettings(ShopSettings(
        shopName: _nameController.text,
        shopAddress: "",
        upiId: _upiController.text,
        phone: "",
        ownerName: "User",
        pin: "0000",
        isOnboarded: true,
      ));
      // Auth provider will handle redirect if we connect it, for now we just pop or replace
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScanBillColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.flash_1, size: 80, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text('Welcome to ScanIt', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const Text('Setup your shop in 30 seconds', style: TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(color: ScanBillColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Shop Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Shop Name", hintText: "e.g. Sharma Kirana Store")),
                  const SizedBox(height: 16),
                  TextField(controller: _upiController, decoration: const InputDecoration(labelText: "UPI ID", hintText: "shop@okaxis")),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _complete,
                      style: ElevatedButton.styleFrom(backgroundColor: ScanBillColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: const Text('Start Billing →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
