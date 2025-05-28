import 'dart:convert';

import 'package:admin_signup/Screens/login.dart';
import 'package:flutter/material.dart';
import 'package:admin_signup/main.dart';
import 'package:http/http.dart' as http;
import 'MainDashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:admin_signup/main.dart';

class Dashboard extends StatefulWidget {
  final email;
  Dashboard({required this.email, super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String? name;

  @override
  void initState() {
    super.initState();
    _loadName();
    getAdminId();
  }

  Future<void> getAdminId() async {
    String url = '$apiurl/admin-id/${widget.email}';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          adminid = data['adminid'];
          print('Admin ID: $adminid');
        });
      } else {
        print('Failed to fetch Admin ID: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching Admin ID: $e');
    }
  }

  Future<void> _loadName() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      name = prefs.getString('name') ?? 'Guest';
    });
  }

  @override
  Widget build(BuildContext context) {
    //String name = 'Guest';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Account Created',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Center(
            child: Column(
          children: [
            SizedBox(
              height: 5,
            ),
            Text(
              'Welcome $name',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(
              height: 15,
            ),
            Text(
              'Your account has been successfully created.',
              style: TextStyle(fontSize: 17),
            ),
            SizedBox(
              height: 20,
            ),
            SizedBox(
              width: MediaQuery.sizeOf(context).width,
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: ContinuousRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => Maindashboard()));
                  },
                  child: Text(
                    'Let\'s go',
                    style: TextStyle(color: Colors.white),
                  )),
            ),
            SizedBox(
              height: 40,
            ),
            Opacity(
              opacity: 0.4,
              child: Text(
                'By continuing, you agree to the Terms of Use. Read our Privacy Policy.',
                style: TextStyle(),
              ),
            )
          ],
        )),
      ),
    );
  }
}
