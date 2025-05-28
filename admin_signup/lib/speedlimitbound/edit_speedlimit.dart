import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:admin_signup/Screens/MainDashboard.dart';

class EditSpeedlimit extends StatefulWidget {
  final int speedboundid;
  final String areaname;
  final double speedlimit;
  final Map<String, dynamic> polygon;

  const EditSpeedlimit({
    Key? key,
    required this.speedboundid,
    required this.areaname,
    required this.speedlimit,
    required this.polygon,
  }) : super(key: key);

  @override
  State<EditSpeedlimit> createState() => _EditSpeedlimitState();
}

class _EditSpeedlimitState extends State<EditSpeedlimit> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _areanameController;
  late TextEditingController _speedlimitController;

  bool isLoading = false;
  List<LatLng> polygonPoints = [];
  MapController mapController = MapController();
  double zoom = 10.0;
  late LatLng center;
  bool isDrawing = false;

  @override
  void initState() {
    super.initState();
    _areanameController = TextEditingController(text: widget.areaname);
    _speedlimitController =
        TextEditingController(text: widget.speedlimit.toString());

    // Parse polygon coordinates
    _loadPolygonPoints();
  }

  void _loadPolygonPoints() {
    try {
      if (widget.polygon['type'] == 'Polygon') {
        List<dynamic> coordinates = widget.polygon['coordinates'][0];
        polygonPoints = coordinates.map((coord) {
          // GeoJSON is [longitude, latitude]
          return LatLng(coord[1], coord[0]);
        }).toList();

        // Remove the last point if it's the same as the first (closed polygon in GeoJSON)
        if (polygonPoints.length > 1 &&
            polygonPoints.first.latitude == polygonPoints.last.latitude &&
            polygonPoints.first.longitude == polygonPoints.last.longitude) {
          polygonPoints.removeLast();
        }

        // Calculate center of polygon for map display
        if (polygonPoints.isNotEmpty) {
          double latSum = 0, lngSum = 0;
          for (var point in polygonPoints) {
            latSum += point.latitude;
            lngSum += point.longitude;
          }
          center = LatLng(
              latSum / polygonPoints.length, lngSum / polygonPoints.length);
        } else {
          // Default center if no points
          center = LatLng(0, 0);
        }
      }
    } catch (e) {
      print('Error parsing polygon data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading map data: $e')),
      );
      center = LatLng(0, 0);
    }
  }

  Future<void> _updateSpeedlimit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Convert polygonPoints back to GeoJSON format
      List<List<double>> coordinates = polygonPoints.map((point) {
        // GeoJSON uses [longitude, latitude]
        return [point.longitude, point.latitude];
      }).toList();

      // Close the polygon by adding the first point at the end
      if (coordinates.isNotEmpty) {
        coordinates.add(coordinates.first);
      }

      Map<String, dynamic> geometry = {
        "type": "Polygon",
        "coordinates": [coordinates]
      };

      final response = await http.put(
        Uri.parse('$apiurl/edit-speedboundarea/${widget.speedboundid}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'areaname': _areanameController.text,
          'speedlimit': double.parse(_speedlimitController.text),
          'boundarypoints': geometry
        }),
      );

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Speed limit area updated successfully')),
        );
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => Maindashboard()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to update speed limit area: ${response.body}')),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _areanameController.dispose();
    _speedlimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Speed Limit Area'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Speed Limit Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _areanameController,
                                decoration: const InputDecoration(
                                  labelText: 'Area Name',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter an area name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _speedlimitController,
                                decoration: const InputDecoration(
                                  labelText: 'Speed Limit (km/h)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a speed limit';
                                  }
                                  try {
                                    double speed = double.parse(value);
                                    if (speed <= 0) {
                                      return 'Speed limit must be greater than 0';
                                    }
                                  } catch (e) {
                                    return 'Please enter a valid number';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Area Boundary',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                height: 300,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: FlutterMap(
                                    mapController: mapController,
                                    options: MapOptions(
                                      center: center,
                                      zoom: zoom,
                                      interactiveFlags: InteractiveFlag.all,
                                      onTap: (tapPosition, latlng) {
                                        if (isDrawing) {
                                          setState(() {
                                            polygonPoints.add(latlng);
                                          });
                                        }
                                      },
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate:
                                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        subdomains: const ['a', 'b', 'c'],
                                      ),
                                      PolygonLayer(
                                        polygons: [
                                          Polygon(
                                            points: polygonPoints,
                                            color: Colors.blue.withOpacity(0.5),
                                            borderColor: Colors.blue,
                                            borderStrokeWidth: 3,
                                          ),
                                        ],
                                      ),
                                      MarkerLayer(
                                        markers: polygonPoints
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          int idx = entry.key;
                                          LatLng point = entry.value;
                                          return Marker(
                                            width: 20,
                                            height: 20,
                                            point: point,
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  (idx + 1).toString(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Tip: Tap "Clear & Redraw" to update the boundary on the map.',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  polygonPoints.clear();
                                  isDrawing = true;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                              ),
                              child: const Text(
                                'Clear & Redraw',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Expanded(
                          //   child: ElevatedButton(
                          //     onPressed: () {
                          //       setState(() {
                          //         isDrawing = false;
                          //       });
                          //     },
                          //     style: ElevatedButton.styleFrom(
                          //       backgroundColor: Colors.green,
                          //       padding:
                          //           const EdgeInsets.symmetric(vertical: 15),
                          //     ),
                          //     child: const Text(
                          //       'Done Drawing',
                          //       style: TextStyle(color: Colors.white),
                          //     ),
                          //   ),
                          // ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _updateSpeedlimit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                              ),
                              child: const Text(
                                'Update',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
