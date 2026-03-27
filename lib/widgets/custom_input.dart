import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import 'package:iconsax/iconsax.dart';

class CustomInput extends StatelessWidget {
  final String label;
  final String placeholder;
  final IconData icon;
  final bool isPassword;
  final bool? showPassword;
  final VoidCallback? onTogglePassword;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const CustomInput({
    super.key,
    required this.label,
    required this.placeholder,
    required this.icon,
    this.isPassword = false,
    this.showPassword,
    this.onTogglePassword,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ScanBillColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: ScanBillColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ScanBillColors.border, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: ScanBillColors.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  obscureText: isPassword && !(showPassword ?? false),
                  keyboardType: keyboardType,
                  validator: validator,
                  style: const TextStyle(fontSize: 15, color: ScanBillColors.text),
                  decoration: InputDecoration(
                    hintText: placeholder,
                    hintStyle: const TextStyle(color: ScanBillColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    errorStyle: const TextStyle(height: 0, fontSize: 0), // Hide default error text to keep UI clean
                  ),
                ),
              ),
              if (isPassword)
                GestureDetector(
                  onTap: onTogglePassword,
                  child: Icon(
                    (showPassword ?? false) ? Iconsax.eye_slash : Iconsax.eye,
                    size: 18,
                    color: ScanBillColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
