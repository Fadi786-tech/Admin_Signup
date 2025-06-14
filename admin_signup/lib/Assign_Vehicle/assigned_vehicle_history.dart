import 'package:admin_signup/Screens/login.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../Screens/MainDashboard.dart';

class AssignedVehiclesScreen extends StatefulWidget {
  @override
  _AssignedVehiclesScreenState createState() => _AssignedVehiclesScreenState();
}

class _AssignedVehiclesScreenState extends State<AssignedVehiclesScreen> {
  List<dynamic> vehicles = [];

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final response = await http
        .get(Uri.parse('$vehicledriverurl/past-assigned-vehicles/$adminid'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      setState(() {
        vehicles = data['data'];
      });
    } else {
      throw Exception('Failed to load data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Center(child: Text("Assigned Vehicles"))),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: [
              DataColumn(label: Text("Driver Name")),
              DataColumn(label: Text("Driver Licensenumber")),
              DataColumn(label: Text("Vehicle Model")),
              DataColumn(label: Text("License Plate")),
              DataColumn(label: Text("Start Date")),
              DataColumn(label: Text("End Date")),
              DataColumn(label: Text("Unassign Vehicle")),
            ],
            rows: vehicles.map((vehicle) {
              return DataRow(cells: [
                DataCell(Text(vehicle['driver_name'] ?? "N/A")),
                DataCell(Text(vehicle['driver_licensenumber'] ?? "N/A")),
                DataCell(Text(vehicle['model'] ?? "N/A")),
                DataCell(Text(vehicle['licenseplate'] ?? "N/A")),
                DataCell(Text(vehicle['start_date'] ?? "N/A")),
                DataCell(Text(vehicle['end_date'] ?? "N/A")),
                DataCell(ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black, // Background color
                  ),
                  onPressed: () async {
                    final response = await http.post(
                      Uri.parse('$vehicledriverurl/unassign-vehicle'),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({
                        'vehicleid': vehicle['vehicleid'],
                        'driverid': vehicle['driverid'],
                        'adminid': adminid,
                        'status': 'Active',
                      }),
                    );
                    if (response.statusCode == 200) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Vehicle unassigned successfully')),
                      );
                      fetchData(); // Refresh the data
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to unassign vehicle')),
                      );
                    }
                  },
                  child: Text(
                    "Unassign",
                    style: TextStyle(color: Colors.white),
                  ),
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
