import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AuthService {
  // ===== Синглтон: один экземпляр на всё приложение =====
  AuthService._internal();

  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;

  // ===== Данные текущей сессии =====
  String token = '';

  // Полные данные пользователя (их ждёт RoleService)
  Map<String, dynamic>? user;

  // ===== Удобные геттеры =====
  int? get userId {
    final id = user?['id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    return null;
  }

  String get role => (user?['role'] ?? '').toString();

  String get login => (user?['login'] ?? '').toString();

  String get fullName =>
      (user?['full_name'] ?? user?['name'] ?? '').toString();

  bool get isLoggedIn => token.isNotEmpty && user != null;

  // ===== Сохранение после логина =====
  void setUser({
    required Map<String, dynamic> user,
    String token = '',
  }) {
    this.user = user;
    if (token.isNotEmpty) this.token = token;
  }

  // ===== Очистка при выходе =====
  void clear() {
    token = '';
    user = null;
  }

  // ===== Регистрация (с ключами для admin/manager) =====
  /// Возвращает null при успехе, текст ошибки при неудаче.
  Future<String?> register(
    String loginValue,
    String password,
    String fullName,
    String role, {
    String registrationKey = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.register),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'login': loginValue,
          'password': password,
          'full_name': fullName,
          'role': role,
          if (registrationKey.isNotEmpty)
            'registration_key': registrationKey,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) return null;
      return data['error'] ?? data['message'] ?? 'Ошибка регистрации';
    } catch (e) {
      return 'Ошибка сети: $e';
    }
  }

  // ===== Авторизация =====
  /// Возвращает null при успехе (и сохраняет сессию), текст ошибки при неудаче.
  Future<String?> signIn(String loginValue, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'login': loginValue,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        setUser(
          user: Map<String, dynamic>.from(data['user'] ?? {}),
          token: data['token'] ?? '',
        );
        return null;
      }

      return data['error'] ?? data['message'] ?? 'Неверный логин или пароль';
    } catch (e) {
      return 'Ошибка сети: $e';
    }
  }

  // ===== Удаление аккаунта =====
  /// Пользователь удаляет только свой аккаунт, admin — любой.
  /// Возвращает true при успехе (и очищает локальную сессию).
  Future<bool> deleteAccount(dynamic userId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.deleteAccount),
        headers: authHeaders,
        body: jsonEncode({'user_id': userId}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        clear(); // локальная сессия больше не нужна
        return true;
      }
      return false;
    } catch (e) {
      print('deleteAccount error: $e');
      return false;
    }
  }

  // ===== Обновление профиля =====
  /// Пользователь меняет только свой профиль, admin — любой.
  /// Возвращает true при успехе и обновляет локальные данные пользователя.
  Future<bool> updateProfile({
    dynamic userId,
    String fullName = '',
    String login = '',
    String? password,
  }) async {
    try {
      final body = <String, dynamic>{'user_id': userId};
      if (fullName.isNotEmpty) body['full_name'] = fullName;
      if (login.isNotEmpty) body['login'] = login;
      if (password != null && password.isNotEmpty) {
        body['password'] = password;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.updateProfile),
        headers: authHeaders,
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Обновляем локальную копию данных пользователя
        if (data['user'] is Map) {
          user = Map<String, dynamic>.from(data['user']);
        }
        return true;
      }
      return false;
    } catch (e) {
      print('updateProfile error: $e');
      return false;
    }
  }

  // ===== Заголовки для защищённых запросов =====
  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
}