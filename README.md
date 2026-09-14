# Учёт смен и производства

Мобильное приложение для учёта смен, выработки и складских операций на производстве изделий из пластика.

- **Клиент:** Flutter (Dart), Android
- **Сервер:** PHP 8 + MySQL, хостинг BEGET, домен `api.crystal-box.ru`
- **Медиа:** S3-совместимое хранилище (cloud.ru), стриминг видео через PHP-прокси

---

## Архитектура

Классическая клиент-серверная схема с JSON API:

```
[Flutter App] --HTTP/JSON--> [PHP API (BEGET)] --> [MySQL]
                                      |
                                      +--> [S3 bucket (cloud.ru)]
```

- Каждый доменный модуль — отдельная папка в `API/` с независимыми эндпоинтами
- Все ответы — JSON в едином контракте (см. «Контракт API»)
- Аутентификация — Bearer-токены; токен хранится в таблице `tokens`, пароль — bcrypt
- Медиафайлы загружаются в S3 через подписанные AWS4-запросы, метаданные — в `media_files`

## Роли и права

| Роль | Назначение |
|------|------------|
| `user` | Сотрудник: свои смены, выработка, свои данные |
| `admin` | Техническая роль: расширенный доступ к данным |
| `manager` | **Старшая роль бизнес-логики**: финансы и ставки, все смены и отчёты, управление медиа, закрытие чужих смен |

Регистрация `admin` и `manager` — только по специальным ключам из `config.php`.

## Структура репозитория

```
plastic_production_mobile/
├── lib/
│   ├── config/            # URL API, тема оформления
│   ├── screens/           # Экраны приложения
│   ├── services/          # HTTP-сервисы (синглтоны)
│   ├── models/            # Модели данных
│   ├── widgets/           # Переиспользуемые виджеты
│   ├── utils/             # Вспомогательные утилиты
│   └── main.dart
├── android/               # Нативная часть Android (gradle, keystore)
└── test/
```

Серверный код (PHP) развёрнут на хостинге в `public_html/API/` и зеркалируется в репозиторий в папке `server/` (см. roadmap).

## Серверные модули API

| Модуль | Назначение | Ключевые эндпоинты |
|--------|-----------|--------------------|
| `auth/` | Регистрация, вход, middleware авторизации | `register.php`, `login.php`, `auth_middleware.php` |
| `account/` | Профиль пользователя | `update.php`, `delete.php` |
| `shifts/` | Смены и нарушения | `start.php`, `end_shift.php`, `get_shifts.php`, `check_violations.php`, `get_violations.php` |
| `production/` | Отчёты о выработке | `report.php`, `get_reports.php` |
| `warehouse/` | Сырьё, заготовки, готовая продукция | `get_materials.php`, `get_blanks.php`, `get_finished_goods.php`, `add_ready.php` и др. |
| `recipes/` | Рецептуры изделий | `get_recipes.php`, `add_recipe.php`, `update_recipe.php`, `delete_recipe.php` |
| `finance/` | Ставки и заработок | `get_rates.php`, `set_rate.php`, `get_earnings.php`, `send_report_email.php` |
| `media/` | Загрузка/удаление/стриминг медиа | `upload_multipart.php`, `get_media.php`, `delete_media.php`, `proxy.php` |
| `time_off/` | Отгулы | `get_time_off.php`, `add_time_off.php`, `delete_time_off.php` |
| `monitoring/` | Активность сотрудников | `get_daily_activity.php` |

## Контракт API

Успех:

```json
{ "success": true, ... }
```

Ошибка (сопровождается HTTP-кодом 400/401/403/404/503):

```json
{ "success": false, "error": "Человекочитаемое описание" }
```

Защищённые эндпоинты ожидают заголовок:

```
Authorization: Bearer <token>
```

## Матрица доступа (основные эндпоинты)

| Эндпоинт | Метод | Доступ |
|----------|-------|--------|
| `auth/register.php` | POST | публичный (admin/manager — по ключу) |
| `auth/login.php` | POST | публичный |
| `account/update.php`, `account/delete.php` | POST | авторизованный (свой аккаунт; admin — любой) |
| `shifts/start.php` | POST | авторизованный (только за себя) |
| `shifts/end_shift.php` | POST | авторизованный (своя; manager/admin — любую) |
| `shifts/get_shifts.php` | GET | авторизованный (свои; manager/admin — любые) |
| `production/report.php` | POST | авторизованный (только за себя) |
| `production/get_reports.php` | GET | авторизованный (свои; manager/admin — все) |
| `finance/get_rates.php`, `finance/set_rate.php` | GET/POST | только `manager` |
| `media/upload_multipart.php` | POST | авторизованный |
| `media/delete_media.php` | POST | `manager` / `admin` |

## База данных

Основные таблицы: `users`, `tokens`, `shifts`, `production_reports`, `rates`, `media_files`, `recipes`, `materials`, `blanks`, `finished_goods`, `violations`, `time_off`.

Миграция сессий (таблица токенов):

```sql
CREATE TABLE tokens (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    token VARCHAR(128) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_token (token)
);
```

## Безопасность

- Пароли — `password_hash()` / `password_verify()` (bcrypt), в открытом виде не хранятся
- Токены — `bin2hex(random_bytes(32))`, хранятся в БД, отзываются удалением строки
- Единая проверка авторизации — `auth/auth_middleware.php` (`get_auth_user()`)
- Ролевые проверки на каждом защищённом эндпоинте; `user_id` из тела запроса сверяется с владельцем токена
- `.htaccess` в `API/` пробрасывает заголовок `Authorization` в PHP (особенность Apache CGI):
  ```apache
  RewriteEngine On
  RewriteCond %{HTTP:Authorization} .
  RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
  ```
- Ключи регистрации admin/manager и креденшелы БД — только в `config.php` (вне репозитория)
- `key.properties` и `*.jks` исключены из git (см. `.gitignore`)

## Запуск и разработка

### Сервер

Требования: PHP >= 8.0, расширения `pdo_mysql`, `curl`, `json`.

1. Разместить код в `public_html/API/` на хостинге
2. Прописать в `config.php` доступы к БД и ключи регистрации
3. Применить миграции (см. выше)
4. Убедиться, что в `API/` лежит `.htaccess` из раздела «Безопасность»

### Клиент

Требования: Flutter SDK 3.x, Dart 3.x, Android SDK.

```bash
flutter pub get
flutter run            # debug на подключённом устройстве
```

Базовый URL API задаётся в `lib/config/api_config.dart`.

Особенности клиентских сервисов:
- сервисы — синглтоны, заголовки с токеном формируются централизованно
- id из JSON могут приходить строками — все сервисы приводят типы безопасно (`int.tryParse`)
- все сетевые вызовы — с таймаутами (`ApiConfig.connectionTimeout`)

## Релизная сборка и дистрибуция

1. Подписывающий ключ (однократно):

```bash
keytool -genkeypair -v -keystore android/app/release-keystore.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias production
```

2. `android/key.properties` (в git не коммитится):

```properties
storePassword=<...>
keyPassword=<...>
keyAlias=production
storeFile=<абсолютный путь к release-keystore.jks>
```

3. Сборка:

```bash
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

Дистрибуция: APK и страница установки выложены на `http://api.crystal-box.ru/app/`
(страница содержит кнопку загрузки и QR-код для установки с телефона).
Обновления — тем же ключом: новый APK устанавливается поверх старого.

## Соглашения по коду

- Сервер: один файл — один эндпоинт; проверка авторизации до любой бизнес-логики; подготовленные выражения PDO везде
- Клиент: экран — `StatefulWidget` + соответствующий сервис; никаких прямых HTTP-вызовов из виджетов вне сервисов
- Обработка ошибок: сервис возвращает пустой результат/флаг, экран показывает SnackBar; логи — через `print`/`debugPrint`

## Текущий статус и roadmap

Готово:
- [x] Регистрация с ролями и ключами, вход, Bearer-авторизация
- [x] Смены: старт/стоп/история, проверка нарушений (опоздание, ранний уход)
- [x] Производство: отчёты, списание заготовок, брак с причиной, склад готовой продукции
- [x] Финансы: ставки (manager), расчёт заработка
- [x] Медиа: загрузка в S3, стриминг, удаление с подтверждением
- [x] Релизная сборка, дистрибуция по ссылке и QR

В планах:
- [ ] Защита токенами эндпоинтов `warehouse/*` и `recipes/*`
- [ ] Зеркалирование серверного кода в репозиторий (`server/`)
- [ ] Перевод трафика на HTTPS после выпуска сертификата
- [ ] iOS-таргет
- [ ] Пуш-уведомления о сменах

## Лицензия

Внутренний проект компании. Не для публичного распространения.