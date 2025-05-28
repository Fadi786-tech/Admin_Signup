import 'dart:convert';
import 'package:admin_signup/Geofence/geofence_list.dart';
import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:admin_signup/Screens/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeoFenceScreen extends StatefulWidget {
  const GeoFenceScreen({super.key});

  @override
  _GeoFenceScreenState createState() => _GeoFenceScreenState();
}

class _GeoFenceScreenState extends State<GeoFenceScreen> {
  List<LatLng> polygonPoints = [];
  TextEditingController nameController = TextEditingController();
  void _onTap(LatLng point) {
    setState(() {
      polygonPoints.add(point);
    });
  }

  Future<void> _saveGeofence() async {
    String geofenceName = nameController.text.trim();

    if (polygonPoints.length < 3 || geofenceName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Enter a name and select at least 3 points")),
      );
      return;
    }
    print(polygonPoints);
    final data = {
      "name": geofenceName,
      "boundaryPoints": polygonPoints
          .map((point) =>
              {"latitude": point.latitude, "longitude": point.longitude})
          .toList(),
    };

    try {
      final response = await http.post(
        Uri.parse("$apiUrl/create/${adminid}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Geofence saved successfully!")),
        );
        _clearGeofence();
        Navigator.push(context, MaterialPageRoute(builder: (context) {
          return Maindashboard();
        }));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save geofence")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _clearGeofence() {
    setState(() {
      polygonPoints.clear();
      nameController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Geofence"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearGeofence,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              center: const LatLng(33.6995, 73.0363),
              zoom: 12,
              onTap: (_, point) => _onTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
              ),
              if (polygonPoints.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: polygonPoints,
                      color: Colors.yellow.withOpacity(0.3),
                      borderColor: Colors.red,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: polygonPoints.map((point) {
                  return Marker(
                    point: point,
                    width: 30,
                    height: 30,
                    child: const Icon(
                      Icons.location_pin,
                      size: 30,
                      color: Colors.red,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          /// Bottom Section: Name Input & Save Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Geofence Name",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.edit_location_alt),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveGeofence,
                      child: const Text("Save Geofence"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
