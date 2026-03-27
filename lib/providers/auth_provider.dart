import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/config.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  bool _isLocalMode = true;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null || _isLocalMode && _isAuthenticatedLocal;
  bool _isAuthenticatedLocal = false;

  AuthProvider() {
    if (AppConfig.isSupabaseConfigured) {
      _isLocalMode = false;
      _user = Supabase.instance.client.auth.currentUser;
      
      // Listen for auth state changes
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;
        
        _user = session?.user;
        if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.signedOut) {
          notifyListeners();
        }
      });
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (AppConfig.isSupabaseConfigured) {
        final res = await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
        if (res.user != null) {
          _user = res.user;
          _isLocalMode = false;
        }
      } else {
        await Future.delayed(const Duration(seconds: 1));
        _isAuthenticatedLocal = true;
      }
    } on AuthException catch (e) {
      throw e.message;
    } catch (e) {
      throw 'An unexpected error occurred during login';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signup(String email, String password, {Map<String, dynamic>? data}) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (AppConfig.isSupabaseConfigured) {
        final res = await Supabase.instance.client.auth.signUp(
          email: email, 
          password: password,
          data: data,
        );
        _user = res.user;
        _isLocalMode = false;
      } else {
        await Future.delayed(const Duration(seconds: 1));
        _isAuthenticatedLocal = true;
      }
    } on AuthException catch (e) {
      throw e.message;
    } catch (e) {
      throw 'An unexpected error occurred during signup';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (AppConfig.isSupabaseConfigured) {
      await Supabase.instance.client.auth.signOut();
    }
    _user = null;
    _isAuthenticatedLocal = false;
    notifyListeners();
  }

  void continueLocal() {
    _isLocalMode = true;
    _isAuthenticatedLocal = true;
    notifyListeners();
  }
}
