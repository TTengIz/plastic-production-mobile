import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import '../services/auth_service.dart';
import '../services/role_service.dart';
import 'shifts_screen.dart';
import 'production_screen.dart';
import 'raw_materials_screen.dart';
import 'monitoring_screen.dart';
import 'blanks_screen.dart';
import 'finance_screen.dart';
import 'recipes_screen.dart';
import 'finished_goods_screen.dart';
import 'ready_products_screen.dart';
import 'training_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  late final AuthService _authService;
  late final RoleService _roleService;
  late final List<Widget> _screens;
  late final List<NavigationDestination> _destinations;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _roleService = RoleService(_authService);

    _screens = _buildScreens();
    _destinations = _buildDestinations();
  }

  List<Widget> _buildScreens() {
    final screens = <Widget>[];
    final availableTabs = _roleService.getAvailableTabs();

    if (availableTabs.contains(0)) screens.add(const ShiftsScreen());
    if (availableTabs.contains(1)) screens.add(const ProductionScreen());
    if (availableTabs.contains(2)) screens.add(const RawMaterialsScreen());
    if (availableTabs.contains(3)) screens.add(const MonitoringScreen());
    if (availableTabs.contains(4)) screens.add(const BlanksScreen());
    if (availableTabs.contains(5)) screens.add(const FinanceScreen());
    if (availableTabs.contains(6)) screens.add(const RecipesScreen());
    if (availableTabs.contains(7)) screens.add(const ReadyProductsScreen());
    if (availableTabs.contains(8)) screens.add(const TrainingScreen());

    return screens;
  }

  List<NavigationDestination> _buildDestinations() {
    final destinations = <NavigationDestination>[];
    final availableTabs = _roleService.getAvailableTabs();

    if (availableTabs.contains(0)) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.calendar_today),
        label: 'Смены',
      ));
    }
    if (availableTabs.contains(1)) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.factory),
        label: 'Производство',
      ));
    }
    if (availableTabs.contains(2)) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.inventory),
        label: 'Склад',
      ));
    }
    if (availableTabs.contains(3)) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.people),
        label: 'Мониторинг',
      ));
    }
    if (availableTabs.contains(4)) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.storage),
        label: 'Заготовки',
      ));
    }
    if (availableTabs.contains(5)) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.attach_money),
        label: 'Финансы',
      ));
    }
    if (availableTabs.contains(6)) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.restaurant_menu),
        label: 'Рецепты',
      ));
    }
    if (availableTabs.contains(7)) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.check_circle),
        label: 'Готовое',
      ));
    }
    if (availableTabs.contains(8)) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.school),
        label: 'Обучение',
      ));
    }

    return destinations;
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.user;
    final userName = user?['full_name'] ?? user?['login'] ?? 'Пользователь';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _roleService.getRoleName(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _openProfile,
            tooltip: 'Профиль',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: _destinations,
      ),
    );
  }
}
