import 'dart:convert';
import 'package:admin_signup/Screens/WelcomeScreenAfterSignup.dart';
import 'package:admin_signup/Screens/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../Screens/MainDashboard.dart';
import 'assigned_vehicle_history.dart';

class AssignVehicleScreen extends StatefulWidget {
  const AssignVehicleScreen({super.key});

  @override
  State<AssignVehicleScreen> createState() => _AssignVehicleScreenState();
}

class _AssignVehicleScreenState extends State<AssignVehicleScreen> {
  String? selectedEmployee;
  String? selectedVehicle;
  DateTime? startDate;
  DateTime? endDate;

  List<String> vehicles = [];
  List<String> drivers = [];

  @override
  void initState() {
    super.initState();
    fetchDriversAndVehicles();
  }

  Future<void> fetchDriversAndVehicles() async {
    try {
      final response = await http.get(
        Uri.parse('$vehicledriverurl/getAvailableDriversVehicles/${adminid}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          drivers =
              (data['drivers'] as List?)?.map((d) => d.toString()).toList() ??
                  [];
          vehicles =
              (data['vehicles'] as List?)?.map((v) => v.toString()).toList() ??
                  [];
        });
      } else {
        _showErrorMessage('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorMessage('Connection error: $e');
    }
  }

  Future<void> assignVehicle() async {
    if (selectedEmployee == null ||
        selectedVehicle == null ||
        startDate == null) {
      _showErrorMessage('Please fill all required fields');
      return;
    }

    try {
      final Map<String, dynamic> requestBody = {
        'Name': selectedEmployee,
        'LicensePlate': selectedVehicle,
        'startDate': DateFormat('yyyy-MM-dd').format(startDate!),
        'adminid': adminid,
      };

      // Only add endDate if it's selected
      if (endDate != null) {
        requestBody['endDate'] = DateFormat('yyyy-MM-dd').format(endDate!);
      }

      final response = await http.post(
        Uri.parse('$vehicledriverurl/assignVehicle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        _showErrorMessage('Vehicle assigned successfully');
        setState(() {
          selectedEmployee = null;
          selectedVehicle = null;
          startDate = null;
          endDate = null;
        });
        fetchDriversAndVehicles(); // Refresh list after assignment
        // Navigator.push(context, MaterialPageRoute(builder: (context) {
        //   return Maindashboard();
        // }));
      } else {
        final errorData = jsonDecode(response.body);
        _showErrorMessage(
            'Failed to assign vehicle: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showErrorMessage('Connection error: $e');
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: const Text('Assign Vehicle')),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return AssignedVehiclesScreen();
                }));
              },
              child: Text(
                'History',
                style: TextStyle(color: Colors.white),
              ))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Driver',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: selectedEmployee,
              hint: const Text('Select Driver'),
              items: drivers.map((String driver) {
                return DropdownMenuItem<String>(
                  value: driver,
                  child: Text(driver),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedEmployee = value),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text('Vehicle',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: selectedVehicle,
              hint: const Text('Select Vehicle'),
              items: vehicles.map((String vehicle) {
                return DropdownMenuItem<String>(
                  value: vehicle,
                  child: Text(vehicle),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedVehicle = value),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text('Start Date *',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            TextFormField(
              readOnly: true,
              onTap: () => _selectDate(context, true),
              controller: TextEditingController(
                  text: startDate != null
                      ? DateFormat('MM/dd/yyyy').format(startDate!)
                      : ''),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 16),
            const Text('End Date (Optional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    onTap: () => _selectDate(context, false),
                    controller: TextEditingController(
                        text: endDate != null
                            ? DateFormat('MM/dd/yyyy').format(endDate!)
                            : ''),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                      hintText: 'Select end date (optional)',
                    ),
                  ),
                ),
                if (endDate != null)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        endDate = null;
                      });
                    },
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear end date',
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: assignVehicle,
                child:
                    const Text('Save', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
