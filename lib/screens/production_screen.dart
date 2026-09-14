import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/production_service.dart';
import '../services/recipes_service.dart';
import '../services/blanks_service.dart';
import '../services/auth_service.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  final _productionService = ProductionService();
  final _recipesService = RecipesService();
  final _blanksService = BlanksService();
  final _authService = AuthService();
  
  bool _isLoading = false;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _blanks = [];

  // Этап 1: выбор заготовки
  int? _selectedRecipeId;
  final _blanksTakenController = TextEditingController();
  
  // Этап 2: работа (таймер)
  bool _isWorking = false;
  DateTime? _startTime;
  Timer? _timer;
  String _elapsedTime = '00:00:00';
  
  // Этап 3: сдача
  final _itemsSubmittedController = TextEditingController();
  String _defectReason = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _blanksTakenController.dispose();
    _itemsSubmittedController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    
    final results = await Future.wait([
      _recipesService.getRecipes(),
      _blanksService.getBlanks(),
    ]);
    
    _recipes = results[0];
    _blanks = results[1];
    
    final user = _authService.user;
    _reports = await _productionService.getReports(userId: user?['id']);
    
    if (mounted) setState(() => _isLoading = false);
  }

  int _getAvailableBlanks(int recipeId) {
    final blank = _blanks.firstWhere((b) => b['recipe_id'] == recipeId, orElse: () => {});
    return blank['quantity'] ?? 0;
  }

  void _startWork() {
    final blanksTaken = int.tryParse(_blanksTakenController.text);
    
    if (_selectedRecipeId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите заготовку')),
        );
      }
      return;
    }

    if (blanksTaken == null || blanksTaken < 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите количество')),
        );
      }
      return;
    }

    final available = _getAvailableBlanks(_selectedRecipeId!);
    if (blanksTaken > available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Недостаточно заготовок. Доступно: $available')),
        );
      }
      return;
    }

    // Запускаем таймер
    setState(() {
      _isWorking = true;
      _startTime = DateTime.now();
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null && mounted) {
        final elapsed = DateTime.now().difference(_startTime!);
        final hours = elapsed.inHours.toString().padLeft(2, '0');
        final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
        setState(() {
          _elapsedTime = '$hours:$minutes:$seconds';
        });
      }
    });
  }

  void _cancelWork() {
    _timer?.cancel();
    setState(() {
      _isWorking = false;
      _startTime = null;
      _elapsedTime = '00:00:00';
      _selectedRecipeId = null;
      _blanksTakenController.clear();
      _itemsSubmittedController.clear();
      _defectReason = '';
    });
  }

  void _submitItems() {
    final blanksTaken = int.tryParse(_blanksTakenController.text);
    final itemsSubmitted = int.tryParse(_itemsSubmittedController.text);
    
    if (itemsSubmitted == null || itemsSubmitted < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите количество сданных изделий')),
        );
      }
      return;
    }

    if (itemsSubmitted > blanksTaken!) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нельзя сдать больше чем взяли')),
        );
      }
      return;
    }

    final defectCount = blanksTaken - itemsSubmitted;

    // Если есть брак, запрашиваем причину
    if (defectCount > 0 && _defectReason.isEmpty) {
      _showDefectReasonDialog(defectCount);
      return;
    }

    _doSubmit();
  }

  void _showDefectReasonDialog(int defectCount) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Причина брака'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Не хватает $defectCount шт изделий'),
            const SizedBox(height: 12),
            const Text('Укажите причину:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Причина брака',
                border: OutlineInputBorder(),
                hintText: 'Например: трещина, скол, деформация...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() {
                _defectReason = reasonController.text.trim();
              });
              _doSubmit();
            },
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
  }

  Future<void> _doSubmit() async {
    final user = _authService.user;
    if (user == null || _selectedRecipeId == null || _startTime == null) return;

    final blanksTaken = int.tryParse(_blanksTakenController.text);
    final itemsSubmitted = int.tryParse(_itemsSubmittedController.text);
    
    if (blanksTaken == null || itemsSubmitted == null) return;

    // 🆕 Получаем название изделия из выбранного рецепта
    final selectedRecipe = _recipes.firstWhere((r) => r['id'] == _selectedRecipeId);
    final productName = selectedRecipe['blank_name'] ?? 'Неизвестное изделие';

    if (mounted) setState(() => _isSubmitting = true);

    final result = await _productionService.submitReport(
      userId: user['id'],
      recipeId: _selectedRecipeId!,
      blanksTaken: blanksTaken,
      itemsSubmitted: itemsSubmitted,
      productName: productName, // 🆕 Передаём название изделия
      startTime: _startTime!.toIso8601String(),
      defectReason: _defectReason.isNotEmpty ? _defectReason : null,
    );

    _timer?.cancel();
    if (mounted) setState(() => _isSubmitting = false);

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Отчёт сохранён'),
            backgroundColor: Colors.green,
          ),
        );
        _cancelWork();
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Ошибка'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'Не указано';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('dd.MM.yyyy HH:mm').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _calculateDuration(String? startTime, String? endTime) {
    if (startTime == null) return '0ч 0м';
    try {
      final start = DateTime.parse(startTime);
      final end = endTime != null ? DateTime.parse(endTime) : DateTime.now();
      final duration = end.difference(start);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '${hours}ч ${minutes}м';
    } catch (e) {
      return '0ч 0м';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Карточка производства
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.factory, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Производство',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Этап 1: Взять заготовки (если не работаем)
                          if (!_isWorking) ...[
                            const Text(
                              'Шаг 1: Выберите заготовку',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'Заготовка',
                                border: OutlineInputBorder(),
                              ),
                              items: _recipes.map((recipe) {
                                final available = _getAvailableBlanks(recipe['id']);
                                return DropdownMenuItem<int>(
                                  value: recipe['id'],
                                  child: Text(
                                    '${recipe['blank_name']} (${recipe['material_name']}, ${recipe['thickness']}) - доступно: $available',
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedRecipeId = value;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            if (_selectedRecipeId != null) ...[
                              TextField(
                                controller: _blanksTakenController,
                                decoration: InputDecoration(
                                  labelText: 'Сколько взять?',
                                  border: const OutlineInputBorder(),
                                  helperText: 'Доступно: ${_getAvailableBlanks(_selectedRecipeId!)}',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _startWork,
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Взять и начать работу'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ]

                          // Этап 2: Работа (таймер)
                          else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.timer, color: Colors.green[700], size: 32),
                                      const SizedBox(width: 8),
                                      Text(
                                        _elapsedTime,
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700],
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Builder(
                                    builder: (context) {
                                      final recipe = _recipes.firstWhere((r) => r['id'] == _selectedRecipeId);
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Заготовка: ${recipe['blank_name']}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          Text('Взято: ${_blanksTakenController.text} шт'),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Шаг 2: Сдайте готовые изделия',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _itemsSubmittedController,
                              decoration: InputDecoration(
                                labelText: 'Сколько сдаёте?',
                                border: const OutlineInputBorder(),
                                helperText: 'Взяли: ${_blanksTakenController.text} шт',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            Builder(
                              builder: (context) {
                                final blanksTaken = int.tryParse(_blanksTakenController.text) ?? 0;
                                final itemsSubmitted = int.tryParse(_itemsSubmittedController.text) ?? 0;
                                final defectCount = blanksTaken - itemsSubmitted;
                                
                                if (itemsSubmitted > 0 && defectCount > 0) {
                                  return Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Брак: $defectCount шт',
                                      style: TextStyle(
                                        color: Colors.orange[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _isSubmitting ? null : _cancelWork,
                                    icon: const Icon(Icons.cancel),
                                    label: const Text('Отмена'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isSubmitting ? null : _submitItems,
                                    icon: _isSubmitting
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.check),
                                    label: const Text('Сдать'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // История отчётов
                  Row(
                    children: [
                      Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'История производства',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_reports.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Нет отчётов',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  else
                    ..._reports.take(10).map((report) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: (report['defect_count'] ?? 0) > 0
                                  ? Colors.orange
                                  : Colors.green,
                              child: Icon(
                                (report['defect_count'] ?? 0) > 0
                                    ? Icons.warning
                                    : Icons.check,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(report['blank_name'] ?? 'Без названия'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Взял: ${report['blanks_taken']} шт'),
                                Text('Сдал: ${report['items_submitted']} шт'),
                                Text('Время работы: ${_calculateDuration(report['start_time'], report['end_time'])}'),
                                if ((report['defect_count'] ?? 0) > 0)
                                  Text(
                                    'Брак: ${report['defect_count']} шт',
                                    style: const TextStyle(color: Colors.orange),
                                  ),
                                if (report['defect_reason'] != null && report['defect_reason'].toString().isNotEmpty)
                                  Text(
                                    'Причина: ${report['defect_reason']}',
                                    style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
                                  ),
                                Text(
                                  _formatDateTime(report['start_time']),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        )),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
