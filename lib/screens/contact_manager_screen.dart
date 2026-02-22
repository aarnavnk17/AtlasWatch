import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/contact_service.dart';

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

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
            TextField(controller: _relationController, decoration: const InputDecoration(labelText: 'Relationship (Optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.isEmpty || _phoneController.text.isEmpty) return;
              await _contactService.addContact(
                _nameController.text,
                _phoneController.text,
                _relationController.text,
              );
              _nameController.clear();
              _phoneController.clear();
              _relationController.clear();
              if (!context.mounted) return;
              Navigator.pop(context);
              _loadContacts();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(EmergencyContact contact) {
    _nameController.text = contact.name;
    _phoneController.text = contact.phone;
    _relationController.text = contact.relationship ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
            TextField(controller: _relationController, decoration: const InputDecoration(labelText: 'Relationship (Optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.isEmpty || _phoneController.text.isEmpty) return;
              if (contact.id != null) {
                await _contactService.updateContact(
                  contact.id!,
                  _nameController.text,
                  _phoneController.text,
                  _relationController.text,
                );
              }
              _nameController.clear();
              _phoneController.clear();
              _relationController.clear();
              if (!context.mounted) return;
              Navigator.pop(context);
              _loadContacts();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        actions: [
          TextButton.icon(
            onPressed: _importContact,
            icon: const Icon(Icons.import_contacts, color: Colors.white),
            label: const Text('Import', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? const Center(child: Text('No emergency contacts added yet.'))
              : ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return ListTile(
                      title: Text(contact.name),
                      subtitle: Text('${contact.phone} (${contact.relationship ?? "N/A"})'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditDialog(contact),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await _contactService.deleteContact(contact.id!);
                              if (!mounted) return;
                              _loadContacts();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
