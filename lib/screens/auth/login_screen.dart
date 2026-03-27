import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_input.dart';
import 'package:iconsax/iconsax.dart';
import '../../utils/notifications.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Logo Section
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: ScanBillColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🛒', style: TextStyle(fontSize: 40)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ScanIt',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: ScanBillColors.text),
                  ),
                  const Text(
                    'Smart Billing · UPI Payments · WhatsApp Invoicing',
                    style: TextStyle(fontSize: 14, color: ScanBillColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // Login Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ScanBillColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ScanBillColors.text),
                    ),
                    const Text(
                      'Sign in to your shop account',
                      style: TextStyle(fontSize: 14, color: ScanBillColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    CustomInput(
                      label: 'EMAIL',
                      placeholder: 'your@email.com',
                      icon: Iconsax.sms,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    CustomInput(
                      label: 'PASSWORD',
                      placeholder: 'Enter your password',
                      icon: Iconsax.lock,
                      isPassword: true,
                      showPassword: _showPassword,
                      onTogglePassword: () => setState(() => _showPassword = !_showPassword),
                      controller: _passwordController,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading
                            ? null
                            : () async {
                                try {
                                  await authProvider.login(_emailController.text, _passwordController.text);
                                } catch (e) {
                                  if (mounted) {
                                    ScanItNotifications.showTopSnackBar(
                                      context,
                                      e.toString().contains('Invalid login credentials') 
                                          ? 'Invalid email or password' 
                                          : 'Login failed: ${e.toString()}',
                                      backgroundColor: ScanBillColors.error,
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ScanBillColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 6,
                          shadowColor: ScanBillColors.primary.withOpacity(0.5),
                        ),
                        child: Text(
                          authProvider.isLoading ? 'Signing in...' : 'Sign In',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/signup'),
                        child: Text.rich(
                          TextSpan(
                            text: "Don't have an account? ",
                            style: const TextStyle(color: ScanBillColors.textSecondary, fontSize: 14),
                            children: [
                              TextSpan(
                                text: 'Create one',
                                style: TextStyle(color: ScanBillColors.primary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Provider.of<AuthProvider>(context, listen: false).continueLocal(),
                child: const Text(
                  'Continue without account →',
                  style: TextStyle(color: ScanBillColors.textMuted, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              SizedBox(height: bottomInset > 0 ? bottomInset + 20 : 40),
            ],
          ),
        ),
      ),
    );
  }
}
