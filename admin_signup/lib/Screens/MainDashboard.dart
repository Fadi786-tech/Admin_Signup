import 'dart:convert';
import 'package:admin_signup/Demo/demoTracking.dart';
import 'package:admin_signup/Screens/notification_screen.dart';
import 'package:admin_signup/Track/TrackAll.dart';
import 'package:admin_signup/speedlimitbound/bound_speedlimit.dart';
import 'package:http/http.dart' as http;

import '../Assign_Geofence/assign_geofence.dart';
import '../Driver/driver_list.dart';
import '../Screens/AdminProfile.dart';
import '../Screens/login.dart';
import '../Vehicle/vehicle_list.dart';
import 'package:flutter/material.dart';
import '../Assign_Vehicle/assign_vehicle.dart';
import '../Geofence/geofence_list.dart';
import '../Track/Tracking.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class Maindashboard extends StatefulWidget {
  const Maindashboard({super.key});

  @override
  State<Maindashboard> createState() => _MaindashboardState();
}

String ip = '192.168.10.21';
String getBaseUrl() {
  if (kIsWeb) {
    // Web (Admin panel) ke liye localhost
    return "http://localhost:3000/api";
  } else if (Platform.isAndroid) {
    // Android Emulator ke liye different IP
    return "http://${ip}:3000/api";
  } else {
    // Physical Device ke liye local Wi-Fi IP
    return "http://127.0.0.1:3000/api";
  }
}
// String ip = '192.168.10.21'; // Your local machine IP

// String getBaseUrl() {
//   return "http://$ip:3000/api";
//}

Future<void> GetCompanyName(var email) async {
  try {
    final response =
        await http.get(Uri.parse('$apiurl/Get-company-name/$email'));
    if (response.statusCode == 200) {
      print("Company name fetched successfully");
      var data = jsonDecode(response.body);
      companyname = data['companyname'];
      print(companyname);
    } else {
      print("Error fetching details: ${response.body}");
    }
  } catch (e) {
    print("Exception while fetching details: $e");
  }
}

final String vehicleapiurl = '${getBaseUrl()}/vehicles';
final String driverapiurl = '${getBaseUrl()}/drivers';
final String vehicledriverurl = '${getBaseUrl()}/driver-vehicle';
final String apiUrl = '${getBaseUrl()}/geofence';
final String apiurl = '${getBaseUrl()}/Admin';

class _MaindashboardState extends State<Maindashboard> {
  @override
  void initState() {
    super.initState();
    GetCompanyName(Adminemail).then((_) {
      setState(() {}); // Refresh the UI after fetching company name
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              return NotificationScreen();
            }));
          },
        ),
        title: Text(companyname == null ? 'Dashboard' : companyname!),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.person), // Replace with your desired icon
            onSelected: (value) {
              if (value == 'Profile') {
                // Navigate to Profile Page or perform action
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const Adminprofile())).then((_) {
                  setState(
                      () {}); // Forces a refresh when returning from profile
                });
              } else if (value == 'Logout') {
                // Handle logout
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return const Login();
                }));
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'Profile',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Profile'),
                ),
              ),
              const PopupMenuItem<String>(
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
      body: SingleChildScrollView(
        child: Column(
          spacing: 10,
          children: [
            const SizedBox(
              height: 5,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const VehicleListScreen()),
                    );
                  },
                  child: SizedBox(
                    width: 161,
                    height: 197,
                    child: Card(
                      color: Colors.grey.shade400,
                      shape: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      child: const Column(
                        children: [
                          Image(
                            image: AssetImage('assets/images/vehiclefront.png'),
                          ),
                          Text(
                            'Vehicle',
                            style: TextStyle(fontSize: 20),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => GeofencesScreen()),
                    );
                  },
                  child: SizedBox(
                    width: 161,
                    height: 197,
                    child: Card(
                      color: Colors.grey.shade400,
                      shape: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      child: const Column(
                        children: [
                          Image(
                              image: AssetImage('assets/images/geofence.png')),
                          Text(
                            'Geofence',
                            style: TextStyle(fontSize: 20),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 25,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const DriverListScreen()),
                    );
                  },
                  child: SizedBox(
                    width: 161,
                    height: 197,
                    child: Card(
                      color: Colors.grey.shade400,
                      shape: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      child: const Column(
                        children: [
                          Image(
                              image: AssetImage('assets/images/adddriver.png')),
                          Text(
                            'Driver',
                            style: TextStyle(fontSize: 20),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return const AssignVehicleScreen();
                    }));
                  },
                  child: SizedBox(
                    width: 161,
                    height: 197,
                    child: Card(
                      color: Colors.grey.shade400,
                      shape: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      child: const Column(
                        children: [
                          Image(
                              image:
                                  AssetImage('assets/images/vehiclefront.png')),
                          Text(
                            'Assign Vehicle',
                            style: TextStyle(fontSize: 20),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 25,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return const AssignGeofenceScreen();
                    }));
                  },
                  child: SizedBox(
                    width: 161,
                    height: 197,
                    child: Card(
                      color: Colors.grey.shade400,
                      shape: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      child: const Column(
                        children: [
                          Image(
                              image: AssetImage('assets/images/geofence.png')),
                          Row(
                            children: [
                              SizedBox(
                                width: 15,
                              ),
                              Text(
                                'Assign Geofence',
                                style: TextStyle(fontSize: 18),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return const TrackingScreen();
                    }));
                  },
                  child: SizedBox(
                    width: 161,
                    height: 197,
                    child: Card(
                      color: Colors.grey.shade400,
                      shape: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      child: const Column(
                        children: [
                          Image(image: AssetImage('assets/images/track.png')),
                          Text(
                            'Track',
                            style: TextStyle(fontSize: 20),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 25,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return const BoundSpeedlimit();
                    }));
                  },
                  child: SizedBox(
                    width: 161,
                    height: 197,
                    child: Card(
                      color: Colors.grey.shade400,
                      shape: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      child: const Column(
                        children: [
                          Image(
                              image: AssetImage(
                                  'assets/images/boundSpeedlimit.png')),
                          Text(
                            'Set Speedlimit',
                            style: TextStyle(fontSize: 20),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return Trackall();
                    }));
                  },
                  child: SizedBox(
                    width: 161,
                    height: 197,
                    child: Card(
                      color: Colors.grey.shade400,
                      shape: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      child: const Column(
                        children: [
                          Image(
                              image: AssetImage('assets/images/Trackall.png')),
                          Text(
                            'Track All',
                            style: TextStyle(fontSize: 20),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 25,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return DemoTrackingScreen();
                    }));
                  },
                  child: SizedBox(
                    width: 161,
                    height: 197,
                    child: Card(
                      color: Colors.grey.shade400,
                      shape: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      child: const Column(
                        children: [
                          Image(image: AssetImage('assets/images/track.png')),
                          Text(
                            'Demo',
                            style: TextStyle(fontSize: 20),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
