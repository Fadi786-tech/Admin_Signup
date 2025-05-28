import 'dart:convert';
import 'package:admin_signup/Assign_Geofence/assign_geofence_history.dart';
import 'package:admin_signup/Screens/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../Screens/MainDashboard.dart';

class AssignGeofenceScreen extends StatefulWidget {
  const AssignGeofenceScreen({super.key});

  @override
  State<AssignGeofenceScreen> createState() => _AssignGeofenceScreenState();
}

class _AssignGeofenceScreenState extends State<AssignGeofenceScreen> {
  String? selectedGeofence;
  String? selectedVehicle;
  String allowedOutside = 'Restricted'; // Default value
  DateTime? startDate;
  DateTime? endDate;

  List<String> vehicles = [];
  List<String> geofences = [];
  List<String> allowedOutsideOptions = [
    'Restricted',
    'Allowed'
  ]; // Dropdown options
  @override
  void initState() {
    super.initState();
    fetchGeofencesAndVehicles();
  }

  Future<void> assignVehicle() async {
    if (selectedGeofence == null ||
        selectedVehicle == null ||
        startDate == null ||
        endDate == null) {
      _showErrorMessage("Please fill in all fields before assigning.");
      return;
    }

    final Map<String, dynamic> requestBody = {
      "geofence": selectedGeofence,
      "vehicle": selectedVehicle,
      "start_date": DateFormat('yyyy-MM-dd').format(startDate!),
      "end_date": DateFormat('yyyy-MM-dd').format(endDate!),
      "allowed_outside": allowedOutside,
    };

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/assignGeofenceToVehicle/$adminid'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Geofence assigned successfully!")));
        Navigator.push(context, MaterialPageRoute(builder: (context) {
          return Maindashboard();
        }));
      } else {
        _showErrorMessage("Failed to assign geofence: ${response.body}");
      }
    } catch (e) {
      _showErrorMessage("Error assigning geofence: $e");
    }
  }

  Future<void> fetchGeofencesAndVehicles() async {
    try {
      final response = await http.get(
        Uri.parse('$vehicledriverurl/getAvailableGeofencesVehicles/$adminid'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          geofences =
              (data['geofences'] as List?)?.whereType<String>().toList() ?? [];
          vehicles =
              (data['vehicles'] as List?)?.whereType<String>().toList() ?? [];
        });
      } else {
        _showErrorMessage('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorMessage('Connection error: $e');
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Geofence'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) {
                return AssignedGeofencesScreen();
              }));
            },
            child: Text('History', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Geofence',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: selectedGeofence,
              hint: const Text('Select Geofence'),
              items: geofences.map((String geofence) {
                return DropdownMenuItem<String>(
                  value: geofence,
                  child: Text(geofence),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedGeofence = value;
                });
              },
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
              onChanged: (value) {
                setState(() {
                  selectedVehicle = value;
                });
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text('Allowed Outside',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: allowedOutside,
              items: allowedOutsideOptions.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  allowedOutside = value!;
                });
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text('Start Date',
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
            const Text('End Date',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            TextFormField(
              readOnly: true,
              onTap: () => _selectDate(context, false),
              controller: TextEditingController(
                  text: endDate != null
                      ? DateFormat('MM/dd/yyyy').format(endDate!)
                      : ''),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: assignVehicle,
                child:
                    const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
