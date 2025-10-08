// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'patients_page.dart';
import 'appointments_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    "Dashboard",
    "Patients",
    "Appointments",
    "Reports",
    "Settings"
  ];

  final List<Widget> _pages = const [
    DashboardPage(), // ✅ shows your new "Daily Control Center"
    PatientsPage(),
    AppointmentsPage(),
    ReportsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1625),
      body: Row(
        children: [
          // 🔹 Sidebar
          Container(
            width: 230,
            color: const Color(0xFF0D1B2A),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  "Doctack",
                  style: TextStyle(
                    color: Colors.purpleAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: ListView(
                    children: [
                      _buildNavItem(Icons.dashboard_rounded, "Dashboard", 0),
                      _buildNavItem(Icons.people_alt_rounded, "Patients", 1),
                      _buildNavItem(Icons.event_rounded, "Appointments", 2),
                      _buildNavItem(Icons.bar_chart_rounded, "Reports", 3),
                      _buildNavItem(Icons.settings_rounded, "Settings", 4),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    "Technical support gm",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                )
              ],
            ),
          ),

          // 🔹 Main Content
          Expanded(
            child: Container(
              color: const Color(0xFF0A1625),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔸 Header bar
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                    color: const Color(0xFF0F223A),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedIndex == 0
                              ? "Daily Control Center"
                              : "${_titles[_selectedIndex]} Overview",
                          style: const TextStyle(
                            color: Colors.purpleAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Icon(Icons.light_mode, color: Colors.amberAccent),
                      ],
                    ),
                  ),

                  // 🔸 Dynamic Page Content
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      color: const Color(0xFF0A1625),
                      child: _pages[_selectedIndex],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, int index) {
    final bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purpleAccent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.purpleAccent : Colors.white54, size: 22),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.purpleAccent : Colors.white70,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}