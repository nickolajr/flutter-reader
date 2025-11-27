import 'package:flutter/material.dart';
import '../services/manhwa_service.dart';
import '../services/api_service.dart'; // Add this import
import '../models/manwha.dart';
import 'manhwa_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Manhwa> manhwas = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String _syncProgress = '';
  @override
  void initState() {
    super.initState();
    _initializeLibrary();
  }

  Future<void> _initializeLibrary() async {
    setState(() => _isLoading = true);
    
    try {
      // Initialize API service first
      await ApiService.initialize();
      
      // If logged in, sync with backend first
      if (ApiService.isLoggedIn) {
        setState(() => _isSyncing = true);
        final syncResult = await ApiService.enhancedPullSync();
        if (!syncResult.success) {
          print('Sync failed: ${syncResult.error}');
          // Continue loading local data even if sync fails
        }
        setState(() => _isSyncing = false);
      }
      
      // Then load from local database
      final loadedManhwas = await ManhwaService.getAllManhwa();
      setState(() {
        manhwas = loadedManhwas;
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing library: $e');
      setState(() {
        _isLoading = false;
        _isSyncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load library: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadManhwas() async {
    setState(() => _isLoading = true);
    
    try {
      final loadedManhwas = await ManhwaService.getAllManhwa();
      setState(() {
        manhwas = loadedManhwas;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading manhwas: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load library: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Delete manhwa method - UPDATED to sync with backend
  Future<void> _deleteManhwa(Manhwa manhwa) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text(
          'Remove from Library',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to remove "${manhwa.name}" from your library?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        // Remove from local database
        await ManhwaService.deleteManhwa(manhwa.id);
        
        // If logged in, sync removal with backend
        if (ApiService.isLoggedIn) {
          await ApiService.syncLibrary(remove: [manhwa.id]);
        }
        
        setState(() {
          manhwas.removeWhere((m) => m.id == manhwa.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${manhwa.name}" removed from library'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        print('Error deleting manhwa: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove manhwa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // NEW: Sync with backend method
Future<void> _syncWithBackend() async {
  if (!ApiService.isLoggedIn) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please log in to sync with backend'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  setState(() {
    _isSyncing = true;
    _syncProgress = 'Starting sync...';
  });
  
  try {
    // Step 1: Pull sync data from backend
    setState(() => _syncProgress = 'Downloading sync data...');
    final pullResult = await ApiService.enhancedPullSync();
    
    if (pullResult.success) {
      setState(() => _syncProgress = 'Processing library data...');
      
      // Wait a moment for the background processing
      await Future.delayed(const Duration(seconds: 2));
      
      // Step 2: PUSH local library to backend (THIS IS WHAT YOU'RE MISSING)
      setState(() => _syncProgress = 'Uploading library to backend...');
      final pushResult = await ApiService.enhancedPushSync();
      
      if (pushResult.success) {
        setState(() => _syncProgress = 'Loading updated library...');
        
        // Reload the library to show changes
        await _loadManhwas();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully synced library with backend'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Push sync failed: ${pushResult.error}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pull sync failed: ${pullResult.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sync error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() {
      _isSyncing = false;
      _syncProgress = '';
    });
  }
}

  // Show context menu on right-click/long-press
  void _showContextMenu(Manhwa manhwa, TapDownDetails details) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromSize(
      Rect.fromPoints(
        details.globalPosition,
        details.globalPosition,
      ),
      overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'open',
          child: Row(
            children: [
              Icon(Icons.open_in_new, size: 20),
              SizedBox(width: 8),
              Text('Open'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                'Remove from Library',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'open') {
        _openManhwa(manhwa);
      } else if (value == 'delete') {
        _deleteManhwa(manhwa);
      }
    });
  }

  // Open manhwa method
  void _openManhwa(Manhwa manhwa) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManhwaScreen(
          manhwaId: manhwa.id,
          name: manhwa.name,
          genre: manhwa.genreString,
        ),
      ),
    );
    
    if (result == true) {
      _loadManhwas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // App Bar
        Container(
          height: 56,
          color: const Color(0xFF1a1a1a),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Library',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Sync indicator/button
              if (_isSyncing)
                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6c5ce7),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.sync, color: Colors.white),
                onPressed: _isSyncing ? null : _syncWithBackend,
                tooltip: 'Sync with backend',
              ),
              IconButton(
                icon: const Icon(Icons.sort, color: Colors.white),
                onPressed: _showSortOptions,
                tooltip: 'Sort library',
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadManhwas,
                tooltip: 'Refresh library',
              ),
            ],
          ),
        ),
        Expanded(child: _buildLibraryContent()),
      ],
    );
  }

  Widget _buildLibraryContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF6c5ce7)),
            SizedBox(height: 16),
            Text(
              'Loading library...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (manhwas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Your library is empty',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add some manhwa to get started',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadManhwas,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6c5ce7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Refresh Library',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            if (ApiService.isLoggedIn)
              ElevatedButton.icon(
                onPressed: _syncWithBackend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00b894),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.sync, color: Colors.white),
                label: const Text(
                  'Sync with Backend',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadManhwas,
      backgroundColor: const Color(0xFF2a2a2a),
      color: const Color(0xFF6c5ce7),
      child: _buildLibraryGrid(),
    );
  }

  // Rest of your methods remain the same...
  Widget _buildLibraryGrid() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          mainAxisExtent: 260,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: manhwas.length,
        itemBuilder: (context, index) {
          return _buildManhwaCard(manhwas[index]);
        },
      ),
    );
  }

  Widget _buildManhwaCard(Manhwa manhwa) {
    return GestureDetector(
      onTap: () => _openManhwa(manhwa),
      onLongPress: () => _deleteManhwa(manhwa),
      onSecondaryTapDown: (details) => _showContextMenu(manhwa, details),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: manhwa.coverImageUrl != null
                    ? Image.network(
                        manhwa.coverImageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(manhwa),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.grey[900],
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        },
                      )
                    : _buildPlaceholderImage(manhwa),
              ),
            ),
            // Info Section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      manhwa.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          manhwa.genreString,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${manhwa.totalChapters} chapters',
                          style: const TextStyle(
                            color: Color(0xFF6c5ce7),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(Manhwa manhwa) {
    return Container(
      color: const Color(0xFF6c5ce7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                manhwa.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2a2a2a),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sort by',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildSortOption('Name (A-Z)', Icons.sort_by_alpha),
              _buildSortOption('Recently Added', Icons.access_time),
              _buildSortOption('Total Chapters', Icons.numbers),
              _buildSortOption('Genre', Icons.category),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6c5ce7)),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: () {
        Navigator.pop(context);
        setState(() {
          switch (title) {
            case 'Name (A-Z)':
              manhwas.sort((a, b) => a.name.compareTo(b.name));
              break;
            case 'Total Chapters':
              manhwas.sort((a, b) => b.totalChapters.compareTo(a.totalChapters));
              break;
            case 'Genre':
              manhwas.sort((a, b) => a.genreString.compareTo(b.genreString));
              break;
            default:
              break;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sorted by $title'),
            backgroundColor: const Color(0xFF6c5ce7),
          ),
        );
      },
    );
  }
}