import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ViewSpeedlimitarea extends StatefulWidget {
  var speedboundid;
  ViewSpeedlimitarea({super.key, this.speedboundid});

  @override
  State<ViewSpeedlimitarea> createState() => _ViewSpeedlimitareaState();
}

class _ViewSpeedlimitareaState extends State<ViewSpeedlimitarea> {
  List<LatLng> polygonPoints = [];
  double speedLimit = 0.0;
  String areaName = "";

  @override
  void initState() {
    super.initState();
    fetchSpeedZone();
  }

  Future<void> fetchSpeedZone() async {
    final url = Uri.parse("$apiurl/speedzone/${widget.speedboundid}");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final geoJson = data['boundarypoints']; // No jsonDecode
      speedLimit = double.parse(data['speedlimit'].toString());
      areaName = data['areaname'];

      final coords = geoJson['coordinates'][0]; // Correct for Polygon
      polygonPoints = coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();

      setState(() {});
    } else {
      print("Failed to load zone: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (polygonPoints.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Speed Limit Area')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Speed Limit Area')),
      body: FlutterMap(
        options: MapOptions(
          center: polygonPoints[0],
          zoom: 16,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: const ['a', 'b', 'c'],
          ),
          PolygonLayer(
            polygons: [
              Polygon(
                points: polygonPoints,
                color: Colors.blue.withOpacity(0.3),
                borderColor: Colors.blue,
                borderStrokeWidth: 2,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: polygonPoints[0],
                width: 200,
                height: 60,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        areaName,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Speed Limit: ${speedLimit.toStringAsFixed(0)} km/h',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
