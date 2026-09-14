import 'auth_service.dart';

enum UserRole { user, manager, admin }

class RoleService {
  final AuthService _authService;

  RoleService(this._authService);

  UserRole get currentRole {
    final user = _authService.user;
    if (user == null) return UserRole.user;

    final roleStr = user['role']?.toString().toLowerCase() ?? 'user';

    switch (roleStr) {
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'user':
      default:
        return UserRole.user;
    }
  }

  bool get isAdmin => currentRole == UserRole.admin;
  bool get isManager => currentRole == UserRole.manager;
  bool get isUser => currentRole == UserRole.user;

  List<int> getAvailableTabs() {
    switch (currentRole) {
      case UserRole.admin:
        return [0, 1, 2, 3, 4, 6, 7, 8]; // Все КРОМЕ финансов + Рецепты + Готовая продукция + Обучение
      case UserRole.manager:
        return [1, 2, 3, 4, 5, 6, 7, 8]; // Без смен (0), но с финансами (5) + Обучение
      case UserRole.user:
        return [0, 1, 8]; // Только смены и производство + Обучение
    }
  }

  String getRoleName() {
    switch (currentRole) {
      case UserRole.admin:
        return 'Администратор';
      case UserRole.manager:
        return 'Менеджер';
      case UserRole.user:
        return 'Пользователь';
    }
  }
}
