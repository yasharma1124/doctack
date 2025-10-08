// lib/pages/settings_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _clinicController = TextEditingController();
  final _specializationController = TextEditingController();
  bool _autoCreateAppointment = true;
  bool _notificationsEnabled = true;

  String? _logoUrl;
  File? _logoFile;
  bool _loading = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _clinicController.text = data['clinicName'] ?? '';
        _specializationController.text = data['specialization'] ?? '';
        _autoCreateAppointment = data['auto_create_appointment'] ?? true;
        _notificationsEnabled = data['notifications_enabled'] ?? true;
        _logoUrl = data['logoUrl'];
      } else {
        // If doctor doc doesn't exist, create a minimal one so saves/update are consistent
        await FirebaseFirestore.instance.collection('doctors').doc(user.uid).set({
          'createdAt': FieldValue.serverTimestamp(),
          'auto_create_appointment': _autoCreateAppointment,
          'notifications_enabled': _notificationsEnabled,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Failed to load profile")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickLogo() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked == null) return;
    setState(() => _logoFile = File(picked.path));
  }

  Future<String?> _uploadLogo(String uid) async {
    if (_logoFile == null) return _logoUrl; // unchanged
    final ref = FirebaseStorage.instance.ref().child('doctor_logos/$uid/logo_${DateTime.now().millisecondsSinceEpoch}');
    final task = await ref.putFile(_logoFile!);
    if (task.state == TaskState.success) {
      return await ref.getDownloadURL();
    } else {
      return null;
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final clinicName = _clinicController.text.trim();
    final specialization = _specializationController.text.trim();

    if (clinicName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Clinic name is required")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final uploadedUrl = await _uploadLogo(user.uid);

      final docRef = FirebaseFirestore.instance.collection('doctors').doc(user.uid);
      await docRef.set({
        'clinicName': clinicName,
        'specialization': specialization,
        'logoUrl': uploadedUrl ?? _logoUrl,
        'auto_create_appointment': _autoCreateAppointment,
        'notifications_enabled': _notificationsEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Profile updated")),
        );
        // refresh local values
        _logoFile = null;
        _loadProfile();
      }
    } catch (e) {
      debugPrint("Save profile error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to save profile")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildLogoPreview() {
    final radius = 46.0;
    if (_logoFile != null) {
      return CircleAvatar(radius: radius, backgroundImage: FileImage(_logoFile!));
    }
    if (_logoUrl != null && _logoUrl!.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(_logoUrl!));
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white12,
      child: const Icon(Icons.local_hospital, color: Colors.white70, size: 34),
    );
  }

  @override
  void dispose() {
    _clinicController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        title: const Text('Profile & Settings'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _saveProfile,
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Card(
              color: const Color(0xFF1B263B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildLogoPreview(),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _clinicController,
                                decoration: const InputDecoration(
                                  labelText: 'Clinic Name',
                                  labelStyle: TextStyle(color: Colors.white70),
                                  filled: true,
                                  fillColor: Color(0xFF243447),
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _specializationController,
                                decoration: const InputDecoration(
                                  labelText: 'Specialization (comma separated)',
                                  labelStyle: TextStyle(color: Colors.white70),
                                  filled: true,
                                  fillColor: Color(0xFF243447),
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                          onPressed: _pickLogo,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload Logo'),
                        ),
                        const SizedBox(width: 8),
                        if (_logoFile != null)
                          TextButton(
                            onPressed: () => setState(() => _logoFile = null),
                            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                          )
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              color: const Color(0xFF1B263B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Auto-create Appointment', style: TextStyle(color: Colors.white70)),
                      subtitle: const Text('Create appointment automatically from visit records', style: TextStyle(color: Colors.white38)),
                      value: _autoCreateAppointment,
                      activeColor: Colors.purpleAccent,
                      onChanged: (v) => setState(() => _autoCreateAppointment = v),
                    ),
                    SwitchListTile(
                      title: const Text('Notifications', style: TextStyle(color: Colors.white70)),
                      subtitle: const Text('Enable push/notification reminders', style: TextStyle(color: Colors.white38)),
                      value: _notificationsEnabled,
                      activeColor: Colors.purpleAccent,
                      onChanged: (v) => setState(() => _notificationsEnabled = v),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                // reset logo locally & in firestore
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: const Color(0xFF1B263B),
                    title: const Text('Confirm', style: TextStyle(color: Colors.white)),
                    content: const Text('Remove clinic logo?', style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No', style: TextStyle(color: Colors.white70))),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes', style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await FirebaseFirestore.instance.collection('doctors').doc(user.uid).update({'logoUrl': FieldValue.delete()});
                  setState(() => _logoUrl = null);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Logo removed')));
                }
              },
              icon: const Icon(Icons.delete_forever),
              label: const Text('Remove Logo'),
            ),
          ],
        ),
      ),
    );
  }
}