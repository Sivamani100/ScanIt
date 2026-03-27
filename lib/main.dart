import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'constants/colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'utils/config.dart';
import 'screens/dashboard/home_screen.dart';
import 'screens/dashboard/insights_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/management/products_screen.dart';
import 'screens/management/management_screens.dart';
import 'screens/billing/new_bill_screen.dart';
import 'screens/billing/bill_detail_screen.dart';
import 'screens/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (AppConfig.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const ScanItApp(),
    ),
  );
}

class ScanItApp extends StatelessWidget {
  const ScanItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScanIt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ScanBillColors.primary,
          primary: ScanBillColors.primary,
          secondary: ScanBillColors.info,
          surface: ScanBillColors.surface,
        ),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ),
        scaffoldBackgroundColor: ScanBillColors.background,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: ScanBillColors.surface,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: ScanBillColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: ScanBillColors.text),
        ),
      ),
      scaffoldMessengerKey: Provider.of<AppProvider>(context, listen: false).messengerKey,
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/home': (context) => MainContainer(),
        '/new-bill': (context) => NewBillScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (authProvider.isAuthenticated) {
      return const MainContainer();
    }
    
    return const LoginScreen();
  }
}

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const InsightsScreen(),
    const CustomerListScreen(),
    const ProductListScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final app = Provider.of<AppProvider>(context, listen: false);
      app.setAuth(auth.user?.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final app = Provider.of<AppProvider>(context);
    
    // If auth state changes, update app provider (handle logout)
    if (auth.user?.id != app.userId) {
       Future.microtask(() => app.setAuth(auth.user?.id));
    }

    return Scaffold(
      backgroundColor: ScanBillColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey<int>(app.currentTabIndex),
          child: _screens[app.currentTabIndex],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Direct to scanner as requested
          Navigator.push(context, MaterialPageRoute(builder: (_) => const NewBillScreen(autoScan: true)));
        },
        backgroundColor: ScanBillColors.primary,
        child: const Icon(Iconsax.scan, color: Colors.white),
      ),
      bottomNavigationBar: Container(
        height: 60,
        margin: const EdgeInsets.only(left: 30, right: 30, bottom: 12),
        decoration: BoxDecoration(
          color: ScanBillColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BottomNavigationBar(
            currentIndex: app.currentTabIndex,
            onTap: (index) => app.setTabIndex(index),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: ScanBillColors.primary,
            unselectedItemColor: ScanBillColors.textSecondary,
            backgroundColor: ScanBillColors.surface,
            elevation: 0,
            iconSize: 22,
            selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 10),
            items: [
              BottomNavigationBarItem(
                icon: Icon(app.currentTabIndex == 0 ? Iconsax.home5 : Iconsax.home_1), 
                label: "Home"
              ),
              BottomNavigationBarItem(
                icon: Icon(app.currentTabIndex == 1 ? Iconsax.status_up5 : Iconsax.status_up), 
                label: "Insights"
              ),
              BottomNavigationBarItem(
                icon: Icon(app.currentTabIndex == 2 ? Iconsax.profile_2user5 : Iconsax.profile_2user), 
                label: "Customers"
              ),
              BottomNavigationBarItem(
                icon: Icon(app.currentTabIndex == 3 ? Iconsax.add_square5 : Iconsax.add_square), 
                label: "Add"
              ),
            ],
          ),
        ),
      ),
    );
  }
}
