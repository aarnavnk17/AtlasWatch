import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/contact_service.dart';
import '../widgets/sleek_animation.dart';

class ContactManagerScreen extends StatefulWidget {
  const ContactManagerScreen({super.key});

  @override
  State<ContactManagerScreen> createState() => _ContactManagerScreenState();
}

class _ContactManagerScreenState extends State<ContactManagerScreen> {
  final _contactService = ContactService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationController = TextEditingController();
  
  List<EmergencyContact> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    final contacts = await _contactService.getContacts();
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  Future<void> _importContact() async {
    if (await Permission.contacts.request().isGranted) {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        // Fetch full contact details
        final fullContact = await FlutterContacts.getContact(contact.id);
        if (fullContact != null && fullContact.phones.isNotEmpty) {
          final name = fullContact.displayName;
          final phone = fullContact.phones.first.number;
          
          await _contactService.addContact(name, phone, 'Imported');
          if (!mounted) return;
          _loadContacts();
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission denied')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Emergency Contacts', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _importContact,
            icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.blue),
            tooltip: 'Import from Phone',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return SleekAnimation(
                      delay: Duration(milliseconds: 100 * index),
                      type: SleekAnimationType.slide,
                      slideOffset: const Offset(0.05, 0),
                      child: _buildContactCard(contact),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.blue.shade600,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 80, color: Colors.grey.shade800),
          const SizedBox(height: 16),
          const Text(
            'No Emergency Contacts',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add trusted people who should be\nnotified in case of an emergency.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(EmergencyContact contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person_outline_rounded, color: Colors.orange.shade400),
        ),
        title: Text(
          contact.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          '${contact.phone} • ${contact.relationship ?? "No relation"}',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey, size: 20),
              onPressed: () => _showEditDialog(contact),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
              onPressed: () => _showDeleteConfirm(contact),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(EmergencyContact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Contact?', style: TextStyle(color: Colors.white)),
        content: Text('Remove ${contact.name} from your emergency list?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _contactService.deleteContact(contact.id!);
              _loadContacts();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // --- REUSABLE DIALOG FOR ADD/EDIT ---
  void _showContactDialog({EmergencyContact? contact}) {
    final isEdit = contact != null;
    if (isEdit) {
      _nameController.text = contact.name;
      _phoneController.text = contact.phone;
      _relationController.text = contact.relationship ?? '';
    } else {
      _nameController.clear();
      _phoneController.clear();
      _relationController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          isEdit ? 'Edit Contact' : 'New Contact',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Full Name', Icons.person_outline),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration('Phone Number', Icons.phone_outlined),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _relationController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Relationship', Icons.favorite_outline),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (_nameController.text.isEmpty || _phoneController.text.isEmpty) return;
              if (isEdit) {
                await _contactService.updateContact(contact.id!, _nameController.text, _phoneController.text, _relationController.text);
              } else {
                await _contactService.addContact(_nameController.text, _phoneController.text, _relationController.text);
              }
              if (!context.mounted) return;
              Navigator.pop(context);
              _loadContacts();
            },
            child: Text(isEdit ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
  }

  // Override the existing methods to use the unified dialog
  @override
  void _showAddDialog() => _showContactDialog();
  @override
  void _showEditDialog(EmergencyContact contact) => _showContactDialog(contact: contact);

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
      ),
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
