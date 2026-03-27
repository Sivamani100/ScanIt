import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../billing/scanner_screen.dart';
import '../../widgets/shimmer_loading.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter/services.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final filteredProducts = appProvider.products.where((p) => 
      p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
      (p.barcode?.contains(_searchQuery) ?? false)
    ).toList();

    return Scaffold(
      backgroundColor: ScanBillColors.background,
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.add_circle, color: ScanBillColors.primary),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search products...',
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
              child: appProvider.isLoading && filteredProducts.isEmpty
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 5,
                    itemBuilder: (_, __) => const ShimmerCard(),
                  )
                : ListView.builder(
                    itemCount: filteredProducts.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (ctx, i) {
                      final product = filteredProducts[i];
                      return _ProductCard(product: product);
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.stock <= 5;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScanBillColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('₹${product.price.toInt()}', style: const TextStyle(fontSize: 14, color: ScanBillColors.primary, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isLowStock ? ScanBillColors.error : ScanBillColors.success).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Stock: ${product.stock}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isLowStock ? ScanBillColors.error : ScanBillColors.success),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Iconsax.edit, size: 20, color: ScanBillColors.textSecondary),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddProductScreen(product: product))),
          ),
        ],
      ),
    );
  }
}

class AddProductScreen extends StatefulWidget {
  final Product? product;
  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _barcodeController = TextEditingController();
  String _selectedCategory = "cat_7";
  bool _isWeightBased = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _priceController.text = widget.product!.price.toString();
      _stockController.text = widget.product!.stock.toString();
      _barcodeController.text = widget.product!.barcode ?? "";
      _selectedCategory = widget.product!.categoryId;
      _isWeightBased = widget.product!.isWeightBased;
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final productData = {
        'name': _nameController.text,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'stock': double.tryParse(_stockController.text) ?? 0.0,
        'barcode': _barcodeController.text.isEmpty ? null : _barcodeController.text,
        'categoryId': _selectedCategory,
        'categoryName': appProvider.categories.firstWhere((c) => c.id == _selectedCategory).name,
        'gstPercent': 0.0,
        'isWeightBased': _isWeightBased,
      };

      if (widget.product != null) {
        final updatedProduct = widget.product!.copyWith(
          name: _nameController.text,
          price: double.parse(_priceController.text),
          stock: double.parse(_stockController.text),
          barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
          categoryId: _selectedCategory,
          categoryName: appProvider.categories.firstWhere((c) => c.id == _selectedCategory).name,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        appProvider.updateProduct(updatedProduct);
      } else {
        appProvider.addProduct(productData);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = Provider.of<AppProvider>(context).categories;

    return Scaffold(
      backgroundColor: ScanBillColors.background,
      appBar: AppBar(title: Text(widget.product != null ? 'Edit Product' : 'Add Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLabel("Product Name"),
              TextFormField(
                controller: _nameController,
                decoration: _InputDecor("Enter product name"),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel("Price (₹)"),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: _InputDecor("0.00"),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel("Stock"),
                        TextFormField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          decoration: _InputDecor("0"),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _FieldLabel("Barcode (Optional)"),
              TextFormField(
                controller: _barcodeController,
                decoration: _InputDecor("Scan or enter barcode").copyWith(
                  suffixIcon: IconButton(
                    icon: const Icon(Iconsax.scan), 
                    onPressed: () async {
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen(mode: ScannerMode.selection)));
                      if (result != null && result is String) {
                        setState(() => _barcodeController.text = result);
                      }
                    }
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _FieldLabel("Category"),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: ScanBillColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: ScanBillColors.border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Is Weight Based?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: const Text('Enable for items like sugar, rice (kg)'),
                value: _isWeightBased,
                activeColor: ScanBillColors.primary,
                onChanged: (v) => setState(() => _isWeightBased = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ScanBillColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(widget.product != null ? 'Update Product' : 'Save Product', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ScanBillColors.textSecondary)),
  );
}

InputDecoration _InputDecor(String hint) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: ScanBillColors.surface,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ScanBillColors.border)),
);
