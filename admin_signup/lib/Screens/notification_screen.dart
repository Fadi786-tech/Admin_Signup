import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

class NotificationScreen extends StatefulWidget {
  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> notifications = [];
  late IOWebSocketChannel channel;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
    setupWebSocket();
  }

  void fetchNotifications() async {
    final response = await http.get(Uri.parse('http://${ip}:3000/notifications'));
    if (response.statusCode == 200) {
      setState(() {
        notifications = List<Map<String, dynamic>>.from(json.decode(response.body));
      });
    }
  }

  void setupWebSocket() {
    channel = IOWebSocketChannel.connect('ws://${ip}:3000');
    
    channel.stream.listen((message) {
      final newEvent = json.decode(message);
      setState(() {
        notifications.insert(0, newEvent);
      });
    });
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
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
            title: Text("Driver: ${event['name']}"),
            subtitle: Text("${event['eventtype']} - ${event['violatedvalue']}"),
            trailing: Text("${event['timestamp']}"),
          );
        },
      ),
    );
  }
}
