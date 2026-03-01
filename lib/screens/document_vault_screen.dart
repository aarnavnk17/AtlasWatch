import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/document_service.dart';

class DocumentVaultScreen extends StatefulWidget {
  const DocumentVaultScreen({super.key});

  @override
  State<DocumentVaultScreen> createState() => _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends State<DocumentVaultScreen> {
  final DocumentService _docService = DocumentService();
  bool _loading = true;
  List<dynamic> _documents = [];

  final List<String> _categories = ['Ticket', 'Hotel', 'Insurance', 'Passport', 'Other'];
  String _selectedCategory = 'Other';

  @override
  void initState() {
    super.initState();
    _fetchDocs();
  }

  Future<void> _fetchDocs() async {
    setState(() => _loading = true);
    final docs = await _docService.getDocuments();
    setState(() {
      _documents = docs;
      _loading = false;
    });
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      
      // Show category picker
      if (!mounted) return;
      
      final String? category = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Select Document Category'),
            backgroundColor: const Color(0xFF1E1E1E),
            titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: _categories.map((cat) {
                return ListTile(
                  title: Text(cat, style: const TextStyle(color: Colors.white70)),
                  onTap: () => Navigator.pop(context, cat),
                );
              }).toList(),
            ),
          );
        },
      );

      if (category != null) {
        setState(() => _loading = true);
        final success = await _docService.uploadDocument(file, category);
        if (success) {
          _fetchDocs();
        } else {
          setState(() => _loading = false);
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to upload document')),
            );
          }
        }
      }
    }
  }

  Future<void> _viewDocument(dynamic doc) async {
    try {
      final String url = doc['fileUrl'];
      final String fileName = doc['fileName'];
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');

      if (!await tempFile.exists()) {
        final response = await http.get(Uri.parse(url));
        await tempFile.writeAsBytes(response.bodyBytes);
      }

      await OpenFilex.open(tempFile.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open document: $e')),
        );
      }
    }
  }

  Future<void> _deleteDoc(String id) async {
    final success = await _docService.deleteDocument(id);
    if (success) {
      _fetchDocs();
    } else {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete document')),
        );
      }
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Ticket': return Icons.airplane_ticket_outlined;
      case 'Hotel': return Icons.hotel_outlined;
      case 'Insurance': return Icons.verified_user_outlined;
      case 'Passport': return Icons.badge_outlined;
      default: return Icons.description_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Document Vault', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    return _buildDocCard(doc);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickFile,
        backgroundColor: Colors.blue.shade600,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined, size: 80, color: Colors.grey.shade800),
          const SizedBox(height: 16),
          const Text(
            'Your Vault is Empty',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep your tickets, reservations, and identity safe\nin your secure digital vault.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard(dynamic doc) {
    final category = doc['category'] ?? 'Other';
    final name = doc['originalName'] ?? 'Unnamed Document';
    final date = DateTime.parse(doc['uploadDate']).toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getCategoryIcon(category), color: Colors.blue.shade400),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$category • ${date.day}/${date.month}/${date.year}',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility_outlined, color: Colors.blueGrey),
              onPressed: () => _viewDocument(doc),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _showDeleteDialog(doc),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(dynamic doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Document?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete ${doc['originalName']}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDoc(doc['_id']);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
