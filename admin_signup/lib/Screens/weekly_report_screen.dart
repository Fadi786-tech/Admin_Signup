import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'MainDashboard.dart';

class WeeklyReportScreen extends StatefulWidget {
  final int driverVehicleId;

  const WeeklyReportScreen({Key? key, required this.driverVehicleId})
      : super(key: key);

  @override
  _WeeklyReportScreenState createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  Map<String, List<int>> eventData = {
    'Hard Braking': List.filled(7, 0),
    'Sharp Turns': List.filled(7, 0),
    'Over Speeding': List.filled(7, 0),
  };

  @override
  void initState() {
    super.initState();
    fetchWeeklyData();
  }

  Future<void> fetchWeeklyData() async {
    final response = await http.get(
        Uri.parse('$vehicledriverurl/weekly-events/${widget.driverVehicleId}'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print(data);
      setState(() {
        eventData = {
          'Hard Braking': List<int>.from(data['hard_braking']),
          'Sharp Turns': List<int>.from(data['sharp_turns']),
          'Over Speeding': List<int>.from(data['over_speeding']),
        };
      });
    }
  }

  Widget buildBarChart(List<int> data) {
    return BarChart(
      BarChartData(
        barGroups: List.generate(
            7,
            (index) => BarChartGroupData(
                x: index,
                barRods: [BarChartRodData(toY: data[index].toDouble())])),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                List<String> days = [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun'
                ];
                return Text(days[value.toInt()]);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget buildEventCard(String title, List<int> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${data.reduce((a, b) => a + b)} Past 7 days'),
            SizedBox(height: 10),
            SizedBox(height: 150, child: buildBarChart(data)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Driver Weekly Report')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: eventData.entries
              .map((entry) => buildEventCard(entry.key, entry.value))
              .toList(),
        ),
      ),
    );
  }
}
