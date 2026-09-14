import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/time_off_service.dart';
import '../services/monitoring_service.dart';
import '../services/auth_service.dart';
import '../services/role_service.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> with SingleTickerProviderStateMixin {
  final _timeOffService = TimeOffService();
  final _monitoringService = MonitoringService();
  final _authService = AuthService();
  late final RoleService _roleService;
  late TabController _tabController;
  
  bool _isLoading = false;
  List<Map<String, dynamic>> _timeOffList = [];
  List<Map<String, dynamic>> _activityList = [];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _roleService = RoleService(_authService);
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final activityData = await _monitoringService.getDailyActivity(date: dateStr);
    _activityList = activityData['success'] == true 
        ? List<Map<String, dynamic>>.from(activityData['activity']) 
        : [];
    
    _timeOffList = await _timeOffService.getTimeOff();
    
    if (mounted) setState(() => _isLoading = false);
  }

  void _showAddTimeOffDialog() {
    int? selectedUserId;
    String selectedType = 'vacation';
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 14));

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Добавить отпуск/больничный'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Сотрудник *',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<int>(
                      value: 1,
                      child: Text('Томадзе Тенгиз Игоревич (frezer)'),
                    ),
                    DropdownMenuItem<int>(
                      value: 2,
                      child: Text('Иванов Александр Владимирович (direktor)'),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedUserId = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Тип *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'vacation',
                      child: Text('Отпуск'),
                    ),
                    DropdownMenuItem(
                      value: 'sick_leave',
                      child: Text('Больничный'),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Начало'),
                  subtitle: Text(DateFormat('dd.MM.yyyy').format(startDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
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
                  title: const Text('Конец'),
                  subtitle: Text(DateFormat('dd.MM.yyyy').format(endDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        endDate = picked;
                      });
                    }
                  },
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

                final user = _authService.user;
                if (user == null) return;

                Navigator.pop(dialogContext);
                if (mounted) setState(() => _isLoading = true);

                final success = await _timeOffService.addTimeOff(
                  userId: selectedUserId!,
                  type: selectedType,
                  startDate: DateFormat('yyyy-MM-dd').format(startDate),
                  endDate: DateFormat('yyyy-MM-dd').format(endDate),
                  createdBy: user['id'],
                );

                if (mounted) setState(() => _isLoading = false);

                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Запись добавлена'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await _loadData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ошибка добавления'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int timeOffId, String userName, String type) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить запись'),
        content: Text('Удалить $type для $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (mounted) setState(() => _isLoading = true);

              final success = await _timeOffService.deleteTimeOff(timeOffId);

              if (mounted) setState(() => _isLoading = false);

              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Запись удалена'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  await _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ошибка удаления'),
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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadData();
    }
  }

  String _getStatusText(String status, Map<String, dynamic> item) {
    switch(status) {
      case 'working':
        return 'Работает';
      case 'shift_only':
        return 'На смене';
      case 'absent':
        return 'Отсутствует';
      case 'time_off':
        return item['time_off_type'] == 'vacation' ? 'В отпуске' : 'На больничном';
      default:
        return 'Неизвестно';
    }
  }

  Color _getStatusColor(String status) {
    switch(status) {
      case 'working':
        return Colors.green;
      case 'shift_only':
        return Colors.blue;
      case 'absent':
        return Colors.grey;
      case 'time_off':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch(status) {
      case 'working':
        return Icons.work;
      case 'shift_only':
        return Icons.access_time;
      case 'absent':
        return Icons.person_off;
      case 'time_off':
        return Icons.event_busy;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _roleService.isAdmin || _roleService.isManager;
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: _showAddTimeOffDialog,
              icon: const Icon(Icons.add),
              label: const Text('Отпуск/Больничный'),
            )
          : null,
      body: Column(
        children: [
          // Выбор даты (только для админов и менеджеров)
          if (canEdit)
            Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isToday ? 'Сегодня, ${DateFormat('dd.MM.yyyy').format(_selectedDate)}' 
                              : DateFormat('dd.MM.yyyy').format(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.date_range),
                    onPressed: _selectDate,
                    tooltip: 'Выбрать дату',
                  ),
                  if (!isToday)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedDate = DateTime.now();
                        });
                        _loadData();
                      },
                      child: const Text('Сегодня'),
                    ),
                ],
              ),
            ),
          
          // Вкладки
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.people), text: 'Активность'),
              Tab(icon: Icon(Icons.event_busy), text: 'Отпуска'),
            ],
          ),
          
          // Содержимое вкладок
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Вкладка Активность
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _activityList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 80,
                                    color: Colors.grey.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Нет данных за ${DateFormat('dd.MM.yyyy').format(_selectedDate)}',
                                    style: Theme.of(context).textTheme.headlineSmall,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _activityList.length,
                              itemBuilder: (context, index) {
                                final item = _activityList[index];
                                final status = item['status'] ?? 'absent';
                                final statusColor = _getStatusColor(status);
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: statusColor.withOpacity(0.2),
                                      child: Icon(
                                        _getStatusIcon(status),
                                        color: statusColor,
                                      ),
                                    ),
                                    title: Text(
                                      item['full_name'] ?? 'Неизвестно',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getStatusText(status, item),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (status == 'working' || status == 'shift_only') ...[
                                          const SizedBox(height: 4),
                                          if (item['reports_count'] > 0)
                                            Text('Отчётов: ${item['reports_count']}'),
                                          if (item['blanks_taken'] > 0)
                                            Text('Взял заготовок: ${item['blanks_taken']}'),
                                          if (item['items_submitted'] > 0)
                                            Text('Сдал изделий: ${item['items_submitted']}'),
                                          if (item['defect_count'] > 0)
                                            Text(
                                              'Брак: ${item['defect_count']} шт',
                                              style: const TextStyle(color: Colors.orange),
                                            ),
                                          if (item['work_hours'] > 0)
                                            Text(
                                              'Время работы: ${item['work_hours']} ч',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                        ],
                                        if (status == 'time_off') ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'С ${DateFormat('dd.MM.yyyy').format(DateTime.parse(item['time_off_start']))} по ${DateFormat('dd.MM.yyyy').format(DateTime.parse(item['time_off_end']))}',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                        ],
                                      ],
                                    ),
                                    isThreeLine: true,
                                  ),
                                );
                              },
                            ),
                ),
                
                // Вкладка Отпуска/Больничные
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _timeOffList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.event_busy,
                                    size: 80,
                                    color: Colors.grey.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Нет запланированных отпусков/больничных',
                                    style: Theme.of(context).textTheme.headlineSmall,
                                  ),
                                  if (canEdit) ...[
                                    const SizedBox(height: 8),
                                    const Text('Нажмите "Отпуск/Больничный" чтобы создать'),
                                  ],
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _timeOffList.length,
                              itemBuilder: (context, index) {
                                final timeOff = _timeOffList[index];
                                final isVacation = timeOff['type'] == 'vacation';
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isVacation 
                                          ? Colors.blue 
                                          : Colors.red,
                                      child: Icon(
                                        isVacation 
                                            ? Icons.beach_access 
                                            : Icons.local_hospital,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(
                                      timeOff['full_name'] ?? 'Неизвестно',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Логин: ${timeOff['login'] ?? 'Не указан'}'),
                                        Text(
                                          'Тип: ${isVacation ? "Отпуск" : "Больничный"}',
                                          style: TextStyle(
                                            color: isVacation ? Colors.blue : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Период: ${DateFormat('dd.MM.yyyy').format(DateTime.parse(timeOff['start_date']))} - ${DateFormat('dd.MM.yyyy').format(DateTime.parse(timeOff['end_date']))}',
                                        ),
                                      ],
                                    ),
                                    trailing: canEdit
                                        ? IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () {
                                              _showDeleteConfirmation(
                                                timeOff['id'],
                                                timeOff['full_name'] ?? 'Неизвестно',
                                                isVacation ? 'отпуск' : 'больничный',
                                              );
                                            },
                                          )
                                        : null,
                                    isThreeLine: true,
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
