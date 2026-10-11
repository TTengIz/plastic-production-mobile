import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import '../services/media_service.dart';
import '../services/auth_service.dart';
import '../services/role_service.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final _mediaService = MediaService();
  final _authService = AuthService();
  late final RoleService _roleService;

  bool _isLoading = false;
  String _selectedCategory = 'training';

  // === Папки ===
  List<Map<String, dynamic>> _folders = [];
  int? _currentFolderId; // null = корень раздела
  String? _currentFolderName;

  // === Файлы ===
  List<Map<String, dynamic>> _mediaFiles = [];

  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _roleService = RoleService(_authService);
    _loadAll();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (mounted) setState(() => _isLoading = true);

    if (_currentFolderId == null) {
      // В корне: папки + файлы БЕЗ папки
      final results = await Future.wait([
        _mediaService.getFolders(category: _selectedCategory),
        _mediaService.getMedia(category: _selectedCategory),
      ]);
      _folders = results[0];
      _mediaFiles = results[1];
    } else {
      // Внутри папки: подпапки + файлы этой папки
      final results = await Future.wait([
        _mediaService.getFolders(category: _selectedCategory, parentId: _currentFolderId),
        _mediaService.getMedia(category: _selectedCategory, folderId: _currentFolderId),
      ]);
      _folders = results[0];
      _mediaFiles = results[1];
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _enterFolder(Map<String, dynamic> folder) {
    setState(() {
      _currentFolderId = int.tryParse(folder['id'].toString());
      _currentFolderName = folder['name']?.toString() ?? 'Папка';
      _mediaFiles = [];
    });
    _loadAll();
  }

  void _exitFolder() {
    setState(() {
      _currentFolderId = null;
      _currentFolderName = null;
    });
    _loadAll();
  }

  // === Загрузка ===

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _currentFolderId == null
                    ? 'Загрузить в раздел'
                    : 'Загрузить в папку «$_currentFolderName»',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Сделать фото'),
              onTap: () {
                Navigator.pop(context);
                _uploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Выбрать фото из галереи'),
              onTap: () {
                Navigator.pop(context);
                _uploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Загрузить видео'),
              onTap: () {
                Navigator.pop(context);
                _uploadVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadImage(ImageSource source) async {
    final user = _authService.user;
    if (user == null) return;

    if (mounted) setState(() => _isLoading = true);

    final result = await _mediaService.pickAndUploadImage(
      category: _selectedCategory,
      uploadedBy: user['id'],
      source: source,
      folderId: _currentFolderId,
    );

    if (mounted) setState(() => _isLoading = false);

    if (mounted) {
      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл загружен'), backgroundColor: Colors.green),
        );
        await _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result?['error'] ?? result?['message'] ?? 'Ошибка загрузки'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadVideo() async {
    final user = _authService.user;
    if (user == null) return;

    if (mounted) setState(() => _isLoading = true);

    final result = await _mediaService.pickAndUploadVideo(
      category: _selectedCategory,
      uploadedBy: user['id'],
      folderId: _currentFolderId,
    );

    if (mounted) setState(() => _isLoading = false);

    if (mounted) {
      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Видео загружено'), backgroundColor: Colors.green),
        );
        await _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result?['error'] ?? result?['message'] ?? 'Ошибка загрузки'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // === Создание папки ===

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_currentFolderId == null ? 'Новая папка' : 'Новая подпапка'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Название',
            hintText: _currentFolderId == null
                ? 'Например: Термопластавтоматы'
                : 'Внутри «$_currentFolderName»',
            border: const OutlineInputBorder(),
          ),
          maxLength: 100,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    setState(() => _isLoading = true);
    final response = await _mediaService.createFolder(
      name: result,
      category: _selectedCategory,
      parentId: _currentFolderId, // <-- ВОТ ЭТО БЫЛО ПРОПУЩЕНО!
    );
    setState(() => _isLoading = false);

    if (mounted) {
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Папка создана'), backgroundColor: Colors.green),
        );
        await _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? response['message'] ?? 'Ошибка создания'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // === Удаление папки ===

  Future<void> _confirmDeleteFolder(Map<String, dynamic> folder) async {
    final id = int.tryParse(folder['id'].toString()) ?? 0;
    final name = folder['name']?.toString() ?? 'Папка';
    final count = int.tryParse(folder['files_count'].toString()) ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить папку?'),
        content: Text(
          count > 0
              ? 'Удалить папку «$name»? Файлы из неё ($count шт.) вернутся в раздел без папки.'
              : 'Удалить пустую папку «$name»?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true || id <= 0) return;

    setState(() => _isLoading = true);
    final result = await _mediaService.deleteFolder(folderId: id);
    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Папка удалена'), backgroundColor: Colors.green),
        );
        await _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? result['message'] ?? 'Ошибка удаления'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // === Удаление файла ===

  Future<void> _confirmDeleteMedia(Map<String, dynamic> media) async {
    final mediaId = int.tryParse(media['id'].toString()) ?? 0;
    final fileName = media['file_name'] ?? 'файл';
    if (mediaId <= 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить файл?'),
        content: Text('«$fileName» будет удалён с сервера и из облака. Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final result = await _mediaService.deleteMedia(mediaId: mediaId);
    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл удалён'), backgroundColor: Colors.green),
        );
        await _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? result['message'] ?? 'Ошибка удаления'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // === Просмотр ===

  Future<void> _showMediaViewer(Map<String, dynamic> media) async {
    final fileUrl = media['file_url']?.toString() ?? '';
    final fileType = media['file_type']?.toString() ?? '';
    final fileName = media['file_name']?.toString() ?? '';

    final isVideo = fileType.startsWith('video/') ||
        fileName.toLowerCase().endsWith('.mp4') ||
        fileName.toLowerCase().endsWith('.avi') ||
        fileName.toLowerCase().endsWith('.mov') ||
        fileName.toLowerCase().endsWith('.mkv');

    if (isVideo) {
      final cleanFileName = fileUrl.split('/').last.split('?').first;
      final proxyUrl = 'http://api.crystal-box.ru/API/media/proxy.php?file=$cleanFileName';

      await _videoController?.dispose();
      _videoController = VideoPlayerController.networkUrl(Uri.parse(proxyUrl));
      await _videoController!.initialize();

      if (mounted) {
        setState(() {});
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(fileName),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _videoController?.pause();
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
                VideoProgressIndicator(_videoController!, allowScrubbing: true),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                      onPressed: () {
                        setState(() {
                          _videoController!.value.isPlaying
                              ? _videoController!.pause()
                              : _videoController!.play();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(fileName),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                InteractiveViewer(
                  child: Image.network(fileUrl, fit: BoxFit.contain),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  // === UI helpers ===

  String _categoryTitle(String c) {
    switch (c) {
      case 'training':
        return 'Обучение';
      case 'products':
        return 'Изделия';
      case 'other':
        return 'Другое';
      default:
        return c;
    }
  }

  Widget _buildFolderTile(Map<String, dynamic> folder) {
    final canEdit = _roleService.isAdmin || _roleService.isManager;
    final name = folder['name']?.toString() ?? 'Папка';
    final count = int.tryParse(folder['files_count'].toString()) ?? 0;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.amber.shade100,
          child: const Icon(Icons.folder, color: Colors.amber),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$count ${_pluralFiles(count)}'),
        trailing: canEdit
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDeleteFolder(folder),
              )
            : null,
        onTap: () => _enterFolder(folder),
      ),
    );
  }

  String _pluralFiles(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'файл';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return 'файла';
    return 'файлов';
  }

  Widget _buildFileTile(Map<String, dynamic> media) {
    final canEdit = _roleService.isAdmin || _roleService.isManager;
    final fileType = media['file_type']?.toString() ?? '';
    final isVideo = fileType.startsWith('video/');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isVideo ? Colors.purple : Colors.blue,
          child: Icon(isVideo ? Icons.videocam : Icons.image, color: Colors.white),
        ),
        title: Text(
          media['file_name']?.toString() ?? 'Без названия',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Тип: $fileType'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility, color: Colors.blue),
              onPressed: () => _showMediaViewer(media),
            ),
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDeleteMedia(media),
              ),
          ],
        ),
        onTap: () => _showMediaViewer(media),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _roleService.isAdmin || _roleService.isManager;
    final inFolder = _currentFolderId != null;

    return Scaffold(
      appBar: inFolder
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _exitFolder,
              ),
              title: Text(_currentFolderName ?? 'Папка'),
            )
          : null,
      floatingActionButton: canEdit
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!inFolder || _selectedCategory == 'training') ...[
                  FloatingActionButton(
                    heroTag: 'add_folder',
                    onPressed: _showCreateFolderDialog,
                    child: const Icon(Icons.create_new_folder),
                  ),
                  const SizedBox(height: 12),
                ],
                FloatingActionButton.extended(
                  heroTag: 'upload',
                  onPressed: _showUploadOptions,
                  icon: const Icon(Icons.upload),
                  label: const Text('Загрузить'),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          // Переключатель категорий (только в корне)
          if (!inFolder)
            Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'training', label: Text('Обучение')),
                  ButtonSegment(value: 'products', label: Text('Изделия')),
                  ButtonSegment(value: 'other', label: Text('Другое')),
                ],
                selected: {_selectedCategory},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _selectedCategory = newSelection.first;
                    _currentFolderId = null; // Сброс при смене раздела
                    _currentFolderName = null;
                  });
                  _loadAll();
                },
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAll,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _folders.isEmpty && _mediaFiles.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Column(
                                children: [
                                  Icon(
                                    inFolder ? Icons.folder_open : Icons.folder_open,
                                    size: 80,
                                    color: Colors.grey.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    inFolder ? 'В папке пока пусто' : 'Нет файлов и папок',
                                    style: Theme.of(context).textTheme.headlineSmall,
                                  ),
                                  if (!inFolder)
                                    Text(
                                      'Раздел: ${_categoryTitle(_selectedCategory)}',
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // === Папки (в корне или подпапки внутри папки) ===
                            if (_folders.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.folder, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      inFolder ? 'Подпапки' : 'Папки',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                              ..._folders.map(_buildFolderTile),
                              const SizedBox(height: 16),
                            ],

                            // === В корне: секция "Без папки" (если есть файлы) ===
                            if (!inFolder && _mediaFiles.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.video_library, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Без папки',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // === Файлы (в корне — без папки; внутри — только этой папки) ===
                            if (_mediaFiles.isNotEmpty) ...[
                              if (inFolder) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.video_library, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Файлы',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              ..._mediaFiles.map(_buildFileTile),
                            ],
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}