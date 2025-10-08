// lib/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'patients_page.dart';
import 'appointments_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<int> _getCount(String collection, [Query<Map<String, dynamic>>? query]) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // no user -> return 0 so UI doesn't hang
      return 0;
    }
    final col = query ?? FirebaseFirestore.instance.collection(collection).where('doctorId', isEqualTo: currentUser.uid);
    final snap = await col.get();
    return snap.docs.length;
  }

  Future<Map<String, int>> _fetchStats() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // return zeros if user is not signed in yet
      return {
        'totalPatients': 0,
        'todayAppointments': 0,
        'completedVisits': 0,
        'newPatients7Days': 0,
      };
    }

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final totalPatients = await _getCount('patients');
    final todayAppointments = await _getCount(
      'appointments',
      FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: currentUser.uid)
          .where('appointmentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('appointmentDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay)),
    );

    final completedVisits = await _getCount(
      'appointments',
      FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'completed'),
    );

    final newPatients7Days = await _getCount(
      'patients',
      FirebaseFirestore.instance
          .collection('patients')
          .where('doctorId', isEqualTo: currentUser.uid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(today.subtract(const Duration(days: 7)))),
    );

    return {
      'totalPatients': totalPatients,
      'todayAppointments': todayAppointments,
      'completedVisits': completedVisits,
      'newPatients7Days': newPatients7Days,
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1625),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Header
              const Text(
                "Daily Control Center",
                style: TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // 🔹 Summary Cards
              FutureBuilder<Map<String, int>>(
                future: _fetchStats(),
                builder: (context, snapshot) {
                  // Handle waiting / error / data states robustly
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                  }
                  if (snapshot.hasError) {
                    debugPrint('Error fetching dashboard stats: ${snapshot.error}');
                    return const Center(child: Text("Failed to load dashboard stats", style: TextStyle(color: Colors.white70)));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: Text("No data", style: TextStyle(color: Colors.white70)));
                  }

                  final data = snapshot.data!;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = constraints.maxWidth > 900
                          ? 4
                          : constraints.maxWidth > 600
                              ? 2
                              : 1;
                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.8,
                        children: [
                          _buildSummaryCard("Total Patients", data['totalPatients'], Icons.people_alt_rounded),
                          _buildSummaryCard("Today’s Appointments", data['todayAppointments'], Icons.calendar_today_rounded),
                          _buildSummaryCard("Completed Visits", data['completedVisits'], Icons.check_circle_rounded),
                          _buildSummaryCard("New Patients (7 Days)", data['newPatients7Days'], Icons.trending_up_rounded),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 25),
              Divider(color: Colors.white10),

              // 🔹 Upcoming Appointments
              const Text(
                "Upcoming Appointments",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),

              // If user not signed in show message rather than creating a stream with null uid
              if (currentUser == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text("Login required to load appointments.", style: TextStyle(color: Colors.white54)),
                )
              else
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('appointments')
                      .where('doctorId', isEqualTo: currentUser.uid)
                      .where('appointmentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
                      .orderBy('appointmentDate', descending: false)
                      .limit(3)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                    }
                    if (snapshot.hasError) {
                      debugPrint('Upcoming appointments stream error: ${snapshot.error}');
                      return const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text("Failed to load upcoming appointments.", style: TextStyle(color: Colors.white54)),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text("No upcoming appointments.", style: TextStyle(color: Colors.white54)),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    return Column(
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final patient = data['patientName'] ?? "Unknown Patient";
                        final date = (data['appointmentDate'] as Timestamp).toDate();
                        final purpose = data['purpose'] ?? "Consultation";

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF101C33),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(patient,
                                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                                  Text(
                                    "$purpose • ${date.day}/${date.month}/${date.year}",
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                              const Icon(Icons.chevron_right, color: Colors.purpleAccent),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              const SizedBox(height: 20),
              Divider(color: Colors.white10),

              // 🔹 Quick Actions
              const Text(
                "Quick Actions",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  _buildQuickAction(Icons.person_add_rounded, "Add Patient", () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientsPage()));
                  }),
                  const SizedBox(width: 12),
                  _buildQuickAction(Icons.event_available_rounded, "Add Appointment", () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AppointmentsPage()));
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, int? count, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101C33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.purpleAccent, size: 26),
          const SizedBox(height: 8),
          Text(
            count?.toString() ?? '0',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF101C33),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purpleAccent.withOpacity(0.25)),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.purpleAccent, size: 20),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}