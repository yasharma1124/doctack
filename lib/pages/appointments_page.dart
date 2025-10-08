// lib/pages/appointments_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../utils/snackbar_helper.dart'; // make sure this exists

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _selectedRange = 'All Upcoming'; // used for apply filter
  String _pendingRange = 'All Upcoming'; // UI dropdown value until Apply
  bool _isListView = false;
  bool _isLoading = false;

  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // stats
  int _total = 0;
  int _completed = 0;
  int _scheduled = 0;
  int _cancelled = 0;

  late final StreamSubscription<User?> _authSub;

  @override
  void initState() {
    super.initState();
    // Try to load right away; if user isn't present, authStateChanges will trigger later
    _loadAppointments();

    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (u != null) {
        _loadAppointments();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _authSub.cancel();
    super.dispose();
  }

  /// Load appointments + compute stats
  Future<void> _loadAppointments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: user.uid)
          .orderBy('appointmentDate', descending: false)
          .get();

      if (!mounted) return;

      final Map<DateTime, List<Map<String, dynamic>>> newEvents = {};
      int comp = 0, sched = 0, canc = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['appointmentDate'] == null) continue;

        final date = (data['appointmentDate'] as Timestamp).toDate();
        final normalized = DateTime(date.year, date.month, date.day);

        newEvents.putIfAbsent(normalized, () => []);
        newEvents[normalized]!.add({
          'id': doc.id,
          'patientName': data['patientName'] ?? 'Unknown',
          'purpose': data['purpose'] ?? 'N/A',
          'appointmentDate': date,
          'status': data['status'] ?? 'scheduled',
          'clinicId': data['clinicId'] ?? '',
        });

        switch (data['status']) {
          case 'completed':
            comp++;
            break;
          case 'cancelled':
            canc++;
            break;
          default:
            sched++;
        }
      }

      // small delay to reduce quick flicker during view switch
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      setState(() {
        _events = newEvents;
        _isLoading = false;
        _total = comp + sched + canc;
        _completed = comp;
        _scheduled = sched;
        _cancelled = canc;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarHelper.showError(context, "❌ Failed to load appointments");
      }
      debugPrint("Error loading appointments: $e");
    }
  }

  /// Add appointment dialog
  void _showAddAppointmentDialog() {
    final _patientController = TextEditingController();
    final _purposeController = TextEditingController();
    DateTime selectedDate = _focusedDay;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B263B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "Add Appointment",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(_patientController, 'Patient Name'),
              const SizedBox(height: 8),
              _buildTextField(_purposeController, 'Purpose of Visit'),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => selectedDate = picked);
                },
                child: Text(
                  "Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}",
                  style: const TextStyle(color: Colors.purpleAccent),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                SnackbarHelper.showInfo(context, "ℹ️ Appointment creation cancelled");
              },
              child: const Text("Cancel", style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null ||
                    _patientController.text.isEmpty ||
                    _purposeController.text.isEmpty) {
                  SnackbarHelper.showError(context, "⚠️ Please fill all fields");
                  return;
                }

                try {
                  await FirebaseFirestore.instance.collection('appointments').add({
                    'doctorId': user.uid,
                    'patientName': _patientController.text.trim(),
                    'purpose': _purposeController.text.trim(),
                    'status': 'scheduled',
                    'appointmentDate': Timestamp.fromDate(selectedDate),
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(context);
                  await _loadAppointments();
                  SnackbarHelper.showSuccess(context, "✅ Appointment added successfully");
                } catch (e) {
                  SnackbarHelper.showError(context, "❌ Failed to save appointment");
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF243447),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final normalizedDate = DateTime(day.year, day.month, day.day);
    return _events[normalizedDate] ?? [];
  }

  /// Apply filter button handler (manual apply)
  void _applyFilter() {
    setState(() {
      _selectedRange = _pendingRange;
    });
    SnackbarHelper.showInfo(context, "🔎 Filter applied: $_selectedRange");
    // no extra server call — _events already has all appointments, filters are applied in UI lists
  }

  /// Filter matcher for ranges
  bool _inSelectedRange(DateTime dt) {
    final now = DateTime.now();
    final dateOnly = DateTime(dt.year, dt.month, dt.day);

    switch (_selectedRange) {
      case "This Week":
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return dateOnly.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
            dateOnly.isBefore(endOfWeek.add(const Duration(days: 1)));
      case "Next Week":
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startNext = startOfWeek.add(const Duration(days: 7));
        final endNext = startNext.add(const Duration(days: 6));
        return dateOnly.isAfter(startNext.subtract(const Duration(days: 1))) &&
            dateOnly.isBefore(endNext.add(const Duration(days: 1)));
      case "All Upcoming":
      default:
        return dateOnly.isAfter(now.subtract(const Duration(days: 1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // build filtered list of appointments based on selected filter + search
    final allAppointments = _events.values.expand((e) => e).toList();
    List<Map<String, dynamic>> filteredByRange =
        allAppointments.where((a) => _inSelectedRange(a['appointmentDate'] as DateTime)).toList();

    if (_searchQuery.isNotEmpty) {
      filteredByRange = filteredByRange.where((a) {
        final name = a['patientName'].toString().toLowerCase();
        final purpose = a['purpose'].toString().toLowerCase();
        return name.contains(_searchQuery) || purpose.contains(_searchQuery);
      }).toList();
    }

    // sort ascending (BUG FIX: compare a with b)
    filteredByRange.sort((a, b) => (a['appointmentDate'] as DateTime).compareTo(b['appointmentDate'] as DateTime));

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.purpleAccent,
        onPressed: _showAddAppointmentDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // Top toolbar: stats + actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                // Stats Row (gradient cards)
                Row(
                  children: [
                    Expanded(child: _buildGradientStat("Total", _total, Icons.event_available)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildGradientStat("Completed", _completed, Icons.check_circle)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildGradientStat("Scheduled", _scheduled, Icons.schedule)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildGradientStat("Cancelled", _cancelled, Icons.cancel)),
                  ],
                ),

                const SizedBox(height: 12),

                // Toolbar: Refresh + Filter dropdown + Apply button + view toggle
                Row(
                  children: [
                    IconButton(
                      onPressed: () async {
                        await _loadAppointments();
                        SnackbarHelper.showSuccess(context, "🔄 Refreshed appointments");
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      tooltip: "Refresh",
                    ),
                    const SizedBox(width: 8),

                    // Filter dropdown (chooses pendingRange until Apply)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B263B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: DropdownButton<String>(
                        value: _pendingRange,
                        dropdownColor: const Color(0xFF1B263B),
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'All Upcoming', child: Text('All Upcoming', style: TextStyle(color: Colors.white70))),
                          DropdownMenuItem(value: 'This Week', child: Text('This Week', style: TextStyle(color: Colors.white70))),
                          DropdownMenuItem(value: 'Next Week', child: Text('Next Week', style: TextStyle(color: Colors.white70))),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _pendingRange = v ?? 'All Upcoming';
                          });
                        },
                      ),
                    ),

                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _applyFilter,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                      child: const Text("Apply Filter"),
                    ),

                    const Spacer(),

                    // Search field
                    SizedBox(
                      width: 320,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search by patient or purpose...',
                          hintStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF1B263B),
                          prefixIcon: const Icon(Icons.search, color: Colors.white70),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // View toggle
                    IconButton(
                      icon: Icon(_isListView ? Icons.calendar_month : Icons.list, color: Colors.purpleAccent),
                      onPressed: () {
                        setState(() => _isListView = !_isListView);
                      },
                      tooltip: _isListView ? "Switch to Calendar View" : "Switch to List View",
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Loading state
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
            )
          else
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isListView ? _buildListViewMode() : _buildCalendarMode(filteredByRange),
              ),
            ),
        ],
      ),
    );
  }

  // gradient stat card
  Widget _buildGradientStat(String label, int value, IconData icon) {
    return Container(
      height: 86,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C4DFF), Color(0xFF536DFE)], // purple -> blue
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white24,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              Text("$value", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  /// Calendar mode: shows TableCalendar + list based on filtered appointments passed in
  Widget _buildCalendarMode(List<Map<String, dynamic>> filteredAppointments) {
    return Column(
      key: const ValueKey('calendarView'),
      children: [
        TableCalendar(
          focusedDay: _focusedDay,
          firstDay: DateTime.utc(2020),
          lastDay: DateTime.utc(2030),
          eventLoader: _getEventsForDay,
          selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
              _selectedRange = "Day";
            });
          },
          calendarFormat: CalendarFormat.month,
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(color: Colors.white),
            leftChevronIcon: Icon(Icons.chevron_left, color: Colors.purpleAccent),
            rightChevronIcon: Icon(Icons.chevron_right, color: Colors.purpleAccent),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: Colors.white70),
            weekendStyle: TextStyle(color: Colors.white70),
          ),
          calendarStyle: CalendarStyle(
            weekendTextStyle: const TextStyle(color: Colors.white),
            defaultTextStyle: const TextStyle(color: Colors.white),
            todayDecoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.4), shape: BoxShape.circle),
            selectedDecoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle),
            markerDecoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle),
          ),
        ),

        const SizedBox(height: 10),

        Expanded(
          child: filteredAppointments.isEmpty
              ? const Center(child: Text("No appointments found", style: TextStyle(color: Colors.white70)))
              : ListView.builder(
                  itemCount: filteredAppointments.length,
                  itemBuilder: (context, index) {
                    final appt = filteredAppointments[index];
                    return Card(
                      color: const Color(0xFF1B263B),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        title: Text(appt['patientName'], style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          "${appt['purpose']} • ${DateFormat('dd MMM yyyy').format(appt['appointmentDate'])}",
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () async {
                            try {
                              await FirebaseFirestore.instance.collection('appointments').doc(appt['id']).delete();
                              await _loadAppointments();
                              SnackbarHelper.showSuccess(context, "🗑️ Appointment deleted");
                            } catch (e) {
                              SnackbarHelper.showError(context, "❌ Failed to delete appointment");
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// List view mode: stream-based for live changes + actions
  Widget _buildListViewMode() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Login required", style: TextStyle(color: Colors.white)));
    }

    return StreamBuilder<QuerySnapshot>(
      key: const ValueKey('listView'),
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: user.uid)
          .orderBy('appointmentDate', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No appointments available", style: TextStyle(color: Colors.white70)));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final date = (data['appointmentDate'] as Timestamp).toDate();
            final formattedDate = DateFormat('dd MMM yyyy • hh:mm a').format(date);
            final status = data['status'] ?? 'scheduled';

            Color statusColor;
            switch (status) {
              case 'completed':
                statusColor = Colors.greenAccent;
                break;
              case 'cancelled':
                statusColor = Colors.redAccent;
                break;
              default:
                statusColor = Colors.purpleAccent;
            }

            return Card(
              color: const Color(0xFF1B263B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: Icon(Icons.calendar_today, color: statusColor),
                title: Text(data['patientName'] ?? 'Unnamed', style: const TextStyle(color: Colors.white)),
                subtitle: Text("${data['purpose'] ?? 'No purpose'}\n$formattedDate", style: const TextStyle(color: Colors.white70)),
                trailing: PopupMenuButton<String>(
                  color: const Color(0xFF1B263B),
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  onSelected: (value) async {
                    final ref = FirebaseFirestore.instance.collection('appointments').doc(docs[index].id);
                    try {
                      if (value == 'complete') {
                        await ref.update({'status': 'completed'});
                        SnackbarHelper.showSuccess(context, "✅ Marked as completed");
                      } else if (value == 'cancel') {
                        await ref.update({'status': 'cancelled'});
                        SnackbarHelper.showInfo(context, "🚫 Appointment cancelled");
                      } else if (value == 'delete') {
                        await ref.delete();
                        SnackbarHelper.showSuccess(context, "🗑️ Appointment deleted");
                      }
                      // reload local events when user returns to calendar mode
                      if (!mounted) return;
                      if (!_isListView) await _loadAppointments();
                    } catch (e) {
                      SnackbarHelper.showError(context, "❌ Failed to update appointment");
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'complete', child: Text("Mark as Completed", style: TextStyle(color: Colors.white))),
                    PopupMenuItem(value: 'cancel', child: Text("Mark as Cancelled", style: TextStyle(color: Colors.white))),
                    PopupMenuItem(value: 'delete', child: Text("Delete Appointment", style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}