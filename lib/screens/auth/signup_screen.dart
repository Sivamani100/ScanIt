import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../widgets/custom_input.dart';
import 'package:iconsax/iconsax.dart';
import '../../utils/notifications.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _upiIdController = TextEditingController();
  
  bool _showPassword = false;
  bool _isAgreed = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: ScanBillColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: ScanBillColors.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create ScanIt Account', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: ScanBillColors.text, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                const Text('Industry-level billing for modern shops', style: TextStyle(fontSize: 15, color: ScanBillColors.textSecondary)),
                const SizedBox(height: 32),
                
                // Shop Details Section
                _buildSectionTitle('BUSINESS DETAILS'),
                const SizedBox(height: 16),
                CustomInput(
                  label: 'SHOP NAME',
                  placeholder: 'e.g. Daily Needs Supermarket',
                  icon: Iconsax.shop,
                  controller: _shopNameController,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                CustomInput(
                  label: 'BUSINESS PHONE',
                  placeholder: '91234 56789',
                  icon: Iconsax.call,
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                CustomInput(
                  label: 'UPI ID (For Payments)',
                  placeholder: 'yourname@oksbi',
                  icon: Iconsax.card_receive,
                  controller: _upiIdController,
                ),
                const SizedBox(height: 32),
                
                // Account Details Section
                _buildSectionTitle('ACCOUNT ACCESS'),
                const SizedBox(height: 16),
                CustomInput(
                  label: 'EMAIL ADDRESS',
                  placeholder: 'owner@business.com',
                  icon: Iconsax.sms,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                CustomInput(
                  label: 'PASSWORD',
                  placeholder: 'Minimum 8 characters',
                  icon: Iconsax.lock,
                  isPassword: true,
                  showPassword: _showPassword,
                  onTogglePassword: () => setState(() => _showPassword = !_showPassword),
                  controller: _passwordController,
                  validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Checkbox(
                      value: _isAgreed,
                      onChanged: (val) => setState(() => _isAgreed = val ?? false),
                      activeColor: ScanBillColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    const Expanded(
                      child: Text(
                        'I agree to the Terms of Service and Privacy Policy',
                        style: TextStyle(fontSize: 13, color: ScanBillColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading || !_isAgreed ? null : () async {
                      if (_formKey.currentState!.validate()) {
                        try {
                          await authProvider.signup(
                            _emailController.text, 
                            _passwordController.text,
                            data: {
                              'full_name': _shopNameController.text,
                              'shop_name': _shopNameController.text,
                              'phone': _phoneController.text,
                            },
                          );
                        } catch (e) {
                          if (mounted) {
                            ScanItNotifications.showTopSnackBar(context, 'Signup failed: ${e.toString()}', backgroundColor: ScanBillColors.error);
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ScanBillColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: authProvider.isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Register Business', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ScanBillColors.textMuted, letterSpacing: 1.2),
    );
  }
}
