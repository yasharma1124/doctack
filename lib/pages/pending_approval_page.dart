import 'package:flutter/material.dart';

class PendingApprovalPage extends StatelessWidget {
  final String doctorId;
  const PendingApprovalPage({super.key, required this.doctorId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        title: const Text("Awaiting Approval"),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            "Your account is pending admin approval.\nWe will notify you once it is approved.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      ),
    );
  }
}