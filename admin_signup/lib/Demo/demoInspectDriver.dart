import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:admin_signup/DRIVER%20SIDE/driver_login.dart';
import 'package:admin_signup/Track/Inspect_Driver.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Screens/MainDashboard.dart';
import '../Screens/weekly_report_screen.dart';

// Data models for simulation
class RoutePoint {
  final LatLng position;
  final double speed; // km/h
  final double angle; // degrees
  final String name; // Point name/description
  final DateTime timestamp;

  RoutePoint({
    required this.position,
    required this.speed,
    required this.angle,
    required this.name,
    required this.timestamp,
  });
}

class SimulationViolation {
  final String type;
  final LatLng position;
  final DateTime timestamp;
  final String description;
  final double value;
  //final String severity; // 'low', 'medium', 'high'

  SimulationViolation({
    required this.type,
    required this.position,
    required this.timestamp,
    required this.description,
    required this.value,
    //required this.severity,
  });
}

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

  // Simulation variables
  List<RoutePoint> _simulationRoute = [];
  bool _isDefiningRoute = false;
  bool _isSimulationRunning = false;
  int _currentRouteIndex = 0;
  Timer? _simulationTimer;
  List<SimulationViolation> _simulationViolations = [];
  double _currentSpeed = 0.0;
  double _previousSpeed = 0.0;
  double _currentAngle = 0.0;
  double _previousAngle = 0.0;
  LatLng? _tempRoutePoint;

  // Speed and geofence limits for violation detection
  double _speedLimit = 60.0; // km/h
  double _hardBrakingThreshold = -1.5; // km/h change per second
  double _sharpTurnThreshold = 45.0; // degrees change
  bool _isInsideGeofence = true;

  @override
  void initState() {
    super.initState();
    fetchDriverDetails();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _simulationTimer?.cancel();
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
        //await fetchViolations();
      } else {
        print('Failed to load driver details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching driver details: $e');
    }
  }

  // Future<void> fetchViolations() async {
  //   try {
  //     if (dvid == null) return;

  //     final response = await http.get(
  //       Uri.parse('$vehicledriverurl/driver-violations/$dvid'),
  //     );

  //     if (response.statusCode == 200) {
  //       final List<dynamic> data = json.decode(response.body);
  //       setState(() {
  //         violations = data
  //             .map((v) => {
  //                   'eventid': v['eventid'],
  //                   'eventtype': v['eventtype'],
  //                   'latitude': v['latitude']?.toDouble(),
  //                   'longitude': v['longitude']?.toDouble(),
  //                   'timestamp': v['timestamp'],
  //                   'violatedvalue': v['violatedvalue'],
  //                 })
  //             .toList();
  //       });
  //     } else {
  //       print('Failed to fetch violations: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     print('Error fetching violations: $e');
  //   }
  // }

  bool _parseDrivingStatus(dynamic drivingValue) {
    print(
        'Raw isdriving value: $drivingValue (type: ${drivingValue.runtimeType})');

    if (drivingValue is bool) {
      return drivingValue;
    } else if (drivingValue is String) {
      return drivingValue.toLowerCase() == 'true' ||
          drivingValue == 't' ||
          drivingValue == 'yes' ||
          drivingValue == 'y' ||
          drivingValue == '1';
    } else if (drivingValue is num) {
      return drivingValue != 0;
    }
    return false;
  }

  IconData _getViolationIcon(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'speeding':
      case 'overspeeding':
        return Icons.speed;
      case 'harsh braking':
      case 'hardbraking':
        return Icons.emergency;
      case 'harsh acceleration':
        return Icons.rocket_launch;
      case 'sharp turn':
      case 'sharpturn':
        return Icons.turn_right;
      case 'geofence violation':
        return Icons.fence;
      default:
        return Icons.warning;
    }
  }

  Color _getViolationColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.yellow.shade700;
      default:
        return Colors.red;
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

  void _showRoutePointDetails(RoutePoint point, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Route Point Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Point: ${point.name}'),
            Text('Index: ${index + 1}'),
            Text('Speed: ${point.speed.toStringAsFixed(1)} km/h'),
            Text('Angle: ${point.angle.toStringAsFixed(1)}°'),
            Text('Latitude: ${point.position.latitude.toStringAsFixed(6)}'),
            Text('Longitude: ${point.position.longitude.toStringAsFixed(6)}'),
            Text('Created: ${point.timestamp.toString().substring(0, 19)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editRoutePoint(index);
            },
            child: Text('Edit'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRoutePoint(index);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _editRoutePoint(int index) {
    final point = _simulationRoute[index];
    final speedController = TextEditingController(text: point.speed.toString());
    final angleController = TextEditingController(text: point.angle.toString());
    final nameController = TextEditingController(text: point.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Route Point'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Point Name',
                hintText: 'Enter point name',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: speedController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Speed (km/h)',
                hintText: 'Enter speed',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: angleController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Angle (degrees)',
                hintText: 'Enter angle (0-360)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final speed =
                  double.tryParse(speedController.text) ?? point.speed;
              final angle =
                  double.tryParse(angleController.text) ?? point.angle;
              final name = nameController.text.isNotEmpty
                  ? nameController.text
                  : point.name;

              setState(() {
                _simulationRoute[index] = RoutePoint(
                  position: point.position,
                  speed: speed,
                  angle: angle,
                  name: name,
                  timestamp: point.timestamp,
                );
              });

              Navigator.pop(context);
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteRoutePoint(int index) {
    setState(() {
      _simulationRoute.removeAt(index);
      if (routePoints.length > index) {
        routePoints.removeAt(index);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Route point deleted')),
    );
  }

  void _showAllRoutePoints() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          height: 400,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Route Points (${_simulationRoute.length})',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _simulationRoute.length,
                  itemBuilder: (context, index) {
                    final point = _simulationRoute[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text('${index + 1}'),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      title: Text(point.name),
                      subtitle: Text(
                        'Speed: ${point.speed.toStringAsFixed(1)} km/h, '
                        'Angle: ${point.angle.toStringAsFixed(1)}°',
                      ),
                      trailing: Icon(Icons.info_outline),
                      onTap: () {
                        Navigator.pop(context);
                        _showRoutePointDetails(point, index);
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _zoomIn() {
    _mapZoom += 1;
    if (driverLocation != null) {
      _mapController.move(driverLocation!, _mapZoom);
    }
  }

  void _zoomOut() {
    _mapZoom -= 1;
    if (_mapZoom < 3) _mapZoom = 3;
    if (driverLocation != null) {
      _mapController.move(driverLocation!, _mapZoom);
    }
  }

  void _centerOnDriver() {
    if (driverLocation != null) {
      _mapController.move(driverLocation!, _mapZoom);
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    return (point1.latitude - point2.latitude).abs() +
        (point1.longitude - point2.longitude).abs();
  }

  void _clearRoute() {
    setState(() {
      routePoints.clear();
      _simulationRoute.clear();
      _simulationViolations.clear();
    });
  }

  // Simulation methods
  void _startDefiningRoute() {
    setState(() {
      _isDefiningRoute = true;
      _simulationRoute.clear();
      _simulationViolations.clear();
      routePoints.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tap on the map to define route points'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _stopDefiningRoute() {
    setState(() {
      _isDefiningRoute = false;
    });
  }

  void _onMapTap(LatLng position) {
    if (_isDefiningRoute) {
      setState(() {
        _tempRoutePoint = position;
      });
      _showSpeedAngleDialog(position);
    }
  }

  void _showSpeedAngleDialog(LatLng position) {
    final speedController = TextEditingController(text: '50');
    final angleController = TextEditingController(text: '0');
    final nameController =
        TextEditingController(text: 'Point ${_simulationRoute.length + 1}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Route Point Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Point Name',
                hintText: 'Enter point name',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: speedController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Speed (km/h)',
                hintText: 'Enter speed',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: angleController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Angle (degrees)',
                hintText: 'Enter angle (0-360)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final speed = double.tryParse(speedController.text) ?? 50.0;
              final angle = double.tryParse(angleController.text) ?? 0.0;
              final name = nameController.text.isNotEmpty
                  ? nameController.text
                  : 'Point ${_simulationRoute.length + 1}';

              setState(() {
                _simulationRoute.add(RoutePoint(
                  position: position,
                  speed: speed,
                  angle: angle,
                  name: name,
                  timestamp: DateTime.now(),
                ));
                routePoints.add(position);
              });

              Navigator.pop(context);
            },
            child: Text('Add Point'),
          ),
        ],
      ),
    );
  }

  void _startSimulation() {
    if (_simulationRoute.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please define a route first')),
      );
      return;
    }

    setState(() {
      _isSimulationRunning = true;
      _currentRouteIndex = 0;
      driverLocation = _simulationRoute[0].position;
      _currentSpeed = _simulationRoute[0].speed;
      _previousSpeed = _currentSpeed;
      _currentAngle = _simulationRoute[0].angle;
      _previousAngle = _currentAngle;
      isDriverActive = true;
      _simulationViolations.clear(); // Clear previous violations
    });

    _simulationTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      _updateSimulation();
    });
  }

  void _stopSimulation() {
    setState(() {
      _isSimulationRunning = false;
      isDriverActive = false;
    });
    _simulationTimer?.cancel();
  }

  void _updateSimulation() {
    if (_currentRouteIndex >= _simulationRoute.length - 1) {
      _stopSimulation();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Simulation completed')),
      );
      return;
    }

    setState(() {
      _previousSpeed = _currentSpeed;
      _previousAngle = _currentAngle;

      _currentRouteIndex++;
      final currentPoint = _simulationRoute[_currentRouteIndex];
      driverLocation = currentPoint.position;
      _currentSpeed = currentPoint.speed;
      _currentAngle = currentPoint.angle;

      // Check for violations at current point
      _checkViolations(currentPoint);
    });

    // Move map to follow vehicle
    _mapController.move(driverLocation!, _mapZoom);
  }

// Add this method to your _DriverDetailsScreenState class
  double getDynamicGyroAngleThreshold(double speed) {
    // For Sedan - dynamic threshold based on speed
    if (speed <= 20) return 80;
    if (speed > 20 && speed <= 40) return 60;
    if (speed > 40 && speed <= 60) return 45;
    if (speed > 60 && speed <= 80) return 35;
    if (speed > 80 && speed <= 100) return 25;
    if (speed > 100 && speed <= 120) return 20;
    return 15;
  }

// Updated _checkViolations method - replace the sharp turn section
  void _checkViolations(RoutePoint point) {
    String severity = 'medium';

    // Check overspeeding violation
    if (point.speed > _speedLimit) {
      severity = point.speed > _speedLimit * 1.5
          ? 'high'
          : point.speed > _speedLimit * 1.2
              ? 'medium'
              : 'low';

      _addSimulationViolation(
        'Overspeeding',
        point.position,
        'Speed exceeded: ${point.speed.toStringAsFixed(1)} km/h (limit: $_speedLimit km/h)',
        point.speed - _speedLimit,
      );
    }

    // Check hard braking using deceleration formula
    double _hardBrakingThreshold = 1.5; // m/s²
    double _simulationTimeInterval = 1.0; // seconds

    double currentSpeedMs = point.speed * (1000.0 / 3600.0); // km/h to m/s
    double previousSpeedMs = _previousSpeed * (1000.0 / 3600.0); // km/h to m/s

    double deltaVelocity = currentSpeedMs - previousSpeedMs;
    double deceleration = deltaVelocity / _simulationTimeInterval;

    if (deceleration < -_hardBrakingThreshold) {
      double decelerationMagnitude = deceleration.abs();

      _addSimulationViolation(
          'HardBraking',
          point.position,
          'Hard braking detected: ${decelerationMagnitude.toStringAsFixed(2)} m/s² deceleration',
          decelerationMagnitude);
    }

    // Check sharp turn with dynamic threshold based on speed
    double angleDifference = (point.angle - _previousAngle).abs();
    // Handle angle wrap-around (e.g., 359° to 1°)
    if (angleDifference > 180) {
      angleDifference = 360 - angleDifference;
    }

    // Get dynamic threshold based on current speed
    double dynamicSharpTurnThreshold =
        getDynamicGyroAngleThreshold(point.speed);

    if (angleDifference > dynamicSharpTurnThreshold) {
      // Determine severity based on how much the angle exceeds the dynamic threshold
      severity = angleDifference > dynamicSharpTurnThreshold * 2
          ? 'high'
          : angleDifference > dynamicSharpTurnThreshold * 1.5
              ? 'medium'
              : 'low';

      _addSimulationViolation(
        'SharpTurn',
        point.position,
        'Sharp turn detected: ${angleDifference.toStringAsFixed(1)}° change (threshold: ${dynamicSharpTurnThreshold.toStringAsFixed(1)}° at ${point.speed.toStringAsFixed(1)} km/h)',
        angleDifference,
      );
    }

    // Check geofence violation
    bool insideAnyGeofence = false;
    for (var polygon in geofencePolygons) {
      if (_isPointInPolygon(point.position, polygon.points)) {
        insideAnyGeofence = true;
        break;
      }
    }

    if (!insideAnyGeofence && geofencePolygons.isNotEmpty) {
      _addSimulationViolation(
        'Geofence Violation',
        point.position,
        'Vehicle outside designated area',
        0.0,
      );
    }
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].latitude;
      final yi = polygon[i].longitude;
      final xj = polygon[j].latitude;
      final yj = polygon[j].longitude;

      if (((yi > point.longitude) != (yj > point.longitude)) &&
          (point.latitude <
              (xj - xi) * (point.longitude - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  void _addSimulationViolation(
      String type, LatLng position, String description, double value) {
    //, String severity) {
    setState(() {
      _simulationViolations.add(
        SimulationViolation(
          type: type,
          position: position,
          timestamp: DateTime.now(),
          description: description,
          value: value,
          //severity: severity,
        ),
      );
    });
  }

  void _showSimulationViolationDetails(SimulationViolation violation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Simulation Violation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${violation.type}',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            // Text('Severity: ${violation.severity.toUpperCase()}',
            //     style: TextStyle(
            //         color: _getViolationColor(violation.severity),
            //         fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Description: ${violation.description}'),
            SizedBox(height: 8),
            Text('Value: ${violation.value.toStringAsFixed(2)}'),
            SizedBox(height: 8),
            Text('Time: ${violation.timestamp.toString().substring(0, 19)}'),
            SizedBox(height: 8),
            Text(
                'Location: ${violation.position.latitude.toStringAsFixed(6)}, ${violation.position.longitude.toStringAsFixed(6)}'),
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

  Future<void> fetchGeofences() async {
    try {
      if (driverEmail == null) {
        print('Driver email is null, skipping geofence fetch');
        return;
      }

      print('Fetching geofences for driver email: $driverEmail');
      final response = await http
          .get(Uri.parse('$vehicledriverurl/assigned-geofence/$driverEmail'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (data.isEmpty) {
          print('No geofences assigned to this driver');
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
      if (!_isSimulationRunning) {
        fetchDriverLocation();
      }
    });
  }

  Future<void> fetchDriverLocation() async {
    try {
      if (id == null) {
        print('Driver ID is null, skipping location fetch');
        return;
      }

      print('Fetching location for driver ID: $id');
      final response =
          await http.get(Uri.parse('$vehicledriverurl/live-location/$id'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Location data from API: $data');

        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          final newLocation = LatLng(
              data['latitude'] is num ? data['latitude'].toDouble() : 0.0,
              data['longitude'] is num ? data['longitude'].toDouble() : 0.0);

          bool isDriving = _parseDrivingStatus(data['isdriving']);

          DateTime? lastUpdate;
          if (data.containsKey('lastUpdated')) {
            try {
              lastUpdate = DateTime.parse(data['lastUpdated']);
            } catch (e) {
              print('Error parsing timestamp: $e');
            }
          }

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
            isDriverActive = isDriving && isRecentUpdate;

            if (isDriverActive && driverLocation != null) {
              if (routePoints.isEmpty ||
                  _calculateDistance(routePoints.last, driverLocation!) >
                      0.00005) {
                routePoints.add(driverLocation!);
                if (routePoints.length > 100) {
                  routePoints.removeAt(0);
                }
              }
            }
          });

          if (!_initialPositionSet && driverLocation != null) {
            _mapController.move(driverLocation!, _mapZoom);
            _initialPositionSet = true;
          } else if (isDriverActive && driverLocation != null) {
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
        title: Center(child: Text("Enhanced Driver Simulation")),
        actions: [
          IconButton(
            icon: Icon(Icons.list),
            onPressed: _simulationRoute.isNotEmpty ? _showAllRoutePoints : null,
            tooltip: "View All Points",
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              if (!_isSimulationRunning) {
                fetchDriverLocation();
                //fetchViolations();
              }
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
            // Simulation Controls
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle Simulation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSimulationRunning
                                ? null
                                : (_isDefiningRoute
                                    ? _stopDefiningRoute
                                    : _startDefiningRoute),
                            icon: Icon(
                                _isDefiningRoute ? Icons.stop : Icons.route),
                            label: Text(_isDefiningRoute
                                ? 'Stop Defining'
                                : 'Define Route'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isDefiningRoute
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isDefiningRoute
                                ? null
                                : (_isSimulationRunning
                                    ? _stopSimulation
                                    : _startSimulation),
                            icon: Icon(_isSimulationRunning
                                ? Icons.stop
                                : Icons.play_arrow),
                            label: Text(_isSimulationRunning
                                ? 'Stop Driving'
                                : 'Start Driving'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isSimulationRunning
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isSimulationRunning) ...[
                      SizedBox(height: 12),
                      Text(
                          'Current Speed: ${_currentSpeed.toStringAsFixed(1)} km/h'),
                      Text(
                          'Current Angle: ${_currentAngle.toStringAsFixed(1)}°'),
                      Text(
                          'Route Progress: ${_currentRouteIndex + 1}/${_simulationRoute.length}'),
                    ],
                    if (_simulationRoute.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text('Route Points: ${_simulationRoute.length}'),
                    ],
                  ],
                ),
              ),
            ),

            // Map
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
                        onTap: (tapPosition, point) => _onMapTap(point),
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
                        // Original violations layer
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
                        // Simulation violations layer
                        if (_showViolations)
                          MarkerLayer(
                            markers: _simulationViolations.map((violation) {
                              return Marker(
                                width: 40.0,
                                height: 40.0,
                                point: violation.position,
                                child: GestureDetector(
                                  onTap: () => _showSimulationViolationDetails(
                                      violation),
                                  child: Container(
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: Colors.orange, width: 2),
                                    ),
                                    child: Icon(
                                      _getViolationIcon(violation.type),
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        // Route points markers
                        MarkerLayer(
                          markers:
                              _simulationRoute.asMap().entries.map((entry) {
                            int index = entry.key;
                            RoutePoint point = entry.value;
                            return Marker(
                              width: 30.0,
                              height: 30.0,
                              point: point.position,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(15),
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        // Vehicle marker
                        if (driverLocation != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                width: 50.0,
                                height: 50.0,
                                point: driverLocation!,
                                child: Transform.rotate(
                                  angle: _currentAngle * (math.pi / 180),
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
                              ]),
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
          ],
        ),
      ),
    );
  }
}
