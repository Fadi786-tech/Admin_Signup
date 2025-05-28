import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ViewGeofenceScreen extends StatelessWidget {
  final Map<String, dynamic> geofence;

  ViewGeofenceScreen({required this.geofence});

  @override
  Widget build(BuildContext context) {
    // Ensure boundary_points exists and is not null
    List<dynamic>? rawCoordinates = geofence['boundary_points'];

    List<LatLng> polygonPoints = rawCoordinates != null
        ? rawCoordinates.map((coord) => LatLng(coord[0], coord[1])).toList()
        : []; // If null, use an empty list to prevent errors

    return Scaffold(
      appBar: AppBar(
        title: Text(geofence['name'] ?? "Geofence"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: polygonPoints.isEmpty
          ? Center(child: Text("No geofence data available"))
          : FlutterMap(
        options: MapOptions(
          center: polygonPoints.first,
          zoom: 14.0,
        ),
        children: [
          TileLayer(
            urlTemplate:
            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          ),
          PolygonLayer(
            polygons: [
              Polygon(
                points: polygonPoints,
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
