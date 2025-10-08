import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ Correct paths (since this file is already inside /pages)
import 'home_page.dart'; // 👈 Added this import instead of dashboard direct call
import 'login_page.dart';
import 'onboarding_page.dart';
import 'pending_approval_page.dart';
import 'admin_dashboard.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 🔹 While checking login status
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D1B2A),
            body: Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent),
            ),
          );
        }

        final user = snapshot.data;

        // 🔹 If not logged in → go to login page
        if (user == null) {
          return const LoginPage();
        }

        // ✅ 🔹 Instant override for admin email (safety net)
        if (user.email == "yasharma279@gmail.com") {
          return const AdminDashboardPage();
        }

        // 🔹 User is logged in → check their Firestore data
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userDoc) {
            if (userDoc.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF0D1B2A),
                body: Center(
                  child: CircularProgressIndicator(color: Colors.purpleAccent),
                ),
              );
            }

            // 🔹 If no user doc exists → treat as normal doctor
            if (!userDoc.hasData || !userDoc.data!.exists) {
              return _buildDoctorFlow(user);
            }

            final data = userDoc.data!.data() as Map<String, dynamic>?;
            final role = data?['role'] ?? 'doctor';

            // 🔹 If role = admin → go to admin dashboard
            if (role == 'admin') {
              return const AdminDashboardPage();
            }

            // 🔹 Default → doctor flow
            return _buildDoctorFlow(user);
          },
        );
      },
    );
  }

  /// 🩺 Handles all Doctor-side navigation logic (onboarding, pending, approved)
  Widget _buildDoctorFlow(User user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('doctors')
          .doc(user.uid)
          .snapshots(),
      builder: (context, docSnapshot) {
        if (docSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D1B2A),
            body: Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent),
            ),
          );
        }

        // 🔹 If no doctor profile exists → onboarding
        if (!docSnapshot.hasData || !docSnapshot.data!.exists) {
          return OnboardingPage(user: user);
        }

        final data = docSnapshot.data!.data() as Map<String, dynamic>?;

        // 🔹 Handle null/empty data
        if (data == null) {
          return OnboardingPage(user: user);
        }

        // 🔹 If doctor is pending approval → show pending screen
        if (data['approved'] == false || (data['status'] ?? '') == 'pending') {
          return PendingApprovalPage(doctorId: user.uid);
        }

        // 🔹 Approved → Full sidebar home layout (Dashboard inside)
        return const HomePage(); // 👈 FINAL FIX
      },
    );
  }
}