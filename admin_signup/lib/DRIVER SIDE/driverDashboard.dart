// import 'dart:async';
// import 'dart:convert';
// import 'package:admin_signup/Screens/MainDashboard.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:sensors_plus/sensors_plus.dart';
// import 'package:http/http.dart' as http;
// import 'package:admin_signup/DRIVER%20SIDE/driver_notification_screen.dart';
// import 'package:admin_signup/DRIVER%20SIDE/driver_profile.dart';
// import 'package:admin_signup/DRIVER%20SIDE/driver_login.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class ViolationMarker {
//   final String eventType;
//   final String violatedValue;
//   final double latitude;
//   final double longitude;
//   final DateTime timestamp;
//   final int eventId;

//   ViolationMarker({
//     required this.eventType,
//     required this.violatedValue,
//     required this.latitude,
//     required this.longitude,
//     required this.timestamp,
//     required this.eventId,
//   });

//   factory ViolationMarker.fromJson(Map<String, dynamic> json) {
//     return ViolationMarker(
//       eventType: json['eventtype'] ?? '',
//       violatedValue: json['violatedvalue'] ?? '',
//       latitude: json['latitude']?.toDouble() ?? 0.0,
//       longitude: json['longitude']?.toDouble() ?? 0.0,
//       timestamp: DateTime.parse(json['timestamp']),
//       eventId: json['eventid'] ?? 0,
//     );
//   }

//   Color get color {
//     switch (eventType.toLowerCase()) {
//       case 'overspeeding':
//         return Colors.red;
//       case 'geofenceviolation':
//         return Colors.orange;
//       case 'driverfaultsharpturn':
//         return Colors.purple;
//       case 'hardbraking':
//         return Colors.amber;
//       default:
//         return Colors.grey;
//     }
//   }

//   IconData get icon {
//     switch (eventType.toLowerCase()) {
//       case 'overspeeding':
//         return Icons.speed;
//       case 'geofenceviolation':
//         return Icons.location_off;
//       case 'driverfaultsharpturn':
//         return Icons.turn_right;
//       case 'hardbraking':
//         return Icons.warning;
//       default:
//         return Icons.error;
//     }
//   }
// }

// class Driverdashboard extends StatefulWidget {
//   final String? email;
//   final dynamic drivervehicleid;

//   Driverdashboard({super.key, this.email, this.drivervehicleid});

//   @override
//   State<Driverdashboard> createState() => _DriverdashboardState();
// }

// class _DriverdashboardState extends State<Driverdashboard> {
//   final MapController _mapController = MapController();
//   LatLng? _currentPosition;
//   List<LatLng> _route = [];
//   double _speed = 0.0;
//   List<double> _gyroscope = [0.0, 0.0, 0.0];
//   List<double> _accelerometer = [0.0, 0.0, 0.0];
//   StreamSubscription<Position>? _positionStream;
//   StreamSubscription<GyroscopeEvent>? _gyroStream;
//   StreamSubscription<AccelerometerEvent>? _accelStream;
//   Timer? _dataSendTimer;
//   Timer? _violationFetchTimer;
//   String _errorMessage = "";
//   bool isDriving = false;
//   dynamic drivervehicleid;
//   String driverEmail = "";
//   bool _isLoading = true;
//   List<LatLng> routePoints = [];
//   List<Polygon> geofencePolygons = [];
//   bool _locationPermissionGranted = false;
//   List<ViolationMarker> _violations = [];
//   bool _showViolations = true;
//   bool _showGeofences = true;

//   @override
//   void initState() {
//     super.initState();
//     drivervehicleid = widget.drivervehicleid;
//     _initializeData();
//     _startViolationUpdates();
//   }

//   Future<void> _initializeData() async {
//     try {
//       if (widget.email != null && widget.email!.isNotEmpty) {
//         driverEmail = widget.email!;
//       } else {
//         final prefs = await SharedPreferences.getInstance();
//         driverEmail = prefs.getString('driverEmail') ?? "";
//       }

//       if (driverEmail.isEmpty) {
//         setState(() {
//           _errorMessage = "Driver email not found. Please log in again.";
//           _isLoading = false;
//         });
//         return;
//       }

//       if (drivervehicleid == null) {
//         await fetchDriverVehicleId();
//       }

//       await _checkLocationPermission();
//       await fetchGeofences();
//     } catch (e) {
//       print("Error initializing data: $e");
//       setState(() {
//         _errorMessage = "Failed to initialize: $e";
//         _isLoading = false;
//       });
//     }
//   }

//   Future<void> fetchGeofences() async {
//     try {
//       if (driverEmail.isEmpty) {
//         print('Driver email is empty, skipping geofence fetch');
//         return;
//       }

//       print('Fetching geofences for driver email: $driverEmail');
//       final response = await http.get(
//         Uri.parse('$vehicledriverurl/assigned-geofence/$driverEmail'),
//       );

//       if (response.statusCode == 200) {
//         final List<dynamic> data = json.decode(response.body);
//         print('Received geofence data: $data');

//         if (data.isEmpty) {
//           print('No geofences assigned to this driver');
//           return;
//         }

//         List<Polygon> newPolygons = [];

//         for (var geofence in data) {
//           try {
//             List<LatLng> points = [];

//             if (geofence['coordinates'] is List) {
//               var coords = geofence['coordinates'] as List;
//               if (coords.isNotEmpty) {
//                 if (coords.first is List) {
//                   points = coords
//                       .map((point) {
//                         if (point is List && point.length >= 2) {
//                           return LatLng(
//                             point[0] is num ? point[0].toDouble() : 0.0,
//                             point[1] is num ? point[1].toDouble() : 0.0,
//                           );
//                         }
//                         return null;
//                       })
//                       .where((point) => point != null)
//                       .cast<LatLng>()
//                       .toList();
//                 } else if (coords.first is Map) {
//                   points = coords
//                       .map((point) {
//                         if (point is Map) {
//                           return LatLng(
//                             point['latitude'] is num
//                                 ? point['latitude'].toDouble()
//                                 : 0.0,
//                             point['longitude'] is num
//                                 ? point['longitude'].toDouble()
//                                 : 0.0,
//                           );
//                         }
//                         return null;
//                       })
//                       .where((point) => point != null)
//                       .cast<LatLng>()
//                       .toList();
//                 }
//               }
//             }

//             if (points.isNotEmpty) {
//               newPolygons.add(
//                 Polygon(
//                   points: points,
//                   color: Colors.blue.withOpacity(0.3),
//                   borderColor: Colors.blue,
//                   borderStrokeWidth: 2,
//                   isFilled: true,
//                 ),
//               );
//               print('Added geofence with ${points.length} points');
//             } else {
//               print('No valid points found for geofence');
//             }
//           } catch (e) {
//             print('Error parsing geofence: $e');
//           }
//         }

//         setState(() {
//           geofencePolygons = newPolygons;
//         });
//         print('Successfully updated ${geofencePolygons.length} geofences');
//       } else {
//         print('Failed to fetch geofences: ${response.statusCode}');
//         print('Response body: ${response.body}');
//       }
//     } catch (e) {
//       print('Error fetching geofences: $e');
//     }
//   }

//   Future<void> fetchDriverVehicleId() async {
//     try {
//       final url = "$vehicledriverurl/get-drivervehicle-id/$driverEmail";
//       final response = await http.get(Uri.parse(url));

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         setState(() {
//           drivervehicleid = data['drivervehicleid'];
//         });
//       } else {
//         setState(() {
//           _errorMessage = "Failed to fetch vehicle ID";
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = "Error fetching vehicle ID: $e";
//       });
//     }
//   }

//   Future<void> _fetchViolations() async {
//     if (drivervehicleid == null) return;

//     try {
//       final url = "$vehicledriverurl/driver-violations/$drivervehicleid";
//       final response = await http.get(Uri.parse(url));

//       if (response.statusCode == 200) {
//         final List<dynamic> data = jsonDecode(response.body);
//         setState(() {
//           _violations =
//               data.map((json) => ViolationMarker.fromJson(json)).toList();
//         });
//       }
//     } catch (e) {
//       print("Error fetching violations: $e");
//     }
//   }

//   void _startViolationUpdates() {
//     _fetchViolations();
//     _violationFetchTimer = Timer.periodic(const Duration(seconds: 30), (_) {
//       _fetchViolations();
//     });
//   }

//   Future<void> _checkLocationPermission() async {
//     try {
//       final defaultLocation = LatLng(33.6995, 73.0363);

//       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) {
//         setState(() {
//           _errorMessage = 'Location services are disabled';
//           _currentPosition = defaultLocation;
//           _isLoading = false;
//         });
//         return;
//       }

//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//         if (permission == LocationPermission.denied) {
//           setState(() {
//             _errorMessage = 'Location permissions are denied';
//             _currentPosition = defaultLocation;
//             _isLoading = false;
//           });
//           return;
//         }
//       }

//       if (permission == LocationPermission.deniedForever) {
//         setState(() {
//           _errorMessage = 'Location permissions are permanently denied';
//           _currentPosition = defaultLocation;
//           _isLoading = false;
//         });
//         return;
//       }

//       setState(() {
//         _locationPermissionGranted = true;
//       });

//       try {
//         Position position = await Geolocator.getCurrentPosition(
//           desiredAccuracy: LocationAccuracy.high,
//           timeLimit: Duration(seconds: 5),
//         );

//         setState(() {
//           _currentPosition = LatLng(position.latitude, position.longitude);
//           _isLoading = false;
//         });
//       } catch (e) {
//         setState(() {
//           _currentPosition = defaultLocation;
//           _errorMessage =
//               "Using default location - couldn't get current position";
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = "Location error: $e";
//         _isLoading = false;
//       });
//     }
//   }

//   void toggleDriving() {
//     if (_errorMessage.contains('Location')) {
//       _showErrorSnackBar('Location permission required');
//       return;
//     }

//     setState(() {
//       isDriving = !isDriving;
//     });

//     if (isDriving) {
//       startDriving();
//     } else {
//       stopDriving();
//     }
//   }

//   void startDriving() {
//     setState(() {
//       _route = [];
//     });

//     _callStartDrivingAPI();

//     _positionStream = Geolocator.getPositionStream(
//       locationSettings: const LocationSettings(
//         accuracy: LocationAccuracy.high,
//         distanceFilter: 10,
//       ),
//     ).listen((position) {
//       if (!_isSignificantMovement(position)) return;

//       final newPosition = LatLng(position.latitude, position.longitude);
//       setState(() {
//         _currentPosition = newPosition;
//         _route.add(newPosition);
//         _speed = position.speed * 3.6;
//       });

//       _mapController.move(newPosition, 16);
//     }, onError: (e) {
//       _showErrorSnackBar('Location error: $e');
//       stopDriving();
//       setState(() {
//         isDriving = false;
//       });
//     });

//     _gyroStream = gyroscopeEvents.listen((event) {
//       _gyroscope = [event.x, event.y, event.z];
//     });

//     _accelStream = accelerometerEvents.listen((event) {
//       _accelerometer = [event.x, event.y, event.z];
//     });

//     _dataSendTimer = Timer.periodic(const Duration(seconds: 5), (_) {
//       sendLiveData();
//     });
//   }

//   bool _isSignificantMovement(Position newPosition) {
//     if (_currentPosition == null) return true;
//     double distance = Geolocator.distanceBetween(
//       _currentPosition!.latitude,
//       _currentPosition!.longitude,
//       newPosition.latitude,
//       newPosition.longitude,
//     );
//     return distance > 8.0;
//   }

//   Future<void> _callStartDrivingAPI() async {
//     if (_currentPosition == null || drivervehicleid == null) return;

//     try {
//       final data = {
//         "drivervehicleid": drivervehicleid,
//         "latitude": _currentPosition!.latitude,
//         "longitude": _currentPosition!.longitude
//       };

//       final response = await http.post(
//         Uri.parse("$vehicledriverurl/start-driving"),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode(data),
//       );

//       if (response.statusCode != 200) {
//         _showErrorSnackBar("Failed to record starting location");
//       }
//     } catch (e) {
//       _showErrorSnackBar("Error recording start location: $e");
//     }
//   }

//   void stopDriving() {
//     _callStopDrivingAPI();
//     sendFinalDrivingUpdate();

//     _positionStream?.cancel();
//     _gyroStream?.cancel();
//     _accelStream?.cancel();
//     _dataSendTimer?.cancel();
//   }

//   Future<void> _callStopDrivingAPI() async {
//     if (_currentPosition == null || drivervehicleid == null) return;

//     try {
//       final data = {
//         "drivervehicleid": drivervehicleid,
//         "latitude": _currentPosition!.latitude,
//         "longitude": _currentPosition!.longitude
//       };

//       final response = await http.post(
//         Uri.parse("$vehicledriverurl/stop-driving"),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode(data),
//       );

//       if (response.statusCode == 200) {
//         _showErrorSnackBar("Trip recorded successfully!");
//       } else {
//         _showErrorSnackBar("Failed to record trip details");
//       }
//     } catch (e) {
//       _showErrorSnackBar("Error recording trip: $e");
//     }
//   }

//   Future<void> sendLiveData() async {
//     if (_currentPosition == null || drivervehicleid == null || !isDriving)
//       return;

//     final data = {
//       "latitude": _currentPosition!.latitude,
//       "longitude": _currentPosition!.longitude,
//       "speed": _speed,
//       "gyroscope": {"x": _gyroscope[0], "y": _gyroscope[1], "z": _gyroscope[2]},
//       "accelerometer": {
//         "x": _accelerometer[0],
//         "y": _accelerometer[1],
//         "z": _accelerometer[2]
//       },
//       "drivervehicleid": drivervehicleid,
//       "isdriving": "true",
//     };

//     try {
//       await http.post(
//         Uri.parse("$vehicledriverurl/current-location"),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode(data),
//       );
//     } catch (e) {
//       print("Error sending data: $e");
//     }
//   }

//   Future<void> sendFinalDrivingUpdate() async {
//     if (_currentPosition == null || drivervehicleid == null) return;

//     final data = {
//       "latitude": _currentPosition!.latitude,
//       "longitude": _currentPosition!.longitude,
//       "speed": _speed,
//       "gyroscope": {"x": _gyroscope[0], "y": _gyroscope[1], "z": _gyroscope[2]},
//       "accelerometer": {
//         "x": _accelerometer[0],
//         "y": _accelerometer[1],
//         "z": _accelerometer[2]
//       },
//       "drivervehicleid": drivervehicleid,
//       "isdriving": "false",
//     };

//     try {
//       await http.post(
//         Uri.parse("$vehicledriverurl/current-location"),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode(data),
//       );
//     } catch (e) {
//       print("Error sending final driving update: $e");
//     }
//   }

//   void _showViolationDetails(ViolationMarker violation) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Row(
//             children: [
//               Icon(violation.icon, color: violation.color),
//               SizedBox(width: 8),
//               Expanded(child: Text(violation.eventType)),
//             ],
//           ),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('Details: ${violation.violatedValue}'),
//               SizedBox(height: 8),
//               Text('Time: ${violation.timestamp.toString().substring(0, 19)}'),
//               SizedBox(height: 8),
//               Text(
//                   'Location: ${violation.latitude.toStringAsFixed(4)}, ${violation.longitude.toStringAsFixed(4)}'),
//             ],
//           ),
//           actions: [
//             TextButton(
//               child: Text('Close'),
//               onPressed: () => Navigator.of(context).pop(),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message)),
//     );
//   }

//   @override
//   void dispose() {
//     stopDriving();
//     _violationFetchTimer?.cancel();
//     _mapController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Driver Dashboard"),
//         centerTitle: true,
//         leading: IconButton(
//           icon: const Icon(Icons.notifications),
//           onPressed: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                   builder: (_) => DriverNotificationScreen(email: driverEmail)),
//             );
//           },
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(
//               _showViolations ? Icons.warning : Icons.warning_outlined,
//               color: _showViolations ? Colors.red : Colors.grey,
//             ),
//             onPressed: () => setState(() => _showViolations = !_showViolations),
//             tooltip: _showViolations ? 'Hide Violations' : 'Show Violations',
//           ),
//           IconButton(
//             icon: Icon(
//               _showGeofences ? Icons.map : Icons.map_outlined,
//               color: _showGeofences ? Colors.blue : Colors.grey,
//             ),
//             onPressed: () {
//               setState(() => _showGeofences = !_showGeofences);
//               if (_showGeofences) fetchGeofences();
//             },
//             tooltip: _showGeofences ? 'Hide Geofences' : 'Show Geofences',
//           ),
//           PopupMenuButton<String>(
//             icon: const Icon(Icons.person),
//             onSelected: (value) {
//               if (value == 'Profile') {
//                 Navigator.push(context,
//                     MaterialPageRoute(builder: (_) => const DriverProfile()));
//               } else if (value == 'Logout') {
//                 stopDriving();
//                 Navigator.pushReplacement(context,
//                     MaterialPageRoute(builder: (_) => const DriverLogin()));
//               }
//             },
//             itemBuilder: (context) => [
//               const PopupMenuItem(
//                 value: 'Profile',
//                 child: ListTile(
//                   leading: Icon(Icons.person),
//                   title: Text('Profile'),
//                 ),
//               ),
//               const PopupMenuItem(
//                 value: 'Logout',
//                 child: ListTile(
//                   leading: Icon(Icons.exit_to_app),
//                   title: Text('Logout'),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 if (_errorMessage.isNotEmpty)
//                   Container(
//                     color: Colors.amber[100],
//                     padding: const EdgeInsets.all(8.0),
//                     child: Row(
//                       children: [
//                         const Icon(Icons.warning, color: Colors.red),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             _errorMessage,
//                             style: const TextStyle(color: Colors.red),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 // Adjusted map container with fixed height
//                 Container(
//                   height: MediaQuery.of(context).size.height *
//                       0.5, // 50% of screen height
//                   child: Stack(
//                     children: [
//                       FlutterMap(
//                         mapController: _mapController,
//                         options: MapOptions(
//                           initialCenter: _currentPosition ??
//                               const LatLng(33.6995, 73.0363),
//                           initialZoom: 14,
//                         ),
//                         children: [
//                           TileLayer(
//                             urlTemplate:
//                                 "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
//                             subdomains: const ['a', 'b', 'c'],
//                           ),
//                           if (_showGeofences)
//                             PolygonLayer(
//                               polygons: geofencePolygons,
//                             ),
//                           if (routePoints.isNotEmpty && routePoints.length > 1)
//                             PolylineLayer(
//                               polylines: [
//                                 Polyline(
//                                   points: routePoints,
//                                   color: Colors.deepPurple,
//                                   strokeWidth: 4.0,
//                                 ),
//                               ],
//                             ),
//                           if (_currentPosition != null)
//                             MarkerLayer(
//                               markers: [
//                                 Marker(
//                                   point: _currentPosition!,
//                                   width: 50,
//                                   height: 50,
//                                   child: const Icon(Icons.directions_car,
//                                       size: 40, color: Colors.blue),
//                                 )
//                               ],
//                             ),
//                           if (_route.length >= 2)
//                             PolylineLayer(
//                               polylines: [
//                                 Polyline(
//                                   points: _route,
//                                   strokeWidth: 4,
//                                   color: Colors.blue,
//                                 )
//                               ],
//                             ),
//                           if (_showViolations && _violations.isNotEmpty)
//                             MarkerLayer(
//                               markers: _violations.map((violation) {
//                                 return Marker(
//                                   point: LatLng(
//                                       violation.latitude, violation.longitude),
//                                   width: 40,
//                                   height: 40,
//                                   child: GestureDetector(
//                                     onTap: () =>
//                                         _showViolationDetails(violation),
//                                     child: Container(
//                                       decoration: BoxDecoration(
//                                         color: violation.color,
//                                         shape: BoxShape.circle,
//                                         border: Border.all(
//                                             color: Colors.white, width: 2),
//                                       ),
//                                       child: Icon(
//                                         violation.icon,
//                                         color: Colors.white,
//                                         size: 20,
//                                       ),
//                                     ),
//                                   ),
//                                 );
//                               }).toList(),
//                             ),
//                         ],
//                       ),
//                       Positioned(
//                         bottom: 10,
//                         left: 10,
//                         child: Container(
//                           padding: const EdgeInsets.all(8),
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.8),
//                             borderRadius: BorderRadius.circular(5),
//                           ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Row(
//                                 children: [
//                                   Icon(Icons.directions_car,
//                                       color: Colors.blue, size: 20),
//                                   SizedBox(width: 5),
//                                   Text('Vehicle'),
//                                 ],
//                               ),
//                               SizedBox(height: 5),
//                               if (_showGeofences)
//                                 Row(
//                                   children: [
//                                     Container(
//                                       width: 15,
//                                       height: 15,
//                                       decoration: BoxDecoration(
//                                         color: Colors.blue.withOpacity(0.3),
//                                         border: Border.all(color: Colors.blue),
//                                       ),
//                                     ),
//                                     SizedBox(width: 5),
//                                     Text('Geofence'),
//                                   ],
//                                 ),
//                               if (_showViolations)
//                                 Row(
//                                   children: [
//                                     Icon(Icons.warning,
//                                         color: Colors.red, size: 20),
//                                     SizedBox(width: 5),
//                                     Text('Violation'),
//                                   ],
//                                 ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 // Violation counts section moved up
//                 if (_violations.isNotEmpty)
//                   Padding(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 16.0, vertical: 8.0),
//                     child: Container(
//                       padding: const EdgeInsets.all(12.0),
//                       decoration: BoxDecoration(
//                         color: Colors.red[50],
//                         borderRadius: BorderRadius.circular(8.0),
//                         border: Border.all(color: Colors.red[200]!),
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                         children: [
//                           _buildViolationCount(
//                               'Overspeeding', Icons.speed, Colors.red),
//                           _buildViolationCount(
//                               'Hard Braking', Icons.warning, Colors.amber),
//                           _buildViolationCount(
//                               'Sharp Turns', Icons.turn_right, Colors.purple),
//                         ],
//                       ),
//                     ),
//                   ),
//                 // Speed and driving controls section
//                 Expanded(
//                   child: Container(
//                     padding: const EdgeInsets.all(16.0),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.all(16.0),
//                           decoration: BoxDecoration(
//                             color: Colors.grey[200],
//                             borderRadius: BorderRadius.circular(8.0),
//                           ),
//                           child: Column(
//                             children: [
//                               const Text(
//                                 "Current Speed",
//                                 style: TextStyle(
//                                     fontSize: 16, fontWeight: FontWeight.bold),
//                               ),
//                               const SizedBox(height: 8),
//                               Text(
//                                 "${_speed.toStringAsFixed(1)} km/h",
//                                 style: TextStyle(
//                                   fontSize: 24,
//                                   color:
//                                       _speed > 60 ? Colors.red : Colors.green,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(height: 20),
//                         Expanded(
//                           child: ElevatedButton(
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor:
//                                   isDriving ? Colors.red : Colors.black,
//                               foregroundColor: Colors.white,
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 40, vertical: 12),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(30),
//                               ),
//                             ),
//                             onPressed: toggleDriving,
//                             child: Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Icon(isDriving ? Icons.stop : Icons.play_arrow),
//                                 const SizedBox(width: 8),
//                                 Text(
//                                   isDriving ? "Stop Driving" : "Start Driving",
//                                   style: const TextStyle(fontSize: 16),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                         if (drivervehicleid == null)
//                           Padding(
//                             padding: const EdgeInsets.only(top: 8.0),
//                             child: Text(
//                               "No vehicle assigned",
//                               style: TextStyle(color: Colors.grey[600]),
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//     );
//   }

//   Widget _buildViolationCount(String type, IconData icon, Color color) {
//     final count = _violations.where((v) {
//       switch (type) {
//         case 'Overspeeding':
//           return v.eventType.toLowerCase().contains('overspeed');
//         case 'Hard Braking':
//           return v.eventType.toLowerCase().contains('hardbraking');
//         case 'Sharp Turns':
//           return v.eventType.toLowerCase().contains('sharpturn');
//         default:
//           return false;
//       }
//     }).length;

//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(icon, color: color),
//         const SizedBox(height: 4),
//         Text(
//           '$count',
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 18,
//             color: color,
//           ),
//         ),
//         Text(
//           type,
//           style: const TextStyle(fontSize: 12),
//         ),
//       ],
//     );
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:http/http.dart' as http;
import 'package:admin_signup/DRIVER%20SIDE/driver_notification_screen.dart';
import 'package:admin_signup/DRIVER%20SIDE/driver_profile.dart';
import 'package:admin_signup/DRIVER%20SIDE/driver_login.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViolationMarker {
  final String eventType;
  final String violatedValue;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final int eventId;

  ViolationMarker({
    required this.eventType,
    required this.violatedValue,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.eventId,
  });

  factory ViolationMarker.fromJson(Map<String, dynamic> json) {
    return ViolationMarker(
      eventType: json['eventtype'] ?? '',
      violatedValue: json['violatedvalue'] ?? '',
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']),
      eventId: json['eventid'] ?? 0,
    );
  }

  Color get color {
    switch (eventType.toLowerCase()) {
      case 'overspeeding':
        return Colors.red;
      case 'geofenceviolation':
        return Colors.orange;
      case 'driverfaultsharpturn':
        return Colors.purple;
      case 'hardbraking':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (eventType.toLowerCase()) {
      case 'overspeeding':
        return Icons.speed;
      case 'geofenceviolation':
        return Icons.location_off;
      case 'driverfaultsharpturn':
        return Icons.turn_right;
      case 'hardbraking':
        return Icons.warning;
      default:
        return Icons.error;
    }
  }
}

class Driverdashboard extends StatefulWidget {
  final String? email;
  final dynamic drivervehicleid;

  Driverdashboard({super.key, this.email, this.drivervehicleid});

  @override
  State<Driverdashboard> createState() => _DriverdashboardState();
}

class _DriverdashboardState extends State<Driverdashboard> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  List<LatLng> _route = [];
  double _speed = 0.0;
  List<double> _gyroscope = [0.0, 0.0, 0.0];
  List<double> _accelerometer = [0.0, 0.0, 0.0];
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<GyroscopeEvent>? _gyroStream;
  StreamSubscription<AccelerometerEvent>? _accelStream;
  Timer? _dataSendTimer;
  Timer? _violationFetchTimer;
  String _errorMessage = "";
  bool isDriving = false;
  dynamic drivervehicleid;
  String driverEmail = "";
  bool _isLoading = true;
  List<LatLng> routePoints = [];
  List<Polygon> geofencePolygons = [];
  bool _locationPermissionGranted = false;
  List<ViolationMarker> _violations = [];
  bool _showViolations = true;
  bool _showGeofences = true;

  @override
  void initState() {
    super.initState();
    drivervehicleid = widget.drivervehicleid;
    _initializeData();
    _startViolationUpdates();
  }

  Future<void> _initializeData() async {
    try {
      if (widget.email != null && widget.email!.isNotEmpty) {
        driverEmail = widget.email!;
      } else {
        final prefs = await SharedPreferences.getInstance();
        driverEmail = prefs.getString('driverEmail') ?? "";
      }

      if (driverEmail.isEmpty) {
        setState(() {
          _errorMessage = "Driver email not found. Please log in again.";
          _isLoading = false;
        });
        return;
      }

      if (drivervehicleid == null) {
        await fetchDriverVehicleId();
      }

      await _checkLocationPermission();
      await fetchGeofences();
    } catch (e) {
      print("Error initializing data: $e");
      setState(() {
        _errorMessage = "Failed to initialize: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> fetchGeofences() async {
    try {
      if (driverEmail.isEmpty) {
        print('Driver email is empty, skipping geofence fetch');
        return;
      }

      print('Fetching geofences for driver email: $driverEmail');
      final response = await http.get(
        Uri.parse('$vehicledriverurl/assigned-geofence/$driverEmail'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Received geofence data: $data');

        if (data.isEmpty) {
          print('No geofences assigned to this driver');
          return;
        }

        List<Polygon> newPolygons = [];

        for (var geofence in data) {
          try {
            List<LatLng> points = [];

            if (geofence['coordinates'] is List) {
              var coords = geofence['coordinates'] as List;
              if (coords.isNotEmpty) {
                if (coords.first is List) {
                  points = coords
                      .map((point) {
                        if (point is List && point.length >= 2) {
                          return LatLng(
                            point[0] is num ? point[0].toDouble() : 0.0,
                            point[1] is num ? point[1].toDouble() : 0.0,
                          );
                        }
                        return null;
                      })
                      .where((point) => point != null)
                      .cast<LatLng>()
                      .toList();
                } else if (coords.first is Map) {
                  points = coords
                      .map((point) {
                        if (point is Map) {
                          return LatLng(
                            point['latitude'] is num
                                ? point['latitude'].toDouble()
                                : 0.0,
                            point['longitude'] is num
                                ? point['longitude'].toDouble()
                                : 0.0,
                          );
                        }
                        return null;
                      })
                      .where((point) => point != null)
                      .cast<LatLng>()
                      .toList();
                }
              }
            }

            if (points.isNotEmpty) {
              newPolygons.add(
                Polygon(
                  points: points,
                  color: Colors.blue.withOpacity(0.3),
                  borderColor: Colors.blue,
                  borderStrokeWidth: 2,
                  isFilled: true,
                ),
              );
              print('Added geofence with ${points.length} points');
            } else {
              print('No valid points found for geofence');
            }
          } catch (e) {
            print('Error parsing geofence: $e');
          }
        }

        setState(() {
          geofencePolygons = newPolygons;
        });
        print('Successfully updated ${geofencePolygons.length} geofences');
      } else {
        print('Failed to fetch geofences: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error fetching geofences: $e');
    }
  }

  Future<void> fetchDriverVehicleId() async {
    try {
      final url = "$vehicledriverurl/get-drivervehicle-id/$driverEmail";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          drivervehicleid = data['drivervehicleid'];
        });
      } else {
        setState(() {
          _errorMessage = "Failed to fetch vehicle ID";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error fetching vehicle ID: $e";
      });
    }
  }

  Future<void> _fetchViolations() async {
    if (drivervehicleid == null) return;

    try {
      final url = "$vehicledriverurl/driver-violations/$drivervehicleid";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _violations =
              data.map((json) => ViolationMarker.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print("Error fetching violations: $e");
    }
  }

  void _startViolationUpdates() {
    _fetchViolations();
    _violationFetchTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchViolations();
    });
  }

  Future<void> _checkLocationPermission() async {
    try {
      final defaultLocation = LatLng(33.6995, 73.0363);

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled';
          _currentPosition = defaultLocation;
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permissions are denied';
            _currentPosition = defaultLocation;
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permissions are permanently denied';
          _currentPosition = defaultLocation;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _locationPermissionGranted = true;
      });

      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        );

        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _currentPosition = defaultLocation;
          _errorMessage =
              "Using default location - couldn't get current position";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Location error: $e";
        _isLoading = false;
      });
    }
  }

  void toggleDriving() {
    if (_errorMessage.contains('Location')) {
      _showErrorSnackBar('Location permission required');
      return;
    }

    setState(() {
      isDriving = !isDriving;
    });

    if (isDriving) {
      startDriving();
    } else {
      stopDriving();
    }
  }

  void startDriving() {
    setState(() {
      _route = [];
    });

    _callStartDrivingAPI();

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      if (!_isSignificantMovement(position)) return;

      final newPosition = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = newPosition;
        _route.add(newPosition);
        _speed = position.speed * 3.6;
      });

      _mapController.move(newPosition, 16);
    }, onError: (e) {
      _showErrorSnackBar('Location error: $e');
      stopDriving();
      setState(() {
        isDriving = false;
      });
    });

    _gyroStream = gyroscopeEvents.listen((event) {
      _gyroscope = [event.x, event.y, event.z];
    });

    _accelStream = accelerometerEvents.listen((event) {
      _accelerometer = [event.x, event.y, event.z];
    });

    _dataSendTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      sendLiveData();
    });
  }

  bool _isSignificantMovement(Position newPosition) {
    if (_currentPosition == null) return true;
    double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      newPosition.latitude,
      newPosition.longitude,
    );
    return distance > 8.0;
  }

  Future<void> _callStartDrivingAPI() async {
    if (_currentPosition == null || drivervehicleid == null) return;

    try {
      final data = {
        "drivervehicleid": drivervehicleid,
        "latitude": _currentPosition!.latitude,
        "longitude": _currentPosition!.longitude
      };

      final response = await http.post(
        Uri.parse("$vehicledriverurl/start-driving"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      if (response.statusCode != 200) {
        _showErrorSnackBar("Failed to record starting location");
      }
    } catch (e) {
      _showErrorSnackBar("Error recording start location: $e");
    }
  }

  void stopDriving() {
    _callStopDrivingAPI();
    sendFinalDrivingUpdate();

    _positionStream?.cancel();
    _gyroStream?.cancel();
    _accelStream?.cancel();
    _dataSendTimer?.cancel();
  }

  Future<void> _callStopDrivingAPI() async {
    if (_currentPosition == null || drivervehicleid == null) return;

    try {
      final data = {
        "drivervehicleid": drivervehicleid,
        "latitude": _currentPosition!.latitude,
        "longitude": _currentPosition!.longitude
      };

      final response = await http.post(
        Uri.parse("$vehicledriverurl/stop-driving"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        _showErrorSnackBar("Trip recorded successfully!");
      } else {
        _showErrorSnackBar("Failed to record trip details");
      }
    } catch (e) {
      _showErrorSnackBar("Error recording trip: $e");
    }
  }

  Future<void> sendLiveData() async {
    if (_currentPosition == null || drivervehicleid == null || !isDriving)
      return;

    final data = {
      "latitude": _currentPosition!.latitude,
      "longitude": _currentPosition!.longitude,
      "speed": _speed,
      "gyroscope": {"x": _gyroscope[0], "y": _gyroscope[1], "z": _gyroscope[2]},
      "accelerometer": {
        "x": _accelerometer[0],
        "y": _accelerometer[1],
        "z": _accelerometer[2]
      },
      "drivervehicleid": drivervehicleid,
      "isdriving": "true",
    };

    try {
      await http.post(
        Uri.parse("$vehicledriverurl/current-location"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );
    } catch (e) {
      print("Error sending data: $e");
    }
  }

  Future<void> sendFinalDrivingUpdate() async {
    if (_currentPosition == null || drivervehicleid == null) return;

    final data = {
      "latitude": _currentPosition!.latitude,
      "longitude": _currentPosition!.longitude,
      "speed": _speed,
      "gyroscope": {"x": _gyroscope[0], "y": _gyroscope[1], "z": _gyroscope[2]},
      "accelerometer": {
        "x": _accelerometer[0],
        "y": _accelerometer[1],
        "z": _accelerometer[2]
      },
      "drivervehicleid": drivervehicleid,
      "isdriving": "false",
    };

    try {
      await http.post(
        Uri.parse("$vehicledriverurl/current-location"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );
    } catch (e) {
      print("Error sending final driving update: $e");
    }
  }

  void _showViolationDetails(ViolationMarker violation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(violation.icon, color: violation.color),
              SizedBox(width: 8),
              Expanded(child: Text(violation.eventType)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Details: ${violation.violatedValue}'),
              SizedBox(height: 8),
              Text('Time: ${violation.timestamp.toString().substring(0, 19)}'),
              SizedBox(height: 8),
              Text(
                  'Location: ${violation.latitude.toStringAsFixed(4)}, ${violation.longitude.toStringAsFixed(4)}'),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Dashboard"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DriverNotificationScreen(email: driverEmail)),
            );
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showViolations ? Icons.warning : Icons.warning_outlined,
              color: _showViolations ? Colors.red : Colors.grey,
            ),
            onPressed: () => setState(() => _showViolations = !_showViolations),
            tooltip: _showViolations ? 'Hide Violations' : 'Show Violations',
          ),
          IconButton(
            icon: Icon(
              _showGeofences ? Icons.map : Icons.map_outlined,
              color: _showGeofences ? Colors.blue : Colors.grey,
            ),
            onPressed: () {
              setState(() => _showGeofences = !_showGeofences);
              if (_showGeofences) fetchGeofences();
            },
            tooltip: _showGeofences ? 'Hide Geofences' : 'Show Geofences',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.person),
            onSelected: (value) {
              if (value == 'Profile') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DriverProfile()));
              } else if (value == 'Logout') {
                stopDriving();
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const DriverLogin()));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'Profile',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Profile'),
                ),
              ),
              const PopupMenuItem(
                value: 'Logout',
                child: ListTile(
                  leading: Icon(Icons.exit_to_app),
                  title: Text('Logout'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_errorMessage.isNotEmpty)
                  Container(
                    color: Colors.amber[100],
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Adjusted map container with fixed height
                Container(
                  height: MediaQuery.of(context).size.height *
                      0.5, // 50% of screen height
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _currentPosition ??
                              const LatLng(33.6995, 73.0363),
                          initialZoom: 14,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                            subdomains: const ['a', 'b', 'c'],
                          ),
                          if (_showGeofences)
                            PolygonLayer(
                              polygons: geofencePolygons,
                            ),
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
                          if (_currentPosition != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _currentPosition!,
                                  width: 50,
                                  height: 50,
                                  child: const Icon(Icons.directions_car,
                                      size: 40, color: Colors.blue),
                                )
                              ],
                            ),
                          if (_route.length >= 2)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _route,
                                  strokeWidth: 4,
                                  color: Colors.blue,
                                )
                              ],
                            ),
                          if (_showViolations && _violations.isNotEmpty)
                            MarkerLayer(
                              markers: _violations.map((violation) {
                                return Marker(
                                  point: LatLng(
                                      violation.latitude, violation.longitude),
                                  width: 40,
                                  height: 40,
                                  child: GestureDetector(
                                    onTap: () =>
                                        _showViolationDetails(violation),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: violation.color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: Icon(
                                        violation.icon,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.directions_car,
                                      color: Colors.blue, size: 20),
                                  SizedBox(width: 5),
                                  Text('Vehicle'),
                                ],
                              ),
                              SizedBox(height: 5),
                              if (_showGeofences)
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
                              if (_showViolations)
                                Row(
                                  children: [
                                    Icon(Icons.warning,
                                        color: Colors.red, size: 20),
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
                // Violation counts section moved up
                //if (_violations.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildViolationCount(
                            'Overspeeding', Icons.speed, Colors.red),
                        _buildViolationCount(
                            'Hard Braking', Icons.warning, Colors.amber),
                        _buildViolationCount(
                            'Sharp Turns', Icons.turn_right, Colors.purple),
                      ],
                    ),
                  ),
                ),
                // Speed and driving controls section
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                "Current Speed",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "${_speed.toStringAsFixed(1)} km/h",
                                style: TextStyle(
                                  fontSize: 24,
                                  color:
                                      _speed > 60 ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isDriving ? Colors.red : Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: toggleDriving,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(isDriving ? Icons.stop : Icons.play_arrow),
                                const SizedBox(width: 8),
                                Text(
                                  isDriving ? "Stop Driving" : "Start Driving",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (drivervehicleid == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              "No vehicle assigned",
                              style: TextStyle(color: Colors.grey[600]),
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

  Widget _buildViolationCount(String type, IconData icon, Color color) {
    final count = _violations.where((v) {
      switch (type) {
        case 'OverSpeeding':
          return v.eventType.toLowerCase().contains('OverSpeedi ng');
        case 'HardBraking':
          return v.eventType.toLowerCase().contains('HardBraking');
        case 'SharpTurn':
          return v.eventType.toLowerCase().contains('SharpTurn');
        default:
          return false;
      }
    }).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(
          type,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
