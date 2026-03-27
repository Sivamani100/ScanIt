import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/pdf_service.dart';

class AppProvider extends ChangeNotifier {
  final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
  ShopSettings? _shopSettings;
  bool _isLoading = true;
  List<Product> _products = [];
  List<Category> _categories = [];
  List<Customer> _customers = [];
  List<Bill> _bills = [];
  List<CartItem> _cart = [];
  List<Expense> _expenses = [];  int _currentTabIndex = 0;
  List<String> _syncErrors = []; // Added

  int get currentTabIndex => _currentTabIndex;

  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }
  
  String? _userId;
  String? _shopId;

  final _uuid = const Uuid();

  // Getters
  ShopSettings? get shopSettings => _shopSettings;
  bool get isLoading => _isLoading;
  List<Product> get products => _products;
  List<Category> get categories => _categories;
  List<Customer> get customers => _customers;
  List<Bill> get bills => _bills;
  List<CartItem> get cart => _cart;
  List<Expense> get expenses => _expenses;
  String? get userId => _userId;
  String? get shopId => _shopId;
  List<String> get syncErrors => _syncErrors;
  bool get hasSyncErrors => _syncErrors.isNotEmpty;

  static const String _keySettings = "billease_shop_settings";
  static const String _keyProducts = "billease_products";
  static const String _keyCategories = "billease_categories";
  static const String _keyCustomers = "billease_customers";
  static const String _keyBills = "billease_bills";
  static const String _keyExpenses = "billease_expenses";

  final List<Category> _defaultCategories = [
    Category(id: "cat_1", name: "Grocery", color: "#10B981"),
    Category(id: "cat_2", name: "Beverages", color: "#3B82F6"),
    Category(id: "cat_3", name: "Snacks", color: "#F59E0B"),
    Category(id: "cat_4", name: "Dairy", color: "#8B5CF6"),
    Category(id: "cat_5", name: "Personal Care", color: "#EC4899"),
    Category(id: "cat_6", name: "Stationery", color: "#6B7280"),
    Category(id: "cat_7", name: "Other", color: "#FF6B35"),
  ];

  AppProvider() {
    loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();

      final settingsStr = prefs.getString(_keySettings);
      if (settingsStr != null) _shopSettings = ShopSettings.fromJson(jsonDecode(settingsStr));

      final categoriesStr = prefs.getString(_keyCategories);
      if (categoriesStr != null) {
        _categories = (jsonDecode(categoriesStr) as List).map((e) => Category.fromJson(e)).toList();
      } else {
        _categories = _defaultCategories;
        await prefs.setString(_keyCategories, jsonEncode(_categories.map((e) => e.toJson()).toList()));
      }

      final productsStr = prefs.getString(_keyProducts);
      if (productsStr != null) {
        _products = (jsonDecode(productsStr) as List).map((e) => Product.fromJson(e)).toList();
      } else {
        // Initial Industry-Level Sample Data
        _products = [
          Product(
            id: "prod_sample_1", name: "Organic Whole Milk (1L)", price: 65, mrp: 70, barcode: "8901234567890",
            categoryId: "cat_4", categoryName: "Dairy", stock: 24, hsnCode: "0401", gstPercent: 5,
            createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          Product(
            id: "prod_sample_2", name: "Premium Basmati Rice (5kg)", price: 450, mrp: 520, barcode: "8902345678901",
            categoryId: "cat_1", categoryName: "Grocery", stock: 15, hsnCode: "1006", gstPercent: 0,
            createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          Product(
            id: "prod_sample_3", name: "Dark Roasted Coffee Beans", price: 320, mrp: 350, barcode: "8903456789012",
            categoryId: "cat_2", categoryName: "Beverages", stock: 10, hsnCode: "0901", gstPercent: 12,
            createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ];
        await _saveProductsLocally();
      }

      final customersStr = prefs.getString(_keyCustomers);
      if (customersStr != null) {
        _customers = (jsonDecode(customersStr) as List).map((e) => Customer.fromJson(e)).toList();
      }

      final billsStr = prefs.getString(_keyBills);
      if (billsStr != null) {
        _bills = (jsonDecode(billsStr) as List).map((e) => Bill.fromJson(e)).toList();
      }

      final expensesStr = prefs.getString(_keyExpenses);
      if (expensesStr != null) {
        _expenses = (jsonDecode(expensesStr) as List).map((e) => Expense.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Setters for auth integration
  void setAuth(String? userId) {
    debugPrint("AppProvider: setAuth called with userId: $userId");
    if (_userId == userId && _shopId != null) return;
    _userId = userId;
    if (userId != null) {
      syncData();
    } else {
      _shopId = null;
      _shopSettings = null;
      notifyListeners();
    }
  }

  Future<void> syncData() async {
    if (_userId == null) {
      debugPrint("AppProvider: Cannot sync, userId is null");
      return;
    }
    
    // 1. Migrate any legacy IDs to UUIDs first
    await _migrateIds();

    _isLoading = true;
    _syncErrors.clear(); 
    notifyListeners();
    try {
      debugPrint("AppProvider: Starting cloud sync for $_userId...");
      
      final settings = await SupabaseService.getOrCreateShop(_userId!);
      debugPrint("AppProvider: Shop settings retrieved: ${settings.id}");
      
      if (settings.id != null) {
        _shopSettings = settings;
        _shopId = settings.id;
        
        // Fetch All Data from Cloud
        debugPrint("AppProvider: Fetching cloud data...");
        final cloudProducts = await SupabaseService.getProducts(_shopId!);
        final cloudCustomers = await SupabaseService.getCustomers(_shopId!);
        final cloudBills = await SupabaseService.getBills(_shopId!);
        final cloudExpenses = await SupabaseService.getExpenses(_shopId!);
        
        debugPrint("AppProvider: Cloud data fetched. Pushing missing local data...");
        // Push any local data that isn't in cloud yet
        await _pushMissingLocalData(cloudProducts, cloudCustomers, cloudBills, cloudExpenses);
        
        // Refresh local state with final cloud state
        debugPrint("AppProvider: Refreshing local state from cloud...");
        _products = await SupabaseService.getProducts(_shopId!);
        _customers = await SupabaseService.getCustomers(_shopId!);
        _bills = await SupabaseService.getBills(_shopId!);
        _expenses = await SupabaseService.getExpenses(_shopId!);
        
        await _saveSettingsLocally();
        await _saveProductsLocally();
        await _saveCustomersLocally();
        await _saveBillsLocally();
        await _saveExpensesLocally();
        
        debugPrint("AppProvider: Cloud sync success!");
      } else {
        _syncErrors.add("Cloud shop configuration missing.");
      }
    } catch (e) {
      debugPrint("AppProvider: Sync error: $e");
      _syncErrors.add(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSyncErrors() {
    _syncErrors.clear();
    notifyListeners();
  }

  Future<void> _migrateIds() async {
    bool changed = false;
    // Migrate Products
    for (int i = 0; i < _products.length; i++) {
      if (!_products[i].id.contains('-')) {
        _products[i] = _products[i].copyWith(id: _uuid.v4());
        changed = true;
      }
    }
    // Migrate Customers
    for (int i = 0; i < _customers.length; i++) {
        if (!_customers[i].id.contains('-')) {
            _customers[i] = _customers[i].copyWith(id: _uuid.v4());
            changed = true;
        }
    }
    // Migrate Expenses
    for (int i = 0; i < _expenses.length; i++) {
        if (!_expenses[i].id.contains('-')) {
            _expenses[i] = _expenses[i].copyWith(id: _uuid.v4());
            changed = true;
        }
    }

    if (changed) {
      await _saveProductsLocally();
      await _saveCustomersLocally();
      await _saveExpensesLocally();
    }
  }

  Future<void> _pushMissingLocalData(List<Product> cloudProducts, List<Customer> cloudCustomers, List<Bill> cloudBills, List<Expense> cloudExpenses) async {
    if (_shopId == null) return;

    final cloudProdIds = cloudProducts.map((e) => e.id).toSet();
    for (var p in _products) {
      if (!cloudProdIds.contains(p.id)) {
        await SupabaseService.saveProduct(p, _shopId!);
      }
    }

    final cloudCustPhones = cloudCustomers.map((e) => e.phone).toSet();
    for (var c in _customers) {
      if (!cloudCustPhones.contains(c.phone)) {
        await SupabaseService.saveCustomer(c, _shopId!);
      }
    }

    final cloudBillNos = cloudBills.map((e) => e.billNumber).toSet();
    for (var b in _bills) {
      if (!cloudBillNos.contains(b.billNumber)) {
        await SupabaseService.saveBill(b, _shopId!);
      }
    }

    final cloudExpIds = cloudExpenses.map((e) => e.id).toSet();
    for (var ex in _expenses) {
      if (!cloudExpIds.contains(ex.id)) {
        await SupabaseService.saveExpense(ex, _shopId!);
      }
    }
  }

  Future<void> _saveSettingsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    if (_shopSettings != null) await prefs.setString(_keySettings, jsonEncode(_shopSettings!.toJson()));
  }
  
  Future<void> _saveProductsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProducts, jsonEncode(_products.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveCustomersLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomers, jsonEncode(_customers.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveBillsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBills, jsonEncode(_bills.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveExpensesLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyExpenses, jsonEncode(_expenses.map((e) => e.toJson()).toList()));
  }

  Future<void> saveShopSettings(ShopSettings settings) async {
    _shopSettings = settings;
    await _saveSettingsLocally();
    if (_userId != null) await SupabaseService.saveShop(settings, _userId!);
    notifyListeners();
  }

  Future<void> addProduct(Map<String, dynamic> data) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final product = Product(
      id: _uuid.v4(),
      name: data['name'],
      price: (data['price'] as num).toDouble(),
      mrp: data['mrp'] != null ? (data['mrp'] as num).toDouble() : null,
      barcode: data['barcode'],
      categoryId: data['categoryId'],
      categoryName: data['categoryName'],
      stock: (data['stock'] as num).toDouble(),
      hsnCode: data['hsnCode'],
      gstPercent: (data['gstPercent'] as num).toDouble(),
      imageUrl: data['imageUrl'],
      createdAt: now,
      updatedAt: now,
      isWeightBased: data['isWeightBased'] ?? false,
    );
    _products.insert(0, product);
    await _saveProductsLocally();
    if (_shopId != null) {
      await SupabaseService.saveProduct(product, _shopId!);
    }
    notifyListeners();
  }

  Future<void> updateProduct(Product product) async {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product;
      await _saveProductsLocally();
      if (_shopId != null) {
        await SupabaseService.saveProduct(product, _shopId!);
      }
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String id) async {
    _products.removeWhere((p) => p.id == id);
    await _saveProductsLocally();
    if (_shopId != null) {
      await SupabaseService.deleteProduct(id);
    }
    notifyListeners();
  }

  void addToCart(Product product) {
    HapticFeedback.lightImpact();
    final index = _cart.indexWhere((item) => item.product.id == product.id);
    if (index != -1) {
      _cart[index].quantity += 1.0;
    } else {
      _cart.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void addToCartByBarcode(String barcode) {
    try {
      final product = _products.firstWhere((p) => p.barcode == barcode);
      addToCart(product);
    } catch (e) {
      debugPrint("Barcode not found: $barcode");
    }
  }

  void removeFromCart(String productId) {
    HapticFeedback.lightImpact();
    _cart.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateCartQuantity(String productId, double quantity) {
    HapticFeedback.lightImpact();
    if (quantity <= 0) {
      removeFromCart(productId);
    } else {
      final index = _cart.indexWhere((item) => item.product.id == productId);
      if (index != -1) {
        _cart[index].quantity = quantity;
        notifyListeners();
      }
    }
  }

  void clearCart() {
    _cart = [];
    notifyListeners();
  }

  void loadBillIntoCart(Bill bill) {
    _cart = [];
    for (var item in bill.items) {
      final product = _products.firstWhere((p) => p.id == item.productId, orElse: () => Product(
        id: item.productId,
        name: item.productName,
        price: item.price,
        barcode: "",
        categoryId: "Unknown",
        categoryName: "Unknown",
        stock: 0,
        gstPercent: item.gstPercent,
        createdAt: 0,
        updatedAt: 0,
        isWeightBased: false,
      ));
      _cart.add(CartItem(
        product: product,
        quantity: item.quantity,
        discountPercent: item.discountPercent,
      ));
    }
    notifyListeners();
  }

  Future<void> saveBill(Bill bill) async {
    HapticFeedback.heavyImpact();
    // 1. Local Persistence First
    _bills.insert(0, bill);
    await _saveBillsLocally();
    
    // 2. Customer Registry (Essential for "Customers Tab" to show data)
    String? finalCustomerId;
    if (bill.customerPhone != null && bill.customerPhone!.isNotEmpty) {
      final customer = await getOrCreateCustomer(bill.customerPhone!, name: bill.customerName);
      finalCustomerId = customer.id;
      await updateCustomerAfterBill(customer.id, bill.total, balanceAmount: bill.balanceAmount);
    }

    // 3. Inventory Stock Reduction
    for (var item in bill.items) {
      final pIdx = _products.indexWhere((p) => p.id == item.productId);
      if (pIdx != -1) {
        final p = _products[pIdx];
        final updatedProduct = Product(
          id: p.id, name: p.name, price: p.price, mrp: p.mrp, barcode: p.barcode,
          categoryId: p.categoryId, categoryName: p.categoryName,
          stock: (p.stock - item.quantity).clamp(0.0, 9999.0), hsnCode: p.hsnCode, gstPercent: p.gstPercent,
          imageUrl: p.imageUrl, totalSold: (p.totalSold ?? 0.0) + item.quantity,
          totalRevenue: (p.totalRevenue ?? 0) + item.total,
          createdAt: p.createdAt, updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        _products[pIdx] = updatedProduct;
        if (_shopId != null) {
          try {
            await SupabaseService.saveProduct(updatedProduct, _shopId!);
          } catch (e) {
            debugPrint("AppProvider: Stock sync failed for ${updatedProduct.name}: $e");
            _syncErrors.add("Stock sync failed for ${updatedProduct.name}: $e");
          }
        }
      }
    }
    await _saveProductsLocally();

    // 4. Cloud Persistence
    if (_shopId != null) {
      try {
        // Ensure bill has customer ID linked if profile exists
        final cloudBill = Bill(
          id: bill.id, billNumber: bill.billNumber, items: bill.items, subtotal: bill.subtotal,
          gstAmount: bill.gstAmount, discountAmount: bill.discountAmount, total: bill.total,
          amountPaid: bill.amountPaid, balanceAmount: bill.balanceAmount,
          paymentMethod: bill.paymentMethod, paymentStatus: bill.paymentStatus, notes: bill.notes,
          createdAt: bill.createdAt, customerId: finalCustomerId ?? bill.customerId, 
          customerName: bill.customerName, customerPhone: bill.customerPhone,
          pdfUrl: bill.pdfUrl,
        );
        await SupabaseService.saveBill(cloudBill, _shopId!);
        
        // Background PDF generation and upload if not already there
        if (bill.pdfUrl == null && _shopSettings != null) {
          _uploadBillPdfInBackground(bill);
        }
      } catch (e) {
        debugPrint("AppProvider: Cloud bill sync failed: $e");
        _syncErrors.add("Bill ${bill.billNumber} sync failed: $e");
      }
    }
    
    notifyListeners();
  }

  Future<Customer> getOrCreateCustomer(String phone, {String? name}) async {
    // Robust phone matching
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final index = _customers.indexWhere((c) => 
      c.phone == phone || c.phone == cleanPhone || 
      c.phone == "91$cleanPhone" || "91${c.phone}" == cleanPhone
    );
    if (index != -1) return _customers[index];

    final now = DateTime.now().millisecondsSinceEpoch;
    Customer customer = Customer(
      id: _uuid.v4(),
      phone: phone,
      name: name,
      totalSpent: 0,
      visitCount: 0,
      loyaltyPoints: 0,
      loyaltyTier: LoyaltyTier.bronze,
      createdAt: now,
      updatedAt: now,
    );
    
    if (_shopId != null) {
      try {
        final cloudCustomer = await SupabaseService.saveCustomer(customer, _shopId!);
        customer = cloudCustomer; // Adopts the cloud ID if it was a duplicate
      } catch (e) {
        debugPrint("Error saving customer to cloud: $e");
      }
    }
    
    // Ensure no duplicates exist before adding
    _customers.removeWhere((c) => c.phone == customer.phone);
    _customers.add(customer);
    await _saveCustomersLocally();
    notifyListeners();
    return customer;
  }

  Future<void> updateCustomerAfterBill(String customerId, double amount, {double balanceAmount = 0}) async {
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index != -1) {
      final c = _customers[index];
      final newSpent = c.totalSpent + amount;
      final newBalance = c.creditBalance + balanceAmount;
      Customer updated = Customer(
        id: c.id, phone: c.phone, name: c.name, email: c.email,
        totalSpent: newSpent,
        visitCount: c.visitCount + 1,
        creditBalance: newBalance,
        loyaltyPoints: (newSpent / 10).floor(),
        loyaltyTier: _computeTier(newSpent),
        notes: c.notes,
        createdAt: c.createdAt, updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      
      if (_shopId != null) {
        try {
          final cloudCustomer = await SupabaseService.saveCustomer(updated, _shopId!);
          updated = cloudCustomer;
        } catch (e) {
          debugPrint("Error updating customer in cloud: $e");
        }
      }
      
      _customers[index] = updated;
      await _saveCustomersLocally();
      notifyListeners();
    }
  }

  Future<void> settleKhata(String customerId, double amountPaid) async {
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index != -1) {
      final c = _customers[index];
      final newBalance = (c.creditBalance - amountPaid).clamp(0, 9999999.0);
      Customer updated = Customer(
        id: c.id, phone: c.phone, name: c.name, email: c.email,
        totalSpent: c.totalSpent,
        visitCount: c.visitCount,
        creditBalance: newBalance.toDouble(),
        loyaltyPoints: c.loyaltyPoints,
        loyaltyTier: c.loyaltyTier,
        notes: c.notes,
        createdAt: c.createdAt, updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      
      if (_shopId != null) {
        try {
          final cloudCustomer = await SupabaseService.saveCustomer(updated, _shopId!);
          updated = cloudCustomer;
        } catch (e) {
          debugPrint("Error settling khata in cloud: $e");
        }
      }
      
      _customers[index] = updated;
      await _saveCustomersLocally();
      notifyListeners();
      HapticFeedback.mediumImpact();
    }
  }

  LoyaltyTier _computeTier(double amount) {
    if (amount >= 15000) return LoyaltyTier.platinum;
    if (amount >= 5000) return LoyaltyTier.gold;
    if (amount >= 1000) return LoyaltyTier.silver;
    return LoyaltyTier.bronze;
  }

  Product? getProductByBarcode(String barcode) {
    try {
      return _products.firstWhere((p) => p.barcode == barcode);
    } catch (e) {
      return null;
    }
  }

  Future<void> addExpense(String title, ExpenseCategory category, double amount, String date, {String? description}) async {
    final expense = Expense(
      id: _uuid.v4(),
      title: title,
      category: category,
      amount: amount,
      date: date,
      description: description,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _expenses.add(expense);
    await _saveExpensesLocally();
    if (_shopId != null) await SupabaseService.saveExpense(expense, _shopId!);
    notifyListeners();
  }

  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    await _saveExpensesLocally();
    if (_shopId != null) await SupabaseService.deleteExpense(id);
    notifyListeners();
  }

  Future<void> deleteBill(String id) async {
    _bills.removeWhere((b) => b.id == id);
    await _saveBillsLocally();
    if (_shopId != null) await Supabase.instance.client.from('bills').delete().eq('id', id);
    notifyListeners();
  }

  Customer? getCustomerByPhone(String phone) {
    try {
      return _customers.firstWhere((c) => c.phone == phone || c.phone == "91$phone");
    } catch (e) {
      return null;
    }
  }

  // Analytics Methods
  double get todayRevenue {
    final today = DateTime.now();
    return _bills.where((b) {
      final date = DateTime.fromMillisecondsSinceEpoch(b.createdAt);
      return date.year == today.year && date.month == today.month && date.day == today.day;
    }).fold(0.0, (sum, b) => sum + b.total);
  }

  int get todayBillCount {
    final today = DateTime.now();
    return _bills.where((b) {
      final date = DateTime.fromMillisecondsSinceEpoch(b.createdAt);
      return date.year == today.year && date.month == today.month && date.day == today.day;
    }).length;
  }

  double get averageBillValue {
    if (_bills.isEmpty) return 0;
    final totalRevenue = _bills.fold(0.0, (sum, b) => sum + b.total);
    return totalRevenue / _bills.length;
  }

  Map<String, int> get topProducts {
    final Map<String, int> productSales = {};
    for (var bill in _bills) {
      for (var item in bill.items) {
        productSales[item.productName] = (productSales[item.productName] ?? 0) + item.quantity.toInt();
      }
    }
    final sortedEntries = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sortedEntries.take(5));
  }

  List<double> get weeklySalesData {
    final List<double> dailySales = List.filled(7, 0.0);
    final now = DateTime.now();
    for (var bill in _bills) {
      final date = DateTime.fromMillisecondsSinceEpoch(bill.createdAt);
      final difference = now.difference(date).inDays;
      if (difference < 7) {
        int idx = 6 - difference;
        if (idx >= 0 && idx < 7) dailySales[idx] += bill.total;
      }
    }
    return dailySales;
  }

  List<double> get dailyHourlySalesData {
    final List<double> hourlySales = List.filled(24, 0.0);
    final today = DateTime.now();
    for (var bill in _bills) {
      final date = DateTime.fromMillisecondsSinceEpoch(bill.createdAt);
      if (date.year == today.year && date.month == today.month && date.day == today.day) {
        hourlySales[date.hour] += bill.total;
      }
    }
    return hourlySales;
  }

  List<double> get monthlyDaySalesData {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final List<double> daySales = List.filled(daysInMonth, 0.0);
    for (var bill in _bills) {
      final date = DateTime.fromMillisecondsSinceEpoch(bill.createdAt);
      if (date.year == now.year && date.month == now.month) {
        if (date.day >= 1 && date.day <= daysInMonth) {
          daySales[date.day - 1] += bill.total;
        }
      }
    }
    return daySales;
  }

  Future<void> updateBillStatus(String billId, PaymentStatus status) async {
    final index = _bills.indexWhere((b) => b.id == billId);
    if (index != -1) {
      final b = _bills[index];
      final updated = Bill(
        id: b.id, billNumber: b.billNumber, items: b.items, subtotal: b.subtotal,
        gstAmount: b.gstAmount, discountAmount: b.discountAmount, total: b.total,
        paymentMethod: b.paymentMethod, paymentStatus: status, notes: b.notes,
        createdAt: b.createdAt, customerId: b.customerId, customerName: b.customerName,
        customerPhone: b.customerPhone,
      );
      _bills[index] = updated;
      await _saveBillsLocally();
      if (_shopId != null) {
        await Supabase.instance.client.from('bills').update({'payment_status': status.name}).eq('id', billId);
      }
      notifyListeners();
    }
  }

  Future<void> _uploadBillPdfInBackground(Bill bill) async {
    if (_shopSettings == null || _shopId == null) return;
    try {
      final url = await PdfService.uploadInvoice(bill, _shopSettings!);
      if (url != null) {
        final index = _bills.indexWhere((b) => b.id == bill.id);
        if (index != -1) {
          final b = _bills[index];
          _bills[index] = Bill(
            id: b.id, billNumber: b.billNumber, items: b.items, subtotal: b.subtotal,
            gstAmount: b.gstAmount, discountAmount: b.discountAmount, total: b.total,
            amountPaid: b.amountPaid, balanceAmount: b.balanceAmount,
            paymentMethod: b.paymentMethod, paymentStatus: b.paymentStatus, notes: b.notes,
            createdAt: b.createdAt, customerId: b.customerId, customerName: b.customerName,
            customerPhone: b.customerPhone, pdfUrl: url,
          );
          await _saveBillsLocally();
          await Supabase.instance.client.from('bills').update({'pdf_url': url}).eq('id', bill.id);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("AppProvider: Background PDF upload failed: $e");
    }
  }
}
