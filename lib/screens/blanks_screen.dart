import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/blanks_service.dart';
import '../services/recipes_service.dart';
import '../services/auth_service.dart';
import '../services/role_service.dart';

class BlanksScreen extends StatefulWidget {
  const BlanksScreen({super.key});

  @override
  State<BlanksScreen> createState() => _BlanksScreenState();
}

class _BlanksScreenState extends State<BlanksScreen> {
  final _blanksService = BlanksService();
  final _recipesService = RecipesService();
  final _authService = AuthService();
  late final RoleService _roleService;
  bool _isLoading = false;
  List<Map<String, dynamic>> _blanks = [];
  List<Map<String, dynamic>> _recipes = [];

  @override
  void initState() {
    super.initState();
    _roleService = RoleService(_authService);
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    _blanks = await _blanksService.getBlanks();
    _recipes = await _recipesService.getRecipes();
    if (mounted) setState(() => _isLoading = false);
  }

  void _showAddBlanksDialog() {
    final quantityController = TextEditingController(text: '1');
    int? selectedRecipeId;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Добавить заготовки'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Выберите заготовку *',
                    border: OutlineInputBorder(),
                  ),
                  items: _recipes.map((recipe) {
                    return DropdownMenuItem<int>(
                      value: recipe['id'],
                      child: Text(
                        '${recipe['blank_name']} (${recipe['material_name']}, ${recipe['thickness']})',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedRecipeId = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Количество *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setDialogState(() {});
                  },
                ),
                if (selectedRecipeId != null) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final recipe = _recipes.firstWhere((r) => r['id'] == selectedRecipeId);
                      final blanksPerSheet = recipe['blanks_per_sheet'] ?? 1;
                      final quantity = int.tryParse(quantityController.text) ?? 0;
                      final sheetsNeeded = blanksPerSheet > 0 ? (quantity / blanksPerSheet).ceil() : 0;
                      
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Расчёт материалов:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Заготовок в листе: $blanksPerSheet'),
                            Text('Нужно листов: $sheetsNeeded'),
                          ],
                        ),
                      );
                    },
                  ),
                ],
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
                if (selectedRecipeId == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Выберите заготовку')),
                    );
                  }
                  return;
                }

                final quantity = int.tryParse(quantityController.text);
                if (quantity == null || quantity < 1) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Введите количество')),
                    );
                  }
                  return;
                }

                Navigator.pop(dialogContext);
                
                final user = _authService.user;
                if (user == null) return;

                if (mounted) setState(() => _isLoading = true);

                final result = await _blanksService.addBlanks(
                  recipeId: selectedRecipeId!,
                  quantity: quantity,
                  userId: user['id'],
                );

                if (mounted) setState(() => _isLoading = false);

                if (mounted) {
                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Заготовки добавлены'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await _loadData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Ошибка добавления'),
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

  void _showEditBlanksDialog(Map<String, dynamic> blank) {
    final currentQuantity = blank['quantity'] ?? 0;
    final addController = TextEditingController();
    final blanksPerSheet = blank['blanks_per_sheet'] ?? 1;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Добавить заготовки'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Заготовка: ${blank['blank_name']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Текущее количество: $currentQuantity шт'),
                      Text('Заготовок в листе: $blanksPerSheet'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addController,
                  decoration: const InputDecoration(
                    labelText: 'Сколько добавить? *',
                    border: OutlineInputBorder(),
                    helperText: 'Введите количество для добавления',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setDialogState(() {});
                  },
                ),
                Builder(
                  builder: (context) {
                    final addQuantity = int.tryParse(addController.text) ?? 0;
                    
                    if (addQuantity > 0) {
                      final additionalSheets = blanksPerSheet > 0 ? (addQuantity / blanksPerSheet).ceil() : 0;
                      final newTotal = currentQuantity + addQuantity;
                      return Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Будет добавлено:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Добавка: +$addQuantity шт'),
                            Text('Доп. листов: $additionalSheets'),
                            const Divider(),
                            Text(
                              'Итого станет: $newTotal шт',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    } else if (addQuantity < 0) {
                      return Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Нельзя добавить отрицательное число!',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
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
                final addQuantity = int.tryParse(addController.text);
                
                if (addQuantity == null || addQuantity < 1) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Введите количество для добавления')),
                    );
                  }
                  return;
                }

                Navigator.pop(dialogContext);
                if (mounted) setState(() => _isLoading = true);

                final newTotal = currentQuantity + addQuantity;

                final result = await _blanksService.updateBlanks(
                  blankId: blank['id'],
                  newQuantity: newTotal,
                );

                if (mounted) setState(() => _isLoading = false);

                if (mounted) {
                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Добавлено $addQuantity шт'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await _loadData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Ошибка добавления'),
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

  void _showDeleteConfirmation(int blankId, String blankName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить заготовку'),
        content: Text('Вы уверены, что хотите удалить "$blankName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (mounted) setState(() => _isLoading = true);

              final success = await _blanksService.deleteBlanks(blankId);

              if (mounted) setState(() => _isLoading = false);

              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Заготовка удалена'),
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

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'Не указано';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('dd.MM.yyyy HH:mm').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _roleService.isAdmin || _roleService.isManager;

    return Scaffold(
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: _showAddBlanksDialog,
              icon: const Icon(Icons.add),
              label: const Text('Добавить'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _blanks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.storage,
                          size: 80,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Нет заготовок',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (canEdit) ...[
                          const SizedBox(height: 8),
                          const Text('Нажмите "Добавить" чтобы создать'),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _blanks.length,
                    itemBuilder: (context, index) {
                      final blank = _blanks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(
                              Icons.storage,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            blank['blank_name'] ?? 'Без названия',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Материал: ${blank['material_name'] ?? 'Не указан'}'),
                              if (blank['thickness'] != null && blank['thickness'].toString().isNotEmpty)
                                Text('Толщина: ${blank['thickness']}'),
                              Text(
                                'Количество: ${blank['quantity'] ?? 0} шт',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Списано листов: ${blank['sheets_used'] ?? 0}',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (blank['added_by_name'] != null)
                                Text('Добавил: ${blank['added_by_name']}'),
                              Text('Дата: ${_formatDateTime(blank['created_at'])}'),
                            ],
                          ),
                          trailing: canEdit
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _showEditBlanksDialog(blank),
                                      tooltip: 'Добавить количество',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        _showDeleteConfirmation(
                                          blank['id'],
                                          blank['blank_name'] ?? 'заготовку',
                                        );
                                      },
                                      tooltip: 'Удалить',
                                    ),
                                  ],
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
