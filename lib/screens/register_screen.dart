import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _keyController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureKey = true;
  String _selectedRole = 'user';

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final error = await _authService.register(
        _loginController.text.trim(),
        _passwordController.text,
        _fullNameController.text.trim(),
        _selectedRole,
        registrationKey: _keyController.text.trim(),
      );

      if (!mounted) return;

      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Регистрация успешна! Теперь войдите.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка подключения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Регистрация'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Создать аккаунт',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 48),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'ФИО',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _loginController,
                      decoration: const InputDecoration(
                        labelText: 'Логин',
                        prefixIcon: Icon(Icons.person),
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Пароль',
                        prefixIcon: const Icon(Icons.lock),
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
                        if (value == null || value.isEmpty) {
                          return 'Введите пароль';
                        }
                        if (value.length < 6) {
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
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Подтвердите пароль';
                        }
                        if (value != _passwordController.text) {
                          return 'Пароли не совпадают';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Роль',
                        prefixIcon: Icon(Icons.badge),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'user',
                          child: Row(
                            children: [
                              Icon(Icons.person, size: 20),
                              SizedBox(width: 8),
                              Text('Пользователь'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'manager',
                          child: Row(
                            children: [
                              Icon(Icons.business_center, size: 20),
                              SizedBox(width: 8),
                              Text('Менеджер'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Row(
                            children: [
                              Icon(Icons.admin_panel_settings, size: 20),
                              SizedBox(width: 8),
                              Text('Администратор'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedRole = value ?? 'user';
                          // При возврате на user — очищаем ключ
                          if (_selectedRole == 'user') {
                            _keyController.clear();
                          }
                        });
                      },
                    ),
                    // === ПОЛЕ КЛЮЧА — ТОЛЬКО ДЛЯ admin/manager ===
                    if (_selectedRole != 'user') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _keyController,
                        obscureText: _obscureKey,
                        decoration: InputDecoration(
                          labelText: 'Ключ доступа',
                          hintText: 'Секретный ключ для роли «$_selectedRole»',
                          prefixIcon: const Icon(Icons.key),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureKey ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() => _obscureKey = !_obscureKey);
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Введите ключ доступа для выбранной роли';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Зарегистрироваться'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      child: const Text('Уже есть аккаунт? Войти'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _keyController.dispose();
    super.dispose();
  }
}