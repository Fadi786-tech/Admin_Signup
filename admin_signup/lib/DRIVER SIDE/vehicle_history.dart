import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VehicleHistory extends StatefulWidget {
  final String email;

  VehicleHistory({super.key, required this.email});

  @override
  State<VehicleHistory> createState() => _VehicleHistoryState();
}

class _VehicleHistoryState extends State<VehicleHistory> {
  int? driverid;
  List<dynamic> _assignedVehicles = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchDriverData();
  }

  Future<void> _fetchDriverData() async {
    try {
      // First get the driver ID
      final driverIdResponse = await http.get(
        Uri.parse('$vehicledriverurl/driver-id/${widget.email}'),
      );

      if (driverIdResponse.statusCode == 200) {
        final driverData = jsonDecode(driverIdResponse.body);
        setState(() {
          driverid = driverData['driverid'];
        });

        // Then get the assigned vehicles
        await _fetchAssignedVehicles();
      } else {
        setState(() {
          _errorMessage = 'Failed to load driver data';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAssignedVehicles() async {
    try {
      final response = await http.get(
        Uri.parse('$vehicledriverurl/assigned-vehicles/$driverid'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _assignedVehicles = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load assigned vehicles';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Assignment History'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : _assignedVehicles.isEmpty
                  ? const Center(child: Text('No vehicle assignments found'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Plate Number')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Model')),
                          DataColumn(label: Text('Year')),
                          DataColumn(label: Text('Assigned Date')),
                          DataColumn(label: Text('End Date')),
                        ],
                        rows: _assignedVehicles.map((vehicle) {
                          return DataRow(cells: [
                            DataCell(Text(vehicle['licenseplate'] ?? 'N/A')),
                            DataCell(Text(vehicle['vehicletype'] ?? 'N/A')),
                            DataCell(Text(vehicle['model'] ?? 'N/A')),
                            DataCell(
                                Text(vehicle['year']?.toString() ?? 'N/A')),
                            DataCell(Text(
                              vehicle['start_date'] != null
                                  ? DateTime.parse(vehicle['start_date'])
                                      .toLocal()
                                      .toString()
                                      .split(' ')[0]
                                  : 'N/A',
                            )),
                            DataCell(Text(
                              vehicle['end_date'] != null
                                  ? DateTime.parse(vehicle['end_date'])
                                      .toLocal()
                                      .toString()
                                      .split(' ')[0]
                                  : 'N/A',
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
    );
  }
}
