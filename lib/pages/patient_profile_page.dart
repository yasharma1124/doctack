// lib/pages/patient_profile_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/snackbar_helper.dart';

class PatientProfilePage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientProfilePage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  Map<String, dynamic>? patientData;

  @override
  void initState() {
    super.initState();
    _loadPatientDetails();
  }

  Future<void> _loadPatientDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.patientId)
          .get();

      if (doc.exists) {
        setState(() => patientData = doc.data());
      } else {
        SnackbarHelper.showError(context, "❌ Patient record not found");
      }
    } catch (e) {
      SnackbarHelper.showError(context, "⚠️ Error loading patient: $e");
    }
  }

  Future<void> _updateNextAppointment(DateTime newDate) async {
    try {
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.patientId)
          .update({'nextAppointment': Timestamp.fromDate(newDate)});

      final doctorId =
          patientData?['doctorId'] ?? FirebaseAuth.instance.currentUser?.uid;
      if (doctorId != null) {
        final appointments = await FirebaseFirestore.instance
            .collection('appointments')
            .where('doctorId', isEqualTo: doctorId)
            .where('patientId', isEqualTo: widget.patientId)
            .get();

        if (appointments.docs.isNotEmpty) {
          await appointments.docs.first.reference
              .update({'appointmentDate': Timestamp.fromDate(newDate)});
          SnackbarHelper.showSuccess(context, "✅ Appointment updated");
        } else {
          await FirebaseFirestore.instance.collection('appointments').add({
            'doctorId': doctorId,
            'patientId': widget.patientId,
            'patientName': widget.patientName,
            'purpose': patientData?['Purpose of Visit'] ?? 'Consultation',
            'appointmentDate': Timestamp.fromDate(newDate),
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'scheduled',
          });
          SnackbarHelper.showInfo(context, "📅 New appointment created");
        }
      }
      await _loadPatientDetails();
    } catch (e) {
      SnackbarHelper.showError(context, "❌ Error updating appointment: $e");
    }
  }

  Future<void> _pickNextAppointment() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.purpleAccent,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await _updateNextAppointment(picked);
    } else {
      SnackbarHelper.showInfo(context, "📅 Appointment not selected");
    }
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return 'N/A';
    final date = ts.toDate();
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1625),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F223A),
        elevation: 0,
        title: Text(widget.patientName,
            style: const TextStyle(color: Colors.purpleAccent)),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon:
                const Icon(Icons.refresh, color: Colors.purpleAccent),
            onPressed: _loadPatientDetails,
          ),
        ],
      ),
      body: patientData == null
          ? const Center(
              child: CircularProgressIndicator(
                  color: Colors.purpleAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPatientInfoCard(),
                  const SizedBox(height: 20),
                  _buildAppointmentSection(),
                  const SizedBox(height: 20),
                  _buildVisitHistorySection(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.purpleAccent,
        tooltip: "Update Next Appointment",
        onPressed: _pickNextAppointment,
        child: const Icon(Icons.calendar_month),
      ),
    );
  }

  Widget _buildPatientInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101C33),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(patientData?['Name'] ?? 'Unnamed',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _infoRow("Email", patientData?['Email']),
          _infoRow("Phone", patientData?['Phone']),
          _infoRow("Purpose", patientData?['Purpose of Visit']),
          _infoRow("Medical History", patientData?['Medical History']),
          _infoRow("Consent",
              patientData?['Consent'] == true ? "Yes" : "No"),
          _infoRow("Date of Birth",
              _formatDate(patientData?['Date of Birth'])),
          _infoRow("Visit Date",
              _formatDate(patientData?['dateOfVisit'])),
          _infoRow("Next Appointment",
              _formatDate(patientData?['nextAppointment'])),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 14)),
          Flexible(
            child: Text(
              value ?? 'N/A',
              textAlign: TextAlign.end,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: widget.patientId)
          .snapshots()
          .handleError((e) {
        print('❌ Appointment stream error: $e');
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print("❌ Appointment error: ${snapshot.error}");
          return const Text("Error loading appointments",
              style: TextStyle(color: Colors.redAccent));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Colors.purpleAccent));
        }

        final docs = snapshot.data?.docs ?? [];
        print("📅 Appointment snapshot count: ${docs.length}");

        if (docs.isEmpty) {
          return const Text("No upcoming appointments",
              style: TextStyle(color: Colors.white54));
        }

        final appt = docs.first.data() as Map<String, dynamic>;
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF101C33),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text("Next Appointment",
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15)),
                  Text(
                    "${_formatDate(appt['appointmentDate'] as Timestamp?)} • ${appt['purpose'] ?? 'N/A'}",
                    style: const TextStyle(
                        color: Colors.purpleAccent,
                        fontSize: 14),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_calendar,
                    color: Colors.purpleAccent),
                onPressed: _pickNextAppointment,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisitHistorySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('visits')
          .where('patientId', isEqualTo: widget.patientId)
          .orderBy('visitDate', descending: true)
          .snapshots()
          .handleError((e) {
        print('❌ Visit stream error: $e');
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print("❌ Visit error: ${snapshot.error}");
          return const Text("Error loading visits",
              style: TextStyle(color: Colors.redAccent));
        }

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Colors.purpleAccent));
        }

        final docs = snapshot.data?.docs ?? [];
        print("🩺 Visit snapshot count: ${docs.length}");

        if (docs.isEmpty) {
          return const Text("No previous visits recorded",
              style: TextStyle(color: Colors.white54));
        }

        return Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text("Visit History",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...docs.map((d) {
              final data =
                  d.data() as Map<String, dynamic>;
              final visitDate =
                  (data['visitDate'] as Timestamp?)
                      ?.toDate();
              final visitId = d.id;

              print(
                  "🩶 Visit loaded: $visitId — ${data['notes']}");

              return Container(
                margin:
                    const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF101C33),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitDate != null
                          ? DateFormat('dd MMM yyyy')
                              .format(visitDate)
                          : 'Unknown Date',
                      style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['notes'] ??
                          data['findings'] ??
                          'No notes available',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment:
                          Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            _addPrescription(context, visitId),
                        icon: const Icon(
                            Icons.medical_services_outlined,
                            color: Colors.purpleAccent,
                            size: 18),
                        label: const Text(
                          "Add Prescription",
                          style: TextStyle(
                              color: Colors.purpleAccent),
                        ),
                      ),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('prescriptions')
                          .where('visitId',
                              isEqualTo: visitId)
                          .orderBy('createdAt',
                              descending: true)
                          .snapshots()
                          .handleError((e) {
                        print(
                            '❌ Prescription stream error: $e');
                      }),
                      builder: (context, presSnapshot) {
                        if (presSnapshot.hasError) {
                          print(
                              "❌ Prescription error: ${presSnapshot.error}");
                          return const Text(
                              "Error loading prescriptions",
                              style: TextStyle(
                                  color: Colors.redAccent));
                        }

                        if (!presSnapshot.hasData)
                          return const SizedBox();

                        final presDocs =
                            presSnapshot.data!.docs;
                        print(
                            "💊 Prescriptions found for visit $visitId: ${presDocs.length}");

                        if (presDocs.isEmpty) {
                          return const Text(
                              "No prescriptions added yet.",
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13));
                        }

                        return Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: presDocs.map((p) {
                            final presData =
                                p.data() as Map<String, dynamic>;
                            final meds =
                                (presData['medicines'] ??
                                        [])
                                    as List<dynamic>;

                            return Container(
                              margin:
                                  const EdgeInsets.symmetric(
                                      vertical: 6),
                              padding:
                                  const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF14223C),
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                      "Prescription",
                                      style: TextStyle(
                                          color: Colors
                                              .purpleAccent,
                                          fontSize: 14,
                                          fontWeight:
                                              FontWeight
                                                  .w500)),
                                  const SizedBox(height: 6),
                                  ...meds.map((m) {
                                    final mm =
                                        m as Map<
                                            String,
                                            dynamic>? ??
                                            {};
                                    return Padding(
                                      padding: const EdgeInsets
                                          .symmetric(
                                              vertical: 2),
                                      child: Text(
                                        "• ${mm['name'] ?? ''} - ${mm['dosage'] ?? ''} (${mm['duration'] ?? ''})",
                                        style: const TextStyle(
                                            color:
                                                Colors.white70,
                                            fontSize: 13),
                                      ),
                                    );
                                  }),
                                  if ((presData['notes'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(
                                              top: 4),
                                      child: Text(
                                        "Notes: ${presData['notes']}",
                                        style: const TextStyle(
                                            color:
                                                Colors.white60,
                                            fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Future<void> _addPrescription(
      BuildContext context, String visitId) async {
    final medNameController = TextEditingController();
    final dosageController = TextEditingController();
    final durationController = TextEditingController();
    final notesController = TextEditingController();
    final List<Map<String, String>> medicines = [];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: const Color(0xFF101C33),
            title: const Text("Add Prescription",
                style:
                    TextStyle(color: Colors.purpleAccent)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _smallInput("Medicine name", medNameController),
                  const SizedBox(height: 6),
                  _smallInput("Dosage (e.g. 500mg)",
                      dosageController),
                  const SizedBox(height: 6),
                  _smallInput("Duration (e.g. 5 days)",
                      durationController),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text("Add medicine"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.purpleAccent),
                        onPressed: () {
                          final name =
                              medNameController.text.trim();
                          if (name.isEmpty) {
                            SnackbarHelper.showError(context,
                                "Enter medicine name");
                            return;
                          }
                          medicines.add({
                            'name': name,
                            'dosage':
                                dosageController.text.trim(),
                            'duration':
                                durationController.text.trim(),
                          });
                          medNameController.clear();
                          dosageController.clear();
                          durationController.clear();
                          setStateDialog(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                      Text("${medicines.length} added",
                          style: const TextStyle(
                              color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (medicines.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14223C),
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: medicines
                            .map((m) => Text(
                                "• ${m['name']} — ${m['dosage']} • ${m['duration']}",
                                style: const TextStyle(
                                    color: Colors.white70)))
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _smallInput("Notes (optional)", notesController),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel",
                    style:
                        TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent),
                onPressed: () async {
                  if (medicines.isEmpty) {
                    SnackbarHelper.showError(context,
                        "Add at least one medicine first");
                    return;
                  }

                  try {
                    final doctorId = patientData?['doctorId'] ??
                        FirebaseAuth.instance.currentUser?.uid;
                    await FirebaseFirestore.instance
                        .collection('prescriptions')
                        .add({
                      'doctorId': doctorId,
                      'patientId': widget.patientId,
                      'visitId': visitId,
                      'medicines': medicines,
                      'notes':
                          notesController.text.trim(),
                      'createdAt':
                          FieldValue.serverTimestamp(),
                    });

                    Navigator.pop(context);
                    SnackbarHelper.showSuccess(context,
                        "💊 Prescription added");
                  } catch (e) {
                    SnackbarHelper.showError(context,
                        "❌ Failed to save prescription: $e");
                  }
                },
                child: const Text("Save"),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _smallInput(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: Colors.white70),
        enabledBorder: const UnderlineInputBorder(
            borderSide:
                BorderSide(color: Colors.white12)),
        focusedBorder: const UnderlineInputBorder(
            borderSide:
                BorderSide(color: Colors.purpleAccent)),
      ),
    );
  }
}