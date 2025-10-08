import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../utils/snackbar_helper.dart'; // ✅ Snackbar helper import

class DoctorRecordPage extends StatefulWidget {
  const DoctorRecordPage({super.key});

  @override
  State<DoctorRecordPage> createState() => _DoctorRecordPageState();
}

class _DoctorRecordPageState extends State<DoctorRecordPage> {
  final _findingsController = TextEditingController();
  final _amountPaidController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _transactionIdController = TextEditingController();

  String _modeOfPayment = 'Cash';
  String _selectedClinicId = '';
  String _selectedClinicName = '';
  String _selectedPatientId = '';
  String _selectedPatientName = '';
  String _status = 'completed';
  bool _autoCreateAppointment = true;

  DateTime? _nextVisitDate;
  TimeOfDay? _nextVisitTime;

  List<Map<String, dynamic>> _clinics = [];
  List<Map<String, dynamic>> _patients = [];

  @override
  void initState() {
    super.initState();
    _loadClinics();
    _loadPatients();
  }

  /// 🏥 Load all clinics for this doctor
  Future<void> _loadClinics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clinics')
          .where('doctorId', isEqualTo: user.uid)
          .get();

      setState(() {
        _clinics = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['clinicName'] ?? 'Unnamed Clinic',
          };
        }).toList();

        if (_clinics.isNotEmpty) {
          _selectedClinicId = _clinics.first['id'];
          _selectedClinicName = _clinics.first['name'];
        }
      });
    } catch (e) {
      SnackbarHelper.showError(context, "❌ Failed to load clinics");
    }
  }

  /// 👩‍⚕️ Load all patients linked to this doctor
  Future<void> _loadPatients() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('patients')
          .where('doctorId', isEqualTo: user.uid)
          .get();

      setState(() {
        _patients = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['Name'] ?? 'Unnamed Patient',
          };
        }).toList();

        if (_patients.isNotEmpty) {
          _selectedPatientId = _patients.first['id'];
          _selectedPatientName = _patients.first['name'];
        }
      });
    } catch (e) {
      SnackbarHelper.showError(context, "❌ Failed to load patients");
    }
  }

  /// 💾 Save Doctor Record + Auto Appointment Sync
  Future<void> _saveRecord() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_findingsController.text.isEmpty || _nextVisitDate == null) {
      SnackbarHelper.showInfo(context, "⚠️ Please fill all required fields");
      return;
    }

    try {
      final total = double.tryParse(_totalAmountController.text) ?? 0;
      final paid = double.tryParse(_amountPaidController.text) ?? 0;
      final remaining = total - paid;

      final newDoc =
          FirebaseFirestore.instance.collection('doctor_records').doc();

      final recordData = {
        'visit_id': newDoc.id,
        'doctorId': user.uid,
        'clinic_id': _selectedClinicId,
        'clinicName': _selectedClinicName,
        'doctorName': 'Dr. ${user.displayName ?? 'Unknown'}',
        'patientId': _selectedPatientId,
        'patientName': _selectedPatientName,
        'findings': _findingsController.text.trim(),
        'nextVisitDate': Timestamp.fromDate(_nextVisitDate!),
        'nextVisitTime': _nextVisitTime?.format(context) ?? '',
        'modeOfPayment': _modeOfPayment,
        'transactionId': _transactionIdController.text.trim(),
        'amountPaid': paid,
        'totalAmount': total,
        'remainingAmount': remaining,
        'status': _status,
        'auto_created_appointment': _autoCreateAppointment,
        'timestamp_day': DateFormat('yyyy-MM-dd').format(_nextVisitDate!),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await newDoc.set(recordData);

      // 🧠 Step 2 — Auto-create or update appointment
      if (_autoCreateAppointment && _nextVisitDate != null) {
        await _createOrUpdateAppointment(
          doctorId: user.uid,
          clinicId: _selectedClinicId,
          patientId: _selectedPatientId,
          patientName: _selectedPatientName,
          date: _nextVisitDate!,
          purpose: _findingsController.text.trim().isNotEmpty
              ? _findingsController.text.trim()
              : "General Checkup",
        );
      }

      SnackbarHelper.showSuccess(
          context, "✅ Record added & appointment synced successfully");
      _clearFields();
    } catch (e) {
      SnackbarHelper.showError(context, "❌ Error saving record: $e");
    }
  }

  /// ✅ Auto-create or update appointment in Firestore
  Future<void> _createOrUpdateAppointment({
    required String doctorId,
    required String clinicId,
    required String patientId,
    required String patientName,
    required DateTime date,
    required String purpose,
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
          'status': 'scheduled',
          'clinicId': clinicId,
        });
        SnackbarHelper.showInfo(context, "📅 Appointment updated successfully");
      } else {
        await FirebaseFirestore.instance.collection('appointments').add({
          'doctorId': doctorId,
          'clinicId': clinicId,
          'patientId': patientId,
          'patientName': patientName,
          'appointmentDate': Timestamp.fromDate(date),
          'purpose': purpose,
          'status': 'scheduled',
          'createdAt': FieldValue.serverTimestamp(),
        });
        SnackbarHelper.showSuccess(context, "📅 Appointment created");
      }
    } catch (e) {
      SnackbarHelper.showError(context, "❌ Error syncing appointment: $e");
    }
  }

  void _clearFields() {
    _findingsController.clear();
    _amountPaidController.clear();
    _totalAmountController.clear();
    _transactionIdController.clear();
    _modeOfPayment = 'Cash';
    _nextVisitDate = null;
    _nextVisitTime = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        title: const Text("Add Doctor Record",
            style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdownClinic(),
            const SizedBox(height: 12),
            _buildDropdownPatient(),
            const SizedBox(height: 12),
            _buildTextField(_findingsController, "Findings / Notes"),
            _buildTextField(_totalAmountController, "Total Amount"),
            _buildTextField(_amountPaidController, "Amount Paid"),
            _buildTextField(
                _transactionIdController, "Transaction ID (if online)"),
            const SizedBox(height: 10),
            _buildDropdownPayment(),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  initialDate: _nextVisitDate ?? DateTime.now(),
                );
                if (picked != null) setState(() => _nextVisitDate = picked);
              },
              child: Text(
                _nextVisitDate == null
                    ? "Select Next Visit Date"
                    : "Next Visit: ${DateFormat('dd MMM yyyy').format(_nextVisitDate!)}",
                style: const TextStyle(color: Colors.purpleAccent),
              ),
            ),
            TextButton(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (picked != null) setState(() => _nextVisitTime = picked);
              },
              child: Text(
                _nextVisitTime == null
                    ? "Select Next Visit Time"
                    : "Next Visit Time: ${_nextVisitTime!.format(context)}",
                style: const TextStyle(color: Colors.purpleAccent),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _saveRecord,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Save Record"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownClinic() {
    return DropdownButtonFormField<String>(
      value: _selectedClinicId.isNotEmpty ? _selectedClinicId : null,
      items: _clinics
          .map((clinic) =>
              DropdownMenuItem(value: clinic['id'], child: Text(clinic['name'])))
          .toList(),
      onChanged: (val) {
        setState(() {
          _selectedClinicId = val!;
          _selectedClinicName =
              _clinics.firstWhere((c) => c['id'] == val)['name'];
        });
      },
      decoration: const InputDecoration(
        labelText: "Select Clinic",
        labelStyle: TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Color(0xFF243447),
      ),
      dropdownColor: const Color(0xFF1B263B),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildDropdownPatient() {
    return DropdownButtonFormField<String>(
      value: _selectedPatientId.isNotEmpty ? _selectedPatientId : null,
      items: _patients
          .map((patient) => DropdownMenuItem(
              value: patient['id'], child: Text(patient['name'])))
          .toList(),
      onChanged: (val) {
        setState(() {
          _selectedPatientId = val!;
          _selectedPatientName =
              _patients.firstWhere((p) => p['id'] == val)['name'];
        });
      },
      decoration: const InputDecoration(
        labelText: "Select Patient",
        labelStyle: TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Color(0xFF243447),
      ),
      dropdownColor: const Color(0xFF1B263B),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildDropdownPayment() {
    return DropdownButtonFormField<String>(
      value: _modeOfPayment,
      items: const [
        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
        DropdownMenuItem(value: 'UPI', child: Text('UPI')),
        DropdownMenuItem(value: 'Card', child: Text('Card')),
        DropdownMenuItem(value: 'Online', child: Text('Online')),
      ],
      onChanged: (val) => setState(() => _modeOfPayment = val!),
      decoration: const InputDecoration(
        labelText: "Payment Mode",
        labelStyle: TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Color(0xFF243447),
      ),
      dropdownColor: const Color(0xFF1B263B),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return Padding(
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
  }
}