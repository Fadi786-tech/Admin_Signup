import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:admin_signup/Screens/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vehicle Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: VehicleTrackingScreen(),
    );
  }
}

class Vehicle {
  final int vehicleId;
  final double latitude;
  final double longitude;
  final String timestamp;

  Vehicle({
    required this.vehicleId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      vehicleId: json['vehicle_id'],
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      timestamp: json['timestamp'],
    );
  }
}

class VehicleService {
  static Future<List<Vehicle>> fetchVehicles(int adminId) async {
    try {
      final response = await http.get(
        Uri.parse('$vehicledriverurl/trackall/adminside/$adminId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => Vehicle.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load vehicles: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

class VehicleTrackingScreen extends StatefulWidget {
  @override
  _VehicleTrackingScreenState createState() => _VehicleTrackingScreenState();
}

class _VehicleTrackingScreenState extends State<VehicleTrackingScreen> {
  final MapController _mapController = MapController();
  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  String _errorMessage = '';
  Timer? _refreshTimer;

  // Default map center (you can change this to your preferred location)
  final LatLng _defaultCenter = LatLng(33.6844, 73.0479); // Islamabad, Pakistan

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _loadVehicles();
    });
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final vehicles = await VehicleService.fetchVehicles(adminid);
      setState(() {
        _vehicles = vehicles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _centerMapOnVehicles() {
    if (_vehicles.isNotEmpty) {
      // Calculate bounds to fit all vehicles
      double minLat =
          _vehicles.map((v) => v.latitude).reduce((a, b) => a < b ? a : b);
      double maxLat =
          _vehicles.map((v) => v.latitude).reduce((a, b) => a > b ? a : b);
      double minLng =
          _vehicles.map((v) => v.longitude).reduce((a, b) => a < b ? a : b);
      double maxLng =
          _vehicles.map((v) => v.longitude).reduce((a, b) => a > b ? a : b);

      LatLng center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

      _mapController.move(center, 12.0);
    }
  }

  void _showAdminIdDialog() {
    TextEditingController controller =
        TextEditingController(text: adminid.toString());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Admin ID'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Admin ID',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                int? newAdminId = int.tryParse(controller.text);
                if (newAdminId != null && newAdminId > 0) {
                  setState(() {
                    adminid = newAdminId;
                  });
                  _loadVehicles();
                  Navigator.of(context).pop();
                }
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vehicle Tracker'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.admin_panel_settings),
            onPressed: _showAdminIdDialog,
            tooltip: 'Change Admin ID',
          ),
          IconButton(
            icon: Icon(Icons.center_focus_strong),
            onPressed: _centerMapOnVehicles,
            tooltip: 'Center on Vehicles',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadVehicles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Admin ID: $adminid | Vehicles: ${_vehicles.length}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // Error Message
          if (_errorMessage.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              color: Colors.red[50],
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),

          // Map
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 10.0,
                minZoom: 3.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.vehicle_tracker',
                  maxZoom: 19,
                ),
                MarkerLayer(
                  markers: _vehicles.map((vehicle) {
                    return Marker(
                      point: LatLng(vehicle.latitude, vehicle.longitude),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showVehicleInfo(vehicle),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.directions_car,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadVehicles,
        child: Icon(Icons.my_location),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        tooltip: 'Refresh Locations',
      ),
    );
  }

  void _showVehicleInfo(Vehicle vehicle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Vehicle ${vehicle.vehicleId}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Vehicle ID', vehicle.vehicleId.toString()),
              _buildInfoRow('Latitude', vehicle.latitude.toStringAsFixed(6)),
              _buildInfoRow('Longitude', vehicle.longitude.toStringAsFixed(6)),
              _buildInfoRow('Last Update', vehicle.timestamp),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _mapController.move(
                  LatLng(vehicle.latitude, vehicle.longitude),
                  15.0,
                );
                Navigator.of(context).pop();
              },
              child: Text('Center on Map'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
