import 'package:flutter/material.dart';
import '../services/finance_service.dart';
import '../services/auth_service.dart';
import '../services/role_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import 'package:intl/intl.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final _financeService = FinanceService();
  final _authService = AuthService();
  late final RoleService _roleService;
  bool _isLoading = false;
  List<Map<String, dynamic>> _rates = [];
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _roleService = RoleService(_authService);
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    _rates = await _financeService.getRates();
    await _loadUsers();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUsers() async {
    try {
      final response = await http.get(
        Uri.parse('http://api.crystal-box.ru/API/auth/get_users.php'),
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _users = List<Map<String, dynamic>>.from(data['users']);
        }
      }
    } catch (e) {
      print('Ошибка загрузки пользователей: $e');
    }
  }

  void _showSetRateDialog({Map<String, dynamic>? existingRate}) {
    int? selectedUserId = existingRate?['user_id'];
    String selectedRateType = existingRate?['rate_type'] ?? 'hourly';
    final rateValueController = TextEditingController(
      text: existingRate?['rate_value']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existingRate == null ? 'Установить ставку' : 'Изменить ставку'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existingRate == null) ...[
                  DropdownButtonFormField<int>(
                    value: selectedUserId,
                    decoration: const InputDecoration(
                      labelText: 'Сотрудник *',
                      border: OutlineInputBorder(),
                    ),
                    items: _users.map((user) {
                      return DropdownMenuItem<int>(
                        value: user['id'],
                        child: Text('${user['full_name']} (${user['login']})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedUserId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  value: selectedRateType,
                  decoration: const InputDecoration(
                    labelText: 'Тип ставки *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'hourly',
                      child: Text('Почасовая (за час работы)'),
                    ),
                    DropdownMenuItem(
                      value: 'piecework',
                      child: Text('Сдельная (за клёпку)'),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedRateType = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rateValueController,
                  decoration: InputDecoration(
                    labelText: 'Размер ставки *',
                    border: const OutlineInputBorder(),
                    helperText: selectedRateType == 'hourly' 
                        ? 'Сумма за 1 час работы' 
                        : 'Сумма за 1 клёпку',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedUserId == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Выберите сотрудника')),
                    );
                  }
                  return;
                }

                final rateValue = double.tryParse(rateValueController.text);
                if (rateValue == null || rateValue <= 0) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Введите размер ставки')),
                    );
                  }
                  return;
                }

                Navigator.pop(dialogContext);
                if (mounted) setState(() => _isLoading = true);

                final success = await _financeService.setRate(
                  userId: selectedUserId!,
                  rateType: selectedRateType,
                  rateValue: rateValue,
                );

                if (mounted) setState(() => _isLoading = false);

                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(existingRate == null ? 'Ставка установлена' : 'Ставка изменена'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await _loadData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ошибка'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(existingRate == null ? 'Установить' : 'Изменить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDownloadReportDialog() {
    DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
    DateTime endDate = DateTime.now();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Отправить отчёт на почту'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Выберите период:'),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Начало периода'),
                  subtitle: Text(DateFormat('dd.MM.yyyy').format(startDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        startDate = picked;
                      });
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Конец периода'),
                  subtitle: Text(DateFormat('dd.MM.yyyy').format(endDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        endDate = picked;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email адрес *',
                    border: OutlineInputBorder(),
                    hintText: 'example@mail.ru',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Введите корректный email')),
                    );
                  }
                  return;
                }
                
                Navigator.pop(dialogContext);
                await _sendReportEmail(startDate, endDate, email);
              },
              icon: const Icon(Icons.send),
              label: const Text('Отправить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendReportEmail(DateTime startDate, DateTime endDate, String email) async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);
      
      print('Отправка отчёта на $email: $startDateStr - $endDateStr');

      final response = await http.post(
        Uri.parse('http://api.crystal-box.ru/API/finance/send_report_email.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'start_date': startDateStr,
          'end_date': endDateStr,
          'email': email,
        }),
      ).timeout(ApiConfig.connectionTimeout);

      print('Статус: ${response.statusCode}');
      print('Ответ: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          if (data['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['message'] ?? 'Отчёт отправлен'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['message'] ?? 'Ошибка отправки'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ошибка сервера'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Исключение: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _roleService.isAdmin || _roleService.isManager;

    return Scaffold(
      floatingActionButton: canEdit
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'download',
                  onPressed: _showDownloadReportDialog,
                  icon: const Icon(Icons.email),
                  label: const Text('Отчёт'),
                  backgroundColor: Colors.orange,
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  heroTag: 'add',
                  onPressed: _showSetRateDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Ставка'),
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _rates.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 80,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Нет установленных ставок',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (canEdit) ...[
                          const SizedBox(height: 8),
                          const Text('Нажмите "Ставка" чтобы создать'),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rates.length,
                    itemBuilder: (context, index) {
                      final rate = _rates[index];
                      final isHourly = rate['rate_type'] == 'hourly';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isHourly 
                                ? Colors.blue 
                                : Colors.green,
                            child: Icon(
                              isHourly 
                                  ? Icons.access_time 
                                  : Icons.work,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            rate['full_name'] ?? 'Неизвестно',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Логин: ${rate['login'] ?? 'Не указан'}'),
                              Text(
                                'Тип: ${isHourly ? "Почасовая" : "Сдельная"}',
                                style: TextStyle(
                                  color: isHourly ? Colors.blue : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Ставка: ${rate['rate_value']} ${isHourly ? "руб/час" : "руб/клёпка"}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          trailing: canEdit
                              ? IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showSetRateDialog(existingRate: rate),
                                  tooltip: 'Изменить ставку',
                                )
                              : null,
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
