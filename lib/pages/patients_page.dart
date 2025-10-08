// (full file) - replace lib/pages/patients_page.dart with this content

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../utils/snackbar_helper.dart';
import 'patient_profile_page.dart';

class PatientsPage extends StatefulWidget {
  const PatientsPage({super.key});

  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _searchController = TextEditingController();

  String _selectedPurpose = 'Consultation';
  String _selectedHistory = 'None';
  bool _consent = false;
  bool _autoCreateAppointment = true;

  DateTime? _visitDate;
  DateTime? _nextAppointmentDate;
  String _searchText = '';

  final List<String> purposes = [
    'Consultation',
    'Routine Checkup',
    'Follow-up',
    'Emergency',
    'Diagnosis',
    'Vaccination',
    'Other'
  ];

  final List<String> histories = [
    'None',
    'Diabetes',
    'Allergy',
    'Hypertension',
    'Asthma',
    'Heart Disease',
    'Other'
  ];

  Future<void> _addOrUpdatePatient({String? docId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final dobText = _dobController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty || dobText.isEmpty || _visitDate == null) {
      SnackbarHelper.showInfo(context, "⚠️ Please fill all required fields");
      return;
    }

    try {
      final dob = DateTime.parse(dobText);
      final data = {
        'Name': name,
        'Email': email,
        'Phone': phone,
        'Date of Birth': Timestamp.fromDate(dob),
        'Purpose of Visit': _selectedPurpose,
        'Medical History': _selectedHistory,
        'Consent': _consent,
        'doctorId': user.uid,
        'dateOfVisit': Timestamp.fromDate(_visitDate!),
        'nextAppointment': _nextAppointmentDate != null ? Timestamp.fromDate(_nextAppointmentDate!) : null,
        // <<--- use client timestamp to avoid a short window where createdAt is null
        'createdAt': Timestamp.now(),
      };

      if (docId == null) {
        final docRef = await FirebaseFirestore.instance.collection('patients').add(data);
        await docRef.update({'patientId': docRef.id});

        if (_autoCreateAppointment && _nextAppointmentDate != null) {
          await _createOrUpdateAppointment(
            patientId: docRef.id,
            patientName: name,
            date: _nextAppointmentDate!,
            purpose: _selectedPurpose,
            doctorId: user.uid,
          );
        }

        SnackbarHelper.showSuccess(context, "✅ Patient added successfully");
      } else {
        await FirebaseFirestore.instance.collection('patients').doc(docId).update(data);

        if (_autoCreateAppointment && _nextAppointmentDate != null) {
          await _createOrUpdateAppointment(
            patientId: docId,
            patientName: name,
            date: _nextAppointmentDate!,
            purpose: _selectedPurpose,
            doctorId: user.uid,
          );
        }

        SnackbarHelper.showInfo(context, "ℹ️ Patient updated successfully");
      }

      _clearControllers();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      SnackbarHelper.showError(context, "❌ Error saving patient: $e");
    }
  }

  Future<void> _createOrUpdateAppointment({
    required String patientId,
    required String patientName,
    required DateTime date,
    required String purpose,
    required String doctorId,
  }) async {
    try {
      final existing = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('patientId', isEqualTo: patientId)
          .get();

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update({
          'appointmentDate': Timestamp.fromDate(date),
          'purpose': purpose,
        });
        SnackbarHelper.showInfo(context, "📅 Appointment updated successfully");
      } else {
        await FirebaseFirestore.instance.collection('appointments').add({
          'doctorId': doctorId,
          'patientId': patientId,
          'patientName': patientName,
          'purpose': purpose,
          'appointmentDate': Timestamp.fromDate(date),
          // <<--- client timestamp for appointment too
          'createdAt': Timestamp.now(),
        });
        SnackbarHelper.showSuccess(context, "📅 Appointment created");
      }
    } catch (e) {
      SnackbarHelper.showError(context, "❌ Error updating appointment: $e");
    }
  }

  Future<void> _deletePatient(String patientId) async {
    try {
      await FirebaseFirestore.instance.collection('patients').doc(patientId).delete();
      final appointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .get();

      for (final doc in appointments.docs) {
        await doc.reference.delete();
      }

      SnackbarHelper.showSuccess(context, "🗑️ Patient & linked appointments deleted");
    } catch (e) {
      SnackbarHelper.showError(context, "❌ Error deleting patient: $e");
    }
  }

  void _clearControllers() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _dobController.clear();
    _consent = false;
    _visitDate = null;
    _nextAppointmentDate = null;
    _autoCreateAppointment = true;
  }

  void _showAddOrEditDialog({DocumentSnapshot? doc}) {
    if (doc != null) {
      final map = doc.data() as Map<String, dynamic>;
      _nameController.text = map['Name'] ?? '';
      _emailController.text = map['Email'] ?? '';
      _phoneController.text = map['Phone'] ?? '';
      _dobController.text = map['Date of Birth'] != null
          ? (map['Date of Birth'] as Timestamp).toDate().toIso8601String().split('T')[0]
          : '';
      _selectedPurpose = map['Purpose of Visit'] ?? 'Consultation';
      _selectedHistory = map['Medical History'] ?? 'None';
      _consent = map['Consent'] ?? false;
      _visitDate = map['dateOfVisit'] != null
          ? (map['dateOfVisit'] as Timestamp).toDate()
          : DateTime.now();
      _nextAppointmentDate = map['nextAppointment'] != null
          ? (map['nextAppointment'] as Timestamp).toDate()
          : null;
    } else {
      _clearControllers();
    }

    // showDialog with local state (StatefulBuilder) so switches / pickers work instantly
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => _buildPatientDialog(doc, setStateDialog),
      ),
    );
  }

  // Accept optional StateSetter so dialog interactive widgets can call setStateDialog
  Widget _buildPatientDialog(DocumentSnapshot? doc, StateSetter? setStateDialog) {
    final setLocal = setStateDialog ?? (VoidCallback fn) => setState(fn);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1B263B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doc == null ? 'Add Patient' : 'Edit Patient',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              _buildTextField(_nameController, 'Full Name'),
              _buildTextField(_emailController, 'Email'),
              _buildTextField(_phoneController, 'Phone'),
              _buildTextField(_dobController, 'Date of Birth (YYYY-MM-DD)'),
              const SizedBox(height: 8),
              _buildDropdown('Purpose of Visit', purposes, _selectedPurpose, (v) => setLocal(() => _selectedPurpose = v!)),
              const SizedBox(height: 12),
              _buildDropdown('Medical History', histories, _selectedHistory, (v) => setLocal(() => _selectedHistory = v!)),
              const SizedBox(height: 16),
              // use setLocal so the toggle reflects immediately inside dialog
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Consent", style: const TextStyle(color: Colors.white70)),
                  Switch(
                    value: _consent,
                    onChanged: (v) => setLocal(() => _consent = v),
                    activeColor: Colors.purpleAccent,
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Auto-create Appointment", style: const TextStyle(color: Colors.white70)),
                  Switch(
                    value: _autoCreateAppointment,
                    onChanged: (v) => setLocal(() => _autoCreateAppointment = v),
                    activeColor: Colors.purpleAccent,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    initialDate: _visitDate ?? DateTime.now(),
                  );
                  if (picked != null) setLocal(() => _visitDate = picked);
                },
                child: Text(
                  _visitDate == null ? "Select Visit Date" : "Select Visit Date: ${DateFormat('dd MMM yyyy').format(_visitDate!)}",
                  style: const TextStyle(color: Colors.purpleAccent),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    initialDate: _nextAppointmentDate ?? DateTime.now(),
                  );
                  if (picked != null) setLocal(() => _nextAppointmentDate = picked);
                },
                child: Text(
                  _nextAppointmentDate == null ? "Select Next Appointment Date" : "Select Next Appointment Date: ${DateFormat('dd MMM yyyy').format(_nextAppointmentDate!)}",
                  style: const TextStyle(color: Colors.purpleAccent),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      SnackbarHelper.showInfo(context, "ℹ️ Action cancelled");
                    },
                    child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                    onPressed: () => _addOrUpdatePatient(docId: doc?.id),
                    child: Text(doc == null ? 'Save' : 'Update'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: const Color(0xFF243447),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          style: const TextStyle(color: Colors.white),
        ),
      );

  Widget _buildDropdown(String label, List<String> items, String value, Function(String?) onChanged) => DropdownButtonFormField<String>(
        value: value,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        dropdownColor: const Color(0xFF1B263B),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color(0xFF243447),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Sign in required', style: TextStyle(color: Colors.white)));
    }

    // Keep your logic -- admin sees all, others filtered by doctorId.
    final stream = (user.email == "yasharma279@gmail.com")
        ? FirebaseFirestore.instance
            .collection('patients')
            .orderBy('createdAt', descending: true)
            .snapshots()
        : FirebaseFirestore.instance
            .collection('patients')
            .where('doctorId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.purpleAccent,
        onPressed: () => _showAddOrEditDialog(),
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 10),
            Expanded(child: _buildStreamBuilder(stream)),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamBuilder(Stream<QuerySnapshot> stream) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
        }

        if (snapshot.hasError) {
          debugPrint("❌ Firestore error: ${snapshot.error}");
          return const Center(child: Text("Failed to load patients", style: TextStyle(color: Colors.redAccent)));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text("No patients found", style: TextStyle(color: Colors.white70)));
        }

        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['Name'] ?? '').toString().toLowerCase();
          final email = (data['Email'] ?? '').toString().toLowerCase();
          final phone = (data['Phone'] ?? '').toString().toLowerCase();
          return name.contains(_searchText) || email.contains(_searchText) || phone.contains(_searchText);
        }).toList();

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: ListView.builder(
            key: ValueKey(filtered.length),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final doc = filtered[index];
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                color: const Color(0xFF1B263B),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(data['Name'] ?? 'Unnamed', style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    "Email: ${data['Email'] ?? 'N/A'}\n"
                    "Phone: ${data['Phone'] ?? 'N/A'}\n"
                    "Purpose: ${data['Purpose of Visit'] ?? 'N/A'}\n"
                    "Next Appointment: ${data['nextAppointment'] != null ? DateFormat('dd MMM yyyy').format((data['nextAppointment'] as Timestamp).toDate()) : 'N/A'}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.greenAccent), onPressed: () => _showAddOrEditDialog(doc: doc)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _deletePatient(doc.id)),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientProfilePage(
                          patientId: doc.id,
                          patientName: data['Name'] ?? 'Patient',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchText = value.toLowerCase()),
      decoration: InputDecoration(
        hintText: 'Search by name, email, or phone...',
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
        filled: true,
        fillColor: const Color(0xFF1B263B),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }
}