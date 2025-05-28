import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:admin_signup/Screens/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'Inspect_Driver.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  TrackingScreenState createState() => TrackingScreenState();
}

var driverEmail;

class TrackingScreenState extends State<TrackingScreen> {
  List<dynamic> drivers = [];
  List<dynamic> filteredDrivers = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchDrivers();
    searchController.addListener(() {
      filterDrivers();
    });
  }

  Future<void> fetchDrivers() async {
    try {
      //vehicledriverurl
      final response =
          await http.get(Uri.parse('$vehicledriverurl/details/$adminid'));
      final Map<String, dynamic> data = json.decode(response.body);
      //print('data: ${data}');
      if (data.containsKey('drivers') && data['drivers'] != null) {
        setState(() {
          drivers = data['drivers'];
          filteredDrivers = drivers;
          isLoading = false;
        });
      } else {
        throw Exception('Key "drivers" not found or is null');
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void filterDrivers() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredDrivers = drivers.where((driver) {
        return driver['name'].toLowerCase().contains(query) ||
            driver['email'].toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
            child: const Text('Track', style: TextStyle(color: Colors.black))),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Search by name, Email",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 10),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Expanded(
                    child: ListView.builder(
                      itemCount: filteredDrivers.length,
                      itemBuilder: (context, index) {
                        var driver = filteredDrivers[index];

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          child: GestureDetector(
                              onTap: () async {
                                SharedPreferences pref =
                                    await SharedPreferences.getInstance();
                                pref.setInt('id', driver['id']);
                                pref.setString('email', driver['email']);
                                pref.setInt('drivervehicleid',
                                    driver['drivervehicleid']);
                                pref.setString('picture', driver['picture']);
                                pref.setString('name', driver['name']);
                                pref.setString('model', driver['model']);
                                pref.setString(
                                    'licenseno', driver['licenseplate']);
                                Navigator.push(context,
                                    MaterialPageRoute(builder: (context) {
                                  return DriverDetailsScreen(); //driverId: driver['id'],driverName: driver['name'],);
                                }));
                              },
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: driver['picture'] != null &&
                                          driver['picture'].isNotEmpty
                                      ? NetworkImage(
                                          '$vehicledriverurl${driver['picture']}')
                                      : AssetImage('assets/default_profile.png')
                                          as ImageProvider,
                                  radius: 25,
                                ),
                                title: Text(driver['name'] ?? 'Unknown Name',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        "Email: ${driver['email'] ?? 'No Email'}"),
                                    Text(
                                        "Model: ${driver['model'] ?? 'No Model'}"),
                                    Text(
                                        "Vehicle no: ${driver['licenseplate'] ?? 'No License Plate'}"),
                                    Text(
                                        "Assigned Geofence: ${driver['assignedGeofence'].isNotEmpty ? driver['assignedGeofence'].join(', ') : 'No Geofence Assigned'}"),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                // onTap: () {
                                //   Navigator.push(context, MaterialPageRoute(builder: (context) {
                                //     return DriverDetailsScreen(driverId: driver['id'] , driverName: driver['name']);
                                //   }));
                                //},
                              )),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
