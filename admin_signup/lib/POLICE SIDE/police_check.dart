// Flutter Screen - LicensePlateScreen.dart
import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class LicensePlateScreen extends StatefulWidget {
  @override
  _LicensePlateScreenState createState() => _LicensePlateScreenState();
}

class _LicensePlateScreenState extends State<LicensePlateScreen> {
  TextEditingController _licensePlateController = TextEditingController();
  Map<String, dynamic>? vehicleData;
  bool isLoading = false;
  DateTime? startDate;
  DateTime? endDate;

  Future<void> fetchVehicleDetails() async {
    final licensePlate = _licensePlateController.text.trim();
    if (licensePlate.isEmpty || startDate == null || endDate == null) return;

    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(
            '$vehicledriverurl/police-check-vehicle/$licensePlate?startDate=${startDate!.toIso8601String()}&endDate=${endDate!.toIso8601String()}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          vehicleData = json.decode(response.body);
        });
      } else {
        setState(() {
          vehicleData = {'error': 'No data found'};
        });
      }
    } catch (e) {
      setState(() {
        vehicleData = {'error': 'Failed to fetch data'};
      });
    }
    setState(() => isLoading = false);
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
      appBar: AppBar(title: Text('Check Vehicle Details')),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _licensePlateController,
                decoration: InputDecoration(
                  labelText: 'Enter License Plate',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              _buildDatePicker('Start Date', true),
              SizedBox(height: 10),
              _buildDatePicker('End Date', false),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: fetchVehicleDetails,
                child: Text('Fetch Details'),
              ),
              SizedBox(height: 20),
              if (isLoading) CircularProgressIndicator(),
              if (vehicleData != null) ...[
                if (vehicleData!['error'] != null)
                  Text(vehicleData!['error'],
                      style: TextStyle(color: Colors.red)),
                if (vehicleData!['error'] == null) ...[
                  ListTile(
                    title: Text('Driver: ${vehicleData!['name']}'),
                    subtitle: Text(
                        'Vehicle Model: ${vehicleData!['model']}\nLicense Plate: ${vehicleData!['licensePlate']}\nViolations:'),
                  ),
                  ...vehicleData!['violations'].map((v) => Text(
                      '${v['eventtype']}: ${v['violatedvalue']} : ${v['timestamp']}')),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, bool isStartDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        TextFormField(
          readOnly: true,
          onTap: () => _selectDate(context, isStartDate),
          controller: TextEditingController(
              text: (isStartDate ? startDate : endDate) != null
                  ? DateFormat('MM/dd/yyyy')
                      .format((isStartDate ? startDate : endDate)!)
                  : ''),
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today),
          ),
        ),
      ],
    );
  }
}
