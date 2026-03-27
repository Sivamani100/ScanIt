enum LoyaltyTier { bronze, silver, gold, platinum }

int _parseInt(dynamic value, [int defaultValue = 0]) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}

int _parseDate(dynamic value) {
  if (value == null) return DateTime.now().millisecondsSinceEpoch;
  if (value is int) return value;
  if (value is String) {
    try {
      return DateTime.parse(value).millisecondsSinceEpoch;
    } catch (_) {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }
  return DateTime.now().millisecondsSinceEpoch;
}

class ShopSettings {
  final String? id;
  final String shopName;
  final String shopAddress;
  final String ownerName;
  final String upiId;
  final String phone;
  final String? email;
  final String pin;
  final String? logoUri;
  final String? gstNumber;
  final bool isOnboarded;

  ShopSettings({
    this.id,
    required this.shopName,
    required this.shopAddress,
    required this.ownerName,
    required this.upiId,
    required this.phone,
    this.email,
    required this.pin,
    this.logoUri,
    this.gstNumber,
    required this.isOnboarded,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'shopName': shopName,
    'shopAddress': shopAddress,
    'ownerName': ownerName,
    'upiId': upiId,
    'phone': phone,
    'email': email,
    'pin': pin,
    'logoUri': logoUri,
    'gstNumber': gstNumber,
    'isOnboarded': isOnboarded,
  };

  factory ShopSettings.fromJson(Map<String, dynamic> json) => ShopSettings(
    id: json['id'],
    shopName: json['shopName'] ?? json['name'] ?? 'My Shop',
    shopAddress: json['shopAddress'] ?? json['address'] ?? '',
    ownerName: json['ownerName'] ?? '',
    upiId: json['upiId'] ?? '',
    phone: json['phone'] ?? '',
    email: json['email'],
    pin: json['pin'] ?? '0000',
    logoUri: json['logoUri'] ?? json['logoUrl'],
    gstNumber: json['gstNumber'],
    isOnboarded: json['isOnboarded'] ?? false,
  );
}

class Category {
  final String id;
  final String name;
  final String color;

  Category({required this.id, required this.name, required this.color});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};
  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id']?.toString() ?? 'cat_0', 
    name: json['name']?.toString() ?? 'Unknown', 
    color: json['color']?.toString() ?? '#000000'
  );
}

class Product {
  final String id;
  final String name;
  final double price;
  final double? mrp;
  final String? barcode;
  final String categoryId;
  final String? categoryName;
  final double stock;
  final String? hsnCode;
  final double gstPercent;
  final String? imageUrl;
  final double? totalSold;
  final double? totalRevenue;
  final int createdAt;
  final int updatedAt;
  final bool isWeightBased;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.mrp,
    this.barcode,
    required this.categoryId,
    this.categoryName,
    required this.stock,
    this.hsnCode,
    required this.gstPercent,
    this.imageUrl,
    this.totalSold,
    this.totalRevenue,
    required this.createdAt,
    required this.updatedAt,
    this.isWeightBased = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'price': price, 'mrp': mrp, 'barcode': barcode,
    'categoryId': categoryId, 'categoryName': categoryName, 'stock': stock,
    'hsnCode': hsnCode, 'gstPercent': gstPercent, 'imageUrl': imageUrl,
    'totalSold': totalSold, 'totalRevenue': totalRevenue,
    'createdAt': createdAt, 'updatedAt': updatedAt,
    'isWeightBased': isWeightBased ?? false,
  };

  Product copyWith({
    String? id,
    String? name,
    double? price,
    double? mrp,
    String? barcode,
    String? categoryId,
    String? categoryName,
    double? stock,
    String? hsnCode,
    double? gstPercent,
    String? imageUrl,
    double? totalSold,
    double? totalRevenue,
    int? createdAt,
    int? updatedAt,
    bool? isWeightBased,
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    price: price ?? this.price,
    mrp: mrp ?? this.mrp,
    barcode: barcode ?? this.barcode,
    categoryId: categoryId ?? this.categoryId,
    categoryName: categoryName ?? this.categoryName,
    stock: stock ?? this.stock,
    hsnCode: hsnCode ?? this.hsnCode,
    gstPercent: gstPercent ?? this.gstPercent,
    imageUrl: imageUrl ?? this.imageUrl,
    totalSold: totalSold ?? this.totalSold,
    totalRevenue: totalRevenue ?? this.totalRevenue,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isWeightBased: isWeightBased ?? this.isWeightBased,
  );

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id']?.toString() ?? '', 
    name: json['name']?.toString() ?? 'Unknown Product', 
    price: _parseDouble(json['price']),
    mrp: json['mrp'] != null ? _parseDouble(json['mrp']) : null,
    barcode: json['barcode']?.toString(), 
    categoryId: json['categoryId']?.toString() ?? json['category']?.toString() ?? 'cat_other', 
    categoryName: json['categoryName']?.toString(),
    stock: (json['stock'] ?? 0).toDouble(), 
    hsnCode: json['hsnCode']?.toString(),
    gstPercent: _parseDouble(json['gstPercent']), 
    imageUrl: json['imageUrl']?.toString(),
    totalSold: json['totalSold']?.toDouble(),
    totalRevenue: json['totalRevenue'] != null ? _parseDouble(json['totalRevenue']) : 0.0,
    createdAt: _parseDate(json['createdAt']), 
    updatedAt: _parseDate(json['updatedAt']),
    isWeightBased: json['isWeightBased'] ?? false,
  );
}

class CartItem {
  final Product product;
  double quantity;
  double discountPercent;

  CartItem({required this.product, this.quantity = 1.0, this.discountPercent = 0});

  double get lineTotal => (product.price * quantity) * (1 - discountPercent / 100);
}

class Customer {
  final String id;
  final String? name;
  final String phone;
  final String? email;
  final double totalSpent;
  final int visitCount;
  final double creditBalance; // How much this customer owes (positive means debt)
  final int loyaltyPoints;
  final LoyaltyTier loyaltyTier;
  final String? notes;
  final int createdAt;
  final int updatedAt;

  Customer({
    required this.id, this.name, required this.phone, this.email,
    required this.totalSpent, required this.visitCount, this.creditBalance = 0, required this.loyaltyPoints,
    required this.loyaltyTier, this.notes, required this.createdAt, required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'phone': phone, 'email': email,
    'totalSpent': totalSpent, 'visitCount': visitCount, 'creditBalance': creditBalance, 'loyaltyPoints': loyaltyPoints,
    'loyaltyTier': loyaltyTier.name, 'notes': notes, 'createdAt': createdAt, 'updatedAt': updatedAt,
  };

  Customer copyWith({String? id}) => Customer(
    id: id ?? this.id, name: name, phone: phone, email: email,
    totalSpent: totalSpent, visitCount: visitCount, creditBalance: creditBalance, loyaltyPoints: loyaltyPoints,
    loyaltyTier: loyaltyTier, notes: notes, createdAt: createdAt, updatedAt: updatedAt,
  );

  factory Customer.fromJson(Map<String, dynamic> json) {
    LoyaltyTier getTier(String? tierString) {
      if (tierString == null) return LoyaltyTier.bronze;
      try {
        return LoyaltyTier.values.firstWhere((e) => e.name == tierString);
      } catch (_) {
        return LoyaltyTier.bronze;
      }
    }
    
    return Customer(
      id: json['id']?.toString() ?? '', 
      name: json['name']?.toString(), 
      phone: json['phone']?.toString() ?? '', 
      email: json['email']?.toString(),
      totalSpent: _parseDouble(json['totalSpent']), 
      visitCount: _parseInt(json['visitCount']),
      creditBalance: _parseDouble(json['creditBalance'] ?? json['credit_balance'] ?? 0.0),
      loyaltyPoints: _parseInt(json['loyaltyPoints']),
      loyaltyTier: getTier(json['loyaltyTier']?.toString()),
      notes: json['notes']?.toString(), 
      createdAt: _parseDate(json['createdAt']), 
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

class BillItem {
  final String productId;
  final String productName;
  final double quantity;
  final double price;
  final double gstPercent;
  final double discountPercent;
  final double total;

  BillItem({
    required this.productId, required this.productName, required this.quantity,
    required this.price, required this.gstPercent, required this.discountPercent, required this.total,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId, 'productName': productName, 'quantity': quantity,
    'price': price, 'gstPercent': gstPercent, 'discountPercent': discountPercent, 'total': total,
  };

  factory BillItem.fromJson(Map<String, dynamic> json) => BillItem(
    productId: json['productId']?.toString() ?? '', 
    productName: json['productName']?.toString() ?? 'Item', 
    quantity: _parseDouble(json['quantity'], 1.0),
    price: _parseDouble(json['price']), 
    gstPercent: _parseDouble(json['gstPercent']),
    discountPercent: _parseDouble(json['discountPercent']), 
    total: _parseDouble(json['total']),
  );
}

enum PaymentMethod { cash, upi, partial, credit, pending }
enum PaymentStatus { paid, partial, pending }

class Bill {
  final String id;
  final String billNumber;
  final String? customerId;
  final String? customerPhone;
  final String? customerName;
  final List<BillItem> items;
  final double subtotal;
  final double gstAmount;
  final double discountAmount;
  final double total;
  final double amountPaid;
  final double balanceAmount;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final String? notes;
  final String? pdfUrl;
  final int createdAt;

  Bill({
    required this.id, required this.billNumber, this.customerId, this.customerPhone,
    this.customerName, required this.items, required this.subtotal, required this.gstAmount,
    required this.discountAmount, required this.total, this.amountPaid = 0, this.balanceAmount = 0,
    required this.paymentMethod, required this.paymentStatus, this.notes, this.pdfUrl, required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'billNumber': billNumber, 'customerId': customerId,
    'customerPhone': customerPhone, 'customerName': customerName,
    'items': items.map((i) => i.toJson()).toList(), 'subtotal': subtotal,
    'gstAmount': gstAmount, 'discountAmount': discountAmount, 'total': total,
    'amountPaid': amountPaid, 'balanceAmount': balanceAmount,
    'paymentMethod': paymentMethod.name, 'paymentStatus': paymentStatus.name,
    'notes': notes, 'pdfUrl': pdfUrl, 'createdAt': createdAt,
  };

  factory Bill.fromJson(Map<String, dynamic> json) {
    PaymentMethod getMethod(String? str) {
      if (str == null) return PaymentMethod.upi;
      try { return PaymentMethod.values.firstWhere((e) => e.name == str); } catch (_) { return PaymentMethod.upi; }
    }
    PaymentStatus getStatus(String? str) {
      if (str == null) return PaymentStatus.pending;
      try { return PaymentStatus.values.firstWhere((e) => e.name == str); } catch (_) { return PaymentStatus.pending; }
    }
    
    return Bill(
      id: json['id']?.toString() ?? '', 
      billNumber: json['billNumber']?.toString() ?? '', 
      customerId: json['customerId']?.toString(),
      customerPhone: json['customerPhone']?.toString(), 
      customerName: json['customerName']?.toString(),
      items: (json['items'] as List?)?.map((i) => BillItem.fromJson(i)).toList() ?? [],
      subtotal: _parseDouble(json['subtotal']), 
      gstAmount: _parseDouble(json['gstAmount']),
      discountAmount: _parseDouble(json['discountAmount']), 
      total: _parseDouble(json['total']),
      amountPaid: _parseDouble(json['amountPaid'] ?? json['amount_paid']),
      balanceAmount: _parseDouble(json['balanceAmount'] ?? json['balance_amount']),
      paymentMethod: getMethod(json['paymentMethod']?.toString()),
      paymentStatus: getStatus(json['paymentStatus']?.toString()),
      notes: json['notes']?.toString(), 
      pdfUrl: json['pdfUrl']?.toString() ?? json['pdf_url']?.toString(),
      createdAt: _parseDate(json['createdAt']),
    );
  }
}

enum ExpenseCategory { rent, salary, electricity, purchase, transport, marketing, maintenance, other }

class Expense {
  final String id;
  final String title;
  final ExpenseCategory category;
  final String? description;
  final double amount;
  final String date;
  final int createdAt;

  Expense({
    required this.id,
    required this.title,
    required this.category,
    this.description,
    required this.amount,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'category': category.name, 'description': description,
    'amount': amount, 'date': date, 'createdAt': createdAt,
  };

  Expense copyWith({String? id}) => Expense(
    id: id ?? this.id, title: title, category: category, description: description,
    amount: amount, date: date, createdAt: createdAt,
  );

  factory Expense.fromJson(Map<String, dynamic> json) {
    ExpenseCategory getCat(String? str) {
      if (str == null) return ExpenseCategory.other;
      try { return ExpenseCategory.values.firstWhere((e) => e.name == str); } catch (_) { return ExpenseCategory.other; }
    }
    
    return Expense(
      id: json['id']?.toString() ?? '', 
      title: json['title']?.toString() ?? json['category']?.toString() ?? 'Expense',
      category: getCat(json['category']?.toString()),
      description: json['description']?.toString(), 
      amount: _parseDouble(json['amount']),
      date: json['date']?.toString() ?? DateTime.now().toIso8601String(), 
      createdAt: _parseDate(json['createdAt']),
    );
  }
}
