import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

  // Helper for snake_case mapping
  static Map<String, dynamic> _toSnakeCase(Map<String, dynamic> data) {
    try {
      final Map<String, dynamic> snakeData = {};
      data.forEach((key, value) {
        final snakeKey = key.replaceAllMapped(RegExp(r'([A-Z])'), (match) => '_${match.group(1)!.toLowerCase()}');
        
        // Auto-convert integer timestamps to ISO 8601 strings for Supabase
        if ((snakeKey == 'created_at' || snakeKey == 'updated_at' || snakeKey == 'last_visit') && value is int) {
          snakeData[snakeKey] = DateTime.fromMillisecondsSinceEpoch(value).toUtc().toIso8601String();
        } else {
          snakeData[snakeKey] = value;
        }
      });
      return snakeData;
    } catch (e) {
      debugPrint("Error in _toSnakeCase: $e");
      return data;
    }
  }

  static Map<String, dynamic> _fromSnakeCase(Map<String, dynamic> data) {
    final Map<String, dynamic> camelData = {};
    data.forEach((key, value) {
      final parts = key.split('_');
      final camelKey = parts[0] + parts.skip(1).map((e) => e[0].toUpperCase() + e.substring(1)).join();
      camelData[camelKey] = value;
    });
    return camelData;
  }

  // Shop
  static Future<ShopSettings> getOrCreateShop(String userId) async {
    try {
      // 1. Get shop_id from profile
      final profile = await client.from('profiles').select('shop_id').eq('id', userId).maybeSingle();
      
      if (profile == null || profile['shop_id'] == null) {
        debugPrint("User $userId has no shop. Initializing default shop...");
        
        // Check if a shop already exists for this user (maybe profile link was lost)
        // If not, create one.
        final shopRes = await client.from('shops').insert({'name': 'My ScanIt Shop'}).select().single();
        final shopId = shopRes['id'];
        
        // Upsert profile to link it
        await client.from('profiles').upsert({
          'id': userId,
          'shop_id': shopId,
          'role': 'owner',
        });
        
        return ShopSettings.fromJson(_fromSnakeCase(shopRes));
      }
      
      final shopId = profile['shop_id'];
      final response = await client.from('shops').select().eq('id', shopId).single();
      return ShopSettings.fromJson(_fromSnakeCase(response));
    } catch (e) {
      debugPrint("Error in getOrCreateShop: $e");
      rethrow;
    }
  }

  static Future<void> saveShop(ShopSettings shop, String userId) async {
    final data = _toSnakeCase(shop.toJson());
    // Strip local-only unmapped fields
    data.remove('pin');
    // Map mismatched columns
    if (data.containsKey('shop_name')) data['name'] = data.remove('shop_name');
    if (data.containsKey('shop_address')) data['address'] = data.remove('shop_address');
    if (data.containsKey('logo_uri')) data['logo_url'] = data.remove('logo_uri');

    if (shop.id != null) {
      await client.from('shops').update(data).eq('id', shop.id!);
    } else {
      final res = await client.from('shops').insert(data).select().single();
      // Update profile with new shop_id
      await client.from('profiles').update({'shop_id': res['id']}).eq('id', userId);
    }
  }

  // Products
  static Future<List<Product>> getProducts(String shopId) async {
    final response = await client.from('products').select().eq('shop_id', shopId);
    return (response as List).map((e) => Product.fromJson(_fromSnakeCase(e))).toList();
  }

  static Future<void> saveProduct(Product product, String shopId) async {
    final data = _toSnakeCase(product.toJson())..['shop_id'] = shopId;
    await client.from('products').upsert(data);
  }

  static Future<void> deleteProduct(String productId) async {
    await client.from('products').delete().eq('id', productId);
  }

  // Customers
  static Future<List<Customer>> getCustomers(String shopId) async {
    final response = await client.from('customers').select().eq('shop_id', shopId);
    return (response as List).map((e) => Customer.fromJson(_fromSnakeCase(e))).toList();
  }

  static Future<Customer> saveCustomer(Customer customer, String shopId) async {
    final data = _toSnakeCase(customer.toJson())..['shop_id'] = shopId;
    // Strip computed/local fields that don't exist in Supabase
    data.remove('loyalty_points');
    data.remove('loyalty_tier');
    
    try {
      final res = await client.from('customers').upsert(data, onConflict: 'id').select().single();
      return Customer.fromJson(_fromSnakeCase(res));
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Unique constraint violation on phone. Fetch the canonical existing customer.
        final res = await client.from('customers')
          .select()
          .eq('shop_id', shopId)
          .eq('phone', customer.phone)
          .single();
        
        // Return existing customer so AppProvider can correct its local ID
        return Customer.fromJson(_fromSnakeCase(res));
      }
      rethrow;
    }
  }

  // Bills
  static Future<List<Bill>> getBills(String shopId) async {
    final response = await client.from('bills').select('*, bill_items(*)').eq('shop_id', shopId).order('created_at', ascending: false);
    return (response as List).map((row) {
      final billData = _fromSnakeCase(row);
      billData['items'] = (row['bill_items'] as List).map((i) => _fromSnakeCase(i)).toList();
      return Bill.fromJson(billData);
    }).toList();
  }

  static Future<void> saveBill(Bill bill, String shopId) async {
    try {
      final billData = _toSnakeCase(bill.toJson())..['shop_id'] = shopId;
      final itemsData = (billData.remove('items') as List);
      
      // Resolve customer_id from phone if possible
      if (bill.customerPhone != null && bill.customerPhone!.isNotEmpty) {
        final customerRes = await client.from('customers')
            .select('id')
            .eq('shop_id', shopId)
            .eq('phone', bill.customerPhone!)
            .maybeSingle();
        
        if (customerRes != null) {
          billData['customer_id'] = customerRes['id'];
        }
      }

      // Insert Bill
      final billRes = await client.from('bills').insert(billData).select().single();
      final billId = billRes['id'];
      
      // Insert Items
      final formattedItems = itemsData.map((item) {
        final snakeItem = _toSnakeCase(item);
        snakeItem['bill_id'] = billId;
        // Ensure product_id is UUID if it's a sample ID
        if (snakeItem['product_id'] != null && !snakeItem['product_id'].toString().contains('-')) {
           snakeItem['product_id'] = null; 
        }
        return snakeItem;
      }).toList();
      
      await client.from('bill_items').insert(formattedItems);
    } catch (e) {
      debugPrint("Fatal error in saveBill: $e");
      rethrow;
    }
  }

  // Storage
  static Future<String> uploadInvoicePdf(Uint8List bytes, String fileName) async {
    try {
      final path = 'invoices/$fileName';
      await client.storage.from('Invoices').uploadBinary(
        path, 
        bytes,
        fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
      );
      
      final publicUrl = client.storage.from('Invoices').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint("Storage upload error: $e");
      // Fallback: If it's a duplicate or something, try to get the existing URL
      try {
        final publicUrl = client.storage.from('Invoices').getPublicUrl('invoices/$fileName');
        return publicUrl;
      } catch (_) {
        rethrow;
      }
    }
  }

  // Expenses
  static Future<List<Expense>> getExpenses(String shopId) async {
    final response = await client.from('expenses').select().eq('shop_id', shopId);
    return (response as List).map((e) => Expense.fromJson(_fromSnakeCase(e))).toList();
  }

  static Future<void> saveExpense(Expense expense, String shopId) async {
    final data = _toSnakeCase(expense.toJson())..['shop_id'] = shopId;
    await client.from('expenses').upsert(data);
  }

  static Future<void> deleteExpense(String expenseId) async {
    await client.from('expenses').delete().eq('id', expenseId);
  }
}
