import 'package:flutter/material.dart';
import '../services/recipes_service.dart';
import '../services/materials_service.dart';
import '../services/role_service.dart';
import '../services/auth_service.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _recipesService = RecipesService();
  final _materialsService = MaterialsService();
  final _authService = AuthService();
  late final RoleService _roleService;
  bool _isLoading = false;
  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _materials = [];

  @override
  void initState() {
    super.initState();
    _roleService = RoleService(_authService);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _recipes = await _recipesService.getRecipes();
    _materials = await _materialsService.getMaterials();
    if (mounted) setState(() => _isLoading = false);
  }

  void _showAddRecipeDialog() {
    final blankNameController = TextEditingController();
    final blanksPerSheetController = TextEditingController(text: '1');
    final rivetsPerItemController = TextEditingController(text: '0');
    int? selectedMaterialId;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Добавить рецепт'),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setDialogState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: blankNameController,
                  decoration: const InputDecoration(
                    labelText: 'Название заготовки *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Материал *',
                    border: OutlineInputBorder(),
                  ),
                  items: _materials.map((material) {
                    return DropdownMenuItem<int>(
                      value: material['id'],
                      child: Text('${material['name']} (${material['thickness'] ?? 'толщина не указана'})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedMaterialId = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: blanksPerSheetController,
                  decoration: const InputDecoration(
                    labelText: 'Заготовок из листа *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rivetsPerItemController,
                  decoration: const InputDecoration(
                    labelText: 'Клёпок в изделии',
                    border: OutlineInputBorder(),
                    helperText: 'Количество клёпок на одно изделие',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (blankNameController.text.isEmpty) {
                Navigator.pop(dialogContext);
                await Future.delayed(const Duration(milliseconds: 300));
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Введите название заготовки')),
                  );
                }
                return;
              }

              if (selectedMaterialId == null) {
                Navigator.pop(dialogContext);
                await Future.delayed(const Duration(milliseconds: 300));
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Выберите материал')),
                  );
                }
                return;
              }

              final blanksPerSheet = int.tryParse(blanksPerSheetController.text);
              if (blanksPerSheet == null || blanksPerSheet < 1) {
                Navigator.pop(dialogContext);
                await Future.delayed(const Duration(milliseconds: 300));
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Количество должно быть больше 0')),
                  );
                }
                return;
              }

              final rivetsPerItem = int.tryParse(rivetsPerItemController.text) ?? 0;

              Navigator.pop(dialogContext);
              await Future.delayed(const Duration(milliseconds: 300));

              if (!mounted) return;
              setState(() => _isLoading = true);

              final success = await _recipesService.addRecipe(
                blankName: blankNameController.text.trim(),
                materialId: selectedMaterialId!,
                blanksPerSheet: blanksPerSheet,
                rivetsPerItem: rivetsPerItem,
              );

              if (!mounted) return;
              setState(() => _isLoading = false);

              if (success) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Рецепт добавлен'),
                    backgroundColor: Colors.green,
                  ),
                );
                await _loadData();
              } else {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Ошибка добавления'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _showEditRecipeDialog(Map<String, dynamic> recipe) {
    final blankNameController = TextEditingController(text: recipe['blank_name']);
    final blanksPerSheetController = TextEditingController(text: recipe['blanks_per_sheet']?.toString() ?? '1');
    final rivetsPerItemController = TextEditingController(text: recipe['rivets_per_item']?.toString() ?? '0');
    int? selectedMaterialId = recipe['material_id'];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Редактировать рецепт'),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setDialogState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: blankNameController,
                  decoration: const InputDecoration(
                    labelText: 'Название заготовки',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedMaterialId,
                  decoration: const InputDecoration(
                    labelText: 'Материал',
                    border: OutlineInputBorder(),
                  ),
                  items: _materials.map((material) {
                    return DropdownMenuItem<int>(
                      value: material['id'],
                      child: Text('${material['name']} (${material['thickness'] ?? 'толщина не указана'})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedMaterialId = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: blanksPerSheetController,
                  decoration: const InputDecoration(
                    labelText: 'Заготовок из листа',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rivetsPerItemController,
                  decoration: const InputDecoration(
                    labelText: 'Клёпок в изделии',
                    border: OutlineInputBorder(),
                    helperText: 'Количество клёпок на одно изделие',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await Future.delayed(const Duration(milliseconds: 300));

              if (!mounted) return;
              setState(() => _isLoading = true);

              final success = await _recipesService.updateRecipe(
                recipeId: recipe['id'],
                blankName: blankNameController.text.trim(),
                materialId: selectedMaterialId,
                blanksPerSheet: int.tryParse(blanksPerSheetController.text),
                rivetsPerItem: int.tryParse(rivetsPerItemController.text),
              );

              if (!mounted) return;
              setState(() => _isLoading = false);

              if (success) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Рецепт обновлен'),
                    backgroundColor: Colors.green,
                  ),
                );
                await _loadData();
              } else {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Ошибка обновления'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(int recipeId, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить рецепт'),
        content: Text('Вы уверены, что хотите удалить "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await Future.delayed(const Duration(milliseconds: 300));

              if (!mounted) return;
              setState(() => _isLoading = true);

              final success = await _recipesService.deleteRecipe(recipeId);

              if (!mounted) return;
              setState(() => _isLoading = false);

              if (success) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Рецепт удален'),
                    backgroundColor: Colors.green,
                  ),
                );
                await _loadData();
              } else {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Ошибка удаления'),
                    backgroundColor: Colors.red,
                  ),
                );
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
    final canEdit = _roleService.isAdmin || _roleService.isManager;

    return Scaffold(
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: _showAddRecipeDialog,
              icon: const Icon(Icons.add),
              label: const Text('Добавить'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _recipes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 80,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Нет рецептов',
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
                    itemCount: _recipes.length,
                    itemBuilder: (context, index) {
                      final recipe = _recipes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(
                              Icons.restaurant_menu,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            recipe['blank_name'] ?? 'Без названия',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Материал: ${recipe['material_name'] ?? 'Не указан'}'),
                              if (recipe['thickness'] != null && recipe['thickness'].toString().isNotEmpty)
                                Text('Толщина: ${recipe['thickness']}'),
                              Text(
                                'Заготовок из листа: ${recipe['blanks_per_sheet'] ?? 0}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (recipe['rivets_per_item'] != null && recipe['rivets_per_item'] > 0)
                                Text(
                                  'Клёпок в изделии: ${recipe['rivets_per_item']}',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          trailing: canEdit
                              ? PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showEditRecipeDialog(recipe);
                                    } else if (value == 'delete') {
                                      _showDeleteConfirmation(recipe['id'], recipe['blank_name']);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 20),
                                          SizedBox(width: 8),
                                          Text('Редактировать'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Удалить', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
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
