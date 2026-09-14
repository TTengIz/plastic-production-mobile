import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import '../services/media_service.dart';
import '../services/auth_service.dart';
import '../services/role_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

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
  List<Map<String, dynamic>> _mediaFiles = [];
  String _selectedCategory = 'training';
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _roleService = RoleService(_authService);
    _loadMedia();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('http://api.crystal-box.ru/API/media/get_media.php?category=$_selectedCategory'),
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _mediaFiles = List<Map<String, dynamic>>.from(data['media']);
          });
        }
      }
    } catch (e) {
      print('Ошибка загрузки медиа: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _showUploadOptions() {
    final user = _authService.user;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Загрузить фото'),
              onTap: () async {
                Navigator.pop(context);
                await _uploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Выбрать фото из галереи'),
              onTap: () async {
                Navigator.pop(context);
                await _uploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Загрузить видео'),
              onTap: () async {
                Navigator.pop(context);
                await _uploadVideo();
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
    );

    if (mounted) setState(() => _isLoading = false);

    if (mounted) {
      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл загружен'), backgroundColor: Colors.green),
        );
        await _loadMedia();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result?['message'] ?? 'Ошибка загрузки'), backgroundColor: Colors.red),
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
    );

    if (mounted) setState(() => _isLoading = false);

    if (mounted) {
      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Видео загружено'), backgroundColor: Colors.green),
        );
        await _loadMedia();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result?['message'] ?? 'Ошибка загрузки'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ===== НОВОЕ: удаление файла с подтверждением =====
  Future<void> _confirmDeleteMedia(Map<String, dynamic> media) async {
    final mediaId = int.tryParse(media['id'].toString()) ?? 0;
    final fileName = media['file_name'] ?? 'файл';

    if (mediaId <= 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить файл?'),
        content: Text('«$fileName» будет удалён с сервера и из облака. Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (mounted) setState(() => _isLoading = true);

    final result = await _mediaService.deleteMedia(mediaId: mediaId);

    if (mounted) setState(() => _isLoading = false);

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл удалён'), backgroundColor: Colors.green),
        );
        await _loadMedia();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? result['error'] ?? 'Ошибка удаления'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showMediaViewer(Map<String, dynamic> media) async {
    String fileUrl = media['file_url'] ?? '';
    final fileType = media['file_type'] ?? '';
    final fileName = media['file_name'] ?? '';

    print('🎬 Открываем: $fileName');
    print('🔗 URL: $fileUrl');
    print('️ Тип: $fileType');

    // Определяем видео по расширению ИЛИ по типу
    final isVideo = fileType.startsWith('video/') ||
        fileName.toLowerCase().endsWith('.mp4') ||
        fileName.toLowerCase().endsWith('.avi') ||
        fileName.toLowerCase().endsWith('.mov') ||
        fileName.toLowerCase().endsWith('.mkv');

    print('🎥 Это видео: $isVideo');

    if (isVideo) {
      // Для видео - используем прокси
      final cleanFileName = fileUrl.split('/').last.split('?').first;
      final proxyUrl = 'http://api.crystal-box.ru/API/media/proxy.php?file=$cleanFileName';
      print('🎥 Proxy URL: $proxyUrl');

      await _videoController?.dispose();

      _videoController = VideoPlayerController.networkUrl(Uri.parse(proxyUrl));
      await _videoController!.initialize();

      if (mounted) {
        setState(() {});

        showDialog(
          context: context,
          builder: (context) => Dialog(
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
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
                VideoProgressIndicator(
                  _videoController!,
                  allowScrubbing: true,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _videoController!.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
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
      // Для фото
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(fileName),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
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

  @override
  Widget build(BuildContext context) {
    final canEdit = _roleService.isAdmin || _roleService.isManager;

    return Scaffold(
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: _showUploadOptions,
              icon: const Icon(Icons.upload),
              label: const Text('Загрузить'),
            )
          : null,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            child: Row(
              children: [
                Expanded(
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
                      });
                      _loadMedia();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadMedia,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _mediaFiles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open, size: 80, color: Colors.grey.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              Text('Нет файлов', style: Theme.of(context).textTheme.headlineSmall),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _mediaFiles.length,
                          itemBuilder: (context, index) {
                            final media = _mediaFiles[index];
                            final isVideo = (media['file_type'] ?? '').toString().startsWith('video/');

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isVideo ? Colors.purple : Colors.blue,
                                  child: Icon(
                                    isVideo ? Icons.videocam : Icons.image,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  media['file_name'] ?? 'Без названия',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('Тип: ${media['file_type']}'),
                                // ===== ИЗМЕНЕНО: кнопка просмотра + кнопка удаления =====
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
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}