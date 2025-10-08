import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int total = 0;
  int completed = 0;
  int scheduled = 0;
  int cancelled = 0;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('doctorId', isEqualTo: user.uid)
        .get();

    int comp = 0, sched = 0, canc = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
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

    setState(() {
      total = snapshot.docs.length;
      completed = comp;
      scheduled = sched;
      cancelled = canc;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth < 1000;
    final isMobile = screenWidth < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Reports & Analytics",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // 🧩 Summary Cards
                Flex(
                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCard("Total", total, Colors.purpleAccent),
                    _buildStatCard("Completed", completed, Colors.greenAccent),
                    _buildStatCard("Scheduled", scheduled, Colors.blueAccent),
                    _buildStatCard("Cancelled", cancelled, Colors.redAccent),
                  ],
                ),

                // 📅 Weekly Appointment Insight (Animated)
                FutureBuilder(
                  future: FirebaseFirestore.instance
                      .collection('appointments')
                      .where('doctorId',
                          isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                              color: Colors.purpleAccent),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final now = DateTime.now();

                    final recentWeek = docs.where((d) {
                      final date = (d['appointmentDate'] as Timestamp).toDate();
                      return date.isAfter(now.subtract(const Duration(days: 7)));
                    }).length;

                    final prevWeek = docs.where((d) {
                      final date = (d['appointmentDate'] as Timestamp).toDate();
                      return date.isAfter(now.subtract(const Duration(days: 14))) &&
                          date.isBefore(now.subtract(const Duration(days: 7)));
                    }).length;

                    final diff = recentWeek - prevWeek;
                    final percentChange =
                        prevWeek == 0 ? 100 : ((diff / prevWeek) * 100).toInt();
                    final isPositive = diff >= 0;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B263B),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Weekly Performance",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 16),
                          ),

                          // 🔢 Animated Appointments Count
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: recentWeek.toDouble()),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutExpo,
                            builder: (context, value, _) => Text(
                              "Last 7 Days: ${value.toInt()} Appointments",
                              style: const TextStyle(
                                color: Colors.purpleAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          // 📈 Animated Percentage Change
                          Row(
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(scale: anim, child: child),
                                child: Icon(
                                  isPositive
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  key: ValueKey(isPositive),
                                  color: isPositive
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 6),
                              TweenAnimationBuilder<double>(
                                tween: Tween(
                                    begin: 0,
                                    end: percentChange.abs().toDouble()),
                                duration: const Duration(milliseconds: 900),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) => Text(
                                  "${value.toInt()}%",
                                  style: TextStyle(
                                    color: isPositive
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // 📊 Charts Row (Pie + Line)
                Flex(
                  direction: isTablet ? Axis.vertical : Axis.horizontal,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🥧 Pie Chart
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: EdgeInsets.only(
                            right: isTablet ? 0 : 16,
                            bottom: isTablet ? 16 : 0),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B263B),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Status Breakdown",
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 16),
                            Center(
                              child: AspectRatio(
                                aspectRatio: isMobile ? 1.1 : 1.5,
                                child: PieChart(
                                  PieChartData(
                                    sections: _getSections(),
                                    centerSpaceRadius: isMobile ? 45 : 60,
                                    sectionsSpace: 2,
                                    borderData: FlBorderData(show: false),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(child: _buildLegend()),
                          ],
                        ),
                      ),
                    ),

                    // 📈 Line Chart
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B263B),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Appointments Trend (Last 7 days)",
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 12),
                            AspectRatio(
                              aspectRatio: isMobile ? 1.2 : 2.1,
                              child: LineChart(
                                LineChartData(
                                  gridData: FlGridData(show: false),
                                  borderData: FlBorderData(show: false),
                                  titlesData: FlTitlesData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: List.generate(
                                          7,
                                          (i) => FlSpot(
                                              i.toDouble(), (i + 1) * 1.3)),
                                      isCurved: true,
                                      color: Colors.purpleAccent,
                                      barWidth: 3,
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: Colors.purpleAccent
                                            .withOpacity(0.25),
                                      ),
                                      dotData: FlDotData(show: true),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🟣 Pie Chart Sections
  List<PieChartSectionData> _getSections() {
    final totalValue = completed + scheduled + cancelled;
    if (totalValue == 0) {
      return [
        PieChartSectionData(
          value: 1,
          color: Colors.grey.shade700,
          title: 'No Data',
          titleStyle: const TextStyle(
              color: Colors.white70, fontWeight: FontWeight.bold),
        )
      ];
    }

    return [
      PieChartSectionData(
        value: completed.toDouble(),
        color: Colors.greenAccent,
        title: completed == 0 ? '' : 'Completed',
        titleStyle: const TextStyle(
            color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
      ),
      PieChartSectionData(
        value: scheduled.toDouble(),
        color: Colors.blueAccent,
        title: scheduled == 0 ? '' : 'Scheduled',
        titleStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      ),
      PieChartSectionData(
        value: cancelled.toDouble(),
        color: Colors.redAccent,
        title: cancelled == 0 ? '' : 'Cancelled',
        titleStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    ];
  }

  // 📦 Stat Cards
  Widget _buildStatCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF1B263B),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, val, _) => Text(
                val.toInt().toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 Legend Below Pie
  Widget _buildLegend() {
    final legends = [
      {'color': Colors.greenAccent, 'label': 'Completed'},
      {'color': Colors.blueAccent, 'label': 'Scheduled'},
      {'color': Colors.redAccent, 'label': 'Cancelled'},
    ];

    return Wrap(
      spacing: 20,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: legends
          .map(
            (item) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item['color'] as Color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item['label'] as String,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}