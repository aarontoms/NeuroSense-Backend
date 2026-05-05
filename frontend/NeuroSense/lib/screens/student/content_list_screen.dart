import 'package:flutter/material.dart';
import '../../services/content_service.dart';
import '../../theme/app_theme.dart';

class ContentListScreen extends StatefulWidget {
  const ContentListScreen({super.key});

  @override
  State<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends State<ContentListScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _contentList = [];
  String? _institution;

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  Future<void> _fetchContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ContentService.getContentByInstitution();
      setState(() {
        _contentList = data['content'] ?? [];
        _institution = data['institution'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Learning Content', style: AppTheme.headlineStyle(fontSize: 24)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.ink))
          : _error != null
          ? _buildErrorWidget()
          : _buildContentList(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: NeoBox(
        margin: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.accent),
            const SizedBox(height: 16),
            Text(
              'Failed to load content',
              style: AppTheme.headlineStyle(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: AppTheme.bodyStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            NeoButton(
              onPressed: _fetchContent,
              child: Text(
                'RETRY',
                style: AppTheme.buttonTextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentList() {
    if (_contentList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📂', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            Text(
              'No content availble',
              style: AppTheme.headlineStyle(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              _institution != null
                  ? 'No teachers from $_institution have\nuploaded content yet'
                  : 'Check back later for new content',
              textAlign: TextAlign.center,
              style: AppTheme.bodyStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_institution != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: NeoBox(
              color: Colors.blue[100],
              child: Row(
                children: [
                  const Text('🏫', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _institution!,
                          style: AppTheme.buttonTextStyle(fontSize: 16),
                        ),
                        Text(
                          '${_contentList.length} items available',
                          style: AppTheme.bodyStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).neoEntrance(),
          ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _contentList.length,
            itemBuilder: (context, index) {
              final content = _contentList[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildContentCard(content).neoEntrance(delay: index * 50),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContentCard(Map<String, dynamic> content) {
    final fileName = content['fileName'] as String? ?? 'Untitled';
    final teacherName = content['teacherName'] as String? ?? 'Unknown';
    final metadata = content['metadata'] as List? ?? [];

    String emoji;
    Color color;
    String typeStr;

    if (fileName.endsWith('.pdf')) {
      emoji = '📄';
      color = const Color(0xFFFFCDD2); // Red-ish
      typeStr = 'PDF';
    } else if (fileName.endsWith('.mp4') || fileName.endsWith('.mov')) {
      emoji = '🎬';
      color = const Color(0xFFE1BEE7); // Purple-ish
      typeStr = 'Video';
    } else if (fileName.endsWith('.jpg') || fileName.endsWith('.png')) {
      emoji = '🖼️';
      color = const Color(0xFFFFE0B2); // Orange-ish
      typeStr = 'Image';
    } else if (fileName.endsWith('.mp3')) {
      emoji = '🎵';
      color = const Color(0xFFC8E6C9); // Green-ish
      typeStr = 'Audio';
    } else {
      emoji = '📂';
      color = Colors.grey[300]!;
      typeStr = 'File';
    }

    return GestureDetector(
      onTap: () => _showContentDetails(content),
      child: NeoBox(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                border: AppTheme.neoBorder(),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: AppTheme.buttonTextStyle(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          teacherName,
                          style: AppTheme.bodyStyle(fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.ink),
          ],
        ),
      ),
    );
  }

  void _showContentDetails(Map<String, dynamic> content) {
    final fileName = content['fileName'] as String? ?? 'Untitled';
    final teacherName = content['teacherName'] as String? ?? 'Unknown';
    final metadata = content['metadata'] as List? ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: const Border(top: BorderSide(color: Colors.black, width: 2)),
          boxShadow: [AppTheme.hardShadow(offset: const Offset(0, -4))],
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              color: Colors.grey[300],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: AppTheme.headlineStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  Text('Uploaded by $teacherName', style: AppTheme.bodyStyle(color: Colors.grey)),
                ],
              ),
            ),
            const Divider(color: Colors.black, thickness: 2, height: 2),
            Expanded(
              child: metadata.isEmpty
                  ? Center(child: Text('No metadata', style: AppTheme.bodyStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: metadata.length,
                      itemBuilder: (context, index) {
                        final meta = metadata[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: NeoBox(
                            color: const Color(0xFFE3F2FD),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${meta['time'] ?? 'N/A'}', style: AppTheme.buttonTextStyle()),
                                Text('${meta['data'] ?? ''}', style: AppTheme.bodyStyle()),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: NeoButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Open logic
                  },
                  child: Text('OPEN FILE', style: AppTheme.buttonTextStyle(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
