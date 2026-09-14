import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/role_service.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  late final RoleService _roleService;

  @override
  void initState() {
    super.initState();
    _roleService = RoleService(_authService);
  }

  void _deleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление аккаунта'),
        content: const Text('Вы уверены? Это действие нельзя отменить!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final user = _authService.user;
              if (user != null) {
                final success = await _authService.deleteAccount(user['id']);
                if (success && mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ошибка удаления аккаунта'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.user;
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Профиль'),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primaryContainer,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user?['full_name'] ?? 'Пользователь',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _roleService.getRoleName(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('ФИО'),
                        subtitle: Text(user?['full_name'] ?? 'Не указано'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.login),
                        title: const Text('Логин'),
                        subtitle: Text(user?['login'] ?? 'Не указано'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.badge),
                        title: const Text('Роль'),
                        subtitle: Text(_roleService.getRoleName()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.settings),
                        title: const Text('Настройки'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Выйти'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
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
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                                    );
                                  },
                                  child: const Text('Выйти'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.delete_forever, color: Colors.red),
                        title: const Text('Удалить аккаунт', style: TextStyle(color: Colors.red)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.red),
                        onTap: () => _deleteAccount(context),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
