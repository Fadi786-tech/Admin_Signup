import 'dart:convert';

import 'package:admin_signup/Geofence/geofence_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../Screens/MainDashboard.dart';

class EditGeofenceScreen extends StatefulWidget {
  final Map<String, dynamic> geofence;

  EditGeofenceScreen({required this.geofence});

  @override
  _EditGeofenceScreenState createState() => _EditGeofenceScreenState();
}

class _EditGeofenceScreenState extends State<EditGeofenceScreen> {
  late TextEditingController _nameController;
  List<LatLng> _boundaryPoints = [];
  List<LatLng> _previousBoundaryPoints = []; // Store previous state for undo

  Future<void> editGeofence(int geoid, String newName, List<List<double>> newBoundaryPoints) async {
    final response = await http.put(
      Uri.parse("$apiUrl/update-geofences/$geoid"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": newName,
        "boundary_points": newBoundaryPoints,
      }),
    );

    if (response.statusCode == 200) {
      _showSuccess("Geofence updated successfully");
      Navigator.push(context, MaterialPageRoute(builder: (context){
        return Maindashboard();
      }));
      //Navigator.canPop(context);
    } else {
      _showError("Failed to update geofence");
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.geofence['name']);

    _boundaryPoints = widget.geofence['boundary_points']
        ?.map<LatLng>((point) => LatLng(point[0], point[1]))
        ?.toList() ??
        [];
  }

  void _saveChanges() {
    int? geoid = widget.geofence["id"];

    if (geoid == null) {
      _showError("Geofence ID is missing");
      return;
    }

    editGeofence(geoid, _nameController.text,
        _boundaryPoints.map((p) => [p.latitude, p.longitude]).toList());
  }

  void _undoLastAction() {
    if (_previousBoundaryPoints.isNotEmpty) {
      setState(() {
        _boundaryPoints = List.from(_previousBoundaryPoints); // Restore previous state
        _previousBoundaryPoints.clear(); // Clear history after undo
      });
    } else {
      _showError("No action to undo");
    }
  }

  void _deleteAllBoundaryPoints() {
    if (_boundaryPoints.isNotEmpty) {
      setState(() {
        _previousBoundaryPoints = List.from(_boundaryPoints); // Save previous state
        _boundaryPoints.clear(); // Remove all points
      });
      _showSuccess("All boundary points removed");
    } else {
      _showError("No boundary points to delete");
    }
  }

  LatLng _calculatePolygonCenter(List<LatLng> points) {
    double sumLat = 0, sumLng = 0;
    for (var point in points) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }
    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Edit Geofence")),
      body: Column(
        children: [
          TextField(controller: _nameController, decoration: InputDecoration(labelText: "Geofence Name")),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                center: _boundaryPoints.isNotEmpty
                    ? _calculatePolygonCenter(_boundaryPoints)
                    : LatLng(0, 0),
                zoom: 14.0,
                onTap: (tapPosition, point) {
                  setState(() {
                    _previousBoundaryPoints = List.from(_boundaryPoints); // Save previous state
                    _boundaryPoints.add(point);
                  });
                },
              ),
              children: [
                TileLayer(urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"),
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _boundaryPoints,
                      color: Colors.blue.withOpacity(0.3),
                      borderColor: Colors.red,
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                onPressed: _saveChanges,
                child: Text("Save Changes", style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _undoLastAction,
                child: Text("Undo", style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                onPressed: _deleteAllBoundaryPoints,
                child: Text("Delete All", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
