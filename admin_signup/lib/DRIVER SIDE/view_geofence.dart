import 'dart:convert';
import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class ViewGeofence extends StatefulWidget {
  final int geoid;
  ViewGeofence({required this.geoid});

  @override
  _ViewGeofenceState createState() => _ViewGeofenceState();
}

class _ViewGeofenceState extends State<ViewGeofence> {
  List<LatLng> boundaryPoints = [];

  Future<void> fetchGeofencePoints() async {
    String url = "$vehicledriverurl/view-assigned-geofence/${widget.geoid}";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['success']) {
          List points = data['data'];
          setState(() {
            boundaryPoints = points.map<LatLng>((p) {
              return LatLng(
                double.parse(p['latitude'].toString()),
                double.parse(p['longitude'].toString()),
              );
            }).toList();

          });
        } else {
          print("Error: ${data['message']}");
        }
      } else {
        print("Error: ${response.body}");
      }
    } catch (e) {
      print("Exception: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    fetchGeofencePoints();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Geofence View")),
      body: boundaryPoints.isEmpty
          ? Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                center: boundaryPoints[0],
                zoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: 'com.example.yourapp',
                ),
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: boundaryPoints,
                      color: Colors.blue.withOpacity(0.3),
                      borderStrokeWidth: 3,
                      borderColor: Colors.blue,
                    )
                  ],
                ),
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: boundaryPoints,
                      color: Colors.red.withOpacity(0.3),
                      borderColor: Colors.red,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
