import 'package:admin_signup/main.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'MainDashboard.dart';

class ForgotPasswordConfirmationScreen extends StatefulWidget {
  final String email;
  ForgotPasswordConfirmationScreen({required this.email});

  @override
  _ForgotPasswordConfirmationScreenState createState() => _ForgotPasswordConfirmationScreenState();
}
//late var res;
class _ForgotPasswordConfirmationScreenState extends State<ForgotPasswordConfirmationScreen> {
  bool _isLoading = false;

  Future<void> resendEmail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // SharedPreferences pref=await SharedPreferences.getInstance();
      // res=pref.getString('respass');
       final response = await http.post(
        Uri.parse('$apiurl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'Email': widget.email}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email resent successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resend email. Try again.')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $error')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "We've sent your secure login link to:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            SizedBox(height: 10),
            Text(
              widget.email,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.blue),
            ),
            SizedBox(height: 20),
            Text(
              "If you don’t see it, check your spam folder or click below to resend the email.",
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:(){
                  //_isLoading ? null : () =>
                      resendEmail();
                } ,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.black)
                    : Text('Resend Email', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
