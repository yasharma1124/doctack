import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// NOTE: Do NOT import auth_gate.dart here — that created a circular import.
// AuthGate listens to auth state and will route after sign-in.

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isSigningIn = false;

  /// 🧠 Silent sign-in logic: Automatically logs in returning users (no popup)
  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  Future<void> _checkExistingLogin() async {
    await Future.delayed(const Duration(milliseconds: 400)); // Smooth UX delay
    final currentUser = FirebaseAuth.instance.currentUser;

    // If already signed in, do nothing — AuthGate will take care of routing.
    if (currentUser != null) return;

    // Attempt silent Google Sign-In (no popup)
    try {
      final googleUser = await GoogleSignIn().signInSilently();
      if (googleUser != null) {
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await FirebaseAuth.instance.signInWithCredential(credential);
        // do NOT navigate here; AuthGate will detect the new user and switch screens.
      }
    } catch (e) {
      debugPrint("⚠️ Silent sign-in failed: $e");
    }
  }

  /// 🔐 Manual Google Sign-In
  Future<void> _signInWithGoogle() async {
    setState(() => _isSigningIn = true);

    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut(); // ensures clean session

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isSigningIn = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      // Important: do NOT call Navigator→AuthGate here. AuthGate is the app root and
      // will detect this auth change and present the right screen (admin/home/etc).

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Signed in successfully")),
        );
      }
    } catch (e) {
      debugPrint("❌ Google Sign-In Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sign-in failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  /// 🔓 Optional: Sign-out Helper
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(child: _buildLoginCard(context)),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Doctack",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Smart Doctor Management System",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 30),

          // 🔹 Google Sign-In Button
          _isSigningIn
              ? const CircularProgressIndicator(color: Colors.white)
              : ElevatedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: const Icon(Icons.login, color: Colors.white),
                  label: const Text(
                    "Sign in with Google",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2FF7),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),

          const SizedBox(height: 20),
          const Text(
            "© 2025 Gazing Media",
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}