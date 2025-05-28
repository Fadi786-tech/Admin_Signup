import 'dart:convert';

import 'package:admin_signup/Screens/AdminProfile.dart';
import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DriverNotificationScreen extends StatefulWidget {
  var email;
  DriverNotificationScreen({required this.email});

  @override
  State<DriverNotificationScreen> createState() =>
      _DriverNotificationScreenState();
}

class _DriverNotificationScreenState extends State<DriverNotificationScreen> {
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    getNotification();
  }

  Future<void> getNotification() async {
    // Get notification
    String apiUrl = "$driverapiurl/driver-notification/${widget.email}";
    try {
      var response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          notifications = List<Map<String, dynamic>>.from(data['data']);
        });
      } else {
        print('No Events found');
      }
    } catch (e) {
      print('Exception: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Notifications")),
      body: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final event = notifications[index];
          return ListTile(
            subtitle: Text("${event['eventtype']} - ${event['violatedvalue']}"),
            trailing: Text("${event['timestamp']}"),
          );
        },
      ),
    );
  }
}
