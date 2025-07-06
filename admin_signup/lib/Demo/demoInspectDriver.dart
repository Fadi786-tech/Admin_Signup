// import 'dart:async';
// import 'dart:convert';
// import 'dart:math' as math;
// import 'package:admin_signup/DRIVER%20SIDE/driver_login.dart';
// import 'package:admin_signup/Track/Inspect_Driver.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// import '../Screens/MainDashboard.dart';
// import '../Screens/weekly_report_screen.dart';

// // Data models for simulation
// class RoutePoint {
//   final LatLng position;
//   final double speed; // km/h
//   final double angle; // degrees
//   final String name; // Point name/description
//   final DateTime timestamp;

//   RoutePoint({
//     required this.position,
//     required this.speed,
//     required this.angle,
//     required this.name,
//     required this.timestamp,
//   });
// }

// class SimulationViolation {
//   final String type;
//   final LatLng position;
//   final DateTime timestamp;
//   final String description;
//   final double value;
//   //final String severity; // 'low', 'medium', 'high'

//   SimulationViolation({
//     required this.type,
//     required this.position,
//     required this.timestamp,
//     required this.description,
//     required this.value,
//     //required this.severity,
//   });
// }

// class DriverDetailsScreen extends StatefulWidget {
//   const DriverDetailsScreen();

//   @override
//   _DriverDetailsScreenState createState() => _DriverDetailsScreenState();
// }

// class _DriverDetailsScreenState extends State<DriverDetailsScreen> {
//   var dvid, id, picture, name, model, lp;
//   String? driverEmail;
//   LatLng? driverLocation;
//   bool isDriverActive = false;
//   List<Polygon> geofencePolygons = [];
//   List<LatLng> routePoints = [];
//   List<Map<String, dynamic>> violations = [];
//   bool _showViolations = true;
//   Timer? _timer;
//   final MapController _mapController = MapController();

//   // Store the map zoom level to prevent unwanted zooming
//   double _mapZoom = 11.0;
//   bool _initialPositionSet = false;
//   DateTime? _lastLocationUpdate;

//   // Simulation variables
//   List<RoutePoint> _simulationRoute = [];
//   bool _isDefiningRoute = false;
//   bool _isSimulationRunning = false;
//   int _currentRouteIndex = 0;
//   Timer? _simulationTimer;
//   List<SimulationViolation> _simulationViolations = [];
//   double _currentSpeed = 0.0;
//   double _previousSpeed = 0.0;
//   double _currentAngle = 0.0;
//   double _previousAngle = 0.0;
//   LatLng? _tempRoutePoint;

//   // Speed and geofence limits for violation detection
//   double _speedLimit = 60.0; // km/h
//   double _hardBrakingThreshold = -1.5; // km/h change per second
//   double _sharpTurnThreshold = 45.0; // degrees change
//   bool _isInsideGeofence = true;

//   @override
//   void initState() {
//     super.initState();
//     fetchDriverDetails();
//     _startLocationUpdates();
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     _simulationTimer?.cancel();
//     super.dispose();
//   }

//   Future<void> fetchDriverDetails() async {
//     SharedPreferences pref = await SharedPreferences.getInstance();
//     setState(() {
//       dvid = pref.getInt('drivervehicleid');
//       id = pref.getInt('id');
//       picture = pref.getString('picture');
//       name = pref.getString('name');
//       model = pref.getString('model');
//       lp = pref.getString('licenseno');
//       driverEmail = pref.getString('email');
//     });

//     try {
//       final response =
//           await http.get(Uri.parse('$vehicledriverurl/inspect-driver/$id'));
//       if (response.statusCode == 200) {
//         print('Successfully loaded driver details');
//         await fetchGeofences();
//         //await fetchViolations();
//       } else {
//         print('Failed to load driver details: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching driver details: $e');
//     }
//   }

//   // Future<void> fetchViolations() async {
//   //   try {
//   //     if (dvid == null) return;

//   //     final response = await http.get(
//   //       Uri.parse('$vehicledriverurl/driver-violations/$dvid'),
//   //     );

//   //     if (response.statusCode == 200) {
//   //       final List<dynamic> data = json.decode(response.body);
//   //       setState(() {
//   //         violations = data
//   //             .map((v) => {
//   //                   'eventid': v['eventid'],
//   //                   'eventtype': v['eventtype'],
//   //                   'latitude': v['latitude']?.toDouble(),
//   //                   'longitude': v['longitude']?.toDouble(),
//   //                   'timestamp': v['timestamp'],
//   //                   'violatedvalue': v['violatedvalue'],
//   //                 })
//   //             .toList();
//   //       });
//   //     } else {
//   //       print('Failed to fetch violations: ${response.statusCode}');
//   //     }
//   //   } catch (e) {
//   //     print('Error fetching violations: $e');
//   //   }
//   // }

//   bool _parseDrivingStatus(dynamic drivingValue) {
//     print(
//         'Raw isdriving value: $drivingValue (type: ${drivingValue.runtimeType})');

//     if (drivingValue is bool) {
//       return drivingValue;
//     } else if (drivingValue is String) {
//       return drivingValue.toLowerCase() == 'true' ||
//           drivingValue == 't' ||
//           drivingValue == 'yes' ||
//           drivingValue == 'y' ||
//           drivingValue == '1';
//     } else if (drivingValue is num) {
//       return drivingValue != 0;
//     }
//     return false;
//   }

//   IconData _getViolationIcon(String eventType) {
//     switch (eventType.toLowerCase()) {
//       case 'speeding':
//       case 'overspeeding':
//         return Icons.speed;
//       case 'harsh braking':
//       case 'hardbraking':
//         return Icons.emergency;
//       case 'harsh acceleration':
//         return Icons.rocket_launch;
//       case 'sharp turn':
//       case 'sharpturn':
//         return Icons.turn_right;
//       case 'geofence violation':
//         return Icons.fence;
//       default:
//         return Icons.warning;
//     }
//   }

//   Color _getViolationColor(String severity) {
//     switch (severity.toLowerCase()) {
//       case 'high':
//         return Colors.red;
//       case 'medium':
//         return Colors.orange;
//       case 'low':
//         return Colors.yellow.shade700;
//       default:
//         return Colors.red;
//     }
//   }

//   void _showViolationDetails(Map<String, dynamic> violation) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Violation Details'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Type: ${violation['eventtype']}'),
//             Text('Value: ${violation['violatedvalue']}'),
//             Text('Time: ${violation['timestamp']}'),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showRoutePointDetails(RoutePoint point, int index) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Route Point Details'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Point: ${point.name}'),
//             Text('Index: ${index + 1}'),
//             Text('Speed: ${point.speed.toStringAsFixed(1)} km/h'),
//             Text('Angle: ${point.angle.toStringAsFixed(1)}°'),
//             Text('Latitude: ${point.position.latitude.toStringAsFixed(6)}'),
//             Text('Longitude: ${point.position.longitude.toStringAsFixed(6)}'),
//             Text('Created: ${point.timestamp.toString().substring(0, 19)}'),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _editRoutePoint(index);
//             },
//             child: Text('Edit'),
//           ),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _deleteRoutePoint(index);
//             },
//             child: Text('Delete', style: TextStyle(color: Colors.red)),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _editRoutePoint(int index) {
//     final point = _simulationRoute[index];
//     final speedController = TextEditingController(text: point.speed.toString());
//     final angleController = TextEditingController(text: point.angle.toString());
//     final nameController = TextEditingController(text: point.name);

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Route Point'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: nameController,
//               decoration: InputDecoration(
//                 labelText: 'Point Name',
//                 hintText: 'Enter point name',
//               ),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: speedController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(
//                 labelText: 'Speed (km/h)',
//                 hintText: 'Enter speed',
//               ),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: angleController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(
//                 labelText: 'Angle (degrees)',
//                 hintText: 'Enter angle (0-360)',
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               final speed =
//                   double.tryParse(speedController.text) ?? point.speed;
//               final angle =
//                   double.tryParse(angleController.text) ?? point.angle;
//               final name = nameController.text.isNotEmpty
//                   ? nameController.text
//                   : point.name;

//               setState(() {
//                 _simulationRoute[index] = RoutePoint(
//                   position: point.position,
//                   speed: speed,
//                   angle: angle,
//                   name: name,
//                   timestamp: point.timestamp,
//                 );
//               });

//               Navigator.pop(context);
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _deleteRoutePoint(int index) {
//     setState(() {
//       _simulationRoute.removeAt(index);
//       if (routePoints.length > index) {
//         routePoints.removeAt(index);
//       }
//     });
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Route point deleted')),
//     );
//   }

//   void _showAllRoutePoints() {
//     showDialog(
//       context: context,
//       builder: (context) => Dialog(
//         child: Container(
//           height: 400,
//           child: Column(
//             children: [
//               Padding(
//                 padding: EdgeInsets.all(16),
//                 child: Text(
//                   'Route Points (${_simulationRoute.length})',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//               ),
//               Expanded(
//                 child: ListView.builder(
//                   itemCount: _simulationRoute.length,
//                   itemBuilder: (context, index) {
//                     final point = _simulationRoute[index];
//                     return ListTile(
//                       leading: CircleAvatar(
//                         child: Text('${index + 1}'),
//                         backgroundColor: Colors.blue,
//                         foregroundColor: Colors.white,
//                       ),
//                       title: Text(point.name),
//                       subtitle: Text(
//                         'Speed: ${point.speed.toStringAsFixed(1)} km/h, '
//                         'Angle: ${point.angle.toStringAsFixed(1)}°',
//                       ),
//                       trailing: Icon(Icons.info_outline),
//                       onTap: () {
//                         Navigator.pop(context);
//                         _showRoutePointDetails(point, index);
//                       },
//                     );
//                   },
//                 ),
//               ),
//               Padding(
//                 padding: EdgeInsets.all(16),
//                 child: ElevatedButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: Text('Close'),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   void _zoomIn() {
//     _mapZoom += 1;
//     if (driverLocation != null) {
//       _mapController.move(driverLocation!, _mapZoom);
//     }
//   }

//   void _zoomOut() {
//     _mapZoom -= 1;
//     if (_mapZoom < 3) _mapZoom = 3;
//     if (driverLocation != null) {
//       _mapController.move(driverLocation!, _mapZoom);
//     }
//   }

//   void _centerOnDriver() {
//     if (driverLocation != null) {
//       _mapController.move(driverLocation!, _mapZoom);
//     }
//   }

//   double _calculateDistance(LatLng point1, LatLng point2) {
//     return (point1.latitude - point2.latitude).abs() +
//         (point1.longitude - point2.longitude).abs();
//   }

//   void _clearRoute() {
//     setState(() {
//       routePoints.clear();
//       _simulationRoute.clear();
//       _simulationViolations.clear();
//     });
//   }

//   // Simulation methods
//   void _startDefiningRoute() {
//     setState(() {
//       _isDefiningRoute = true;
//       _simulationRoute.clear();
//       _simulationViolations.clear();
//       routePoints.clear();
//     });

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Tap on the map to define route points'),
//         duration: Duration(seconds: 3),
//       ),
//     );
//   }

//   void _stopDefiningRoute() {
//     setState(() {
//       _isDefiningRoute = false;
//     });
//   }

//   void _onMapTap(LatLng position) {
//     if (_isDefiningRoute) {
//       setState(() {
//         _tempRoutePoint = position;
//       });
//       _showSpeedAngleDialog(position);
//     }
//   }

//   void _showSpeedAngleDialog(LatLng position) {
//     final speedController = TextEditingController(text: '50');
//     final angleController = TextEditingController(text: '0');
//     final nameController =
//         TextEditingController(text: 'Point ${_simulationRoute.length + 1}');

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Route Point Settings'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: nameController,
//               decoration: InputDecoration(
//                 labelText: 'Point Name',
//                 hintText: 'Enter point name',
//               ),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: speedController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(
//                 labelText: 'Speed (km/h)',
//                 hintText: 'Enter speed',
//               ),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: angleController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(
//                 labelText: 'Angle (degrees)',
//                 hintText: 'Enter angle (0-360)',
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               final speed = double.tryParse(speedController.text) ?? 50.0;
//               final angle = double.tryParse(angleController.text) ?? 0.0;
//               final name = nameController.text.isNotEmpty
//                   ? nameController.text
//                   : 'Point ${_simulationRoute.length + 1}';

//               setState(() {
//                 _simulationRoute.add(RoutePoint(
//                   position: position,
//                   speed: speed,
//                   angle: angle,
//                   name: name,
//                   timestamp: DateTime.now(),
//                 ));
//                 routePoints.add(position);
//               });

//               Navigator.pop(context);
//             },
//             child: Text('Add Point'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _startSimulation() {
//     if (_simulationRoute.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please define a route first')),
//       );
//       return;
//     }

//     setState(() {
//       _isSimulationRunning = true;
//       _currentRouteIndex = 0;
//       driverLocation = _simulationRoute[0].position;
//       _currentSpeed = _simulationRoute[0].speed;
//       _previousSpeed = _currentSpeed;
//       _currentAngle = _simulationRoute[0].angle;
//       _previousAngle = _currentAngle;
//       isDriverActive = true;
//       _simulationViolations.clear(); // Clear previous violations
//     });

//     _simulationTimer = Timer.periodic(Duration(seconds: 2), (timer) {
//       _updateSimulation();
//     });
//   }

//   void _stopSimulation() {
//     setState(() {
//       _isSimulationRunning = false;
//       isDriverActive = false;
//     });
//     _simulationTimer?.cancel();
//   }

//   void _updateSimulation() {
//     if (_currentRouteIndex >= _simulationRoute.length - 1) {
//       _stopSimulation();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Simulation completed')),
//       );
//       return;
//     }

//     setState(() {
//       _previousSpeed = _currentSpeed;
//       _previousAngle = _currentAngle;

//       _currentRouteIndex++;
//       final currentPoint = _simulationRoute[_currentRouteIndex];
//       driverLocation = currentPoint.position;
//       _currentSpeed = currentPoint.speed;
//       _currentAngle = currentPoint.angle;

//       // Check for violations at current point
//       _checkViolations(currentPoint);
//     });

//     // Move map to follow vehicle
//     _mapController.move(driverLocation!, _mapZoom);
//   }

// // Add this method to your _DriverDetailsScreenState class
//   double getDynamicGyroAngleThreshold(double speed) {
//     // For Sedan - dynamic threshold based on speed
//     if (speed <= 20) return 80;
//     if (speed > 20 && speed <= 40) return 60;
//     if (speed > 40 && speed <= 60) return 45;
//     if (speed > 60 && speed <= 80) return 35;
//     if (speed > 80 && speed <= 100) return 25;
//     if (speed > 100 && speed <= 120) return 20;
//     return 15;
//   }

// // Updated _checkViolations method - replace the sharp turn section
//   void _checkViolations(RoutePoint point) {
//     String severity = 'medium';

//     // Check overspeeding violation
//     if (point.speed > _speedLimit) {
//       severity = point.speed > _speedLimit * 1.5
//           ? 'high'
//           : point.speed > _speedLimit * 1.2
//               ? 'medium'
//               : 'low';

//       _addSimulationViolation(
//         'Overspeeding',
//         point.position,
//         'Speed exceeded: ${point.speed.toStringAsFixed(1)} km/h (limit: $_speedLimit km/h)',
//         point.speed - _speedLimit,
//       );
//     }

//     // Check hard braking using deceleration formula
//     double _hardBrakingThreshold = 1.5; // m/s²
//     double _simulationTimeInterval = 1.0; // seconds

//     double currentSpeedMs = point.speed * (1000.0 / 3600.0); // km/h to m/s
//     double previousSpeedMs = _previousSpeed * (1000.0 / 3600.0); // km/h to m/s

//     double deltaVelocity = currentSpeedMs - previousSpeedMs;
//     double deceleration = deltaVelocity / _simulationTimeInterval;

//     if (deceleration < -_hardBrakingThreshold) {
//       double decelerationMagnitude = deceleration.abs();

//       _addSimulationViolation(
//           'HardBraking',
//           point.position,
//           'Hard braking detected: ${decelerationMagnitude.toStringAsFixed(2)} m/s² deceleration',
//           decelerationMagnitude);
//     }

//     // Check sharp turn with dynamic threshold based on speed
//     double angleDifference = (point.angle - _previousAngle).abs();
//     // Handle angle wrap-around (e.g., 359° to 1°)
//     if (angleDifference > 180) {
//       angleDifference = 360 - angleDifference;
//     }

//     // Get dynamic threshold based on current speed
//     double dynamicSharpTurnThreshold =
//         getDynamicGyroAngleThreshold(point.speed);

//     if (angleDifference > dynamicSharpTurnThreshold) {
//       // Determine severity based on how much the angle exceeds the dynamic threshold
//       severity = angleDifference > dynamicSharpTurnThreshold * 2
//           ? 'high'
//           : angleDifference > dynamicSharpTurnThreshold * 1.5
//               ? 'medium'
//               : 'low';

//       _addSimulationViolation(
//         'SharpTurn',
//         point.position,
//         'Sharp turn detected: ${angleDifference.toStringAsFixed(1)}° change (threshold: ${dynamicSharpTurnThreshold.toStringAsFixed(1)}° at ${point.speed.toStringAsFixed(1)} km/h)',
//         angleDifference,
//       );
//     }

//     // Check geofence violation
//     bool insideAnyGeofence = false;
//     for (var polygon in geofencePolygons) {
//       if (_isPointInPolygon(point.position, polygon.points)) {
//         insideAnyGeofence = true;
//         break;
//       }
//     }

//     if (!insideAnyGeofence && geofencePolygons.isNotEmpty) {
//       _addSimulationViolation(
//         'Geofence Violation',
//         point.position,
//         'Vehicle outside designated area',
//         0.0,
//       );
//     }
//   }

//   bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
//     if (polygon.length < 3) return false;

//     bool inside = false;
//     int j = polygon.length - 1;

//     for (int i = 0; i < polygon.length; i++) {
//       final xi = polygon[i].latitude;
//       final yi = polygon[i].longitude;
//       final xj = polygon[j].latitude;
//       final yj = polygon[j].longitude;

//       if (((yi > point.longitude) != (yj > point.longitude)) &&
//           (point.latitude <
//               (xj - xi) * (point.longitude - yi) / (yj - yi) + xi)) {
//         inside = !inside;
//       }
//       j = i;
//     }

//     return inside;
//   }

//   void _addSimulationViolation(
//       String type, LatLng position, String description, double value) {
//     //, String severity) {
//     setState(() {
//       _simulationViolations.add(
//         SimulationViolation(
//           type: type,
//           position: position,
//           timestamp: DateTime.now(),
//           description: description,
//           value: value,
//           //severity: severity,
//         ),
//       );
//     });
//   }

//   void _showSimulationViolationDetails(SimulationViolation violation) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Simulation Violation'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Type: ${violation.type}',
//                 style: TextStyle(fontWeight: FontWeight.bold)),
//             SizedBox(height: 8),
//             // Text('Severity: ${violation.severity.toUpperCase()}',
//             //     style: TextStyle(
//             //         color: _getViolationColor(violation.severity),
//             //         fontWeight: FontWeight.bold)),
//             SizedBox(height: 8),
//             Text('Description: ${violation.description}'),
//             SizedBox(height: 8),
//             Text('Value: ${violation.value.toStringAsFixed(2)}'),
//             SizedBox(height: 8),
//             Text('Time: ${violation.timestamp.toString().substring(0, 19)}'),
//             SizedBox(height: 8),
//             Text(
//                 'Location: ${violation.position.latitude.toStringAsFixed(6)}, ${violation.position.longitude.toStringAsFixed(6)}'),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> fetchGeofences() async {
//     try {
//       if (driverEmail == null) {
//         print('Driver email is null, skipping geofence fetch');
//         return;
//       }

//       print('Fetching geofences for driver email: $driverEmail');
//       final response = await http
//           .get(Uri.parse('$vehicledriverurl/assigned-geofence/$driverEmail'));

//       if (response.statusCode == 200) {
//         final List<dynamic> data = json.decode(response.body);

//         if (data.isEmpty) {
//           print('No geofences assigned to this driver');
//           return;
//         }

//         setState(() {
//           geofencePolygons = data.map((geofence) {
//             try {
//               List<LatLng> points = [];

//               if (geofence['coordinates'] is List) {
//                 points = (geofence['coordinates'] as List)
//                     .map((point) {
//                       if (point is List && point.length >= 2) {
//                         return LatLng(
//                             point[0] is num ? point[0].toDouble() : 0.0,
//                             point[1] is num ? point[1].toDouble() : 0.0);
//                       }
//                       return null;
//                     })
//                     .where((point) => point != null)
//                     .cast<LatLng>()
//                     .toList();
//               }

//               return Polygon(
//                 points: points,
//                 color: Colors.blue.withOpacity(0.3),
//                 borderColor: Colors.blue,
//                 borderStrokeWidth: 2,
//               );
//             } catch (e) {
//               print('Error parsing geofence: $e');
//               return Polygon(
//                 points: [],
//                 color: Colors.blue.withOpacity(0.3),
//                 borderColor: Colors.blue,
//                 borderStrokeWidth: 2,
//               );
//             }
//           }).toList();
//         });
//       } else {
//         print('Failed to fetch geofences: ${response.statusCode}');
//         print('Response body: ${response.body}');
//       }
//     } catch (e) {
//       print('Error fetching geofences: $e');
//     }
//   }

//   void _startLocationUpdates() {
//     _timer = Timer.periodic(Duration(seconds: 5), (timer) {
//       if (!_isSimulationRunning) {
//         fetchDriverLocation();
//       }
//     });
//   }

//   Future<void> fetchDriverLocation() async {
//     try {
//       if (id == null) {
//         print('Driver ID is null, skipping location fetch');
//         return;
//       }

//       print('Fetching location for driver ID: $id');
//       final response =
//           await http.get(Uri.parse('$vehicledriverurl/live-location/$id'));

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         print('Location data from API: $data');

//         if (data.containsKey('latitude') && data.containsKey('longitude')) {
//           final newLocation = LatLng(
//               data['latitude'] is num ? data['latitude'].toDouble() : 0.0,
//               data['longitude'] is num ? data['longitude'].toDouble() : 0.0);

//           bool isDriving = _parseDrivingStatus(data['isdriving']);

//           DateTime? lastUpdate;
//           if (data.containsKey('lastUpdated')) {
//             try {
//               lastUpdate = DateTime.parse(data['lastUpdated']);
//             } catch (e) {
//               print('Error parsing timestamp: $e');
//             }
//           }

//           bool isRecentUpdate = false;
//           if (lastUpdate != null) {
//             DateTime now = DateTime.now();
//             Duration difference = now.difference(lastUpdate);
//             isRecentUpdate = difference.inMinutes < 5;
//             print('Last update was ${difference.inMinutes} minutes ago');
//           }

//           setState(() {
//             driverLocation = newLocation;
//             _lastLocationUpdate = lastUpdate;
//             isDriverActive = isDriving && isRecentUpdate;

//             if (isDriverActive && driverLocation != null) {
//               if (routePoints.isEmpty ||
//                   _calculateDistance(routePoints.last, driverLocation!) >
//                       0.00005) {
//                 routePoints.add(driverLocation!);
//                 if (routePoints.length > 100) {
//                   routePoints.removeAt(0);
//                 }
//               }
//             }
//           });

//           if (!_initialPositionSet && driverLocation != null) {
//             _mapController.move(driverLocation!, _mapZoom);
//             _initialPositionSet = true;
//           } else if (isDriverActive && driverLocation != null) {
//             _mapZoom = _mapController.camera.zoom;
//             _mapController.move(driverLocation!, _mapZoom);
//           }
//         } else {
//           print('Location data is missing latitude or longitude');
//         }
//       } else {
//         print('Failed to fetch live location: ${response.statusCode}');
//         print('Response body: ${response.body}');
//       }
//     } catch (e) {
//       print('Error fetching location: $e');
//       print('Stack trace: ${e is Error ? e.stackTrace : "N/A"}');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Center(child: Text("Enhanced Driver Simulation")),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.list),
//             onPressed: _simulationRoute.isNotEmpty ? _showAllRoutePoints : null,
//             tooltip: "View All Points",
//           ),
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: () {
//               if (!_isSimulationRunning) {
//                 fetchDriverLocation();
//                 //fetchViolations();
//               }
//             },
//             tooltip: "Refresh Location",
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Simulation Controls
//             Card(
//               elevation: 2,
//               child: Padding(
//                 padding: EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Vehicle Simulation',
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     SizedBox(height: 12),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: ElevatedButton.icon(
//                             onPressed: _isSimulationRunning
//                                 ? null
//                                 : (_isDefiningRoute
//                                     ? _stopDefiningRoute
//                                     : _startDefiningRoute),
//                             icon: Icon(
//                                 _isDefiningRoute ? Icons.stop : Icons.route),
//                             label: Text(_isDefiningRoute
//                                 ? 'Stop Defining'
//                                 : 'Define Route'),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: _isDefiningRoute
//                                   ? Colors.orange
//                                   : Colors.blue,
//                             ),
//                           ),
//                         ),
//                         SizedBox(width: 12),
//                         Expanded(
//                           child: ElevatedButton.icon(
//                             onPressed: _isDefiningRoute
//                                 ? null
//                                 : (_isSimulationRunning
//                                     ? _stopSimulation
//                                     : _startSimulation),
//                             icon: Icon(_isSimulationRunning
//                                 ? Icons.stop
//                                 : Icons.play_arrow),
//                             label: Text(_isSimulationRunning
//                                 ? 'Stop Driving'
//                                 : 'Start Driving'),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: _isSimulationRunning
//                                   ? Colors.red
//                                   : Colors.green,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     if (_isSimulationRunning) ...[
//                       SizedBox(height: 12),
//                       Text(
//                           'Current Speed: ${_currentSpeed.toStringAsFixed(1)} km/h'),
//                       Text(
//                           'Current Angle: ${_currentAngle.toStringAsFixed(1)}°'),
//                       Text(
//                           'Route Progress: ${_currentRouteIndex + 1}/${_simulationRoute.length}'),
//                     ],
//                     if (_simulationRoute.isNotEmpty) ...[
//                       SizedBox(height: 8),
//                       Text('Route Points: ${_simulationRoute.length}'),
//                     ],
//                   ],
//                 ),
//               ),
//             ),

//             // Map
//             Expanded(
//               child: Stack(
//                 children: [
//                   ClipRRect(
//                     borderRadius: BorderRadius.circular(10),
//                     child: FlutterMap(
//                       mapController: _mapController,
//                       options: MapOptions(
//                         initialCenter:
//                             driverLocation ?? const LatLng(33.6995, 73.0363),
//                         initialZoom: _mapZoom,
//                         onTap: (tapPosition, point) => _onMapTap(point),
//                         onMapEvent: (event) {
//                           if (event.source == MapEventSource.mapController ||
//                               event.source ==
//                                   MapEventSource.flingAnimationController ||
//                               event.source ==
//                                   MapEventSource
//                                       .doubleTapZoomAnimationController) {
//                             _mapZoom = _mapController.camera.zoom;
//                           }
//                         },
//                       ),
//                       children: [
//                         TileLayer(
//                           urlTemplate:
//                               "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
//                           subdomains: const ['a', 'b', 'c'],
//                         ),
//                         PolygonLayer(polygons: geofencePolygons),
//                         if (routePoints.isNotEmpty && routePoints.length > 1)
//                           PolylineLayer(
//                             polylines: [
//                               Polyline(
//                                 points: routePoints,
//                                 color: Colors.deepPurple,
//                                 strokeWidth: 4.0,
//                               ),
//                             ],
//                           ),
//                         // Original violations layer
//                         if (_showViolations)
//                           MarkerLayer(
//                             markers: violations.map((violation) {
//                               return Marker(
//                                 width: 40.0,
//                                 height: 40.0,
//                                 point: LatLng(violation['latitude'],
//                                     violation['longitude']),
//                                 child: GestureDetector(
//                                   onTap: () => _showViolationDetails(violation),
//                                   child: Container(
//                                     padding: EdgeInsets.all(6),
//                                     decoration: BoxDecoration(
//                                       color: Colors.white,
//                                       borderRadius: BorderRadius.circular(20),
//                                       border: Border.all(
//                                           color: Colors.red, width: 2),
//                                     ),
//                                     child: Icon(
//                                       _getViolationIcon(violation['eventtype']),
//                                       color: Colors.red,
//                                       size: 20,
//                                     ),
//                                   ),
//                                 ),
//                               );
//                             }).toList(),
//                           ),
//                         // Simulation violations layer
//                         if (_showViolations)
//                           MarkerLayer(
//                             markers: _simulationViolations.map((violation) {
//                               return Marker(
//                                 width: 40.0,
//                                 height: 40.0,
//                                 point: violation.position,
//                                 child: GestureDetector(
//                                   onTap: () => _showSimulationViolationDetails(
//                                       violation),
//                                   child: Container(
//                                     padding: EdgeInsets.all(6),
//                                     decoration: BoxDecoration(
//                                       color: Colors.white,
//                                       borderRadius: BorderRadius.circular(20),
//                                       border: Border.all(
//                                           color: Colors.orange, width: 2),
//                                     ),
//                                     child: Icon(
//                                       _getViolationIcon(violation.type),
//                                       color: Colors.orange,
//                                       size: 20,
//                                     ),
//                                   ),
//                                 ),
//                               );
//                             }).toList(),
//                           ),
//                         // Route points markers
//                         MarkerLayer(
//                           markers:
//                               _simulationRoute.asMap().entries.map((entry) {
//                             int index = entry.key;
//                             RoutePoint point = entry.value;
//                             return Marker(
//                               width: 30.0,
//                               height: 30.0,
//                               point: point.position,
//                               child: Container(
//                                 decoration: BoxDecoration(
//                                   color: Colors.blue,
//                                   borderRadius: BorderRadius.circular(15),
//                                   border:
//                                       Border.all(color: Colors.white, width: 2),
//                                 ),
//                                 child: Center(
//                                   child: Text(
//                                     '${index + 1}',
//                                     style: TextStyle(
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 12,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             );
//                           }).toList(),
//                         ),
//                         // Vehicle marker
//                         if (driverLocation != null)
//                           MarkerLayer(
//                             markers: [
//                               Marker(
//                                 width: 50.0,
//                                 height: 50.0,
//                                 point: driverLocation!,
//                                 child: Transform.rotate(
//                                   angle: _currentAngle * (math.pi / 180),
//                                   child: Container(
//                                     child: Icon(
//                                       isDriverActive
//                                           ? Icons.directions_car_filled
//                                           : Icons.directions_car_outlined,
//                                       color: isDriverActive
//                                           ? Colors.green
//                                           : Colors.red,
//                                       size: 36,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                       ],
//                     ),
//                   ),

//                   // Map control buttons
//                   Positioned(
//                     top: 10,
//                     right: 10,
//                     child: Column(
//                       children: [
//                         Container(
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(5),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black26,
//                                 blurRadius: 5,
//                                 offset: Offset(0, 2),
//                               ),
//                             ],
//                           ),
//                           child: Column(
//                             children: [
//                               IconButton(
//                                 icon: Icon(Icons.add),
//                                 onPressed: _zoomIn,
//                                 tooltip: 'Zoom in',
//                               ),
//                               Divider(height: 1, thickness: 1),
//                               IconButton(
//                                 icon: Icon(Icons.remove),
//                                 onPressed: _zoomOut,
//                                 tooltip: 'Zoom out',
//                               ),
//                             ],
//                           ),
//                         ),
//                         SizedBox(height: 10),
//                         Container(
//                           decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.circular(5),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.black26,
//                                   blurRadius: 5,
//                                   offset: Offset(0, 2),
//                                 ),
//                               ]),
//                           child: IconButton(
//                             icon: Icon(Icons.my_location),
//                             onPressed: _centerOnDriver,
//                             tooltip: 'Center on driver',
//                           ),
//                         ),
//                         SizedBox(height: 10),
//                         // Clear route points button
//                         Container(
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(5),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black26,
//                                 blurRadius: 5,
//                                 offset: Offset(0, 2),
//                               ),
//                             ],
//                           ),
//                           child: IconButton(
//                             icon: Icon(Icons.clear_all),
//                             onPressed: _clearRoute,
//                             tooltip: 'Clear route',
//                           ),
//                         ),
//                         SizedBox(height: 10),
//                         // Toggle violations button
//                         Container(
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(5),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black26,
//                                 blurRadius: 5,
//                                 offset: Offset(0, 2),
//                               ),
//                             ],
//                           ),
//                           child: IconButton(
//                             icon: Icon(
//                               _showViolations
//                                   ? Icons.warning_amber
//                                   : Icons.warning_amber_outlined,
//                               color: _showViolations ? Colors.red : Colors.grey,
//                             ),
//                             onPressed: () {
//                               setState(() {
//                                 _showViolations = !_showViolations;
//                               });
//                             },
//                             tooltip: 'Toggle violations',
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),

//                   // Map legend
//                   Positioned(
//                     bottom: 10,
//                     left: 10,
//                     child: Container(
//                       padding: EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.8),
//                         borderRadius: BorderRadius.circular(5),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               Icon(Icons.directions_car_filled,
//                                   color: Colors.green, size: 20),
//                               SizedBox(width: 5),
//                               Text('Active'),
//                             ],
//                           ),
//                           SizedBox(height: 5),
//                           Row(
//                             children: [
//                               Icon(Icons.directions_car_outlined,
//                                   color: Colors.red, size: 20),
//                               SizedBox(width: 5),
//                               Text('Inactive'),
//                             ],
//                           ),
//                           SizedBox(height: 5),
//                           Row(
//                             children: [
//                               Container(
//                                 width: 20,
//                                 height: 3,
//                                 color: Colors.deepPurple,
//                               ),
//                               SizedBox(width: 5),
//                               Text('Route'),
//                             ],
//                           ),
//                           SizedBox(height: 5),
//                           Row(
//                             children: [
//                               Container(
//                                 width: 15,
//                                 height: 15,
//                                 decoration: BoxDecoration(
//                                   color: Colors.blue.withOpacity(0.3),
//                                   border: Border.all(color: Colors.blue),
//                                 ),
//                               ),
//                               SizedBox(width: 5),
//                               Text('Geofence'),
//                             ],
//                           ),
//                           SizedBox(height: 5),
//                           Row(
//                             children: [
//                               Icon(Icons.warning, color: Colors.red, size: 20),
//                               SizedBox(width: 5),
//                               Text('Violation'),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// import 'dart:async';
// import 'dart:convert';
// import 'dart:math' as math;
// import 'package:admin_signup/DRIVER%20SIDE/driver_login.dart';
// import 'package:admin_signup/Track/Inspect_Driver.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// import '../Screens/MainDashboard.dart';
// import '../Screens/weekly_report_screen.dart';

// // Data models for simulation
// class RoutePoint {
//   final LatLng position;
//   final double speed; // km/h (calculated automatically)
//   final double angle; // degrees (calculated from gyroscope)
//   final String name;
//   final DateTime timestamp;
//   final Duration? timeInterval; // Time since previous point

//   RoutePoint({
//     required this.position,
//     required this.name,
//     required this.timestamp,
//     this.speed = 0.0,
//     this.angle = 0.0,
//     this.timeInterval,
//   });
// }

// class SimulationViolation {
//   final String type;
//   final LatLng position;
//   final DateTime timestamp;
//   final String description;
//   final double value;

//   SimulationViolation({
//     required this.type,
//     required this.position,
//     required this.timestamp,
//     required this.description,
//     required this.value,
//   });
// }

// class DriverDetailsScreen extends StatefulWidget {
//   const DriverDetailsScreen();

//   @override
//   _DriverDetailsScreenState createState() => _DriverDetailsScreenState();
// }

// class _DriverDetailsScreenState extends State<DriverDetailsScreen>
//     with TickerProviderStateMixin {
//   var dvid, id, picture, name, model, lp;
//   String? driverEmail;
//   LatLng? driverLocation;
//   bool isDriverActive = false;
//   List<Polygon> geofencePolygons = [];
//   List<LatLng> routePoints = [];
//   List<Map<String, dynamic>> violations = [];
//   double _carAnimationDuration = 1.0;
//   double _sensorDataInterval = 1.0;
//   AnimationController? _carAnimationController;
//   Animation<Offset>? _carAnimation;
//   Timer? _sensorDataTimer;
//   LatLng? _previousLocation;
//   bool _showViolations = true;
//   Timer? _timer;
//   final MapController _mapController = MapController();
//   double _mapZoom = 11.0;
//   bool _initialPositionSet = false;
//   DateTime? _lastLocationUpdate;
//   List<RoutePoint> _simulationRoute = [];
//   bool _isDefiningRoute = false;
//   bool _isSimulationRunning = false;
//   int _currentRouteIndex = 0;
//   Timer? _simulationTimer;
//   List<SimulationViolation> _simulationViolations = [];
//   double _currentSpeed = 0.0;
//   double _previousSpeed = 0.0;
//   double _currentAngle = 0.0;
//   double _previousAngle = 0.0;
//   LatLng? _tempRoutePoint;
//   double _speedLimit = 60.0;
//   double _hardBrakingThreshold = -1.5;
//   double _sharpTurnThreshold = 45.0;
//   bool _isInsideGeofence = true;
//   double _gyroToAngleFactor = 0.07;
//   double _gyroNoiseLevel = 0.5;
//   List<double> _gyroZValues = [];
//   double _currentGyroZ = 0.0;
//   List<DateTime> _gyroTimestamps = [];
//   double _simulationProgress = 0.0;

//   @override
//   void initState() {
//     super.initState();
//     fetchDriverDetails();
//     _startLocationUpdates();
//   }

//   @override
//   void dispose() {
//     _carAnimationController?.dispose();
//     _timer?.cancel();
//     _simulationTimer?.cancel();
//     _sensorDataTimer?.cancel();
//     super.dispose();
//   }

//   Future<void> _sendFinalUpdate() async {
//     try {
//       final response = await http.post(
//         Uri.parse('$vehicledriverurl/current-location'),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode({
//           'driverId': id,
//           'latitude': driverLocation!.latitude,
//           'longitude': driverLocation!.longitude,
//           'speed': 0.0,
//           'angle': _currentAngle,
//           'timestamp': DateTime.now().toIso8601String(),
//           'isDriving': false,
//         }),
//       );

//       if (response.statusCode == 200) {
//         print('Final update sent successfully');
//       } else {
//         print('Failed to send final update: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error sending final update: $e');
//     }
//   }

//   Future<void> _sendSensorDataToApi() async {
//     if (!_isSimulationRunning || driverLocation == null) return;

//     try {
//       final response = await http.post(
//         Uri.parse('$vehicledriverurl/current-location'),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode({
//           'driverId': id,
//           'latitude': driverLocation!.latitude,
//           'longitude': driverLocation!.longitude,
//           'speed': _currentSpeed,
//           'angle': _currentAngle,
//           'timestamp': DateTime.now().toIso8601String(),
//           'isDriving': true,
//         }),
//       );

//       if (response.statusCode == 200) {
//         print('Sensor data sent successfully');
//       } else {
//         print('Failed to send sensor data: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error sending sensor data: $e');
//     }
//   }

//   Future<void> fetchDriverDetails() async {
//     SharedPreferences pref = await SharedPreferences.getInstance();
//     setState(() {
//       dvid = pref.getInt('drivervehicleid');
//       id = pref.getInt('id');
//       picture = pref.getString('picture');
//       name = pref.getString('name');
//       model = pref.getString('model');
//       lp = pref.getString('licenseno');
//       driverEmail = pref.getString('email');
//     });

//     try {
//       final response =
//           await http.get(Uri.parse('$vehicledriverurl/inspect-driver/$id'));
//       if (response.statusCode == 200) {
//         print('Successfully loaded driver details');
//         await fetchGeofences();
//       } else {
//         print('Failed to load driver details: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching driver details: $e');
//     }
//   }

//   bool _parseDrivingStatus(dynamic drivingValue) {
//     if (drivingValue is bool) {
//       return drivingValue;
//     } else if (drivingValue is String) {
//       return drivingValue.toLowerCase() == 'true' ||
//           drivingValue == 't' ||
//           drivingValue == 'yes' ||
//           drivingValue == 'y' ||
//           drivingValue == '1';
//     } else if (drivingValue is num) {
//       return drivingValue != 0;
//     }
//     return false;
//   }

//   IconData _getViolationIcon(String eventType) {
//     switch (eventType.toLowerCase()) {
//       case 'speeding':
//       case 'overspeeding':
//         return Icons.speed;
//       case 'harsh braking':
//       case 'hardbraking':
//         return Icons.emergency;
//       case 'harsh acceleration':
//         return Icons.rocket_launch;
//       case 'sharp turn':
//       case 'sharpturn':
//         return Icons.turn_right;
//       case 'geofence violation':
//         return Icons.fence;
//       default:
//         return Icons.warning;
//     }
//   }

//   Color _getViolationColor(String severity) {
//     switch (severity.toLowerCase()) {
//       case 'high':
//         return Colors.red;
//       case 'medium':
//         return Colors.orange;
//       case 'low':
//         return Colors.yellow.shade700;
//       default:
//         return Colors.red;
//     }
//   }

//   void _showViolationDetails(Map<String, dynamic> violation) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Violation Details'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Type: ${violation['eventtype']}'),
//             Text('Value: ${violation['violatedvalue']}'),
//             Text('Time: ${violation['timestamp']}'),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showRoutePointDetails(RoutePoint point, int index) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Route Point Details'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Point: ${point.name}'),
//             Text('Index: ${index + 1}'),
//             Text('Speed: ${point.speed.toStringAsFixed(1)} km/h'),
//             Text('Angle: ${point.angle.toStringAsFixed(1)}°'),
//             Text('Latitude: ${point.position.latitude.toStringAsFixed(6)}'),
//             Text('Longitude: ${point.position.longitude.toStringAsFixed(6)}'),
//             Text('Created: ${point.timestamp.toString().substring(0, 19)}'),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _editRoutePoint(index);
//             },
//             child: Text('Edit'),
//           ),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _deleteRoutePoint(index);
//             },
//             child: Text('Delete', style: TextStyle(color: Colors.red)),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _editRoutePoint(int index) {
//     final point = _simulationRoute[index];
//     final speedController = TextEditingController(text: point.speed.toString());
//     final angleController = TextEditingController(text: point.angle.toString());
//     final nameController = TextEditingController(text: point.name);

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Route Point'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: nameController,
//               decoration: InputDecoration(
//                 labelText: 'Point Name',
//                 hintText: 'Enter point name',
//               ),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: speedController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(
//                 labelText: 'Speed (km/h)',
//                 hintText: 'Enter speed',
//               ),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: angleController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(
//                 labelText: 'Angle (degrees)',
//                 hintText: 'Enter angle (0-360)',
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               final speed =
//                   double.tryParse(speedController.text) ?? point.speed;
//               final angle =
//                   double.tryParse(angleController.text) ?? point.angle;
//               final name = nameController.text.isNotEmpty
//                   ? nameController.text
//                   : point.name;

//               setState(() {
//                 _simulationRoute[index] = RoutePoint(
//                   position: point.position,
//                   speed: speed,
//                   angle: angle,
//                   name: name,
//                   timestamp: point.timestamp,
//                 );
//               });

//               Navigator.pop(context);
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _deleteRoutePoint(int index) {
//     setState(() {
//       _simulationRoute.removeAt(index);
//       if (routePoints.length > index) {
//         routePoints.removeAt(index);
//       }
//     });
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Route point deleted')),
//     );
//   }

//   void _showAllRoutePoints() {
//     showDialog(
//       context: context,
//       builder: (context) => Dialog(
//         child: Container(
//           height: 400,
//           child: Column(
//             children: [
//               Padding(
//                 padding: EdgeInsets.all(16),
//                 child: Text(
//                   'Route Points (${_simulationRoute.length})',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//               ),
//               Expanded(
//                 child: ListView.builder(
//                   itemCount: _simulationRoute.length,
//                   itemBuilder: (context, index) {
//                     final point = _simulationRoute[index];
//                     return ListTile(
//                       leading: CircleAvatar(
//                         child: Text('${index + 1}'),
//                         backgroundColor: Colors.blue,
//                         foregroundColor: Colors.white,
//                       ),
//                       title: Text(point.name),
//                       subtitle: Text(
//                         'Speed: ${point.speed.toStringAsFixed(1)} km/h, '
//                         'Angle: ${point.angle.toStringAsFixed(1)}°',
//                       ),
//                       trailing: Icon(Icons.info_outline),
//                       onTap: () {
//                         Navigator.pop(context);
//                         _showRoutePointDetails(point, index);
//                       },
//                     );
//                   },
//                 ),
//               ),
//               Padding(
//                 padding: EdgeInsets.all(16),
//                 child: ElevatedButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: Text('Close'),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   void _zoomIn() {
//     _mapZoom += 1;
//     if (driverLocation != null) {
//       _mapController.move(driverLocation!, _mapZoom);
//     }
//   }

//   void _zoomOut() {
//     _mapZoom -= 1;
//     if (_mapZoom < 3) _mapZoom = 3;
//     if (driverLocation != null) {
//       _mapController.move(driverLocation!, _mapZoom);
//     }
//   }

//   void _centerOnDriver() {
//     if (driverLocation != null) {
//       _mapController.move(driverLocation!, _mapZoom);
//     }
//   }

//   double _calculateDistance(LatLng point1, LatLng point2) {
//     return (point1.latitude - point2.latitude).abs() +
//         (point1.longitude - point2.longitude).abs();
//   }

//   void _clearRoute() {
//     setState(() {
//       routePoints.clear();
//       _simulationRoute.clear();
//       _simulationViolations.clear();
//     });
//   }

//   void _startDefiningRoute() {
//     setState(() {
//       _isDefiningRoute = true;
//       _simulationRoute.clear();
//       _simulationViolations.clear();
//       routePoints.clear();
//     });

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Tap on the map to define route points'),
//         duration: Duration(seconds: 3),
//       ),
//     );
//   }

//   void _stopDefiningRoute() {
//     setState(() {
//       _isDefiningRoute = false;
//     });
//   }

//   void _onMapTap(LatLng position) {
//     if (_isDefiningRoute) {
//       setState(() {
//         _tempRoutePoint = position;
//       });
//       _showSpeedAngleDialog(position);
//     }
//   }

//   void _showSpeedAngleDialog(LatLng position) {
//     final nameController =
//         TextEditingController(text: 'Point ${_simulationRoute.length + 1}');
//     final intervalController = TextEditingController(text: '2');

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Route Point Settings'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: nameController,
//               decoration: InputDecoration(
//                 labelText: 'Point Name',
//                 hintText: 'Enter point name',
//               ),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: intervalController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(
//                 labelText: 'Time Interval (seconds)',
//                 hintText: 'Enter time since last point',
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               final interval = double.tryParse(intervalController.text) ?? 2.0;
//               final name = nameController.text.isNotEmpty
//                   ? nameController.text
//                   : 'Point ${_simulationRoute.length + 1}';

//               double speed = 0.0;
//               double angle = _currentAngle;

//               if (_simulationRoute.isNotEmpty) {
//                 final prevPoint = _simulationRoute.last;
//                 final distance =
//                     _calculateDistanceInMeters(prevPoint.position, position);
//                 final timeHours = interval / 3600;
//                 speed = timeHours > 0 ? distance / 1000 / timeHours : 0.0;

//                 _updateGyroData(interval);
//                 angle = _calculateAngleFromGyro();
//               }

//               setState(() {
//                 _simulationRoute.add(RoutePoint(
//                   position: position,
//                   name: name,
//                   timestamp: DateTime.now(),
//                   speed: speed,
//                   angle: angle,
//                   timeInterval: Duration(seconds: interval.toInt()),
//                 ));
//                 routePoints.add(position);
//               });

//               Navigator.pop(context);
//             },
//             child: Text('Add Point'),
//           ),
//         ],
//       ),
//     );
//   }

//   double _calculateDistanceInMeters(LatLng point1, LatLng point2) {
//     const Distance distance = Distance();
//     return distance(point1, point2);
//   }

//   void _updateGyroData(double interval) {
//     final random = math.Random();
//     _currentGyroZ = (random.nextDouble() * 20 - 10) +
//         (random.nextDouble() * _gyroNoiseLevel);

//     _gyroZValues.add(_currentGyroZ);
//     _gyroTimestamps.add(DateTime.now());

//     if (_gyroZValues.length > 10) {
//       _gyroZValues.removeAt(0);
//       _gyroTimestamps.removeAt(0);
//     }
//   }

//   double _calculateAngleFromGyro() {
//     if (_gyroZValues.isEmpty) return _currentAngle;

//     double angleChange = 0.0;
//     for (int i = 1; i < _gyroZValues.length; i++) {
//       final timeDiff =
//           _gyroTimestamps[i].difference(_gyroTimestamps[i - 1]).inMilliseconds /
//               1000.0;
//       angleChange += _gyroZValues[i] * timeDiff * _gyroToAngleFactor;
//     }

//     double newAngle = (_currentAngle + angleChange) % 360;
//     return newAngle;
//   }

//   void _initCarAnimation() {
//     _carAnimationController = AnimationController(
//       duration: Duration(milliseconds: (_carAnimationDuration * 1000).toInt()),
//       vsync: this,
//     );

//     _carAnimation = Tween<Offset>(
//       begin: Offset.zero,
//       end: Offset(0, -0.1),
//     ).animate(
//       CurvedAnimation(
//         parent: _carAnimationController!,
//         curve: Curves.easeInOut,
//       ),
//     )..addStatusListener((status) {
//         if (status == AnimationStatus.completed) {
//           _carAnimationController?.reverse();
//         } else if (status == AnimationStatus.dismissed) {
//           _carAnimationController?.forward();
//         }
//       });
//   }

//   void _startSimulation() {
//     if (_simulationRoute.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please define a route first')),
//       );
//       return;
//     }

//     if (_carAnimationController == null) {
//       _initCarAnimation();
//     }

//     _carAnimationController?.forward();

//     _gyroZValues.clear();
//     _gyroTimestamps.clear();
//     _currentGyroZ = 0.0;

//     setState(() {
//       _isSimulationRunning = true;
//       _currentRouteIndex = 0;
//       driverLocation = _simulationRoute[0].position;
//       _currentSpeed = _simulationRoute[0].speed;
//       _previousSpeed = _currentSpeed;
//       _currentAngle = _simulationRoute[0].angle;
//       _previousAngle = _currentAngle;
//       isDriverActive = true;
//       _simulationViolations.clear();
//       _previousLocation = driverLocation;
//       _simulationProgress = 0.0;
//     });

//     _simulationTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
//       _updateSimulation();
//     });

//     _startSendingSensorData();
//   }

//   void _startSendingSensorData() {
//     _sensorDataTimer?.cancel();
//     _sendSensorDataToApi();
//     _sensorDataTimer = Timer.periodic(
//       Duration(seconds: _sensorDataInterval.toInt()),
//       (timer) => _sendSensorDataToApi(),
//     );
//   }

//   void _stopSimulation() {
//     setState(() {
//       _isSimulationRunning = false;
//       isDriverActive = false;
//     });

//     _carAnimationController?.stop();
//     _simulationTimer?.cancel();
//     _sensorDataTimer?.cancel();

//     if (driverLocation != null) {
//       _sendFinalUpdate();
//     }
//   }

//   void _updateSimulation() {
//     if (_currentRouteIndex >= _simulationRoute.length - 1) {
//       _stopSimulation();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Simulation completed')),
//       );
//       return;
//     }

//     final currentPoint = _simulationRoute[_currentRouteIndex];
//     final nextPoint = _simulationRoute[_currentRouteIndex + 1];
//     final interval = nextPoint.timeInterval?.inMilliseconds ?? 1000;
//     final stepDuration = 100;
//     final steps = interval / stepDuration;

//     setState(() {
//       _simulationProgress += 1 / steps;

//       if (_simulationProgress >= 1.0) {
//         _currentRouteIndex++;
//         _simulationProgress = 0.0;
//         driverLocation = nextPoint.position;
//         _currentSpeed = nextPoint.speed;
//         _currentAngle = nextPoint.angle;
//       } else {
//         driverLocation = LatLng(
//           currentPoint.position.latitude +
//               _simulationProgress *
//                   (nextPoint.position.latitude -
//                       currentPoint.position.latitude),
//           currentPoint.position.longitude +
//               _simulationProgress *
//                   (nextPoint.position.longitude -
//                       currentPoint.position.longitude),
//         );
//         _currentSpeed = currentPoint.speed +
//             _simulationProgress * (nextPoint.speed - currentPoint.speed);
//       }

//       _updateGyroData(stepDuration / 1000);
//       _currentAngle = _calculateAngleFromGyro();

//       if (_simulationProgress == 0.0) {
//         _checkViolations(nextPoint);
//       }
//     });

//     _mapController.move(driverLocation!, _mapZoom);
//   }

//   void _checkViolations(RoutePoint point) {
//     if (point.speed > _speedLimit) {
//       _addSimulationViolation(
//         'Overspeeding',
//         point.position,
//         'Speed exceeded: ${point.speed.toStringAsFixed(1)} km/h',
//         point.speed - _speedLimit,
//       );
//     }

//     if (_simulationRoute.length > 1 && _currentRouteIndex > 0) {
//       final prevPoint = _simulationRoute[_currentRouteIndex - 1];
//       final timeDiff = point.timeInterval?.inSeconds ?? 1;

//       if (timeDiff > 0) {
//         final currentSpeedMs = point.speed * (1000 / 3600);
//         final prevSpeedMs = prevPoint.speed * (1000 / 3600);
//         final deceleration = (currentSpeedMs - prevSpeedMs) / timeDiff;

//         if (deceleration < _hardBrakingThreshold) {
//           _addSimulationViolation(
//             'HardBraking',
//             point.position,
//             'Hard braking detected: ${deceleration.toStringAsFixed(2)} m/s²',
//             deceleration.abs(),
//           );
//         }
//       }
//     }

//     if (_simulationRoute.length > 1 && _currentRouteIndex > 0) {
//       final prevPoint = _simulationRoute[_currentRouteIndex - 1];
//       final angleDiff = (point.angle - prevPoint.angle).abs();
//       final effectiveAngleDiff = angleDiff > 180 ? 360 - angleDiff : angleDiff;

//       if (effectiveAngleDiff > _sharpTurnThreshold) {
//         _addSimulationViolation(
//           'SharpTurn',
//           point.position,
//           'Sharp turn detected: ${effectiveAngleDiff.toStringAsFixed(1)}°',
//           effectiveAngleDiff,
//         );
//       }
//     }

//     bool insideAnyGeofence = false;
//     for (var polygon in geofencePolygons) {
//       if (_isPointInPolygon(point.position, polygon.points)) {
//         insideAnyGeofence = true;
//         break;
//       }
//     }

//     if (!insideAnyGeofence && geofencePolygons.isNotEmpty) {
//       _addSimulationViolation(
//         'Geofence Violation',
//         point.position,
//         'Vehicle outside designated area',
//         0.0,
//       );
//     }
//   }

//   bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
//     if (polygon.length < 3) return false;

//     bool inside = false;
//     int j = polygon.length - 1;

//     for (int i = 0; i < polygon.length; i++) {
//       final xi = polygon[i].latitude;
//       final yi = polygon[i].longitude;
//       final xj = polygon[j].latitude;
//       final yj = polygon[j].longitude;

//       if (((yi > point.longitude) != (yj > point.longitude)) &&
//           (point.latitude <
//               (xj - xi) * (point.longitude - yi) / (yj - yi) + xi)) {
//         inside = !inside;
//       }
//       j = i;
//     }

//     return inside;
//   }

//   void _addSimulationViolation(
//       String type, LatLng position, String description, double value) {
//     setState(() {
//       _simulationViolations.add(
//         SimulationViolation(
//           type: type,
//           position: position,
//           timestamp: DateTime.now(),
//           description: description,
//           value: value,
//         ),
//       );
//     });
//   }

//   void _showSimulationViolationDetails(SimulationViolation violation) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Simulation Violation'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Type: ${violation.type}',
//                 style: TextStyle(fontWeight: FontWeight.bold)),
//             SizedBox(height: 8),
//             Text('Description: ${violation.description}'),
//             SizedBox(height: 8),
//             Text('Value: ${violation.value.toStringAsFixed(2)}'),
//             SizedBox(height: 8),
//             Text('Time: ${violation.timestamp.toString().substring(0, 19)}'),
//             SizedBox(height: 8),
//             Text(
//                 'Location: ${violation.position.latitude.toStringAsFixed(6)}, ${violation.position.longitude.toStringAsFixed(6)}'),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> fetchGeofences() async {
//     try {
//       if (driverEmail == null) {
//         return;
//       }

//       print('Fetching geofences for driver email: $driverEmail');
//       final response = await http
//           .get(Uri.parse('$vehicledriverurl/assigned-geofence/$driverEmail'));

//       if (response.statusCode == 200) {
//         final List<dynamic> data = json.decode(response.body);

//         if (data.isEmpty) {
//           return;
//         }

//         setState(() {
//           geofencePolygons = data.map((geofence) {
//             List<LatLng> points = [];

//             if (geofence['coordinates'] is List) {
//               points = (geofence['coordinates'] as List)
//                   .map((point) {
//                     if (point is List && point.length >= 2) {
//                       return LatLng(point[0] is num ? point[0].toDouble() : 0.0,
//                           point[1] is num ? point[1].toDouble() : 0.0);
//                     }
//                     return null;
//                   })
//                   .where((point) => point != null)
//                   .cast<LatLng>()
//                   .toList();
//             }

//             return Polygon(
//               points: points,
//               color: Colors.blue.withOpacity(0.3),
//               borderColor: Colors.blue,
//               borderStrokeWidth: 2,
//             );
//           }).toList();
//         });
//       } else {
//         print('Failed to fetch geofences: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching geofences: $e');
//     }
//   }

//   void _startLocationUpdates() {
//     _timer = Timer.periodic(Duration(seconds: 5), (timer) {
//       if (!_isSimulationRunning) {
//         fetchDriverLocation();
//       }
//     });
//   }

//   Future<void> fetchDriverLocation() async {
//     try {
//       if (id == null) {
//         return;
//       }

//       final response =
//           await http.get(Uri.parse('$vehicledriverurl/live-location/$id'));

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         if (data.containsKey('latitude') && data.containsKey('longitude')) {
//           final newLocation = LatLng(
//               data['latitude'] is num ? data['latitude'].toDouble() : 0.0,
//               data['longitude'] is num ? data['longitude'].toDouble() : 0.0);

//           bool isDriving = _parseDrivingStatus(data['isdriving']);

//           DateTime? lastUpdate;
//           if (data.containsKey('lastUpdated')) {
//             try {
//               lastUpdate = DateTime.parse(data['lastUpdated']);
//             } catch (e) {
//               print('Error parsing timestamp: $e');
//             }
//           }

//           bool isRecentUpdate = false;
//           if (lastUpdate != null) {
//             DateTime now = DateTime.now();
//             Duration difference = now.difference(lastUpdate);
//             isRecentUpdate = difference.inMinutes < 5;
//           }

//           setState(() {
//             driverLocation = newLocation;
//             _lastLocationUpdate = lastUpdate;
//             isDriverActive = isDriving && isRecentUpdate;

//             if (isDriverActive && driverLocation != null) {
//               if (routePoints.isEmpty ||
//                   _calculateDistance(routePoints.last, driverLocation!) >
//                       0.00005) {
//                 routePoints.add(driverLocation!);
//                 if (routePoints.length > 100) {
//                   routePoints.removeAt(0);
//                 }
//               }
//             }
//           });

//           if (!_initialPositionSet && driverLocation != null) {
//             _mapController.move(driverLocation!, _mapZoom);
//             _initialPositionSet = true;
//           } else if (isDriverActive && driverLocation != null) {
//             _mapZoom = _mapController.camera.zoom;
//             _mapController.move(driverLocation!, _mapZoom);
//           }
//         }
//       }
//     } catch (e) {
//       print('Error fetching location: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Center(child: Text("Enhanced Driver Simulation")),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.list),
//             onPressed: _simulationRoute.isNotEmpty ? _showAllRoutePoints : null,
//             tooltip: "View All Points",
//           ),
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: () {
//               if (!_isSimulationRunning) {
//                 fetchDriverLocation();
//               }
//             },
//             tooltip: "Refresh Location",
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Card(
//               elevation: 2,
//               child: Padding(
//                 padding: EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Vehicle Simulation',
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     SizedBox(height: 12),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: ElevatedButton.icon(
//                             onPressed: _isSimulationRunning
//                                 ? null
//                                 : (_isDefiningRoute
//                                     ? _stopDefiningRoute
//                                     : _startDefiningRoute),
//                             icon: Icon(
//                                 _isDefiningRoute ? Icons.stop : Icons.route),
//                             label: Text(_isDefiningRoute
//                                 ? 'Stop Defining'
//                                 : 'Define Route'),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: _isDefiningRoute
//                                   ? Colors.orange
//                                   : Colors.blue,
//                             ),
//                           ),
//                         ),
//                         SizedBox(width: 12),
//                         Expanded(
//                           child: ElevatedButton.icon(
//                             onPressed: _isDefiningRoute
//                                 ? null
//                                 : (_isSimulationRunning
//                                     ? _stopSimulation
//                                     : _startSimulation),
//                             icon: Icon(_isSimulationRunning
//                                 ? Icons.stop
//                                 : Icons.play_arrow),
//                             label: Text(_isSimulationRunning
//                                 ? 'Stop Driving'
//                                 : 'Start Driving'),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: _isSimulationRunning
//                                   ? Colors.red
//                                   : Colors.green,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     if (_isSimulationRunning) ...[
//                       SizedBox(height: 12),
//                       Text(
//                           'Current Speed: ${_currentSpeed.toStringAsFixed(1)} km/h'),
//                       Text(
//                           'Current Angle: ${_currentAngle.toStringAsFixed(1)}°'),
//                       Text(
//                           'Route Progress: ${_currentRouteIndex + 1}/${_simulationRoute.length}'),
//                     ],
//                     if (_simulationRoute.isNotEmpty) ...[
//                       SizedBox(height: 8),
//                       Text('Route Points: ${_simulationRoute.length}'),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//             if (_isSimulationRunning)
//               LinearProgressIndicator(
//                 value: (_currentRouteIndex + _simulationProgress) /
//                     _simulationRoute.length,
//                 backgroundColor: Colors.grey[300],
//                 color: Colors.blue,
//                 minHeight: 8,
//               ),
//             Expanded(
//               child: Stack(
//                 children: [
//                   ClipRRect(
//                     borderRadius: BorderRadius.circular(10),
//                     child: FlutterMap(
//                       mapController: _mapController,
//                       options: MapOptions(
//                         initialCenter:
//                             driverLocation ?? const LatLng(33.6995, 73.0363),
//                         initialZoom: _mapZoom,
//                         onTap: (tapPosition, point) => _onMapTap(point),
//                         onMapEvent: (event) {
//                           if (event.source == MapEventSource.mapController ||
//                               event.source ==
//                                   MapEventSource.flingAnimationController ||
//                               event.source ==
//                                   MapEventSource
//                                       .doubleTapZoomAnimationController) {
//                             _mapZoom = _mapController.camera.zoom;
//                           }
//                         },
//                       ),
//                       children: [
//                         TileLayer(
//                           urlTemplate:
//                               "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
//                           subdomains: const ['a', 'b', 'c'],
//                         ),
//                         PolygonLayer(polygons: geofencePolygons),
//                         if (routePoints.isNotEmpty && routePoints.length > 1)
//                           PolylineLayer(
//                             polylines: [
//                               Polyline(
//                                 points: routePoints,
//                                 color: Colors.deepPurple,
//                                 strokeWidth: 4.0,
//                               ),
//                             ],
//                           ),
//                         if (_showViolations)
//                           MarkerLayer(
//                             markers: violations.map((violation) {
//                               return Marker(
//                                 width: 40.0,
//                                 height: 40.0,
//                                 point: LatLng(violation['latitude'],
//                                     violation['longitude']),
//                                 child: GestureDetector(
//                                   onTap: () => _showViolationDetails(violation),
//                                   child: Container(
//                                     padding: EdgeInsets.all(6),
//                                     decoration: BoxDecoration(
//                                       color: Colors.white,
//                                       borderRadius: BorderRadius.circular(20),
//                                       border: Border.all(
//                                           color: Colors.red, width: 2),
//                                     ),
//                                     child: Icon(
//                                       _getViolationIcon(violation['eventtype']),
//                                       color: Colors.red,
//                                       size: 20,
//                                     ),
//                                   ),
//                                 ),
//                               );
//                             }).toList(),
//                           ),
//                         if (_showViolations)
//                           MarkerLayer(
//                             markers: _simulationViolations.map((violation) {
//                               return Marker(
//                                 width: 40.0,
//                                 height: 40.0,
//                                 point: violation.position,
//                                 child: GestureDetector(
//                                   onTap: () => _showSimulationViolationDetails(
//                                       violation),
//                                   child: Container(
//                                     padding: EdgeInsets.all(6),
//                                     decoration: BoxDecoration(
//                                       color: Colors.white,
//                                       borderRadius: BorderRadius.circular(20),
//                                       border: Border.all(
//                                           color: Colors.orange, width: 2),
//                                     ),
//                                     child: Icon(
//                                       _getViolationIcon(violation.type),
//                                       color: Colors.orange,
//                                       size: 20,
//                                     ),
//                                   ),
//                                 ),
//                               );
//                             }).toList(),
//                           ),
//                         MarkerLayer(
//                           markers:
//                               _simulationRoute.asMap().entries.map((entry) {
//                             int index = entry.key;
//                             RoutePoint point = entry.value;
//                             return Marker(
//                               width: 30.0,
//                               height: 30.0,
//                               point: point.position,
//                               child: Container(
//                                 decoration: BoxDecoration(
//                                   color: Colors.blue,
//                                   borderRadius: BorderRadius.circular(15),
//                                   border:
//                                       Border.all(color: Colors.white, width: 2),
//                                 ),
//                                 child: Center(
//                                   child: Text(
//                                     '${index + 1}',
//                                     style: TextStyle(
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 12,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             );
//                           }).toList(),
//                         ),
//                         if (driverLocation != null)
//                           MarkerLayer(
//                             markers: [
//                               Marker(
//                                 width: 50.0,
//                                 height: 50.0,
//                                 point: driverLocation!,
//                                 child: Transform.rotate(
//                                   angle: _currentAngle * (math.pi / 180),
//                                   child: AnimatedBuilder(
//                                     animation: _carAnimationController ??
//                                         AnimationController(vsync: this),
//                                     builder: (context, child) {
//                                       return Transform.translate(
//                                         offset: isDriverActive
//                                             ? _carAnimation?.value ??
//                                                 Offset.zero
//                                             : Offset.zero,
//                                         child: Icon(
//                                           isDriverActive
//                                               ? Icons.directions_car_filled
//                                               : Icons.directions_car_outlined,
//                                           color: isDriverActive
//                                               ? Colors.green
//                                               : Colors.red,
//                                           size: 36,
//                                         ),
//                                       );
//                                     },
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                       ],
//                     ),
//                   ),
//                   Positioned(
//                     top: 10,
//                     right: 10,
//                     child: Column(
//                       children: [
//                         Container(
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(5),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black26,
//                                 blurRadius: 5,
//                                 offset: Offset(0, 2),
//                               ),
//                             ],
//                           ),
//                           child: Column(
//                             children: [
//                               IconButton(
//                                 icon: Icon(Icons.add),
//                                 onPressed: _zoomIn,
//                                 tooltip: 'Zoom in',
//                               ),
//                               Divider(height: 1, thickness: 1),
//                               IconButton(
//                                 icon: Icon(Icons.remove),
//                                 onPressed: _zoomOut,
//                                 tooltip: 'Zoom out',
//                               ),
//                             ],
//                           ),
//                         ),
//                         SizedBox(height: 10),
//                         Container(
//                           decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.circular(5),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.black26,
//                                   blurRadius: 5,
//                                   offset: Offset(0, 2),
//                                 ),
//                               ]),
//                           child: IconButton(
//                             icon: Icon(Icons.my_location),
//                             onPressed: _centerOnDriver,
//                             tooltip: 'Center on driver',
//                           ),
//                         ),
//                         SizedBox(height: 10),
//                         Container(
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(5),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black26,
//                                 blurRadius: 5,
//                                 offset: Offset(0, 2),
//                               ),
//                             ],
//                           ),
//                           child: IconButton(
//                             icon: Icon(Icons.clear_all),
//                             onPressed: _clearRoute,
//                             tooltip: 'Clear route',
//                           ),
//                         ),
//                         SizedBox(height: 10),
//                         Container(
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(5),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black26,
//                                 blurRadius: 5,
//                                 offset: Offset(0, 2),
//                               ),
//                             ],
//                           ),
//                           child: IconButton(
//                             icon: Icon(
//                               _showViolations
//                                   ? Icons.warning_amber
//                                   : Icons.warning_amber_outlined,
//                               color: _showViolations ? Colors.red : Colors.grey,
//                             ),
//                             onPressed: () {
//                               setState(() {
//                                 _showViolations = !_showViolations;
//                               });
//                             },
//                             tooltip: 'Toggle violations',
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   Positioned(
//                     bottom: 10,
//                     left: 10,
//                     child: Container(
//                       padding: EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.8),
//                         borderRadius: BorderRadius.circular(5),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               Icon(Icons.directions_car_filled,
//                                   color: Colors.green, size: 20),
//                               SizedBox(width: 5),
//                               Text('Active'),
//                             ],
//                           ),
//                           SizedBox(height: 5),
//                           Row(
//                             children: [
//                               Icon(Icons.directions_car_outlined,
//                                   color: Colors.red, size: 20),
//                               SizedBox(width: 5),
//                               Text('Inactive'),
//                             ],
//                           ),
//                           SizedBox(height: 5),
//                           Row(
//                             children: [
//                               Container(
//                                 width: 20,
//                                 height: 3,
//                                 color: Colors.deepPurple,
//                               ),
//                               SizedBox(width: 5),
//                               Text('Route'),
//                             ],
//                           ),
//                           SizedBox(height: 5),
//                           Row(
//                             children: [
//                               Container(
//                                 width: 15,
//                                 height: 15,
//                                 decoration: BoxDecoration(
//                                   color: Colors.blue.withOpacity(0.3),
//                                   border: Border.all(color: Colors.blue),
//                                 ),
//                               ),
//                               SizedBox(width: 5),
//                               Text('Geofence'),
//                             ],
//                           ),
//                           SizedBox(height: 5),
//                           Row(
//                             children: [
//                               Icon(Icons.warning, color: Colors.red, size: 20),
//                               SizedBox(width: 5),
//                               Text('Violation'),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// import 'dart:async';
// import 'dart:convert';
// import 'dart:math' as math;
// import 'package:admin_signup/Screens/MainDashboard.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class RoutePoint {
//   final LatLng position;
//   final double speed;
//   final double angle;
//   final String name;
//   final DateTime timestamp;
//   final Duration? timeInterval;

//   RoutePoint({
//     required this.position,
//     required this.name,
//     required this.timestamp,
//     this.speed = 0.0,
//     this.angle = 0.0,
//     this.timeInterval,
//   });
// }

// class SimulationViolation {
//   final String type;
//   final LatLng position;
//   final DateTime timestamp;
//   final String description;
//   final double value;

//   SimulationViolation({
//     required this.type,
//     required this.position,
//     required this.timestamp,
//     required this.description,
//     required this.value,
//   });
// }

// class DriverDetailsScreen extends StatefulWidget {
//   const DriverDetailsScreen({Key? key}) : super(key: key);

//   @override
//   _DriverDetailsScreenState createState() => _DriverDetailsScreenState();
// }

// class _DriverDetailsScreenState extends State<DriverDetailsScreen>
//     with TickerProviderStateMixin {
//   // Driver and vehicle info
//   var dvid, id;
//   String? picture, name, model, lp, driverEmail;

//   // Location and mapping
//   LatLng? driverLocation;
//   final MapController _mapController = MapController();
//   double _mapZoom = 11.0;
//   bool _initialPositionSet = false;

//   // Activity tracking
//   bool isDriverActive = false;
//   List<LatLng> routePoints = [];
//   List<Polygon> geofencePolygons = [];

//   // Simulation controls
//   bool _isDefiningRoute = false;
//   bool _isSimulationRunning = false;
//   List<RoutePoint> _simulationRoute = [];
//   int _currentRouteIndex = 0;
//   double _simulationProgress = 0.0;

//   // Animation
//   AnimationController? _carAnimationController;
//   Animation<Offset>? _carAnimation;
//   double _carAnimationDuration = 1.0;

//   // Sensors and physics
//   double _currentSpeed = 0.0;
//   double _previousSpeed = 0.0;
//   double _currentAngle = 0.0;
//   double _previousAngle = 0.0;
//   double _currentGyroZ = 0.0;
//   List<double> _gyroZValues = [];
//   List<DateTime> _gyroTimestamps = [];

//   // Violation detection
//   List<SimulationViolation> _simulationViolations = [];
//   bool _showViolations = true;
//   double _speedLimit = 60.0;
//   double _hardBrakingThreshold = -1.5;
//   double _sharpTurnThreshold = 45.0;
//   double _gyroToAngleFactor = 0.07;
//   double _gyroNoiseLevel = 0.5;

//   // Timers
//   Timer? _timer;
//   Timer? _simulationTimer;
//   Timer? _sensorDataTimer;
//   double _sensorDataInterval = 1.0;

//   @override
//   void initState() {
//     super.initState();
//     fetchDriverDetails();
//     _startLocationUpdates();
//   }

//   @override
//   void dispose() {
//     _carAnimationController?.dispose();
//     _timer?.cancel();
//     _simulationTimer?.cancel();
//     _sensorDataTimer?.cancel();
//     super.dispose();
//   }

//   IconData _getViolationIcon(String eventType) {
//     switch (eventType.toLowerCase()) {
//       case 'speeding':
//       case 'overspeeding':
//         return Icons.speed;
//       case 'harsh braking':
//       case 'hardbraking':
//         return Icons.emergency;
//       case 'harsh acceleration':
//         return Icons.rocket_launch;
//       case 'sharp turn':
//       case 'sharpturn':
//         return Icons.turn_right;
//       case 'geofence violation':
//         return Icons.fence;
//       default:
//         return Icons.warning;
//     }
//   }

//   // API Communication Methods
//   Future<void> _sendFinalUpdate() async {
//     try {
//       final response = await http.post(
//         Uri.parse('$vehicledriverurl/current-location'),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode({
//           'driverId': id,
//           'latitude': driverLocation?.latitude ?? 0,
//           'longitude': driverLocation?.longitude ?? 0,
//           'speed': 0.0,
//           'angle': _currentAngle,
//           'timestamp': DateTime.now().toIso8601String(),
//           'isDriving': false,
//           'gyroscope': {'x': 0, 'y': 0, 'z': _currentGyroZ},
//           'accelerometer': {'x': 0, 'y': 0, 'z': 0},
//           'drivervehicleid': dvid,
//         }),
//       );

//       if (response.statusCode == 200) {
//         print('Final update sent successfully');
//       } else {
//         print('Failed to send final update: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error sending final update: $e');
//     }
//   }

//   Future<void> _sendSensorDataToApi() async {
//     if (!_isSimulationRunning || driverLocation == null) return;

//     try {
//       // Simulate accelerometer data based on movement
//       final random = math.Random();
//       final accelZ = _previousSpeed != 0
//           ? ((_currentSpeed - _previousSpeed) / (_sensorDataInterval * 3.6))
//           : random.nextDouble() * 0.5 - 0.25;

//       final response = await http.post(
//         Uri.parse('$vehicledriverurl/current-location'),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode({
//           'driverId': id,
//           'latitude': driverLocation!.latitude,
//           'longitude': driverLocation!.longitude,
//           'speed': _currentSpeed,
//           'angle': _currentAngle,
//           'timestamp': DateTime.now().toIso8601String(),
//           'isDriving': true,
//           'gyroscope': {'x': 0, 'y': 0, 'z': _currentGyroZ},
//           'accelerometer': {'x': 0, 'y': 0, 'z': accelZ},
//           'drivervehicleid': dvid,
//         }),
//       );

//       if (response.statusCode == 200) {
//         print('Sensor data sent successfully');
//       } else {
//         print('Failed to send sensor data: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error sending sensor data: $e');
//     }
//   }

//   Future<void> fetchDriverDetails() async {
//     SharedPreferences pref = await SharedPreferences.getInstance();
//     setState(() {
//       dvid = pref.getInt('drivervehicleid');
//       id = pref.getInt('id');
//       picture = pref.getString('picture');
//       name = pref.getString('name');
//       model = pref.getString('model');
//       lp = pref.getString('licenseno');
//       driverEmail = pref.getString('email');
//     });

//     try {
//       final response =
//           await http.get(Uri.parse('$vehicledriverurl/inspect-driver/$id'));
//       if (response.statusCode == 200) {
//         print('Successfully loaded driver details');
//         await fetchGeofences();
//       } else {
//         print('Failed to load driver details: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching driver details: $e');
//     }
//   }

//   Future<void> fetchGeofences() async {
//     try {
//       if (driverEmail == null) return;

//       final response = await http
//           .get(Uri.parse('$vehicledriverurl/assigned-geofence/$driverEmail'));
//       if (response.statusCode == 200) {
//         final List<dynamic> data = json.decode(response.body);

//         setState(() {
//           geofencePolygons = data.map((geofence) {
//             List<LatLng> points = [];

//             if (geofence['coordinates'] is List) {
//               points = (geofence['coordinates'] as List)
//                   .map((point) {
//                     if (point is List && point.length >= 2) {
//                       return LatLng(
//                         point[0] is num ? point[0].toDouble() : 0.0,
//                         point[1] is num ? point[1].toDouble() : 0.0,
//                       );
//                     }
//                     return null;
//                   })
//                   .where((point) => point != null)
//                   .cast<LatLng>()
//                   .toList();
//             }

//             return Polygon(
//               points: points,
//               color: Colors.blue.withOpacity(0.3),
//               borderColor: Colors.blue,
//               borderStrokeWidth: 2,
//             );
//           }).toList();
//         });
//       }
//     } catch (e) {
//       print('Error fetching geofences: $e');
//     }
//   }

//   void _startLocationUpdates() {
//     _timer = Timer.periodic(Duration(seconds: 5), (timer) {
//       if (!_isSimulationRunning) {
//         _fetchDriverLocation();
//       }
//     });
//   }

//   Future<void> _fetchDriverLocation() async {
//     try {
//       if (id == null) return;

//       final response =
//           await http.get(Uri.parse('$vehicledriverurl/live-location/$id'));
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         if (data.containsKey('latitude') && data.containsKey('longitude')) {
//           final newLocation = LatLng(
//             data['latitude'] is num ? data['latitude'].toDouble() : 0.0,
//             data['longitude'] is num ? data['longitude'].toDouble() : 0.0,
//           );

//           bool isDriving = _parseDrivingStatus(data['isdriving']);
//           bool isRecentUpdate = false;

//           if (data.containsKey('lastUpdated')) {
//             try {
//               final lastUpdate = DateTime.parse(data['lastUpdated']);
//               isRecentUpdate =
//                   DateTime.now().difference(lastUpdate).inMinutes < 5;
//             } catch (e) {
//               print('Error parsing timestamp: $e');
//             }
//           }

//           setState(() {
//             driverLocation = newLocation;
//             isDriverActive = isDriving && isRecentUpdate;

//             if (isDriverActive && driverLocation != null) {
//               if (routePoints.isEmpty ||
//                   _calculateDistance(routePoints.last, driverLocation!) >
//                       0.00005) {
//                 routePoints.add(driverLocation!);
//                 if (routePoints.length > 100) routePoints.removeAt(0);
//               }
//             }
//           });

//           if (!_initialPositionSet && driverLocation != null) {
//             _mapController.move(driverLocation!, _mapZoom);
//             _initialPositionSet = true;
//           } else if (isDriverActive && driverLocation != null) {
//             _mapZoom = _mapController.camera.zoom;
//             _mapController.move(driverLocation!, _mapZoom);
//           }
//         }
//       }
//     } catch (e) {
//       print('Error fetching location: $e');
//     }
//   }

//   double _calculateDistance(LatLng point1, LatLng point2) {
//     return (point1.latitude - point2.latitude).abs() +
//         (point1.longitude - point2.longitude).abs();
//   }

//   // Simulation Control Methods
//   void _initCarAnimation() {
//     _carAnimationController = AnimationController(
//       duration: Duration(milliseconds: (_carAnimationDuration * 1000).toInt()),
//       vsync: this,
//     );

//     _carAnimation = Tween<Offset>(
//       begin: Offset.zero,
//       end: Offset(0, -0.1),
//     ).animate(
//       CurvedAnimation(
//         parent: _carAnimationController!,
//         curve: Curves.easeInOut,
//       ),
//     )..addStatusListener((status) {
//         if (status == AnimationStatus.completed) {
//           _carAnimationController?.reverse();
//         } else if (status == AnimationStatus.dismissed) {
//           _carAnimationController?.forward();
//         }
//       });
//   }

//   void _startSimulation() {
//     if (_simulationRoute.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please define a route first')),
//       );
//       return;
//     }

//     if (_carAnimationController == null) {
//       _initCarAnimation();
//     }

//     _carAnimationController?.forward();
//     _gyroZValues.clear();
//     _gyroTimestamps.clear();
//     _currentGyroZ = 0.0;

//     setState(() {
//       _isSimulationRunning = true;
//       _currentRouteIndex = 0;
//       driverLocation = _simulationRoute[0].position;
//       _currentSpeed = _simulationRoute[0].speed;
//       _previousSpeed = _currentSpeed;
//       _currentAngle = _simulationRoute[0].angle;
//       _previousAngle = _currentAngle;
//       isDriverActive = true;
//       _simulationViolations.clear();
//       _simulationProgress = 0.0;
//     });

//     _simulationTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
//       _updateSimulation();
//     });

//     _startSendingSensorData();
//   }

//   void _startSendingSensorData() {
//     _sensorDataTimer?.cancel();
//     _sendSensorDataToApi();
//     _sensorDataTimer = Timer.periodic(
//       Duration(seconds: _sensorDataInterval.toInt()),
//       (timer) => _sendSensorDataToApi(),
//     );
//   }

//   void _stopSimulation() {
//     setState(() {
//       _isSimulationRunning = false;
//       isDriverActive = false;
//     });

//     _carAnimationController?.stop();
//     _simulationTimer?.cancel();
//     _sensorDataTimer?.cancel();

//     if (driverLocation != null) {
//       _sendFinalUpdate();
//     }
//   }

//   bool _parseDrivingStatus(dynamic drivingValue) {
//     if (drivingValue is bool) {
//       return drivingValue;
//     } else if (drivingValue is String) {
//       return drivingValue.toLowerCase() == 'true' ||
//           drivingValue == 't' ||
//           drivingValue == 'yes' ||
//           drivingValue == 'y' ||
//           drivingValue == '1';
//     } else if (drivingValue is num) {
//       return drivingValue != 0;
//     }
//     return false;
//   }

//   void _updateSimulation() {
//     if (_currentRouteIndex >= _simulationRoute.length - 1) {
//       _stopSimulation();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Simulation completed')),
//       );
//       return;
//     }

//     final currentPoint = _simulationRoute[_currentRouteIndex];
//     final nextPoint = _simulationRoute[_currentRouteIndex + 1];
//     final interval = nextPoint.timeInterval?.inMilliseconds ?? 1000;
//     final stepDuration = 100;
//     final steps = interval / stepDuration;

//     setState(() {
//       _simulationProgress += 1 / steps;

//       if (_simulationProgress >= 1.0) {
//         _currentRouteIndex++;
//         _simulationProgress = 0.0;
//         driverLocation = nextPoint.position;
//         _currentSpeed = nextPoint.speed;
//         _currentAngle = nextPoint.angle;
//       } else {
//         driverLocation = LatLng(
//           currentPoint.position.latitude +
//               _simulationProgress *
//                   (nextPoint.position.latitude -
//                       currentPoint.position.latitude),
//           currentPoint.position.longitude +
//               _simulationProgress *
//                   (nextPoint.position.longitude -
//                       currentPoint.position.longitude),
//         );
//         _currentSpeed = currentPoint.speed +
//             _simulationProgress * (nextPoint.speed - currentPoint.speed);
//       }

//       _updateGyroData(stepDuration / 1000);
//       _currentAngle = _calculateAngleFromGyro();

//       if (_simulationProgress == 0.0) {
//         _checkViolations(nextPoint);
//       }
//     });

//     _mapController.move(driverLocation!, _mapZoom);
//   }

//   // Sensor Data Processing
//   void _updateGyroData(double interval) {
//     final random = math.Random();
//     _currentGyroZ = (random.nextDouble() * 20 - 10) +
//         (random.nextDouble() * _gyroNoiseLevel);

//     _gyroZValues.add(_currentGyroZ);
//     _gyroTimestamps.add(DateTime.now());

//     if (_gyroZValues.length > 10) {
//       _gyroZValues.removeAt(0);
//       _gyroTimestamps.removeAt(0);
//     }
//   }

//   double _calculateAngleFromGyro() {
//     if (_gyroZValues.isEmpty) return _currentAngle;

//     double angleChange = 0.0;
//     for (int i = 1; i < _gyroZValues.length; i++) {
//       final timeDiff =
//           _gyroTimestamps[i].difference(_gyroTimestamps[i - 1]).inMilliseconds /
//               1000.0;
//       angleChange += _gyroZValues[i] * timeDiff * _gyroToAngleFactor;
//     }

//     return (_currentAngle + angleChange) % 360;
//   }

//   // Violation Detection
//   void _checkViolations(RoutePoint point) {
//     // Overspeeding
//     if (point.speed > _speedLimit) {
//       _addSimulationViolation(
//         'Overspeeding',
//         point.position,
//         'Speed exceeded: ${point.speed.toStringAsFixed(1)} km/h',
//         point.speed - _speedLimit,
//       );
//     }

//     // Hard braking
//     if (_simulationRoute.length > 1 && _currentRouteIndex > 0) {
//       final prevPoint = _simulationRoute[_currentRouteIndex - 1];
//       final timeDiff = point.timeInterval?.inSeconds ?? 1;

//       if (timeDiff > 0) {
//         final currentSpeedMs = point.speed * (1000 / 3600);
//         final prevSpeedMs = prevPoint.speed * (1000 / 3600);
//         final deceleration = (currentSpeedMs - prevSpeedMs) / timeDiff;

//         if (deceleration < _hardBrakingThreshold) {
//           _addSimulationViolation(
//             'HardBraking',
//             point.position,
//             'Hard braking detected: ${deceleration.toStringAsFixed(2)} m/s²',
//             deceleration.abs(),
//           );
//         }
//       }
//     }

//     // Sharp turn
//     if (_simulationRoute.length > 1 && _currentRouteIndex > 0) {
//       final prevPoint = _simulationRoute[_currentRouteIndex - 1];
//       final angleDiff = (point.angle - prevPoint.angle).abs();
//       final effectiveAngleDiff = angleDiff > 180 ? 360 - angleDiff : angleDiff;

//       if (effectiveAngleDiff > _sharpTurnThreshold) {
//         _addSimulationViolation(
//           'SharpTurn',
//           point.position,
//           'Sharp turn detected: ${effectiveAngleDiff.toStringAsFixed(1)}°',
//           effectiveAngleDiff,
//         );
//       }
//     }

//     // Geofence violation
//     bool insideAnyGeofence = false;
//     for (var polygon in geofencePolygons) {
//       if (_isPointInPolygon(point.position, polygon.points)) {
//         insideAnyGeofence = true;
//         break;
//       }
//     }

//     if (!insideAnyGeofence && geofencePolygons.isNotEmpty) {
//       _addSimulationViolation(
//         'Geofence Violation',
//         point.position,
//         'Vehicle outside designated area',
//         0.0,
//       );
//     }
//   }

//   void _addSimulationViolation(
//       String type, LatLng position, String description, double value) {
//     setState(() {
//       _simulationViolations.add(
//         SimulationViolation(
//           type: type,
//           position: position,
//           timestamp: DateTime.now(),
//           description: description,
//           value: value,
//         ),
//       );
//     });
//   }

//   // Route Management
//   void _startDefiningRoute() {
//     setState(() {
//       _isDefiningRoute = true;
//       _simulationRoute.clear();
//       _simulationViolations.clear();
//       routePoints.clear();
//     });
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Tap on the map to define route points')),
//     );
//   }

//   void _stopDefiningRoute() {
//     setState(() {
//       _isDefiningRoute = false;
//     });
//   }

//   void _onMapTap(LatLng position) {
//     if (_isDefiningRoute) {
//       _showSpeedAngleDialog(position);
//     }
//   }

//   void _showSpeedAngleDialog(LatLng position) {
//     final nameController =
//         TextEditingController(text: 'Point ${_simulationRoute.length + 1}');
//     final intervalController = TextEditingController(text: '2');

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Route Point Settings'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: nameController,
//               decoration: InputDecoration(labelText: 'Point Name'),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: intervalController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: 'Time Interval (seconds)'),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               final interval = double.tryParse(intervalController.text) ?? 2.0;
//               final name = nameController.text.isNotEmpty
//                   ? nameController.text
//                   : 'Point ${_simulationRoute.length + 1}';

//               double speed = 0.0;
//               double angle = _currentAngle;

//               if (_simulationRoute.isNotEmpty) {
//                 final prevPoint = _simulationRoute.last;
//                 final distance =
//                     _calculateDistanceInMeters(prevPoint.position, position);
//                 final timeHours = interval / 3600;
//                 speed = timeHours > 0 ? distance / 1000 / timeHours : 0.0;

//                 _updateGyroData(interval);
//                 angle = _calculateAngleFromGyro();
//               }

//               setState(() {
//                 _simulationRoute.add(RoutePoint(
//                   position: position,
//                   name: name,
//                   timestamp: DateTime.now(),
//                   speed: speed,
//                   angle: angle,
//                   timeInterval: Duration(seconds: interval.toInt()),
//                 ));
//                 routePoints.add(position);
//               });

//               Navigator.pop(context);
//             },
//             child: Text('Add Point'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showAllRoutePoints() {
//     showDialog(
//       context: context,
//       builder: (context) => Dialog(
//         child: Container(
//           height: 400,
//           child: Column(
//             children: [
//               Padding(
//                 padding: EdgeInsets.all(16),
//                 child: Text(
//                   'Route Points (${_simulationRoute.length})',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//               ),
//               Expanded(
//                 child: ListView.builder(
//                   itemCount: _simulationRoute.length,
//                   itemBuilder: (context, index) {
//                     final point = _simulationRoute[index];
//                     return ListTile(
//                       leading: CircleAvatar(
//                         child: Text('${index + 1}'),
//                         backgroundColor: Colors.blue,
//                         foregroundColor: Colors.white,
//                       ),
//                       title: Text(point.name),
//                       subtitle: Text(
//                         'Speed: ${point.speed.toStringAsFixed(1)} km/h, '
//                         'Angle: ${point.angle.toStringAsFixed(1)}°',
//                       ),
//                       trailing: Icon(Icons.info_outline),
//                       onTap: () {
//                         Navigator.pop(context);
//                         _showRoutePointDetails(point, index);
//                       },
//                     );
//                   },
//                 ),
//               ),
//               Padding(
//                 padding: EdgeInsets.all(16),
//                 child: ElevatedButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: Text('Close'),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   void _showRoutePointDetails(RoutePoint point, int index) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Route Point Details'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Point: ${point.name}'),
//             Text('Index: ${index + 1}'),
//             Text('Speed: ${point.speed.toStringAsFixed(1)} km/h'),
//             Text('Angle: ${point.angle.toStringAsFixed(1)}°'),
//             Text('Latitude: ${point.position.latitude.toStringAsFixed(6)}'),
//             Text('Longitude: ${point.position.longitude.toStringAsFixed(6)}'),
//             Text('Created: ${point.timestamp.toString().substring(0, 19)}'),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _editRoutePoint(index);
//             },
//             child: Text('Edit'),
//           ),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _deleteRoutePoint(index);
//             },
//             child: Text('Delete', style: TextStyle(color: Colors.red)),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _editRoutePoint(int index) {
//     final point = _simulationRoute[index];
//     final speedController = TextEditingController(text: point.speed.toString());
//     final angleController = TextEditingController(text: point.angle.toString());
//     final nameController = TextEditingController(text: point.name);

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Route Point'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: nameController,
//               decoration: InputDecoration(labelText: 'Point Name'),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: speedController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: 'Speed (km/h)'),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: angleController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: 'Angle (degrees)'),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               final speed =
//                   double.tryParse(speedController.text) ?? point.speed;
//               final angle =
//                   double.tryParse(angleController.text) ?? point.angle;
//               final name = nameController.text.isNotEmpty
//                   ? nameController.text
//                   : point.name;

//               setState(() {
//                 _simulationRoute[index] = RoutePoint(
//                   position: point.position,
//                   speed: speed,
//                   angle: angle,
//                   name: name,
//                   timestamp: point.timestamp,
//                 );
//               });

//               Navigator.pop(context);
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _deleteRoutePoint(int index) {
//     setState(() {
//       _simulationRoute.removeAt(index);
//       if (routePoints.length > index) {
//         routePoints.removeAt(index);
//       }
//     });
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Route point deleted')),
//     );
//   }

//   void _clearRoute() {
//     setState(() {
//       routePoints.clear();
//       _simulationRoute.clear();
//       _simulationViolations.clear();
//     });
//   }

//   // Helper Methods
//   double _calculateDistanceInMeters(LatLng point1, LatLng point2) {
//     const Distance distance = Distance();
//     return distance(point1, point2);
//   }

//   bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
//     if (polygon.length < 3) return false;

//     bool inside = false;
//     int j = polygon.length - 1;

//     for (int i = 0; i < polygon.length; i++) {
//       final xi = polygon[i].latitude;
//       final yi = polygon[i].longitude;
//       final xj = polygon[j].latitude;
//       final yj = polygon[j].longitude;

//       if (((yi > point.longitude) != (yj > point.longitude)) &&
//           (point.latitude <
//               (xj - xi) * (point.longitude - yi) / (yj - yi) + xi)) {
//         inside = !inside;
//       }
//       j = i;
//     }

//     return inside;
//   }

//   void _zoomIn() {
//     _mapZoom += 1;
//     if (driverLocation != null) {
//       _mapController.move(driverLocation!, _mapZoom);
//     }
//   }

//   void _zoomOut() {
//     _mapZoom -= 1;
//     if (_mapZoom < 3) _mapZoom = 3;
//     if (driverLocation != null) {
//       _mapController.move(driverLocation!, _mapZoom);
//     }
//   }

//   void _centerOnDriver() {
//     if (driverLocation != null) {
//       _mapController.move(driverLocation!, _mapZoom);
//     }
//   }

//   void _showSimulationViolationDetails(SimulationViolation violation) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Simulation Violation'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Type: ${violation.type}',
//                 style: TextStyle(fontWeight: FontWeight.bold)),
//             SizedBox(height: 8),
//             Text('Description: ${violation.description}'),
//             SizedBox(height: 8),
//             Text('Value: ${violation.value.toStringAsFixed(2)}'),
//             SizedBox(height: 8),
//             Text('Time: ${violation.timestamp.toString().substring(0, 19)}'),
//             SizedBox(height: 8),
//             Text('Location: ${violation.position.latitude.toStringAsFixed(6)}, '
//                 '${violation.position.longitude.toStringAsFixed(6)}'),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Center(child: Text("Enhanced Driver Simulation")),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.list),
//             onPressed: _simulationRoute.isNotEmpty ? _showAllRoutePoints : null,
//             tooltip: "View All Points",
//           ),
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: () {
//               if (!_isSimulationRunning) {
//                 _fetchDriverLocation();
//               }
//             },
//             tooltip: "Refresh Location",
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Card(
//               elevation: 2,
//               child: Padding(
//                 padding: EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Vehicle Simulation',
//                       style:
//                           TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                     ),
//                     SizedBox(height: 12),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: ElevatedButton.icon(
//                             onPressed: _isSimulationRunning
//                                 ? null
//                                 : (_isDefiningRoute
//                                     ? _stopDefiningRoute
//                                     : _startDefiningRoute),
//                             icon: Icon(
//                                 _isDefiningRoute ? Icons.stop : Icons.route),
//                             label: Text(_isDefiningRoute
//                                 ? 'Stop Defining'
//                                 : 'Define Route'),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: _isDefiningRoute
//                                   ? Colors.orange
//                                   : Colors.blue,
//                             ),
//                           ),
//                         ),
//                         SizedBox(width: 12),
//                         Expanded(
//                           child: ElevatedButton.icon(
//                             onPressed: _isDefiningRoute
//                                 ? null
//                                 : (_isSimulationRunning
//                                     ? _stopSimulation
//                                     : _startSimulation),
//                             icon: Icon(_isSimulationRunning
//                                 ? Icons.stop
//                                 : Icons.play_arrow),
//                             label: Text(_isSimulationRunning
//                                 ? 'Stop Driving'
//                                 : 'Start Driving'),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: _isSimulationRunning
//                                   ? Colors.red
//                                   : Colors.green,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     if (_isSimulationRunning) ...[
//                       SizedBox(height: 12),
//                       Text(
//                           'Current Speed: ${_currentSpeed.toStringAsFixed(1)} km/h'),
//                       Text(
//                           'Current Angle: ${_currentAngle.toStringAsFixed(1)}°'),
//                       Text(
//                           'Route Progress: ${_currentRouteIndex + 1}/${_simulationRoute.length}'),
//                     ],
//                     if (_simulationRoute.isNotEmpty) ...[
//                       SizedBox(height: 8),
//                       Text('Route Points: ${_simulationRoute.length}'),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//             if (_isSimulationRunning)
//               LinearProgressIndicator(
//                 value: (_currentRouteIndex + _simulationProgress) /
//                     _simulationRoute.length,
//                 backgroundColor: Colors.grey[300],
//                 color: Colors.blue,
//                 minHeight: 8,
//               ),
//             Expanded(
//               child: Stack(
//                 children: [
//                   ClipRRect(
//                     borderRadius: BorderRadius.circular(10),
//                     child: FlutterMap(
//                       mapController: _mapController,
//                       options: MapOptions(
//                         initialCenter:
//                             driverLocation ?? const LatLng(33.6995, 73.0363),
//                         initialZoom: _mapZoom,
//                         onTap: (tapPosition, point) => _onMapTap(point),
//                         onMapEvent: (event) {
//                           if (event.source == MapEventSource.mapController ||
//                               event.source ==
//                                   MapEventSource.flingAnimationController ||
//                               event.source ==
//                                   MapEventSource
//                                       .doubleTapZoomAnimationController) {
//                             _mapZoom = _mapController.camera.zoom;
//                           }
//                         },
//                       ),
//                       children: [
//                         TileLayer(
//                           urlTemplate:
//                               "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
//                           subdomains: const ['a', 'b', 'c'],
//                         ),
//                         PolygonLayer(polygons: geofencePolygons),
//                         if (routePoints.isNotEmpty && routePoints.length > 1)
//                           PolylineLayer(
//                             polylines: [
//                               Polyline(
//                                 points: routePoints,
//                                 color: Colors.deepPurple,
//                                 strokeWidth: 4.0,
//                               ),
//                             ],
//                           ),
//                         if (_showViolations)
//                           MarkerLayer(
//                             markers: _simulationViolations.map((violation) {
//                               return Marker(
//                                 width: 40.0,
//                                 height: 40.0,
//                                 point: violation.position,
//                                 child: GestureDetector(
//                                   onTap: () => _showSimulationViolationDetails(
//                                       violation),
//                                   child: Container(
//                                     padding: EdgeInsets.all(6),
//                                     decoration: BoxDecoration(
//                                       color: Colors.white,
//                                       borderRadius: BorderRadius.circular(20),
//                                       border: Border.all(
//                                           color: Colors.orange, width: 2),
//                                     ),
//                                     child: Icon(
//                                       _getViolationIcon(violation.type),
//                                       color: Colors.orange,
//                                       size: 20,
//                                     ),
//                                   ),
//                                 ),
//                               );
//                             }).toList(),
//                           ),
//                         MarkerLayer(
//                           markers:
//                               _simulationRoute.asMap().entries.map((entry) {
//                             int index = entry.key;
//                             RoutePoint point = entry.value;
//                             return Marker(
//                               width: 30.0,
//                               height: 30.0,
//                               point: point.position,
//                               child: Container(
//                                 decoration: BoxDecoration(
//                                   color: Colors.blue,
//                                   borderRadius: BorderRadius.circular(15),
//                                   border:
//                                       Border.all(color: Colors.white, width: 2),
//                                 ),
//                                 child: Center(
//                                   child: Text(
//                                     '${index + 1}',
//                                     style: TextStyle(
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 12,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             );
//                           }).toList(),
//                         ),
//                         if (driverLocation != null)
//                           MarkerLayer(
//                             markers: [
//                               Marker(
//                                 width: 50.0,
//                                 height: 50.0,
//                                 point: driverLocation!,
//                                 child: Transform.rotate(
//                                   angle: _currentAngle * (math.pi / 180),
//                                   child: AnimatedBuilder(
//                                     animation: _carAnimationController ??
//                                         AnimationController(vsync: this),
//                                     builder: (context, child) {
//                                       return Transform.translate(
//                                         offset: isDriverActive
//                                             ? _carAnimation?.value ??
//                                                 Offset.zero
//                                             : Offset.zero,
//                                         child: Icon(
//                                           isDriverActive
//                                               ? Icons.directions_car_filled
//                                               : Icons.directions_car_outlined,
//                                           color: isDriverActive
//                                               ? Colors.green
//                                               : Colors.red,
//                                           size: 36,
//                                         ),
//                                       );
//                                     },
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                       ],
//                     ),
//                   ),
//                   Positioned(
//                     top: 10,
//                     right: 10,
//                     child: Column(
//                       children: [
//                         Container(
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(5),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black26,
//                                 blurRadius: 5,
//                                 offset: Offset(0, 2),
//                               ),
//                             ],
//                           ),
//                           child: Column(
//                             children: [
//                               IconButton(
//                                 icon: Icon(Icons.add),
//                                 onPressed: _zoomIn,
//                                 tooltip: 'Zoom in',
//                               ),
//                               Divider(height: 1, thickness: 1),
//                               IconButton(
//                                 icon: Icon(Icons.remove),
//                                 onPressed: _zoomOut,
//                                 tooltip: 'Zoom out',
//                               ),
//                             ],
//                           ),
//                         ),
//                         SizedBox(height: 10),
//                         Container(
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(5),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black26,
//                                 blurRadius: 5,
//                                 offset: Offset(0, 2),
//                               ),
//                             ],
//                           ),
//                           child: IconButton(
//                             icon: Icon(Icons.my_location),
//                             onPressed: _centerOnDriver,
//                             tooltip: 'Center on driver',
//                           ),
//                         ),
//                         SizedBox(height: 10),
//                         Container(
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(5),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black26,
//                                 blurRadius: 5,
//                                 offset: Offset(0, 2),
//                               ),
//                             ],
//                           ),
//                           child: IconButton(
//                             icon: Icon(Icons.clear_all),
//                             onPressed: _clearRoute,
//                             tooltip: 'Clear route',
//                           ),
//                         ),
//                         SizedBox(height: 10),
//                         Container(
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(5),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black26,
//                                 blurRadius: 5,
//                                 offset: Offset(0, 2),
//                               ),
//                             ],
//                           ),
//                           child: IconButton(
//                             icon: Icon(
//                               _showViolations
//                                   ? Icons.warning_amber
//                                   : Icons.warning_amber_outlined,
//                               color: _showViolations ? Colors.red : Colors.grey,
//                             ),
//                             onPressed: () {
//                               setState(() {
//                                 _showViolations = !_showViolations;
//                               });
//                             },
//                             tooltip: 'Toggle violations',
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   Positioned(
//                     bottom: 10,
//                     left: 10,
//                     child: Container(
//                       padding: EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.8),
//                         borderRadius: BorderRadius.circular(5),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               Icon(Icons.directions_car_filled,
//                                   color: Colors.green, size: 20),
//                               SizedBox(width: 5),
//                               Text('Active'),
//                             ],
//                           ),
//                           SizedBox(height: 5),
//                           Row(
//                             children: [
//                               Icon(Icons.directions_car_outlined,
//                                   color: Colors.red, size: 20),
//                               SizedBox(width: 5),
//                               Text('Inactive'),
//                             ],
//                           ),
//                           SizedBox(height: 5),
//                           Row(
//                             children: [
//                               Container(
//                                 width: 20,
//                                 height: 3,
//                                 color: Colors.deepPurple,
//                               ),
//                               SizedBox(width: 5),
//                               Text('Route'),
//                             ],
//                           ),
//                           SizedBox(height: 5),
//                           Row(
//                             children: [
//                               Container(
//                                 width: 15,
//                                 height: 15,
//                                 decoration: BoxDecoration(
//                                   color: Colors.blue.withOpacity(0.3),
//                                   border: Border.all(color: Colors.blue),
//                                 ),
//                               ),
//                               SizedBox(width: 5),
//                               Text('Geofence'),
//                             ],
//                           ),
//                           SizedBox(height: 5),
//                           Row(
//                             children: [
//                               Icon(Icons.warning, color: Colors.red, size: 20),
//                               SizedBox(width: 5),
//                               Text('Violation'),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'dart:async';
// import 'dart:math' as math;
// import 'package:sensors_plus/sensors_plus.dart';
// import 'package:geolocator/geolocator.dart';

// class DriverDetailsScreen extends StatefulWidget {
//   @override
//   DriverDetailsScreenState createState() => DriverDetailsScreenState();
// }

// class DriverDetailsScreenState extends State<DriverDetailsScreen> {
//   final MapController _mapController = MapController();
//   final List<LatLng> _routePoints = [];
//   final List<double> _timeIntervals = [];
//   final List<Marker> _violationMarkers = [];

//   // Animation and driving state
//   bool _isDriving = false;
//   int _currentPointIndex = 0;
//   LatLng _currentPosition = LatLng(33.6844, 73.0479); // Default: Rawalpindi
//   Timer? _drivingTimer;
//   Timer? _sensorTimer;

//   // Sensor data
//   late StreamSubscription<AccelerometerEvent> _accelerometerSubscription;
//   late StreamSubscription<GyroscopeEvent> _gyroscopeSubscription;
//   AccelerometerEvent? _currentAccelerometer;
//   GyroscopeEvent? _currentGyroscope;

//   // Speed and distance calculations
//   double _currentSpeed = 0.0;
//   double _totalDistance = 0.0;
//   DateTime _lastPositionTime = DateTime.now();

//   // UI Controllers
//   final TextEditingController _driverVehicleIdController =
//       TextEditingController();
//   final TextEditingController _apiUrlController = TextEditingController();
//   final TextEditingController _latController = TextEditingController();
//   final TextEditingController _lngController = TextEditingController();
//   final TextEditingController _timeIntervalController = TextEditingController();

//   // Configuration
//   String _driverVehicleId = "1";
//   String _apiUrl = "http://your-api-url.com/api/current-location";

//   @override
//   void initState() {
//     super.initState();
//     _initializeSensors();
//     _driverVehicleIdController.text = _driverVehicleId;
//     _apiUrlController.text = _apiUrl;
//   }

//   void _initializeSensors() {
//     // Initialize accelerometer
//     _accelerometerSubscription =
//         accelerometerEvents.listen((AccelerometerEvent event) {
//       setState(() {
//         _currentAccelerometer = event;
//       });
//     });

//     // Initialize gyroscope
//     _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
//       setState(() {
//         _currentGyroscope = event;
//       });
//     });
//   }

//   // Haversine formula for distance calculation
//   double _calculateDistance(LatLng point1, LatLng point2) {
//     const double earthRadius = 6371000; // Earth's radius in meters

//     double lat1Rad = point1.latitude * math.pi / 180;
//     double lat2Rad = point2.latitude * math.pi / 180;
//     double deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
//     double deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180;

//     double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
//         math.cos(lat1Rad) *
//             math.cos(lat2Rad) *
//             math.sin(deltaLngRad / 2) *
//             math.sin(deltaLngRad / 2);

//     double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

//     return earthRadius * c; // Distance in meters
//   }

//   // Calculate speed using V = d/t
//   double _calculateSpeed(LatLng point1, LatLng point2, double timeInterval) {
//     double distance = _calculateDistance(point1, point2);
//     double speed = (distance / timeInterval) * 3.6; // Convert m/s to km/h
//     return speed;
//   }

//   void _addRoutePoint() {
//     if (_latController.text.isNotEmpty &&
//         _lngController.text.isNotEmpty &&
//         _timeIntervalController.text.isNotEmpty) {
//       double lat = double.parse(_latController.text);
//       double lng = double.parse(_lngController.text);
//       double timeInterval = double.parse(_timeIntervalController.text);

//       setState(() {
//         _routePoints.add(LatLng(lat, lng));
//         _timeIntervals.add(timeInterval);
//       });

//       _latController.clear();
//       _lngController.clear();
//       _timeIntervalController.clear();

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('Point added: ${_routePoints.length} points total')),
//       );
//     }
//   }

//   void _clearRoute() {
//     setState(() {
//       _routePoints.clear();
//       _timeIntervals.clear();
//       _violationMarkers.clear();
//       _currentPointIndex = 0;
//     });
//   }

//   void _startDriving() {
//     if (_routePoints.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please add route points first')),
//       );
//       return;
//     }

//     if (_driverVehicleIdController.text.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please enter Driver Vehicle ID')),
//       );
//       return;
//     }

//     setState(() {
//       _isDriving = true;
//       _currentPointIndex = 0;
//       _currentPosition = _routePoints[0];
//       _driverVehicleId = _driverVehicleIdController.text;
//       _apiUrl = _apiUrlController.text;
//     });

//     _mapController.move(_currentPosition, 15.0);
//     _startRouteAnimation();
//     _startSensorDataTransmission();
//   }

//   void _stopDriving() {
//     setState(() {
//       _isDriving = false;
//     });

//     _drivingTimer?.cancel();
//     _sensorTimer?.cancel();
//   }

//   void _startRouteAnimation() {
//     if (_currentPointIndex >= _routePoints.length - 1) {
//       _stopDriving();
//       return;
//     }

//     LatLng startPoint = _routePoints[_currentPointIndex];
//     LatLng endPoint = _routePoints[_currentPointIndex + 1];
//     double timeInterval = _timeIntervals[_currentPointIndex];

//     // Calculate speed for this segment
//     _currentSpeed = _calculateSpeed(startPoint, endPoint, timeInterval);

//     // Animation parameters
//     int animationSteps = (timeInterval * 10).round(); // 10 steps per second
//     int stepDuration = (timeInterval * 1000 / animationSteps).round();

//     int currentStep = 0;

//     _drivingTimer =
//         Timer.periodic(Duration(milliseconds: stepDuration), (timer) {
//       if (currentStep >= animationSteps) {
//         timer.cancel();
//         _currentPointIndex++;
//         _startRouteAnimation(); // Move to next segment
//         return;
//       }

//       // Interpolate position
//       double progress = currentStep / animationSteps;
//       double lat = startPoint.latitude +
//           (endPoint.latitude - startPoint.latitude) * progress;
//       double lng = startPoint.longitude +
//           (endPoint.longitude - startPoint.longitude) * progress;

//       setState(() {
//         _currentPosition = LatLng(lat, lng);
//       });

//       // Update map center
//       _mapController.move(_currentPosition, _mapController.zoom);

//       currentStep++;
//     });
//   }

//   void _startSensorDataTransmission() {
//     _sensorTimer = Timer.periodic(Duration(seconds: 1), (timer) {
//       if (!_isDriving) {
//         timer.cancel();
//         return;
//       }

//       _sendDataToAPI();
//     });
//   }

//   Future<void> _sendDataToAPI() async {
//     if (_currentAccelerometer == null || _currentGyroscope == null) {
//       return;
//     }

//     try {
//       Map<String, dynamic> data = {
//         'longitude': _currentPosition.longitude,
//         'latitude': _currentPosition.latitude,
//         'speed': _currentSpeed,
//         'gyroscope': {
//           'x': _currentGyroscope!.x,
//           'y': _currentGyroscope!.y,
//           'z': _currentGyroscope!.z,
//         },
//         'accelerometer': {
//           'x': _currentAccelerometer!.x,
//           'y': _currentAccelerometer!.y,
//           'z': _currentAccelerometer!.z,
//         },
//         'drivervehicleid': _driverVehicleId,
//       };

//       final response = await http.post(
//         Uri.parse(_apiUrl),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode(data),
//       );

//       if (response.statusCode == 200) {
//         var responseData = json.decode(response.body);
//         _checkForViolations(responseData);
//       }
//     } catch (e) {
//       print('Error sending data to API: $e');
//     }
//   }

//   void _checkForViolations(Map<String, dynamic> response) {
//     String message = response['message'] ?? '';

//     if (message.contains('OverSpeeding') ||
//         message.contains('SharpTurn') ||
//         message.contains('Hard Braking') ||
//         message.contains('GeofenceViolation')) {
//       _addViolationMarker(message);
//     }
//   }

//   void _addViolationMarker(String violation) {
//     setState(() {
//       _violationMarkers.add(
//         Marker(
//           width: 50.0,
//           height: 50.0,
//           point: _currentPosition,
//           child: Container(
//             child: Icon(
//               Icons.warning,
//               color: Colors.red,
//               size: 30,
//             ),
//           ),
//         ),
//       );
//     });

//     // Show violation dialog
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Violation Detected!'),
//         content: Text(violation),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Driving Simulator'),
//         backgroundColor: Colors.blue,
//       ),
//       body: Column(
//         children: [
//           // Configuration Panel
//           Container(
//             padding: EdgeInsets.all(16),
//             color: Colors.grey[100],
//             child: Column(
//               children: [
//                 Row(
//                   children: [
//                     Expanded(
//                       child: TextField(
//                         controller: _driverVehicleIdController,
//                         decoration: InputDecoration(
//                           labelText: 'Driver Vehicle ID',
//                           border: OutlineInputBorder(),
//                         ),
//                       ),
//                     ),
//                     SizedBox(width: 10),
//                     Expanded(
//                       child: TextField(
//                         controller: _apiUrlController,
//                         decoration: InputDecoration(
//                           labelText: 'API URL',
//                           border: OutlineInputBorder(),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 10),
//                 // Route point input
//                 Row(
//                   children: [
//                     Expanded(
//                       child: TextField(
//                         controller: _latController,
//                         decoration: InputDecoration(
//                           labelText: 'Latitude',
//                           border: OutlineInputBorder(),
//                         ),
//                         keyboardType: TextInputType.number,
//                       ),
//                     ),
//                     SizedBox(width: 5),
//                     Expanded(
//                       child: TextField(
//                         controller: _lngController,
//                         decoration: InputDecoration(
//                           labelText: 'Longitude',
//                           border: OutlineInputBorder(),
//                         ),
//                         keyboardType: TextInputType.number,
//                       ),
//                     ),
//                     SizedBox(width: 5),
//                     Expanded(
//                       child: TextField(
//                         controller: _timeIntervalController,
//                         decoration: InputDecoration(
//                           labelText: 'Time (sec)',
//                           border: OutlineInputBorder(),
//                         ),
//                         keyboardType: TextInputType.number,
//                       ),
//                     ),
//                     SizedBox(width: 5),
//                     ElevatedButton(
//                       onPressed: _addRoutePoint,
//                       child: Text('Add'),
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 10),
//                 // Control buttons
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     ElevatedButton(
//                       onPressed: _isDriving ? null : _startDriving,
//                       child: Text('Start Driving'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.green,
//                       ),
//                     ),
//                     ElevatedButton(
//                       onPressed: _isDriving ? _stopDriving : null,
//                       child: Text('Stop Driving'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.red,
//                       ),
//                     ),
//                     ElevatedButton(
//                       onPressed: _clearRoute,
//                       child: Text('Clear Route'),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           // Status Panel
//           Container(
//             padding: EdgeInsets.all(8),
//             color: Colors.blue[50],
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 Text('Points: ${_routePoints.length}'),
//                 Text('Speed: ${_currentSpeed.toStringAsFixed(1)} km/h'),
//                 Text('Status: ${_isDriving ? "Driving" : "Stopped"}'),
//               ],
//             ),
//           ),
//           // Sensor Data Panel
//           Container(
//             padding: EdgeInsets.all(8),
//             color: Colors.orange[50],
//             child: Column(
//               children: [
//                 Text('Real-time Sensor Data:'),
//                 if (_currentAccelerometer != null)
//                   Text(
//                       'Accelerometer: X=${_currentAccelerometer!.x.toStringAsFixed(2)}, Y=${_currentAccelerometer!.y.toStringAsFixed(2)}, Z=${_currentAccelerometer!.z.toStringAsFixed(2)}'),
//                 if (_currentGyroscope != null)
//                   Text(
//                       'Gyroscope: X=${_currentGyroscope!.x.toStringAsFixed(2)}, Y=${_currentGyroscope!.y.toStringAsFixed(2)}, Z=${_currentGyroscope!.z.toStringAsFixed(2)}'),
//               ],
//             ),
//           ),
//           // Map
//           Expanded(
//             child: FlutterMap(
//               mapController: _mapController,
//               options: MapOptions(
//                 center: _currentPosition,
//                 zoom: 15.0,
//               ),
//               children: [
//                 TileLayer(
//                   urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//                   userAgentPackageName: 'com.example.driving_simulator',
//                 ),
//                 // Route polyline
//                 if (_routePoints.isNotEmpty)
//                   PolylineLayer(
//                     polylines: [
//                       Polyline(
//                         points: _routePoints,
//                         strokeWidth: 4.0,
//                         color: Colors.blue,
//                       ),
//                     ],
//                   ),
//                 // Route points markers
//                 MarkerLayer(
//                   markers: _routePoints.asMap().entries.map((entry) {
//                     int index = entry.key;
//                     LatLng point = entry.value;
//                     return Marker(
//                       width: 30.0,
//                       height: 30.0,
//                       point: point,
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: Colors.blue,
//                           shape: BoxShape.circle,
//                         ),
//                         child: Center(
//                           child: Text(
//                             '${index + 1}',
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 12,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       ),
//                     );
//                   }).toList(),
//                 ),
//                 // Current position marker (car)
//                 MarkerLayer(
//                   markers: [
//                     Marker(
//                       width: 40.0,
//                       height: 40.0,
//                       point: _currentPosition,
//                       child: Container(
//                         child: Icon(
//                           Icons.directions_car,
//                           color: _isDriving ? Colors.green : Colors.grey,
//                           size: 30,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 // Violation markers
//                 MarkerLayer(
//                   markers: _violationMarkers,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _drivingTimer?.cancel();
//     _sensorTimer?.cancel();
//     _accelerometerSubscription.cancel();
//     _gyroscopeSubscription.cancel();
//     _latController.dispose();
//     _lngController.dispose();
//     _timeIntervalController.dispose();
//     _driverVehicleIdController.dispose();
//     _apiUrlController.dispose();
//     super.dispose();
//   }
// }

// import 'package:admin_signup/Screens/MainDashboard.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'dart:async';
// import 'dart:math' as math;
// import 'package:sensors_plus/sensors_plus.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class DriverDetailsScreen extends StatefulWidget {
//   @override
//   DriverDetailsScreenState createState() => DriverDetailsScreenState();
// }

// class DriverDetailsScreenState extends State<DriverDetailsScreen> {
//   final MapController _mapController = MapController();
//   final List<LatLng> _routePoints = [];
//   final List<double> _timeIntervals = [];
//   final List<Marker> _violationMarkers = [];
//   final List<Map<String, dynamic>> _violationsList =
//       []; // Store violations with details
//   List<Polygon> _geofencePolygons = [];
//   final TextEditingController _timeIntervalController = TextEditingController();

//   // Animation and driving state
//   bool _isDriving = false;
//   int _currentPointIndex = 0;
//   LatLng _currentPosition = LatLng(33.6844, 73.0479); // Default: Rawalpindi
//   Timer? _drivingTimer;
//   Timer? _sensorTimer;

//   // Sensor data
//   late StreamSubscription<AccelerometerEvent> _accelerometerSubscription;
//   late StreamSubscription<GyroscopeEvent> _gyroscopeSubscription;
//   AccelerometerEvent? _currentAccelerometer;
//   GyroscopeEvent? _currentGyroscope;

//   // Speed and distance calculations
//   double _currentSpeed = 0.0;
//   double _totalDistance = 0.0;
//   DateTime _lastPositionTime = DateTime.now();

//   // Driver details
//   int? dvid;
//   int? id;
//   String? picture;
//   String? name;
//   String? model;
//   String? lp;
//   String? driverEmail;

//   @override
//   void initState() {
//     super.initState();
//     _initializeSensors();
//     fetchDriverDetails();
//   }

//   Future fetchDriverDetails() async {
//     SharedPreferences pref = await SharedPreferences.getInstance();
//     setState(() {
//       dvid = pref.getInt('drivervehicleid');
//       id = pref.getInt('id');
//       picture = pref.getString('picture');
//       name = pref.getString('name');
//       model = pref.getString('model');
//       lp = pref.getString('licenseno');
//       driverEmail = pref.getString('email');
//     });

//     try {
//       final response =
//           await http.get(Uri.parse('$vehicledriverurl/inspect-driver/$id'));
//       if (response.statusCode == 200) {
//         print('Successfully loaded driver details');
//         await fetchGeofences();
//       } else {
//         print('Failed to load driver details: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching driver details: $e');
//     }
//   }

//   Future fetchGeofences() async {
//     try {
//       if (driverEmail == null) return;

//       final response = await http
//           .get(Uri.parse('$vehicledriverurl/assigned-geofence/$driverEmail'));
//       if (response.statusCode == 200) {
//         final List data = json.decode(response.body);

//         setState(() {
//           _geofencePolygons = data.map((geofence) {
//             List<LatLng> points = [];

//             if (geofence['coordinates'] is List) {
//               points = (geofence['coordinates'] as List)
//                   .map((point) {
//                     if (point is List && point.length >= 2) {
//                       return LatLng(
//                         point[0] is num ? point[0].toDouble() : 0.0,
//                         point[1] is num ? point[1].toDouble() : 0.0,
//                       );
//                     }
//                     return null;
//                   })
//                   .whereType<LatLng>()
//                   .toList();
//             }

//             return Polygon(
//               points: points,
//               color: Colors.blue.withOpacity(0.3),
//               borderColor: Colors.blue,
//               borderStrokeWidth: 2,
//             );
//           }).toList();
//         });
//       }
//     } catch (e) {
//       print('Error fetching geofences: $e');
//     }
//   }

//   void _initializeSensors() {
//     // Initialize accelerometer
//     _accelerometerSubscription =
//         accelerometerEvents.listen((AccelerometerEvent event) {
//       setState(() {
//         _currentAccelerometer = event;
//       });
//     });

//     // Initialize gyroscope
//     _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
//       setState(() {
//         _currentGyroscope = event;
//       });
//     });
//   }

//   // Haversine formula for distance calculation
//   double _calculateDistance(LatLng point1, LatLng point2) {
//     const double earthRadius = 6371000; // Earth's radius in meters

//     double lat1Rad = point1.latitude * math.pi / 180;
//     double lat2Rad = point2.latitude * math.pi / 180;
//     double deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
//     double deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180;

//     double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
//         math.cos(lat1Rad) *
//             math.cos(lat2Rad) *
//             math.sin(deltaLngRad / 2) *
//             math.sin(deltaLngRad / 2);

//     double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

//     return earthRadius * c; // Distance in meters
//   }

//   // Calculate speed using V = d/t
//   double _calculateSpeed(LatLng point1, LatLng point2, double timeInterval) {
//     double distance = _calculateDistance(point1, point2);
//     double speed = (distance / timeInterval) * 3.6; // Convert m/s to km/h
//     return speed;
//   }

//   void _handleMapTap(TapPosition tapPosition, LatLng point) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Add Route Point'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('Latitude: ${point.latitude.toStringAsFixed(6)}'),
//             Text('Longitude: ${point.longitude.toStringAsFixed(6)}'),
//             TextField(
//               controller: _timeIntervalController,
//               decoration: InputDecoration(
//                 labelText: 'Time Interval (seconds)',
//               ),
//               keyboardType: TextInputType.number,
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               if (_timeIntervalController.text.isNotEmpty) {
//                 double timeInterval =
//                     double.parse(_timeIntervalController.text);
//                 setState(() {
//                   _routePoints.add(point);
//                   _timeIntervals.add(timeInterval);
//                 });
//                 _timeIntervalController.clear();
//                 Navigator.pop(context);
//               }
//             },
//             child: Text('Add'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _clearRoute() {
//     setState(() {
//       _routePoints.clear();
//       _timeIntervals.clear();
//       _violationMarkers.clear();
//       _currentPointIndex = 0;
//     });
//   }

//   void _startDriving() {
//     if (_routePoints.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please add route points first')),
//       );
//       return;
//     }

//     if (dvid == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Driver vehicle ID not available')),
//       );
//       return;
//     }

//     setState(() {
//       _isDriving = true;
//       _currentPointIndex = 0;
//       _currentPosition = _routePoints[0];
//     });

//     _mapController.move(_currentPosition, 15.0);
//     _startRouteAnimation();
//     _startSensorDataTransmission();
//   }

//   void _stopDriving() {
//     setState(() {
//       _isDriving = false;
//     });

//     _drivingTimer?.cancel();
//     _sensorTimer?.cancel();

//     // Show summary of violations after driving stops
//     if (_violationsList.isNotEmpty) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         showDialog(
//           context: context,
//           builder: (context) => AlertDialog(
//             title: Text('Driving Completed'),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text('Total Violations: ${_violationsList.length}'),
//                 SizedBox(height: 10),
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     _showViolationsList();
//                   },
//                   child: Text('View All Violations'),
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: Text('OK'),
//               ),
//             ],
//           ),
//         );
//       });
//     }
//   }

//   void _showViolationsList() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('All Violations'),
//         content: Container(
//           width: double.maxFinite,
//           child: ListView.builder(
//             shrinkWrap: true,
//             itemCount: _violationsList.length,
//             itemBuilder: (context, index) {
//               final violation = _violationsList[index];
//               return ListTile(
//                 leading: Icon(Icons.warning, color: Colors.red),
//                 title: Text(violation['type']),
//                 subtitle: Text(
//                     'Speed: ${violation['speed'].toStringAsFixed(1)} km/h'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _showViolationDetails(violation);
//                 },
//               );
//             },
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _startRouteAnimation() {
//     // Reset overspeeding detection for new segment
//     _overspeedingDetectedInSegment = false;

//     if (_currentPointIndex >= _routePoints.length - 1) {
//       _stopDriving();
//       return;
//     }

//     LatLng startPoint = _routePoints[_currentPointIndex];
//     LatLng endPoint = _routePoints[_currentPointIndex + 1];
//     double timeInterval = _timeIntervals[_currentPointIndex];

//     // Calculate speed for this segment
//     _currentSpeed = _calculateSpeed(startPoint, endPoint, timeInterval);

//     // Animation parameters
//     int animationSteps = (timeInterval * 10).round(); // 10 steps per second
//     int stepDuration = (timeInterval * 1000 / animationSteps).round();

//     int currentStep = 0;

//     _drivingTimer =
//         Timer.periodic(Duration(milliseconds: stepDuration), (timer) {
//       if (currentStep >= animationSteps) {
//         timer.cancel();
//         _currentPointIndex++;
//         _startRouteAnimation(); // Move to next segment
//         return;
//       }

//       // Interpolate position
//       double progress = currentStep / animationSteps;
//       double lat = startPoint.latitude +
//           (endPoint.latitude - startPoint.latitude) * progress;
//       double lng = startPoint.longitude +
//           (endPoint.longitude - startPoint.longitude) * progress;

//       setState(() {
//         _currentPosition = LatLng(lat, lng);
//       });

//       // Update map center
//       _mapController.move(_currentPosition, _mapController.zoom);

//       currentStep++;
//     });
//   }

//   void _startSensorDataTransmission() {
//     _sensorTimer = Timer.periodic(Duration(seconds: 1), (timer) {
//       if (!_isDriving) {
//         timer.cancel();
//         return;
//       }

//       _sendDataToAPI();
//     });
//   }

//   Future<void> _sendDataToAPI() async {
//     if (_currentAccelerometer == null ||
//         _currentGyroscope == null ||
//         dvid == null) {
//       return;
//     }

//     try {
//       Map<String, dynamic> data = {
//         'longitude': _currentPosition.longitude,
//         'latitude': _currentPosition.latitude,
//         'speed': _currentSpeed,
//         'gyroscope': {
//           'x': _currentGyroscope!.x,
//           'y': _currentGyroscope!.y,
//           'z': _currentGyroscope!.z,
//         },
//         'accelerometer': {
//           'x': _currentAccelerometer!.x,
//           'y': _currentAccelerometer!.y,
//           'z': _currentAccelerometer!.z,
//         },
//         'drivervehicleid': dvid,
//       };

//       final response = await http.post(
//         Uri.parse('$vehicledriverurl/current-location'),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode(data),
//       );

//       if (response.statusCode == 200) {
//         var responseData = json.decode(response.body);
//         _checkForViolations(responseData);
//       }
//     } catch (e) {
//       print('Error sending data to API: $e');
//     }
//   }

//   bool _overspeedingDetectedInSegment = false;

// // Modify the _checkForViolations method
//   void _checkForViolations(Map<String, dynamic> response) {
//     String message = response['message'] ?? '';
//     String violationType = '';

//     if (message.contains('OverSpeeding')) {
//       if (!_overspeedingDetectedInSegment) {
//         violationType = 'OverSpeeding';
//         _overspeedingDetectedInSegment = true;
//       }
//     } else if (message.contains('DriverFaultSharpTurn')) {
//       violationType = 'Sharp Turn';
//     } else if (message.contains('HardBraking')) {
//       violationType = 'Hard Braking';
//     } else if (message.contains('GeofenceViolation')) {
//       violationType = 'Geofence Violation';
//     }

//     if (violationType.isNotEmpty) {
//       final violation = {
//         'type': violationType,
//         'position': _currentPosition,
//         'time': DateTime.now(),
//         'speed': _currentSpeed,
//         'message': message,
//       };

//       setState(() {
//         _violationsList.add(violation);
//         _violationMarkers.add(
//           Marker(
//             width: 50.0,
//             height: 50.0,
//             point: _currentPosition,
//             child: GestureDetector(
//               onTap: () => _showViolationDetails(violation),
//               child: Container(
//                 child: Icon(
//                   Icons.warning,
//                   color: Colors.red,
//                   size: 30,
//                 ),
//               ),
//             ),
//           ),
//         );
//       });
//     }
//   }

//   void _showViolationDetails(Map<String, dynamic> violation) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Violation Details'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Type: ${violation['type']}'),
//             Text('Time: ${violation['time'].toString()}'),
//             Text('Speed: ${violation['speed'].toStringAsFixed(1)} km/h'),
//             Text(
//                 'Location: ${violation['position'].latitude.toStringAsFixed(6)}, '
//                 '${violation['position'].longitude.toStringAsFixed(6)}'),
//             SizedBox(height: 10),
//             Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
//             Text(violation['message']),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _addViolationMarker(String violation) {
//     setState(() {
//       _violationMarkers.add(
//         Marker(
//           width: 50.0,
//           height: 50.0,
//           point: _currentPosition,
//           child: Container(
//             child: Icon(
//               Icons.warning,
//               color: Colors.red,
//               size: 30,
//             ),
//           ),
//         ),
//       );
//     });

//     // Show violation dialog
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Violation Detected!'),
//         content: Text(violation),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Driving Simulator'),
//         backgroundColor: Colors.blue,
//       ),
//       body: Column(
//         children: [
//           // Status Panel
//           Container(
//             padding: EdgeInsets.all(8),
//             color: Colors.blue[50],
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 Text('Points: ${_routePoints.length}'),
//                 Text('Speed: ${_currentSpeed.toStringAsFixed(1)} km/h'),
//                 Text('Status: ${_isDriving ? "Driving" : "Stopped"}'),
//               ],
//             ),
//           ),
//           // Sensor Data Panel
//           Container(
//             padding: EdgeInsets.all(8),
//             color: Colors.orange[50],
//             child: Column(
//               children: [
//                 Text('Real-time Sensor Data:'),
//                 if (_currentAccelerometer != null)
//                   Text(
//                       'Accelerometer: X=${_currentAccelerometer!.x.toStringAsFixed(2)}, Y=${_currentAccelerometer!.y.toStringAsFixed(2)}, Z=${_currentAccelerometer!.z.toStringAsFixed(2)}'),
//                 if (_currentGyroscope != null)
//                   Text(
//                       'Gyroscope: X=${_currentGyroscope!.x.toStringAsFixed(2)}, Y=${_currentGyroscope!.y.toStringAsFixed(2)}, Z=${_currentGyroscope!.z.toStringAsFixed(2)}'),
//               ],
//             ),
//           ),
//           // Control buttons
//           Container(
//             padding: EdgeInsets.all(8),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 ElevatedButton(
//                   onPressed: _isDriving ? null : _startDriving,
//                   child: Text('Start Driving'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                   ),
//                 ),
//                 ElevatedButton(
//                   onPressed: _isDriving ? _stopDriving : null,
//                   child: Text('Stop Driving'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.red,
//                   ),
//                 ),
//                 ElevatedButton(
//                   onPressed: _clearRoute,
//                   child: Text('Clear Route'),
//                 ),
//               ],
//             ),
//           ),
//           // Map
//           Expanded(
//             child: FlutterMap(
//               mapController: _mapController,
//               options: MapOptions(
//                 center: _currentPosition,
//                 zoom: 15.0,
//                 onTap: _handleMapTap,
//               ),
//               children: [
//                 TileLayer(
//                   urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//                   //userAgentPackageName: 'com.example.driving_simulator',
//                 ),
//                 // Geofence polygons
//                 PolygonLayer(
//                   polygons: _geofencePolygons,
//                 ),
//                 // Route polyline
//                 if (_routePoints.isNotEmpty)
//                   PolylineLayer(
//                     polylines: [
//                       Polyline(
//                         points: _routePoints,
//                         strokeWidth: 4.0,
//                         color: Colors.blue,
//                       ),
//                     ],
//                   ),
//                 // Route points markers
//                 MarkerLayer(
//                   markers: _routePoints.asMap().entries.map((entry) {
//                     int index = entry.key;
//                     LatLng point = entry.value;
//                     return Marker(
//                       width: 30.0,
//                       height: 30.0,
//                       point: point,
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: Colors.blue,
//                           shape: BoxShape.circle,
//                         ),
//                         child: Center(
//                           child: Text(
//                             '${index + 1}',
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 12,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       ),
//                     );
//                   }).toList(),
//                 ),
//                 // Current position marker (car)
//                 MarkerLayer(
//                   markers: [
//                     Marker(
//                       width: 40.0,
//                       height: 40.0,
//                       point: _currentPosition,
//                       child: Container(
//                         child: Icon(
//                           Icons.directions_car,
//                           color: _isDriving ? Colors.green : Colors.grey,
//                           size: 30,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 // Violation markers
//                 MarkerLayer(
//                   markers: _violationMarkers,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _drivingTimer?.cancel();
//     _sensorTimer?.cancel();
//     _accelerometerSubscription.cancel();
//     _gyroscopeSubscription.cancel();
//     _timeIntervalController.dispose();
//     super.dispose();
//   }
// }

// import 'package:admin_signup/Screens/MainDashboard.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'dart:async';
// import 'dart:math' as math;
// import 'package:sensors_plus/sensors_plus.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class DriverDetailsScreen extends StatefulWidget {
//   @override
//   DriverDetailsScreenState createState() => DriverDetailsScreenState();
// }

// class DriverDetailsScreenState extends State<DriverDetailsScreen> {
//   final MapController _mapController = MapController();
//   final List<LatLng> _routePoints = [];
//   final List<double> _timeIntervals = [];
//   List<Marker> _violationMarkers = [];
//   List<Map<String, dynamic>> _violationsList =
//       []; // Store violations with details
//   List<Polygon> _geofencePolygons = [];
//   final TextEditingController _timeIntervalController = TextEditingController();

//   // Animation and driving state
//   bool _isDriving = false;
//   int _currentPointIndex = 0;
//   LatLng _currentPosition = LatLng(33.6844, 73.0479); // Default: Rawalpindi
//   Timer? _drivingTimer;
//   Timer? _sensorTimer;

//   // Sensor data
//   late StreamSubscription<AccelerometerEvent> _accelerometerSubscription;
//   late StreamSubscription<GyroscopeEvent> _gyroscopeSubscription;
//   AccelerometerEvent? _currentAccelerometer;
//   GyroscopeEvent? _currentGyroscope;

//   // Speed and distance calculations
//   double _currentSpeed = 0.0;
//   double _totalDistance = 0.0;
//   DateTime _lastPositionTime = DateTime.now();

//   // Driver details
//   int? dvid;
//   int? id;
//   String? picture;
//   String? name;
//   String? model;
//   String? lp;
//   String? driverEmail;

//   void _initializeData() async {
//     await fetchDriverDetails();
//     await fetchViolations(); // Add this line to fetch violations on init
//   }

// // Update initState to use _initializeData
//   @override
//   void initState() {
//     super.initState();
//     _initializeSensors();
//     _initializeData(); // Changed from fetchDriverDetails()
//   }

//   Future fetchDriverDetails() async {
//     SharedPreferences pref = await SharedPreferences.getInstance();
//     setState(() {
//       dvid = pref.getInt('drivervehicleid');
//       id = pref.getInt('id');
//       picture = pref.getString('picture');
//       name = pref.getString('name');
//       model = pref.getString('model');
//       lp = pref.getString('licenseno');
//       driverEmail = pref.getString('email');
//     });

//     try {
//       final response =
//           await http.get(Uri.parse('$vehicledriverurl/inspect-driver/$id'));
//       if (response.statusCode == 200) {
//         print('Successfully loaded driver details');
//         await fetchGeofences();
//       } else {
//         print('Failed to load driver details: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching driver details: $e');
//     }
//   }

//   Future fetchGeofences() async {
//     try {
//       if (driverEmail == null) return;

//       final response = await http
//           .get(Uri.parse('$vehicledriverurl/assigned-geofence/$driverEmail'));
//       if (response.statusCode == 200) {
//         final List data = json.decode(response.body);

//         setState(() {
//           _geofencePolygons = data.map((geofence) {
//             List<LatLng> points = [];

//             if (geofence['coordinates'] is List) {
//               points = (geofence['coordinates'] as List)
//                   .map((point) {
//                     if (point is List && point.length >= 2) {
//                       return LatLng(
//                         point[0] is num ? point[0].toDouble() : 0.0,
//                         point[1] is num ? point[1].toDouble() : 0.0,
//                       );
//                     }
//                     return null;
//                   })
//                   .whereType<LatLng>()
//                   .toList();
//             }

//             return Polygon(
//               points: points,
//               color: Colors.blue.withOpacity(0.3),
//               borderColor: Colors.blue,
//               borderStrokeWidth: 2,
//             );
//           }).toList();
//         });
//       }
//     } catch (e) {
//       print('Error fetching geofences: $e');
//     }
//   }

//   Future<void> fetchViolations() async {
//     try {
//       if (dvid == null) return;

//       final response = await http.get(
//         Uri.parse('$vehicledriverurl/driver-violations/$dvid'),
//       );

//       if (response.statusCode == 200) {
//         final List data = json.decode(response.body);

//         setState(() {
//           _violationMarkers = data.map((violation) {
//             return Marker(
//               width: 50.0,
//               height: 50.0,
//               point: LatLng(
//                 violation['latitude']?.toDouble() ?? 0.0,
//                 violation['longitude']?.toDouble() ?? 0.0,
//               ),
//               child: GestureDetector(
//                 onTap: () => _showViolationDetails(violation),
//                 child: Icon(
//                   Icons.warning,
//                   color: _getViolationColor(violation['eventtype']),
//                   size: 30,
//                 ),
//               ),
//             );
//           }).toList();

//           _violationsList = data.map((violation) {
//             return {
//               'type': violation['eventtype'],
//               'position': LatLng(
//                 violation['latitude']?.toDouble() ?? 0.0,
//                 violation['longitude']?.toDouble() ?? 0.0,
//               ),
//               'time': DateTime.parse(violation['timestamp']),
//               'speed': violation['violatedvalue']?.toDouble() ?? 0.0,
//               'message': '${violation['eventtype']} violation detected',
//             };
//           }).toList();
//         });
//       } else {
//         print('Failed to load violations: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching violations: $e');
//     }
//   }

// // Helper method to get color based on violation type
//   Color _getViolationColor(String? eventType) {
//     switch (eventType?.toLowerCase()) {
//       case 'overspeeding':
//         return Colors.red;
//       case 'geofence violation':
//         return Colors.orange;
//       case 'driverfaultsharpturn':
//         return Colors.yellow;
//       case 'hardbraking':
//         return Colors.purple;
//       default:
//         return Colors.red;
//     }
//   }

//   void _initializeSensors() {
//     // Initialize accelerometer
//     _accelerometerSubscription =
//         accelerometerEvents.listen((AccelerometerEvent event) {
//       setState(() {
//         _currentAccelerometer = event;
//       });
//     });

//     // Initialize gyroscope
//     _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
//       setState(() {
//         _currentGyroscope = event;
//       });
//     });
//   }

//   // Haversine formula for distance calculation
//   double _calculateDistance(LatLng point1, LatLng point2) {
//     const double earthRadius = 6371000; // Earth's radius in meters

//     double lat1Rad = point1.latitude * math.pi / 180;
//     double lat2Rad = point2.latitude * math.pi / 180;
//     double deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
//     double deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180;

//     double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
//         math.cos(lat1Rad) *
//             math.cos(lat2Rad) *
//             math.sin(deltaLngRad / 2) *
//             math.sin(deltaLngRad / 2);

//     double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

//     return earthRadius * c; // Distance in meters
//   }

//   // Calculate speed using V = d/t
//   double _calculateSpeed(LatLng point1, LatLng point2, double timeInterval) {
//     double distance = _calculateDistance(point1, point2);
//     double speed = (distance / timeInterval) * 3.6; // Convert m/s to km/h
//     return speed;
//   }

//   void _handleMapTap(TapPosition tapPosition, LatLng point) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Add Route Point'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('Latitude: ${point.latitude.toStringAsFixed(6)}'),
//             Text('Longitude: ${point.longitude.toStringAsFixed(6)}'),
//             TextField(
//               controller: _timeIntervalController,
//               decoration: InputDecoration(
//                 labelText: 'Time Interval (seconds)',
//               ),
//               keyboardType: TextInputType.number,
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               if (_timeIntervalController.text.isNotEmpty) {
//                 double timeInterval =
//                     double.parse(_timeIntervalController.text);
//                 setState(() {
//                   _routePoints.add(point);
//                   _timeIntervals.add(timeInterval);
//                 });
//                 _timeIntervalController.clear();
//                 Navigator.pop(context);
//               }
//             },
//             child: Text('Add'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _clearRoute() {
//     setState(() {
//       _routePoints.clear();
//       _timeIntervals.clear();
//       _violationMarkers.clear();
//       _currentPointIndex = 0;
//     });
//   }

//   void _startDriving() {
//     if (_routePoints.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please add route points first')),
//       );
//       return;
//     }

//     if (dvid == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Driver vehicle ID not available')),
//       );
//       return;
//     }

//     setState(() {
//       _isDriving = true;
//       _currentPointIndex = 0;
//       _currentPosition = _routePoints[0];
//     });

//     _mapController.move(_currentPosition, 15.0);
//     _startRouteAnimation();
//     _startSensorDataTransmission();
//   }

//   void _stopDriving() {
//     setState(() {
//       _isDriving = false;
//     });

//     _drivingTimer?.cancel();
//     _sensorTimer?.cancel();

//     // Show summary of violations after driving stops
//     if (_violationsList.isNotEmpty) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         showDialog(
//           context: context,
//           builder: (context) => AlertDialog(
//             title: Text('Driving Completed'),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text('Total Violations: ${_violationsList.length}'),
//                 SizedBox(height: 10),
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     _showViolationsList();
//                   },
//                   child: Text('View All Violations'),
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: Text('OK'),
//               ),
//             ],
//           ),
//         );
//       });
//     }
//   }

//   void _showViolationsList() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('All Violations'),
//         content: Container(
//           width: double.maxFinite,
//           child: ListView.builder(
//             shrinkWrap: true,
//             itemCount: _violationsList.length,
//             itemBuilder: (context, index) {
//               final violation = _violationsList[index];
//               return ListTile(
//                 leading: Icon(Icons.warning, color: Colors.red),
//                 title: Text(violation['type']),
//                 subtitle: Text(
//                     'Speed: ${violation['speed'].toStringAsFixed(1)} km/h'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _showViolationDetails(violation);
//                 },
//               );
//             },
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _startRouteAnimation() {
//     // Reset overspeeding detection for new segment
//     _overspeedingDetectedInSegment = false;

//     if (_currentPointIndex >= _routePoints.length - 1) {
//       _stopDriving();
//       return;
//     }

//     LatLng startPoint = _routePoints[_currentPointIndex];
//     LatLng endPoint = _routePoints[_currentPointIndex + 1];
//     double timeInterval = _timeIntervals[_currentPointIndex];

//     // Calculate speed for this segment
//     _currentSpeed = _calculateSpeed(startPoint, endPoint, timeInterval);

//     // Animation parameters
//     int animationSteps = (timeInterval * 10).round(); // 10 steps per second
//     int stepDuration = (timeInterval * 1000 / animationSteps).round();

//     int currentStep = 0;

//     _drivingTimer =
//         Timer.periodic(Duration(milliseconds: stepDuration), (timer) {
//       if (currentStep >= animationSteps) {
//         timer.cancel();
//         _currentPointIndex++;
//         _startRouteAnimation(); // Move to next segment
//         return;
//       }

//       // Interpolate position
//       double progress = currentStep / animationSteps;
//       double lat = startPoint.latitude +
//           (endPoint.latitude - startPoint.latitude) * progress;
//       double lng = startPoint.longitude +
//           (endPoint.longitude - startPoint.longitude) * progress;

//       setState(() {
//         _currentPosition = LatLng(lat, lng);
//       });

//       // Update map center
//       _mapController.move(_currentPosition, _mapController.zoom);

//       currentStep++;
//     });
//   }

//   void _startSensorDataTransmission() {
//     _sensorTimer = Timer.periodic(Duration(seconds: 1), (timer) {
//       if (!_isDriving) {
//         timer.cancel();
//         return;
//       }

//       _sendDataToAPI();
//     });
//   }

//   Future<void> _sendDataToAPI() async {
//     if (_currentAccelerometer == null ||
//         _currentGyroscope == null ||
//         dvid == null) {
//       return;
//     }
//     print('${_currentPosition.longitude}, ${_currentPosition.latitude}');
//     try {
//       Map<String, dynamic> data = {
//         'longitude': _currentPosition.longitude,
//         'latitude': _currentPosition.latitude,
//         'speed': _currentSpeed,
//         'gyroscope': {
//           'x': _currentGyroscope!.x,
//           'y': _currentGyroscope!.y,
//           'z': _currentGyroscope!.z,
//         },
//         'accelerometer': {
//           'x': _currentAccelerometer!.x,
//           'y': _currentAccelerometer!.y,
//           'z': _currentAccelerometer!.z,
//         },
//         'drivervehicleid': dvid,
//       };

//       final response = await http.post(
//         Uri.parse('$vehicledriverurl/current-location'),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode(data),
//       );

//       if (response.statusCode == 200) {
//         var responseData = json.decode(response.body);
//         _checkForViolations(responseData);
//       }
//     } catch (e) {
//       print('Error sending data to API: $e');
//     }
//   }

//   bool _overspeedingDetectedInSegment = false;

// // Modify the _checkForViolations method
//   void _checkForViolations(Map<String, dynamic> response) {
//     String message = response['message'] ?? '';
//     String violationType = '';

//     if (message.contains('OverSpeeding')) {
//       if (!_overspeedingDetectedInSegment) {
//         violationType = 'OverSpeeding';
//         _overspeedingDetectedInSegment = true;
//       }
//     } else if (message.contains('DriverFaultSharpTurn')) {
//       violationType = 'Sharp Turn';
//     } else if (message.contains('HardBraking')) {
//       violationType = 'Hard Braking';
//     } else if (message.contains('GeofenceViolation')) {
//       violationType = 'Geofence Violation';
//     }

//     if (violationType.isNotEmpty) {
//       final violation = {
//         'type': violationType,
//         'position': _currentPosition,
//         'time': DateTime.now(),
//         'speed': _currentSpeed,
//         'message': message,
//       };

//       setState(() {
//         _violationsList.add(violation);
//         _violationMarkers.add(
//           Marker(
//             width: 50.0,
//             height: 50.0,
//             point: _currentPosition,
//             child: GestureDetector(
//               onTap: () => _showViolationDetails(violation),
//               child: Container(
//                 child: Icon(
//                   Icons.warning,
//                   color: Colors.red,
//                   size: 30,
//                 ),
//               ),
//             ),
//           ),
//         );
//       });
//     }
//   }

//   void _showViolationDetails(Map<String, dynamic> violation) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Violation Details'),
//         content: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('Type: ${violation['type'] ?? violation['eventtype']}'),
//               Text('Driver: ${violation['driver_name'] ?? 'Unknown'}'),
//               if (violation['time'] != null)
//                 Text('Time: ${violation['time'].toString()}'),
//               if (violation['timestamp'] != null)
//                 Text('Time: ${violation['timestamp']}'),
//               if (violation['speed'] != null && violation['speed'] > 0)
//                 Text('Speed: ${violation['speed'].toStringAsFixed(1)} km/h'),
//               if (violation['violatedvalue'] != null)
//                 Text('Value: ${violation['violatedvalue']}'),
//               if (violation['position'] != null)
//                 Text(
//                     'Location: ${violation['position'].latitude.toStringAsFixed(6)}, '
//                     '${violation['position'].longitude.toStringAsFixed(6)}'),
//               if (violation['latitude'] != null &&
//                   violation['longitude'] != null)
//                 Text(
//                     'Location: ${violation['latitude']}, ${violation['longitude']}'),
//               SizedBox(height: 10),
//               Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
//               Text(violation['message'] ?? 'Violation detected'),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _addViolationMarker(String violation) {
//     setState(() {
//       _violationMarkers.add(
//         Marker(
//           width: 50.0,
//           height: 50.0,
//           point: _currentPosition,
//           child: Container(
//             child: Icon(
//               Icons.warning,
//               color: Colors.red,
//               size: 30,
//             ),
//           ),
//         ),
//       );
//     });

//     // Show violation dialog
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Violation Detected!'),
//         content: Text(violation),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Driving Simulator'),
//         backgroundColor: Colors.blue,
//       ),
//       body: Column(
//         children: [
//           // Status Panel
//           Container(
//             padding: EdgeInsets.all(8),
//             color: Colors.blue[50],
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 Text('Points: ${_routePoints.length}'),
//                 Text('Speed: ${_currentSpeed.toStringAsFixed(1)} km/h'),
//                 Text('Status: ${_isDriving ? "Driving" : "Stopped"}'),
//               ],
//             ),
//           ),
//           // Sensor Data Panel
//           Container(
//             padding: EdgeInsets.all(8),
//             color: Colors.orange[50],
//             child: Column(
//               children: [
//                 Text('Real-time Sensor Data:'),
//                 if (_currentAccelerometer != null)
//                   Text(
//                       'Accelerometer: X=${_currentAccelerometer!.x.toStringAsFixed(2)}, Y=${_currentAccelerometer!.y.toStringAsFixed(2)}, Z=${_currentAccelerometer!.z.toStringAsFixed(2)}'),
//                 if (_currentGyroscope != null)
//                   Text(
//                       'Gyroscope: X=${_currentGyroscope!.x.toStringAsFixed(2)}, Y=${_currentGyroscope!.y.toStringAsFixed(2)}, Z=${_currentGyroscope!.z.toStringAsFixed(2)}'),
//               ],
//             ),
//           ),
//           // Control buttons
//           Container(
//             padding: EdgeInsets.all(8),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 ElevatedButton(
//                   onPressed: _isDriving ? null : _startDriving,
//                   child: Text('Start Driving'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                   ),
//                 ),
//                 ElevatedButton(
//                   onPressed: _isDriving ? _stopDriving : null,
//                   child: Text('Stop Driving'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.red,
//                   ),
//                 ),
//                 ElevatedButton(
//                   onPressed: _clearRoute,
//                   child: Text('Clear Route'),
//                 ),
//               ],
//             ),
//           ),
//           // Map
//           Expanded(
//             child: FlutterMap(
//               mapController: _mapController,
//               options: MapOptions(
//                 center: _currentPosition,
//                 zoom: 15.0,
//                 onTap: _handleMapTap,
//               ),
//               children: [
//                 TileLayer(
//                   urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//                   //userAgentPackageName: 'com.example.driving_simulator',
//                 ),
//                 // Geofence polygons
//                 PolygonLayer(
//                   polygons: _geofencePolygons,
//                 ),
//                 // Route polyline
//                 if (_routePoints.isNotEmpty)
//                   PolylineLayer(
//                     polylines: [
//                       Polyline(
//                         points: _routePoints,
//                         strokeWidth: 4.0,
//                         color: Colors.blue,
//                       ),
//                     ],
//                   ),
//                 // Route points markers
//                 MarkerLayer(
//                   markers: _routePoints.asMap().entries.map((entry) {
//                     int index = entry.key;
//                     LatLng point = entry.value;
//                     return Marker(
//                       width: 30.0,
//                       height: 30.0,
//                       point: point,
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: Colors.blue,
//                           shape: BoxShape.circle,
//                         ),
//                         child: Center(
//                           child: Text(
//                             '${index + 1}',
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 12,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       ),
//                     );
//                   }).toList(),
//                 ),
//                 // Current position marker (car)
//                 MarkerLayer(
//                   markers: [
//                     Marker(
//                       width: 40.0,
//                       height: 40.0,
//                       point: _currentPosition,
//                       child: Container(
//                         child: Icon(
//                           Icons.directions_car,
//                           color: _isDriving ? Colors.green : Colors.grey,
//                           size: 30,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 // Violation markers
//                 MarkerLayer(
//                   markers: [
//                     ..._violationMarkers,
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _drivingTimer?.cancel();
//     _sensorTimer?.cancel();
//     _accelerometerSubscription.cancel();
//     _gyroscopeSubscription.cancel();
//     _timeIntervalController.dispose();
//     super.dispose();
//   }
// }

import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverDetailsScreen extends StatefulWidget {
  @override
  DriverDetailsScreenState createState() => DriverDetailsScreenState();
}

class DriverDetailsScreenState extends State<DriverDetailsScreen> {
  final MapController _mapController = MapController();
  final List<LatLng> _routePoints = [];
  final List<double> _timeIntervals = [];
  List<Marker> _violationMarkers = [];
  List<Map<String, dynamic>> _violationsList =
      []; // Store violations with details
  List<Polygon> _geofencePolygons = [];
  final TextEditingController _timeIntervalController = TextEditingController();

  // Animation and driving state
  bool _isDriving = false;
  int _currentPointIndex = 0;
  LatLng _currentPosition = LatLng(33.6844, 73.0479); // Default: Rawalpindi
  Timer? _drivingTimer;
  Timer? _sensorTimer;

  // Sensor data
  late StreamSubscription<AccelerometerEvent> _accelerometerSubscription;
  late StreamSubscription<GyroscopeEvent> _gyroscopeSubscription;
  AccelerometerEvent? _currentAccelerometer;
  GyroscopeEvent? _currentGyroscope;

  // Speed and distance calculations
  double _currentSpeed = 0.0;
  double _totalDistance = 0.0;
  DateTime _lastPositionTime = DateTime.now();

  // Driver details
  int? dvid;
  int? id;
  String? picture;
  String? name;
  String? model;
  String? lp;
  String? driverEmail;

  void _initializeData() async {
    await fetchDriverDetails();
    await fetchViolations(); // Add this line to fetch violations on init
  }

// Update initState to use _initializeData
  @override
  void initState() {
    super.initState();
    _initializeSensors();
    _initializeData(); // Changed from fetchDriverDetails()
  }

  Future fetchDriverDetails() async {
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
      } else {
        print('Failed to load driver details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching driver details: $e');
    }
  }

  Future fetchGeofences() async {
    try {
      if (driverEmail == null) return;

      final response = await http
          .get(Uri.parse('$vehicledriverurl/assigned-geofence/$driverEmail'));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        setState(() {
          _geofencePolygons = data.map((geofence) {
            List<LatLng> points = [];

            if (geofence['coordinates'] is List) {
              points = (geofence['coordinates'] as List)
                  .map((point) {
                    if (point is List && point.length >= 2) {
                      return LatLng(
                        point[0] is num ? point[0].toDouble() : 0.0,
                        point[1] is num ? point[1].toDouble() : 0.0,
                      );
                    }
                    return null;
                  })
                  .whereType<LatLng>()
                  .toList();
            }

            return Polygon(
              points: points,
              color: Colors.blue.withOpacity(0.3),
              borderColor: Colors.blue,
              borderStrokeWidth: 2,
            );
          }).toList();
        });
      }
    } catch (e) {
      print('Error fetching geofences: $e');
    }
  }

  Future<void> fetchViolations() async {
    try {
      if (dvid == null) return;

      final response = await http.get(
        Uri.parse('$vehicledriverurl/driver-violations/$dvid'),
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        setState(() {
          _violationMarkers = data.map((violation) {
            return Marker(
              width: 50.0,
              height: 50.0,
              point: LatLng(
                violation['latitude']?.toDouble() ?? 0.0,
                violation['longitude']?.toDouble() ?? 0.0,
              ),
              child: GestureDetector(
                onTap: () => _showViolationDetails(violation),
                child: Icon(
                  Icons.warning,
                  color: _getViolationColor(violation['eventtype']),
                  size: 30,
                ),
              ),
            );
          }).toList();

          _violationsList = data.map((violation) {
            return {
              'type': violation['eventtype'],
              'position': LatLng(
                violation['latitude']?.toDouble() ?? 0.0,
                violation['longitude']?.toDouble() ?? 0.0,
              ),
              'time': DateTime.parse(violation['timestamp']),
              'speed': violation['violatedvalue']?.toDouble() ?? 0.0,
              'message': '${violation['eventtype']} violation detected',
            };
          }).toList();
        });
      } else {
        print('Failed to load violations: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching violations: $e');
    }
  }

// Helper method to get color based on violation type
  Color _getViolationColor(String? eventType) {
    switch (eventType?.toLowerCase()) {
      case 'overspeeding':
        return Colors.red;
      case 'geofence violation':
        return Colors.orange;
      case 'driverfaultsharpturn':
        return Colors.yellow;
      case 'hardbraking':
        return Colors.purple;
      default:
        return Colors.red;
    }
  }

  void _initializeSensors() {
    // Initialize accelerometer
    _accelerometerSubscription =
        accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        _currentAccelerometer = event;
      });
    });

    // Initialize gyroscope
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      setState(() {
        _currentGyroscope = event;
      });
    });
  }

  // Haversine formula for distance calculation
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters

    double lat1Rad = point1.latitude * math.pi / 180;
    double lat2Rad = point2.latitude * math.pi / 180;
    double deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    double deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180;

    double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c; // Distance in meters
  }

  // Calculate speed using V = d/t
  double _calculateSpeed(LatLng point1, LatLng point2, double timeInterval) {
    double distance = _calculateDistance(point1, point2);
    double speed = (distance / timeInterval) * 3.6; // Convert m/s to km/h
    return speed;
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Route Point'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Latitude: ${point.latitude.toStringAsFixed(6)}'),
            Text('Longitude: ${point.longitude.toStringAsFixed(6)}'),
            TextField(
              controller: _timeIntervalController,
              decoration: InputDecoration(
                labelText: 'Time Interval (seconds)',
              ),
              keyboardType: TextInputType.number,
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
              if (_timeIntervalController.text.isNotEmpty) {
                double timeInterval =
                    double.parse(_timeIntervalController.text);
                setState(() {
                  _routePoints.add(point);
                  _timeIntervals.add(timeInterval);
                });
                _timeIntervalController.clear();
                Navigator.pop(context);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void _clearRoute() {
    setState(() {
      _routePoints.clear();
      _timeIntervals.clear();
      _violationMarkers.clear();
      _currentPointIndex = 0;
    });
  }

  void _startDriving() {
    if (_routePoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add route points first')),
      );
      return;
    }

    if (dvid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Driver vehicle ID not available')),
      );
      return;
    }

    setState(() {
      _isDriving = true;
      _currentPointIndex = 0;
      _currentPosition = _routePoints[0];
    });

    _mapController.move(_currentPosition, 15.0);
    _startRouteAnimation();
    _startSensorDataTransmission();
  }

  void _stopDriving() {
    setState(() {
      _isDriving = false;
    });

    _drivingTimer?.cancel();
    _sensorTimer?.cancel();

    // Show summary of violations after driving stops
    if (_violationsList.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Driving Completed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total Violations: ${_violationsList.length}'),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showViolationsList();
                  },
                  child: Text('View All Violations'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      });
    }
  }

  void _showViolationsList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('All Violations'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _violationsList.length,
            itemBuilder: (context, index) {
              final violation = _violationsList[index];
              return ListTile(
                leading: Icon(Icons.warning, color: Colors.red),
                title: Text(violation['type']),
                subtitle: Text(
                    'Speed: ${violation['speed'].toStringAsFixed(1)} km/h'),
                onTap: () {
                  Navigator.pop(context);
                  _showViolationDetails(violation);
                },
              );
            },
          ),
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

  void _startRouteAnimation() {
    // Reset overspeeding detection for new segment
    _overspeedingDetectedInSegment = false;

    if (_currentPointIndex >= _routePoints.length - 1) {
      _stopDriving();
      return;
    }

    LatLng startPoint = _routePoints[_currentPointIndex];
    LatLng endPoint = _routePoints[_currentPointIndex + 1];
    double timeInterval = _timeIntervals[_currentPointIndex];

    // Calculate distance for this segment
    double segmentDistance = _calculateDistance(startPoint, endPoint);

    // Calculate target speed for this segment (m/s)
    double targetSpeed = segmentDistance / timeInterval;

    // Convert to km/h for display
    double targetSpeedKmh = targetSpeed * 3.6;

    // Animation parameters
    int animationSteps = (timeInterval * 10).round(); // 10 steps per second
    int stepDuration = (timeInterval * 1000 / animationSteps).round();

    int currentStep = 0;
    double lastLat = startPoint.latitude;
    double lastLng = startPoint.longitude;

    _drivingTimer =
        Timer.periodic(Duration(milliseconds: stepDuration), (timer) {
      if (currentStep >= animationSteps) {
        timer.cancel();
        _currentPointIndex++;
        _startRouteAnimation(); // Move to next segment
        return;
      }

      // Calculate progress with easing for more realistic movement
      double progress = currentStep / animationSteps;

      // Apply easing function for smoother acceleration/deceleration
      double easedProgress = _easeInOutCubic(progress);

      // Interpolate position
      double lat = startPoint.latitude +
          (endPoint.latitude - startPoint.latitude) * easedProgress;
      double lng = startPoint.longitude +
          (endPoint.longitude - startPoint.longitude) * easedProgress;

      // Calculate distance moved in this step
      double stepDistance = _calculateDistance(
        LatLng(lastLat, lastLng),
        LatLng(lat, lng),
      );

      // Calculate actual speed in km/h
      double actualSpeed = (stepDistance / (stepDuration / 1000)) * 3.6;

      // Smooth speed transition
      _currentSpeed = _currentSpeed + (actualSpeed - _currentSpeed) * 0.3;

      setState(() {
        _currentPosition = LatLng(lat, lng);
      });

      // Update map center
      _mapController.move(_currentPosition, _mapController.zoom);

      // Store last position for next distance calculation
      lastLat = lat;
      lastLng = lng;

      currentStep++;
    });
  }

// Easing function for smooth acceleration/deceleration
  double _easeInOutCubic(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
  }

  void _startSensorDataTransmission() {
    _sensorTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!_isDriving) {
        timer.cancel();
        return;
      }

      _sendDataToAPI();
    });
  }

  Future<void> _sendDataToAPI() async {
    if (_currentAccelerometer == null ||
        _currentGyroscope == null ||
        dvid == null) {
      return;
    }
    print('${_currentPosition.longitude}, ${_currentPosition.latitude}');
    try {
      Map<String, dynamic> data = {
        'longitude': _currentPosition.longitude,
        'latitude': _currentPosition.latitude,
        'speed': _currentSpeed,
        'gyroscope': {
          'x': _currentGyroscope!.x,
          'y': _currentGyroscope!.y,
          'z': _currentGyroscope!.z,
        },
        'accelerometer': {
          'x': _currentAccelerometer!.x,
          'y': _currentAccelerometer!.y,
          'z': _currentAccelerometer!.z,
        },
        'drivervehicleid': dvid,
      };

      final response = await http.post(
        Uri.parse('$vehicledriverurl/current-location'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        _checkForViolations(responseData);
      }
    } catch (e) {
      print('Error sending data to API: $e');
    }
  }

  bool _overspeedingDetectedInSegment = false;

// Modify the _checkForViolations method
  void _checkForViolations(Map<String, dynamic> response) {
    String message = response['message'] ?? '';
    String violationType = '';

    if (message.contains('OverSpeeding')) {
      if (!_overspeedingDetectedInSegment) {
        violationType = 'OverSpeeding';
        _overspeedingDetectedInSegment = true;
      }
    } else if (message.contains('DriverFaultSharpTurn')) {
      violationType = 'Sharp Turn';
    } else if (message.contains('HardBraking')) {
      violationType = 'Hard Braking';
    } else if (message.contains('GeofenceViolation')) {
      violationType = 'Geofence Violation';
    }

    if (violationType.isNotEmpty) {
      final violation = {
        'type': violationType,
        'position': _currentPosition,
        'time': DateTime.now(),
        'speed': _currentSpeed,
        'message': message,
      };

      setState(() {
        _violationsList.add(violation);
        _violationMarkers.add(
          Marker(
            width: 50.0,
            height: 50.0,
            point: _currentPosition,
            child: GestureDetector(
              onTap: () => _showViolationDetails(violation),
              child: Container(
                child: Icon(
                  Icons.warning,
                  color: Colors.red,
                  size: 30,
                ),
              ),
            ),
          ),
        );
      });
    }
  }

  void _showViolationDetails(Map<String, dynamic> violation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Violation Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type: ${violation['type'] ?? violation['eventtype']}'),
              Text('Driver: ${violation['driver_name'] ?? 'Unknown'}'),
              if (violation['time'] != null)
                Text('Time: ${violation['time'].toString()}'),
              if (violation['timestamp'] != null)
                Text('Time: ${violation['timestamp']}'),
              if (violation['speed'] != null && violation['speed'] > 0)
                Text('Speed: ${violation['speed'].toStringAsFixed(1)} km/h'),
              if (violation['violatedvalue'] != null)
                Text('Value: ${violation['violatedvalue']}'),
              if (violation['position'] != null)
                Text(
                    'Location: ${violation['position'].latitude.toStringAsFixed(6)}, '
                    '${violation['position'].longitude.toStringAsFixed(6)}'),
              if (violation['latitude'] != null &&
                  violation['longitude'] != null)
                Text(
                    'Location: ${violation['latitude']}, ${violation['longitude']}'),
              SizedBox(height: 10),
              Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(violation['message'] ?? 'Violation detected'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _addViolationMarker(String violation) {
    setState(() {
      _violationMarkers.add(
        Marker(
          width: 50.0,
          height: 50.0,
          point: _currentPosition,
          child: Container(
            child: Icon(
              Icons.warning,
              color: Colors.red,
              size: 30,
            ),
          ),
        ),
      );
    });

    // Show violation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Violation Detected!'),
        content: Text(violation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driving Simulator'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Status Panel
          Container(
            padding: EdgeInsets.all(8),
            color: Colors.blue[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Points: ${_routePoints.length}'),
                Text('Speed: ${_currentSpeed.toStringAsFixed(1)} km/h'),
                Text('Status: ${_isDriving ? "Driving" : "Stopped"}'),
              ],
            ),
          ),
          // Sensor Data Panel
          Container(
            padding: EdgeInsets.all(8),
            color: Colors.orange[50],
            child: Column(
              children: [
                Text('Real-time Sensor Data:'),
                if (_currentAccelerometer != null)
                  Text(
                      'Accelerometer: X=${_currentAccelerometer!.x.toStringAsFixed(2)}, Y=${_currentAccelerometer!.y.toStringAsFixed(2)}, Z=${_currentAccelerometer!.z.toStringAsFixed(2)}'),
                if (_currentGyroscope != null)
                  Text(
                      'Gyroscope: X=${_currentGyroscope!.x.toStringAsFixed(2)}, Y=${_currentGyroscope!.y.toStringAsFixed(2)}, Z=${_currentGyroscope!.z.toStringAsFixed(2)}'),
              ],
            ),
          ),
          // Control buttons
          Container(
            padding: EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isDriving ? null : _startDriving,
                  child: Text('Start Driving'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
                ElevatedButton(
                  onPressed: _isDriving ? _stopDriving : null,
                  child: Text('Stop Driving'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
                ElevatedButton(
                  onPressed: _clearRoute,
                  child: Text('Clear Route'),
                ),
              ],
            ),
          ),
          // Map
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _currentPosition,
                zoom: 15.0,
                onTap: _handleMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  //userAgentPackageName: 'com.example.driving_simulator',
                ),
                // Geofence polygons
                PolygonLayer(
                  polygons: _geofencePolygons,
                ),
                // Route polyline
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4.0,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                // Route points markers
                MarkerLayer(
                  markers: _routePoints.asMap().entries.map((entry) {
                    int index = entry.key;
                    LatLng point = entry.value;
                    return Marker(
                      width: 30.0,
                      height: 30.0,
                      point: point,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                // Current position marker (car)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 40.0,
                      height: 40.0,
                      point: _currentPosition,
                      child: Container(
                        child: Icon(
                          Icons.directions_car,
                          color: _isDriving ? Colors.green : Colors.grey,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
                // Violation markers
                MarkerLayer(
                  markers: [
                    ..._violationMarkers,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _drivingTimer?.cancel();
    _sensorTimer?.cancel();
    _accelerometerSubscription.cancel();
    _gyroscopeSubscription.cancel();
    _timeIntervalController.dispose();
    super.dispose();
  }
}
