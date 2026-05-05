import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:autism/services/teacher_service.dart';
import '../../theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class UploadContentScreen extends StatefulWidget {
  const UploadContentScreen({super.key});

  @override
  State<UploadContentScreen> createState() => _UploadContentScreenState();
}

class _UploadContentScreenState extends State<UploadContentScreen> {
  File? _selectedFile;
  String? _fileName;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  final List<Map<String, TextEditingController>> _metadataFields = [];

  @override
  void initState() {
    super.initState();
    _addMetadataField();
  }

  void _addMetadataField() {
    setState(() {
      _metadataFields.add({
        'time': TextEditingController(),
        'data': TextEditingController(),
      });
    });
  }

  void _removeMetadataField(int index) {
    setState(() {
      _metadataFields[index]['time']?.dispose();
      _metadataFields[index]['data']?.dispose();
      _metadataFields.removeAt(index);
    });
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'avi', 'jpg', 'jpeg', 'png', 'pdf', 'mp3'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _fileName = result.files.single.name;
        });
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
    }
  }

  Future<void> _uploadContent() async {
    if (_selectedFile == null) {
      _showError('Please select a file first');
      return;
    }

    final metadata = <Map<String, String>>[];
    for (var field in _metadataFields) {
      final time = field['time']!.text.trim();
      final data = field['data']!.text.trim();

      if (time.isNotEmpty && data.isNotEmpty) {
        metadata.add({'time': time, 'data': data});
      }
    }

    if (metadata.isEmpty) {
      _showError('Please add at least one metadata entry');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      await TeacherService.uploadContent(
        file: _selectedFile!,
        metadata: metadata,
      );

      setState(() {
        _isUploading = false;
        _uploadProgress = 1.0;
      });

      _showSuccess('Content uploaded successfully!');

      setState(() {
        _selectedFile = null;
        _fileName = null;
        _metadataFields.clear();
        _addMetadataField();
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
      _showError('Upload failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTheme.buttonTextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black, width: 2)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTheme.buttonTextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black, width: 2)),
      ),
    );
  }

  @override
  void dispose() {
    for (var field in _metadataFields) {
      field['time']?.dispose();
      field['data']?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background, // Neo-Background
      appBar: AppBar(
        title: Text('Upload Content', style: AppTheme.headlineStyle(fontSize: 24)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
            // Logout for Teacher? Or profile link.
             IconButton(
                icon: const Icon(Icons.logout, color: AppTheme.ink),
                onPressed: () => context.go('/login'),
             )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select File', style: AppTheme.headlineStyle(fontSize: 20)),
            const SizedBox(height: 12),
            
            GestureDetector(
                onTap: _isUploading ? null : _pickFile,
                child: NeoBox(
                  color: Colors.white,
                  border: Border.all(color: AppTheme.ink, width: 2), // Dashed would be cool but standard for now
                  child: Column(
                    children: [
                      Icon(
                        _selectedFile != null ? Icons.check_circle : Icons.cloud_upload_outlined,
                        size: 48,
                        color: _selectedFile != null ? Colors.green : AppTheme.ink,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _fileName ?? 'Tap to choose file',
                        style: AppTheme.bodyStyle(
                          color: _selectedFile != null ? AppTheme.ink : Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
            ),
            
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Metadata', style: AppTheme.headlineStyle(fontSize: 20)),
                IconButton(
                  onPressed: _addMetadataField,
                  icon: const Icon(Icons.add_circle, color: AppTheme.accent, size: 32),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ..._metadataFields.asMap().entries.map((entry) {
              int index = entry.key;
              var controllers = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: NeoBox(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                            Expanded(
                                child: _buildMiniInput(controllers['time']!, 'Time (e.g. 0:30)'),
                            ),
                            if (_metadataFields.length > 1)
                                IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _removeMetadataField(index),
                                )
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildMiniInput(controllers['data']!, 'Description', maxLines: 2),
                    ],
                  ),
                ).neoEntrance(delay: index * 100),
              );
            }),

            const SizedBox(height: 24),

            if (_isUploading) ...[
              LinearProgressIndicator(
                  value: _uploadProgress, 
                  color: AppTheme.accent, 
                  backgroundColor: Colors.grey[300],
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
              ),
              const SizedBox(height: 8),
              Text(
                _uploadProgress == 0
                    ? 'Uploading...'
                    : 'Upload ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                style: AppTheme.bodyStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: NeoButton(
                onPressed: _isUploading ? null : _uploadContent,
                color: AppTheme.accent,
                child: _isUploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                    : Text('UPLOAD CONTENT', style: AppTheme.buttonTextStyle(color: Colors.white)),
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniInput(TextEditingController controller, String label, {int maxLines = 1}) {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                      controller: controller,
                      maxLines: maxLines,
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero
                      ),
                      style: AppTheme.bodyStyle(fontSize: 14),
                  )
              )
          ],
      );
  }
}
