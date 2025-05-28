import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:admin_signup/Screens/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AddSpeedLimitArea extends StatefulWidget {
  const AddSpeedLimitArea({super.key});

  @override
  State<AddSpeedLimitArea> createState() => _AddSpeedLimitAreaState();
}

class _AddSpeedLimitAreaState extends State<AddSpeedLimitArea> {
  List<LatLng> polygonPoints = [];
  final TextEditingController areaNameController = TextEditingController();
  final TextEditingController speedLimitController = TextEditingController();
  final mapController = MapController();

  Future<void> saveSpeedLimitArea() async {
    final String areaName = areaNameController.text.trim();
    final double? speedLimit =
        double.tryParse(speedLimitController.text.trim());

    if (polygonPoints.length < 3 || areaName.isEmpty || speedLimit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Please complete the form and draw a valid polygon.")),
      );
      return;
    }

    final polygonCoordinates = polygonPoints
        .map((point) => [point.longitude, point.latitude])
        .toList();
    final geoJson = {
      "type": "Polygon",
      "coordinates": [polygonCoordinates]
    };

    final response = await http.post(
      Uri.parse('$apiurl/speedbounds'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "adminid": adminid,
        "areaname": areaName,
        "speedlimit": speedLimit,
        "boundarypoints": geoJson,
      }),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Speed Limit Area Added Successfully.")),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const Maindashboard(),
        ),
      );
    } else {
      print("Error: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Speed Limit Area")),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                center: LatLng(33.6844, 73.0479), // Default location
                zoom: 15,
                onTap: (tapPosition, point) {
                  setState(() {
                    polygonPoints.add(point);
                  });
                },
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
                        color: Colors.green.withOpacity(0.3),
                        borderColor: Colors.green,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: polygonPoints
                      .map((point) => Marker(
                            point: point,
                            width: 8,
                            height: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
                            ),
                          ))
                      .toList(),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: areaNameController,
                  decoration: InputDecoration(labelText: 'Area Name'),
                ),
                TextField(
                  controller: speedLimitController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Speed Limit (km/h)'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: saveSpeedLimitArea,
                  child: Text("Save Area"),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
