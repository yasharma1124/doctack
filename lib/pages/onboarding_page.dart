import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/snackbar_helper.dart';

class OnboardingPage extends StatefulWidget {
  final User user;
  const OnboardingPage({super.key, required this.user});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final TextEditingController _clinicName = TextEditingController();
  final TextEditingController _specialization = TextEditingController();
  bool _isLoading = false;
  bool _logoSelected = false;

  Future<void> _submitOnboarding() async {
    if (_clinicName.text.isEmpty || _specialization.text.isEmpty) {
      SnackbarHelper.showError(context, "⚠️ Please fill all details");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.user.uid)
          .set({
        'clinicName': _clinicName.text.trim(),
        'specialization': _specialization.text.trim(),
        'email': widget.user.email,
        'approved': false,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      SnackbarHelper.showInfo(context, "✅ Submitted for admin approval");

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/pending');
    } catch (e) {
      SnackbarHelper.showError(context, "Error: $e");
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        title: const Text("Clinic Onboarding"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _clinicName,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Clinic / Brand Name",
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color(0xFF1B263B),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _specialization,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Specialization (comma separated)",
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color(0xFF1B263B),
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitOnboarding,
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: Text(
                    _isLoading ? "Submitting..." : "Submit for Approval",
                    style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}