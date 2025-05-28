import 'dart:convert';

import 'package:admin_signup/DRIVER%20SIDE/view_geofence.dart';
import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AssignedGeofence extends StatefulWidget {
  var email;
  AssignedGeofence({required this.email});

  @override
  State<AssignedGeofence> createState() => _AssignedGeofenceState();
}

class _AssignedGeofenceState extends State<AssignedGeofence> {
  List<dynamic>? geofenceList;

  Future<void> _fetchgeofenceDetails() async {
    String ip = "$vehicledriverurl/assigned-geofence/${widget.email}";
    try {
      final response = await http.get(Uri.parse(ip));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        // In your backend, this IS the data (a list), so:
        setState(() {
          geofenceList = data;
        });
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
    _fetchgeofenceDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'Assigned Geofence',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: ListView.builder(
          itemCount: geofenceList?.length ?? 0,
          itemBuilder: (context, index) {
            var item = geofenceList![index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewGeofence(
                      geoid: item['geoid'],
                    ),
                  ),
                );
              },
              child: Card(
                child: ListTile(
                  title: Text(item['name'] ?? ''),
                  trailing: Icon(Icons.pin_drop_outlined),
                ),
              ),
            );
          }),
    );
  }
}
