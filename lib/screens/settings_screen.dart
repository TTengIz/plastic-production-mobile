import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    final user = _authService.user;
    print('Текущий пользователь: $user');
    _fullNameController.text = user?['full_name'] ?? '';
    _loginController.text = user?['login'] ?? '';
  }

  Future<void> _saveChanges() async {
    print('Нажата кнопка сохранения');
    
    if (!_formKey.currentState!.validate()) {
      print('Форма не прошла валидацию');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      print('Пароли не совпадают');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пароли не совпадают'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = _authService.user;
    print('User ID: ${user?['id']}');
    
    if (user == null) {
      print('Пользователь не найден');
      setState(() => _isLoading = false);
      return;
    }

    print('Отправка данных на сервер...');
    print('ФИО: ${_fullNameController.text.trim()}');
    print('Логин: ${_loginController.text.trim()}');
    print('Пароль: ${_passwordController.text.isNotEmpty ? "изменён" : "не изменён"}');

    final success = await _authService.updateProfile(
      userId: user['id'],
      fullName: _fullNameController.text.trim(),
      login: _loginController.text.trim(),
      password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
    );

    print('Результат: $success');
    setState(() => _isLoading = false);

    if (success && mounted) {
      print('Успешно обновлено');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Профиль обновлен'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      print('Ошибка обновления');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка обновления профиля'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Личная информация',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'ФИО',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _loginController,
                        decoration: const InputDecoration(
                          labelText: 'Логин',
                          prefixIcon: Icon(Icons.login),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Введите логин';
                          }
                          if (value.length < 3) {
                            return 'Логин должен быть не менее 3 символов';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Изменить пароль',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Оставьте пустым если не хотите менять',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Новый пароль',
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty && value.length < 6) {
                            return 'Пароль должен быть не менее 6 символов';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Подтвердите пароль',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveChanges,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Сохранить изменения'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
