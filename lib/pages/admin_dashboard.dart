import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white70, fontSize: 20),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('doctors').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No doctor records found.",
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          final doctors = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: doctors.length,
            itemBuilder: (context, index) {
              final doc = doctors[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['clinicName'] ?? "Unknown Clinic";
              final email = data['email'] ?? "No email";
              final specialization =
                  data['specialization'] ?? "Not specified";
              final approved = data['approved'] ?? false;
              final status = data['status'] ?? "pending";

              return Card(
                color: const Color(0xFF1B263B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    "$email\nSpecialization: $specialization\nStatus: ${approved ? 'Approved' : status}",
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  isThreeLine: true,
                  trailing: approved
                      ? const Icon(Icons.verified, color: Colors.greenAccent)
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent,
                          ),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('doctors')
                                .doc(doc.id)
                                .update({
                              'approved': true,
                              'status': 'approved',
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text("$name has been approved successfully!"),
                              ),
                            );
                          },
                          child: const Text("Approve"),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}