import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import 'package:iconsax/iconsax.dart';
import '../../utils/notifications.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _shopNameController;
  late TextEditingController _addressController;
  late TextEditingController _upiController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<AppProvider>(context, listen: false).shopSettings;
    _shopNameController = TextEditingController(text: settings?.shopName ?? "");
    _addressController = TextEditingController(text: settings?.shopAddress ?? "");
    _upiController = TextEditingController(text: settings?.upiId ?? "");
    _phoneController = TextEditingController(text: settings?.phone ?? "");
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Provider.of<AppProvider>(context, listen: false).saveShopSettings(ShopSettings(
        shopName: _shopNameController.text,
        shopAddress: _addressController.text,
        upiId: _upiController.text,
        phone: _phoneController.text,
        ownerName: "Owner",
        pin: "0000",
        isOnboarded: true,
      ));
      ScanItNotifications.showTopSnackBar(context, 'Settings saved', backgroundColor: ScanBillColors.success);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScanBillColors.background,
      appBar: AppBar(title: const Text('Shop Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Business Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _FieldLabel("Shop Name"),
              TextFormField(controller: _shopNameController, decoration: _InputDecor("My Awesome Shop"), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              _FieldLabel("Address"),
              TextFormField(controller: _addressController, maxLines: 2, decoration: _InputDecor("123 Street, City")),
              const SizedBox(height: 16),
              _FieldLabel("Phone"),
              TextFormField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: _InputDecor("9876543210")),
              const SizedBox(height: 16),
              _FieldLabel("UPI ID (for QR payment)"),
              TextFormField(controller: _upiController, decoration: _InputDecor("shop@upi"), validator: (v) => v!.isEmpty ? 'Required for payments' : null),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(backgroundColor: ScanBillColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => Provider.of<AppProvider>(context, listen: false).loadData(), // "Reset" simulation
                  child: const Text('Clear Local Cache', style: TextStyle(color: ScanBillColors.error)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ScanBillColors.textSecondary)));
}

InputDecoration _InputDecor(String hint) => InputDecoration(
  hintText: hint, filled: true, fillColor: ScanBillColors.surface,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ScanBillColors.border)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ScanBillColors.border)),
);
