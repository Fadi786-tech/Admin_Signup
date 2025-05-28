import 'package:admin_signup/DRIVER%20SIDE/driverDashboard.dart';
import 'package:admin_signup/Screens/Forgot_Password_Screen.dart';
import 'package:admin_signup/Screens/starting_screen.dart';
import 'package:flutter/material.dart';
import 'package:admin_signup/main.dart';
import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:admin_signup/Screens/Forgot_Password_Screen.dart';
import 'package:admin_signup/Screens/AdminProfile.dart';

class DriverLogin extends StatefulWidget {
  const DriverLogin({super.key});

  @override
  State<DriverLogin> createState() => _DriverLoginState();
}

var driverEmail;
var drivervehicleid;

class _DriverLoginState extends State<DriverLogin> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late String email;
  String _errorMessage = "";
  Future<void> fetchDriverVehicleId() async {
    if (driverEmail.isEmpty) {
      setState(() {
        _errorMessage = 'Driver email is missing';
      });
      return;
    }

    final url = "$vehicledriverurl/get-drivervehicle-id/$driverEmail";

    print("Fetching driver vehicle ID from: $url");

    try {
      final res = await http.get(Uri.parse(url));
      print("API response status: ${res.statusCode}");
      print("API response body: ${res.body}");

      if (res.statusCode == 200) {
        try {
          final responseData = jsonDecode(res.body);
          setState(() {
            drivervehicleid = responseData['drivervehicleid'] ?? "";
          });

          print("Driver vehicle ID: $drivervehicleid");

          if (drivervehicleid.isEmpty) {
            setState(() {
              _errorMessage = 'No vehicle assigned to this driver';
            });
          }
        } catch (e) {
          print("JSON decode error: $e");
          setState(() {
            _errorMessage = 'Error parsing response: $e';
          });
        }
      } else {
        print("Failed API response: ${res.body}");
        setState(() {
          _errorMessage = "Failed to fetch driver ID: ${res.statusCode}";
        });
      }
    } catch (e) {
      print("Network error: $e");
      setState(() {
        _errorMessage = "Network error: $e";
      });
    }
  }

  Future<void> _signin() async {
    String url = '$driverapiurl/login';

    print(
        'Sending data: ${_emailController.text}, ${_passwordController.text}');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      print('Response: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        driverEmail = _emailController.text.trim();
        SharedPreferences pref = await SharedPreferences.getInstance();
        pref.setString('Email', _emailController.text.trim());
        pref.setString('Password', _passwordController.text);
        await fetchDriverVehicleId();
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => Driverdashboard(
                      email: driverEmail,
                      drivervehicleid: drivervehicleid,
                    )));
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email or Password is incorrect.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  Future<void> resetPassword(String email) async {
    final url = Uri.parse("$driverapiurl/reset-password");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"Email": email}),
      );

      if (response.statusCode == 200) {
        print("Password reset email sent successfully.");
        Navigator.push(context, MaterialPageRoute(builder: (context) {
          return ForgotPasswordConfirmationScreen(
            email: email,
          );
        }));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email doesnot exists.')),
        );
        print("Error: ${jsonDecode(response.body)['error']}");
      }
    } catch (e) {
      print("Request failed: $e");
    }
  }

  void _showDialog(BuildContext context) {
    final TextEditingController textController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Email"),
          content: TextField(
            controller: textController,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: "Email",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text(
                "Cancel",
                style: TextStyle(color: Colors.black, fontSize: 17),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () {
                String input = textController.text;
                resetPassword(input); // Call the API
                print("User Input: $input");
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text(
                "Reset Password",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(height: 130),
                Center(
                  child: const Text(
                    'Driver Login',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
                  ),
                ),
                SizedBox(height: 10),
                const Row(
                  children: [
                    SizedBox(
                      width: 1,
                    ),
                    Text(
                      'Email',
                      style: TextStyle(fontSize: 20),
                    )
                  ],
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                      hintText: 'Email', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
                const SizedBox(
                  height: 15,
                ),
                const Row(
                  children: [
                    SizedBox(
                      width: 1,
                    ),
                    Text(
                      'Password',
                      style: TextStyle(fontSize: 20),
                    )
                  ],
                ),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                      hintText: 'Password', border: OutlineInputBorder()),
                  obscureText: true, // This will mask the password input
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your Password';
                    }
                    return null;
                  },
                ),
                const SizedBox(
                  height: 20,
                ),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: ContinuousRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _signin();
                      }
                    },
                    child: const Text(
                      'Sign In',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 0,
                ),
                Row(
                  children: [
                    TextButton(
                        onPressed: () {
                          _showDialog(context);
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: 17,
                            color: Colors.black,
                            decoration: TextDecoration.underline,
                          ),
                        )),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width,
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: ContinuousRectangleBorder(
                              borderRadius: BorderRadius.circular(15))),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const StartingScreen()),
                        );
                      },
                      child: const Text(
                        'Back',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      )),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
