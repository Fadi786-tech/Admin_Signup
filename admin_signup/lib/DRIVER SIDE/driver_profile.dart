import 'dart:convert';

import 'package:admin_signup/DRIVER%20SIDE/assigned_geofence.dart';
import 'package:admin_signup/DRIVER%20SIDE/assigned_vehicle.dart';
import 'package:admin_signup/DRIVER%20SIDE/driver_login.dart';
import 'package:admin_signup/DRIVER%20SIDE/location_history_screen.dart';
import 'package:admin_signup/DRIVER%20SIDE/vehicle_history.dart';
import 'package:admin_signup/DRIVER%20SIDE/weekly_report.dart';
import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DriverProfile extends StatefulWidget {
  const DriverProfile({super.key});

  @override
  State<DriverProfile> createState() => _DriverProfileState();
}

class _DriverProfileState extends State<DriverProfile> {
  String? imageUrl;
  var name, email, password, aemail;
  Future<void> _fetchDetails() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      email = prefs.getString('Email');

      if (email == null) {
        //print("No email stored in SharedPreferences");
        return;
      }

      final response = await http.post(Uri.parse('$driverapiurl/get-details'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            name = data['data']['name'];
            aemail = data['data']['aemail'];
            imageUrl = data['data']['picture'];
            print(imageUrl);
            if (imageUrl != null && imageUrl!.isNotEmpty) {
              imageUrl = '$driverapiurl$imageUrl'; // Full server URL
            }
            print(imageUrl);
          });
          // SharedPreferences pref= await SharedPreferences.getInstance();// as SharedPreferences;
          // pref.setString('name', name);
          // print("Profile details fetched successfully");
        } else {
          print("Error: ${data['message']}");
        }
      } else {
        print("Error fetching details: ${response.body}");
      }
    } catch (e) {
      print("Exception while fetching details: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    //fetchProfileImage();

    //setState(() {
    //});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
                //mainAxisAlignment: MainAxisAlignment.center,
                //crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  //SizedBox(height: 10),
                  // Display Profile Picture or Default Icon
                  Center(
                    child: CircleAvatar(
                      radius: 80,
                      backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
                          ? NetworkImage(imageUrl!) // Load image from server
                          : null, // No image available
                      child: imageUrl == null || imageUrl!.isEmpty
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Display Name
                  Text(
                    name ?? 'Name',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  // Display Email
                  Text(
                    email ?? 'Email',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) {
                        return LocationHistoryScreen(
                          drivervehicleid: drivervehicleid,
                        );
                      }));
                    },
                    child: const ListTile(
                      title: Text(
                        'Location History',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      trailing: Icon(Icons.arrow_forward),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      var email = driverEmail;
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) {
                        return WeeklyReportScreen(
                          email: email,
                        );
                      }));
                    },
                    child: const ListTile(
                      title: Text(
                        'Weekly Report',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      trailing: Icon(Icons.arrow_forward),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      var email = driverEmail;
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) {
                        return AssignedVehicle(
                          email: email,
                        );
                      }));
                    },
                    child: const ListTile(
                      title: Text(
                        'Assigned Vehicle',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      trailing: Icon(Icons.arrow_forward),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      var email = driverEmail;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                AssignedGeofence(email: email)),
                      );
                    },
                    child: const ListTile(
                      title: Text(
                        'Assigned Geofence',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      trailing: Icon(Icons.arrow_forward),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                VehicleHistory(email: driverEmail))),
                    child: const ListTile(
                      title: Text(
                        'Vehicle History',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      trailing: Icon(Icons.arrow_forward),
                    ),
                  ),
                ])),
      ),
    );
  }
}
