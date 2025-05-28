import 'package:admin_signup/Screens/login.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../Screens/MainDashboard.dart';

class AssignedGeofencesScreen extends StatefulWidget {
  @override
  _AssignedGeofencesScreenState createState() =>
      _AssignedGeofencesScreenState();
}

class _AssignedGeofencesScreenState extends State<AssignedGeofencesScreen> {
  List<dynamic> geofences = [];

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final response =
        await http.get(Uri.parse('$apiUrl/past-assigned-geofences/$adminid'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      setState(() {
        geofences = data['data'];
      });
    } else {
      throw Exception('Failed to load data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Center(child: Text("Assigned Geofences"))),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: [
              DataColumn(label: Text("Geofence Name")),
              DataColumn(label: Text("Vehicle Licenseplate")),
              DataColumn(label: Text("Vehicle Model")),
              DataColumn(label: Text("Start Date")),
              DataColumn(label: Text("End Date")),
              DataColumn(label: Text("Status")),
            ],
            rows: geofences.map((geofence) {
              return DataRow(cells: [
                DataCell(Text(geofence['geofence_name'] ?? "N/A")),
                DataCell(Text(geofence['vehicle_licenseplate'] ?? "N/A")),
                DataCell(Text(geofence['model'] ?? "N/A")),
                DataCell(Text(geofence['start_date'] ?? "N/A")),
                DataCell(Text(geofence['end_date'] ?? "N/A")),
                DataCell(Text(geofence['status'] ?? "N/A")),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
