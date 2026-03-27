import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../widgets/shimmer_loading.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../utils/notifications.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final activeCustomers = appProvider.customers.where((c) => c.visitCount > 0).toList();
    final filteredCustomers = activeCustomers.where((c) => 
      (c.name?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) || 
      c.phone.contains(_searchQuery)
    ).toList();

    return Scaffold(
      backgroundColor: ScanBillColors.background,
      appBar: AppBar(title: const Text('Customer Registry')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Iconsax.search_status, size: 20, color: ScanBillColors.textSecondary),
                filled: true,
                fillColor: ScanBillColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                await appProvider.syncData();
              },
              child: appProvider.isLoading && filteredCustomers.isEmpty
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 5,
                    itemBuilder: (_, __) => const ShimmerCard(),
                  )
                : ListView.builder(
                    itemCount: filteredCustomers.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (ctx, i) {
                      final customer = filteredCustomers[i];
                      final customerBills = appProvider.bills.where((b) => b.customerPhone == customer.phone).toList();
                      customerBills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                      return _CustomerCard(customer: customer, relatedBills: customerBills);
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final List<Bill> relatedBills;
  const _CustomerCard({required this.customer, required this.relatedBills});

  @override
  Widget build(BuildContext context) {
    final lastBill = relatedBills.isNotEmpty ? relatedBills.first : null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScanBillColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ScanBillColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: ScanBillColors.primary.withOpacity(0.1),
                child: Text(customer.name?.substring(0, 1).toUpperCase() ?? "#", style: const TextStyle(color: ScanBillColors.primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name ?? 'Guest Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text('+91 ${customer.phone}', style: const TextStyle(color: ScanBillColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          if (customer.creditBalance > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Text('Credit', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      const SizedBox(height: 16), // Added this SizedBox for spacing
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CustomerStat(label: 'Total Spent', value: '₹${customer.totalSpent.toStringAsFixed(0)}'),
          _CustomerStat(label: 'Visits', value: '${customer.visitCount}'),
          if (customer.creditBalance > 0)
            _CustomerStat(label: 'Khata/Debt', value: '₹${customer.creditBalance.toStringAsFixed(0)}', color: Colors.red),
          if (customer.creditBalance <= 0)
            _CustomerStat(label: 'Loyalty', value: customer.loyaltyTier.name.toUpperCase()),
        ],
      ),
          if (lastBill != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LAST PURCHASE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ScanBillColors.textMuted, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, yyyy').format(DateTime.fromMillisecondsSinceEpoch(lastBill.createdAt)),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('ITEMS BOUGHT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ScanBillColors.textMuted, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(
                      lastBill.items.length > 2 
                        ? '${lastBill.items[0].productName}, ${lastBill.items[1].productName} +${lastBill.items.length - 2}'
                        : lastBill.items.map((e) => e.productName).join(", "),
                      style: const TextStyle(fontSize: 13, color: ScanBillColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          if (customer.creditBalance > 0) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showSettleDebtDialog(context, customer),
                icon: const Icon(Iconsax.money_recive, size: 18),
                label: const Text('Settle Khata / Debt', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  final message = "Dear ${customer.name ?? 'Customer'}, this is a reminder regarding your outstanding balance of ₹${customer.creditBalance.toStringAsFixed(0)} at ${Provider.of<AppProvider>(context, listen: false).shopSettings?.shopName ?? 'our shop'}. Please settle it at your earliest convenience. Thank you!";
                  final url = "https://wa.me/${customer.phone.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}";
                  // In a real app we'd use url_launcher, for now we log it or use a custom tool if available.
                  debugPrint("Opening WhatsApp: $url");
                  ScanItNotifications.showTopSnackBar(context, 'WhatsApp reminder link prepared!', backgroundColor: ScanBillColors.success);
                },
                icon: FaIcon(FontAwesomeIcons.whatsapp, size: 18, color: const Color(0xFF25D366)),
                label: const Text('Send WhatsApp Reminder', style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ],
    ),
  );
}

  void _showSettleDebtDialog(BuildContext context, Customer customer) {
    final controller = TextEditingController(text: customer.creditBalance.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Settle Khata'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${customer.name ?? customer.phone}'),
            const SizedBox(height: 8),
            Text('Current Debt: ₹${customer.creditBalance.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount Paid Now', prefixText: '₹'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount > 0) {
                Provider.of<AppProvider>(context, listen: false).settleKhata(customer.id, amount);
                Navigator.pop(ctx);
                ScanItNotifications.showTopSnackBar(context, 'Payment recorded successfully!', backgroundColor: ScanBillColors.success);
              }
            },
            child: const Text('Confirm Settlement'),
          ),
        ],
      ),
    );
  }
}

class _CustomerStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _CustomerStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ScanBillColors.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color ?? ScanBillColors.text)),
      ],
    );
  }
}

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  void _addExpense() {
    // Show a bottom sheet or dialog to add expense
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddExpenseSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final totalExpenses = appProvider.expenses.fold(0.0, (sum, e) => sum + e.amount);
    final totalSales = appProvider.bills.where((b) => b.paymentStatus == PaymentStatus.paid).fold(0.0, (sum, b) => sum + b.total);

    // Combine and sort by date
    final List<dynamic> transactions = [...appProvider.expenses, ...appProvider.bills];
    transactions.sort((a, b) {
      final dateA = a is Expense ? a.createdAt : (a as Bill).createdAt;
      final dateB = b is Expense ? b.createdAt : (b as Bill).createdAt;
      return dateB.compareTo(dateA);
    });

    return Scaffold(
      backgroundColor: ScanBillColors.background,
      appBar: AppBar(
        title: const Text('Shop Ledger'),
        actions: [
          IconButton(icon: const Icon(Iconsax.add_circle, color: ScanBillColors.primary), onPressed: _addExpense),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryCard(title: "Total Sales", amount: totalSales, color: ScanBillColors.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(title: "Expenses", amount: totalExpenses, color: ScanBillColors.error),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent Transactions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ScanBillColors.textSecondary)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: transactions.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (ctx, i) {
                final tx = transactions[i];
                if (tx is Expense) {
                  return _ExpenseCard(expense: tx);
                } else {
                  return _BillTransactionCard(bill: tx as Bill);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  const _SummaryCard({required this.title, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScanBillColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: ScanBillColors.textSecondary)),
          const SizedBox(height: 4),
          Text('₹${amount.toInt()}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _BillTransactionCard extends StatelessWidget {
  final Bill bill;
  const _BillTransactionCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScanBillColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: ScanBillColors.success.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Iconsax.arrow_down_1, color: ScanBillColors.success, size: 20),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sales: ${bill.billNumber}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(bill.customerName ?? bill.customerPhone ?? "Retail Customer", style: const TextStyle(fontSize: 12, color: ScanBillColors.textSecondary)),
                ],
              ),
            ],
          ),
          Text('₹${bill.total.toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ScanBillColors.success)),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScanBillColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(expense.category.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (expense.description != null)
                Text(expense.description!, style: const TextStyle(fontSize: 13, color: ScanBillColors.textSecondary)),
              Text(expense.date, style: const TextStyle(fontSize: 12, color: ScanBillColors.textMuted)),
            ],
          ),
          Text('₹${expense.amount.toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ScanBillColors.error)),
        ],
      ),
    );
  }
}

class _AddExpenseSheet extends StatefulWidget {
  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.other;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      decoration: const BoxDecoration(color: ScanBillColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New Expense', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _FieldLabel("Amount (₹)"),
          TextField(controller: _amountController, keyboardType: TextInputType.number, decoration: _InputDecor("0.00")),
          const SizedBox(height: 16),
          _FieldLabel("Category"),
          DropdownButtonFormField<ExpenseCategory>(
            value: _category,
            decoration: _InputDecor("Select category"),
            items: ExpenseCategory.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 16),
          _FieldLabel("Description"),
          TextField(controller: _descController, decoration: _InputDecor("Rent, Salaries, etc.")),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_amountController.text.isNotEmpty) {
                  Provider.of<AppProvider>(context, listen: false).addExpense(
                    _category.name, // Using category name as title for now
                    _category, 
                    double.parse(_amountController.text), 
                    DateFormat('yyyy-MM-dd').format(DateTime.now()),
                    description: _descController.text,
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: ScanBillColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 40),
        ],
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
  hintText: hint, filled: true, fillColor: ScanBillColors.background,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ScanBillColors.border)),
);
