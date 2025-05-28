import 'package:admin_signup/POLICE%20SIDE/police_check.dart';
import 'package:admin_signup/DRIVER%20SIDE/driver_login.dart';
import 'package:flutter/material.dart';
import 'package:admin_signup/Screens/login.dart';

class StartingScreen extends StatefulWidget {
  const StartingScreen({super.key});

  @override
  State<StartingScreen> createState() => _StartingScreenState();
}

class _StartingScreenState extends State<StartingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 20,
        children: [
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: Size(0, 50),
                backgroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return Login();
                }));
              },
              child: Center(
                  child: Text(
                'Admin',
                style: TextStyle(color: Colors.white, fontSize: 25),
              ))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(0, 50), backgroundColor: Colors.black),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return DriverLogin();
                }));
              },
              child: Center(
                  child: Text(
                'Driver',
                style: TextStyle(color: Colors.white, fontSize: 25),
              ))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(0, 50), backgroundColor: Colors.black),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return LicensePlateScreen();
                }));
              },
              child: Center(
                  child: Text(
                'Police',
                style: TextStyle(color: Colors.white, fontSize: 25),
              ))),
        ],
      ),
    );
  }
}
