import 'dart:async';
import 'dart:convert';
import 'package:admin_signup/DRIVER%20SIDE/driver_login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Screens/MainDashboard.dart';
import '../Screens/weekly_report_screen.dart';

class DriverDetailsScreen extends StatefulWidget {
  const DriverDetailsScreen();

  @override
  _DriverDetailsScreenState createState() => _DriverDetailsScreenState();
}

class _DriverDetailsScreenState extends State<DriverDetailsScreen> {
  var dvid, id, picture, name, model, lp;
  String? driverEmail;
  LatLng? driverLocation;
  bool isDriverActive = false;
  List<Polygon> geofencePolygons = [];
  List<LatLng> routePoints = [];
  List<Map<String, dynamic>> violations = [];
  bool _showViolations = true;
  Timer? _timer;
  final MapController _mapController = MapController();

  // Store the map zoom level to prevent unwanted zooming
  double _mapZoom = 11.0;
  bool _initialPositionSet = false;
  DateTime? _lastLocationUpdate;

  @override
  void initState() {
    super.initState();
    fetchDriverDetails();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchDriverDetails() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    setState(() {
      dvid = pref.getInt('drivervehicleid');
      id = pref.getInt('id');
      picture = pref.getString('picture');
      name = pref.getString('name');
      model = pref.getString('model');
      lp = pref.getString('licenseno');
      driverEmail = pref.getString('email');
    });

    try {
      final response =
          await http.get(Uri.parse('$vehicledriverurl/inspect-driver/$id'));
      if (response.statusCode == 200) {
        print('Successfully loaded driver details');
        await fetchGeofences();
        await fetchViolations(); // Fetch violations when loading driver details
      } else {
        print('Failed to load driver details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching driver details: $e');
    }
  }

  Future<void> fetchViolations() async {
    try {
      if (dvid == null) return;

      final response = await http.get(
        Uri.parse('$vehicledriverurl/driver-violations/$dvid'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          violations = data
              .map((v) => {
                    'eventid': v['eventid'],
                    'eventtype': v['eventtype'],
                    'latitude': v['latitude']?.toDouble(),
                    'longitude': v['longitude']?.toDouble(),
                    'timestamp': v['timestamp'],
                    'violatedvalue': v['violatedvalue'],
                  })
              .toList();
        });
      } else {
        print('Failed to fetch violations: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching violations: $e');
    }
  }

  bool _parseDrivingStatus(dynamic drivingValue) {
    print(
        'Raw isdriving value: $drivingValue (type: ${drivingValue.runtimeType})');

    if (drivingValue is bool) {
      return drivingValue;
    } else if (drivingValue is String) {
      // Handle PostgreSQL text representation of boolean
      return drivingValue.toLowerCase() == 'true' ||
          drivingValue == 't' ||
          drivingValue == 'yes' ||
          drivingValue == 'y' ||
          drivingValue == '1';
    } else if (drivingValue is num) {
      // Convert numeric 1/0 to boolean
      return drivingValue != 0;
    }
    return false;
  }

  IconData _getViolationIcon(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'speeding':
        return Icons.speed;
      case 'harsh braking':
        return Icons.emergency;
      case 'harsh acceleration':
        return Icons.rocket_launch;
      case 'geofence violation':
        return Icons.fence;
      default:
        return Icons.warning;
    }
  }

  void _showViolationDetails(Map<String, dynamic> violation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Violation Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${violation['eventtype']}'),
            Text('Value: ${violation['violatedvalue']}'),
            Text('Time: ${violation['timestamp']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  //   // Zoom in button handler
  void _zoomIn() {
    _mapZoom += 1;
    if (driverLocation != null) {
      _mapController.move(driverLocation!, _mapZoom);
    }
  }

  // Zoom out button handler
  void _zoomOut() {
    _mapZoom -= 1;
    if (_mapZoom < 3) _mapZoom = 3;
    if (driverLocation != null) {
      _mapController.move(driverLocation!, _mapZoom);
    }
  }

  // Center map on driver
  void _centerOnDriver() {
    if (driverLocation != null) {
      _mapController.move(driverLocation!, _mapZoom);
    }
  }

  //   // Calculate distance between two coordinates (simple version)
  double _calculateDistance(LatLng point1, LatLng point2) {
    return (point1.latitude - point2.latitude).abs() +
        (point1.longitude - point2.longitude).abs();
  }

  // Clear route points
  void _clearRoute() {
    setState(() {
      routePoints.clear();
    });
  }

  Future<void> fetchGeofences() async {
    try {
      if (driverEmail == null) {
        print('Driver email is null, skipping geofence fetch');
        return;
      }

      final response = await http
          .get(Uri.parse('$vehicledriverurl/assigned-geofence/$driverEmail'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        //print('Geofences data from API: $data');
        if (data.isEmpty) {
          print('No geofences assigned to this vehicle');
          const SnackBar(
            content: Text('No geofences assigned to this vehicle'),
            duration: Duration(seconds: 2),
          ).show(context);
          return;
        }

        setState(() {
          geofencePolygons = data.map((geofence) {
            try {
              List<LatLng> points = [];

              if (geofence['coordinates'] is List) {
                points = (geofence['coordinates'] as List)
                    .map((point) {
                      if (point is List && point.length >= 2) {
                        return LatLng(
                            point[0] is num ? point[0].toDouble() : 0.0,
                            point[1] is num ? point[1].toDouble() : 0.0);
                      }
                      return null;
                    })
                    .where((point) => point != null)
                    .cast<LatLng>()
                    .toList();
              }

              return Polygon(
                points: points,
                color: Colors.blue.withOpacity(0.3),
                borderColor: Colors.blue,
                borderStrokeWidth: 2,
              );
            } catch (e) {
              print('Error parsing geofence: $e');
              return Polygon(
                points: [],
                color: Colors.blue.withOpacity(0.3),
                borderColor: Colors.blue,
                borderStrokeWidth: 2,
              );
            }
          }).toList();
        });
      } else {
        print('Failed to fetch geofences: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error fetching geofences: $e');
    }
  }

  void _startLocationUpdates() {
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      fetchDriverLocation();
    });
  }

  var speed;
  Future<void> fetchDriverLocation() async {
    try {
      if (id == null) {
        print('Driver ID is null, skipping location fetch');
        return;
      }

//      print('Fetching location for driver ID: $id');
      final response =
          await http.get(Uri.parse('$vehicledriverurl/live-location/$id'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        //print('Location data from API: $data');

        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          final newLocation = LatLng(
              data['latitude'] is num ? data['latitude'].toDouble() : 0.0,
              data['longitude'] is num ? data['longitude'].toDouble() : 0.0);

          // Parse the driving status - handle different possible data types
          bool isDriving = _parseDrivingStatus(data['isdriving']);
          speed = data['speed'] is num
              ? data['speed'].toDouble()
              : (data['speed'] is String
                  ? double.tryParse(data['speed'])
                  : 0.0);
          // Parse timestamp and check if update is recent
          DateTime? lastUpdate;
          if (data.containsKey('lastUpdated')) {
            try {
              lastUpdate = DateTime.parse(data['lastUpdated']);
            } catch (e) {
              print('Error parsing timestamp: $e');
            }
          }

          // Check if update is recent (within 5 minutes)
          bool isRecentUpdate = false;
          if (lastUpdate != null) {
            DateTime now = DateTime.now();
            Duration difference = now.difference(lastUpdate);
            isRecentUpdate = difference.inMinutes < 5;
            print('Last update was ${difference.inMinutes} minutes ago');
          }

          setState(() {
            driverLocation = newLocation;
            _lastLocationUpdate = lastUpdate;

            // Only consider driver active if they're driving AND the update is recent
            isDriverActive = isDriving && isRecentUpdate;

            // Only add new location to route if driver is active and location changed
            if (isDriverActive && driverLocation != null) {
              if (routePoints.isEmpty ||
                  _calculateDistance(routePoints.last, driverLocation!) >
                      0.00005) {
                // Only add if moved a bit
                routePoints.add(driverLocation!);
                // Only keep last 100 points to avoid memory issues
                if (routePoints.length > 100) {
                  routePoints.removeAt(0);
                }
              }
            }
          });

          // Set initial map position only once
          if (!_initialPositionSet && driverLocation != null) {
            _mapController.move(driverLocation!, _mapZoom);
            _initialPositionSet = true;
          }
          // For subsequent updates, only move the map if driver is active, but keep same zoom
          else if (isDriverActive && driverLocation != null) {
            // Get current zoom to maintain it
            _mapZoom = _mapController.camera.zoom;
            _mapController.move(driverLocation!, _mapZoom);
          }
        } else {
          print('Location data is missing latitude or longitude');
        }
      } else {
        print('Failed to fetch live location: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error fetching location: $e');
      print('Stack trace: ${e is Error ? e.stackTrace : "N/A"}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Driver Details"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              fetchDriverLocation();
              fetchViolations(); // Refresh violations when button is pressed
            },
            tooltip: "Refresh Location",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... [keep all existing widgets until the FlutterMap] ...

            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter:
                            driverLocation ?? const LatLng(33.6995, 73.0363),
                        initialZoom: _mapZoom,
                        onMapEvent: (event) {
                          if (event.source == MapEventSource.mapController ||
                              event.source ==
                                  MapEventSource.flingAnimationController ||
                              event.source ==
                                  MapEventSource
                                      .doubleTapZoomAnimationController) {
                            _mapZoom = _mapController.camera.zoom;
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        PolygonLayer(polygons: geofencePolygons),
                        if (routePoints.isNotEmpty && routePoints.length > 1)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: routePoints,
                                color: Colors.deepPurple,
                                strokeWidth: 4.0,
                              ),
                            ],
                          ),
                        // Violation markers layer
                        if (_showViolations)
                          MarkerLayer(
                            markers: violations.map((violation) {
                              return Marker(
                                width: 40.0,
                                height: 40.0,
                                point: LatLng(violation['latitude'],
                                    violation['longitude']),
                                child: GestureDetector(
                                  onTap: () => _showViolationDetails(violation),
                                  child: Container(
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: Colors.red, width: 2),
                                    ),
                                    child: Icon(
                                      _getViolationIcon(violation['eventtype']),
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        if (driverLocation != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                width: 50.0,
                                height: 50.0,
                                point: driverLocation!,
                                child: Container(
                                  child: Icon(
                                    isDriverActive
                                        ? Icons.directions_car_filled
                                        : Icons.directions_car_outlined,
                                    color: isDriverActive
                                        ? Colors.green
                                        : Colors.red,
                                    size: 36,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Map control buttons
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      children: [
                        // Zoom controls
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              IconButton(
                                icon: Icon(Icons.add),
                                onPressed: _zoomIn,
                                tooltip: 'Zoom in',
                              ),
                              Divider(height: 1, thickness: 1),
                              IconButton(
                                icon: Icon(Icons.remove),
                                onPressed: _zoomOut,
                                tooltip: 'Zoom out',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10),
                        // Center on driver button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(Icons.my_location),
                            onPressed: _centerOnDriver,
                            tooltip: 'Center on driver',
                          ),
                        ),
                        SizedBox(height: 10),
                        // Clear route points button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(Icons.clear_all),
                            onPressed: _clearRoute,
                            tooltip: 'Clear route',
                          ),
                        ),
                        SizedBox(height: 10),
                        // Toggle violations button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              _showViolations
                                  ? Icons.warning_amber
                                  : Icons.warning_amber_outlined,
                              color: _showViolations ? Colors.red : Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _showViolations = !_showViolations;
                              });
                            },
                            tooltip: 'Toggle violations',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Map legend
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.directions_car_filled,
                                  color: Colors.green, size: 20),
                              SizedBox(width: 5),
                              Text('Active'),
                            ],
                          ),
                          SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(Icons.directions_car_outlined,
                                  color: Colors.red, size: 20),
                              SizedBox(width: 5),
                              Text('Inactive'),
                            ],
                          ),
                          SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                width: 20,
                                height: 3,
                                color: Colors.deepPurple,
                              ),
                              SizedBox(width: 5),
                              Text('Route'),
                            ],
                          ),
                          SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                width: 15,
                                height: 15,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.3),
                                  border: Border.all(color: Colors.blue),
                                ),
                              ),
                              SizedBox(width: 5),
                              Text('Geofence'),
                            ],
                          ),
                          SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red, size: 20),
                              SizedBox(width: 5),
                              Text('Violation'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Text(
                    'Current Speed: ${speed?.toStringAsFixed(2) ?? 'N/A'} km/h',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            // Weekly Report Link
            InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return WeeklyReportScreen(
                    driverVehicleId: dvid,
                  );
                }));
              },
              child: Card(
                elevation: 2,
                margin: EdgeInsets.symmetric(vertical: 10),
                child: ListTile(
                  leading: Icon(Icons.bar_chart, color: Colors.blue),
                  title: Text(
                    'Weekly Report',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on SnackBar {
  void show(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(this);
  }
}
