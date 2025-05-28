import 'package:admin_signup/Driver/driver_list.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Screens/MainDashboard.dart';

class EditDriverScreen extends StatefulWidget {
  EditDriverScreen({super.key});

  @override
  _EditDriverScreenState createState() => _EditDriverScreenState();
}

class _EditDriverScreenState extends State<EditDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmpasswordController = TextEditingController();
  TextEditingController contactnoController = TextEditingController();
  TextEditingController licensenoController = TextEditingController();
  String vehicleType = '';
  String status = '';
  File? _image;
  final picker = ImagePicker();
  var email, name, contactno, password, licensetype, licensenumber, picture, imageUrl;

  Future<void> getdetails() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    name = pref.getString('name');
    email = pref.getString('email');
    contactno = pref.getString('contactno');
    password = pref.getString('password'); // Image path or URL
    licensetype = pref.getString('licensetype');
    licensenumber = pref.getString('licensenumber');
    picture = pref.getString('picture');
    imageUrl = pref.getString('picture');

// Ensure the URL is correctly formatted
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (!imageUrl.startsWith('http')) {
        imageUrl = '$driverapiurl$imageUrl'; // Prepend API URL
      }
    }
print('$name, $email, $contactno, $password, $licensetype, $licensenumber, $imageUrl');
    setState(() {}); // Refresh UI with fetched data
  }

  @override
  void initState() {
    super.initState();
    getdetails();
    setState(() {

    });
  }

  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> editDriver() async {

    String n = nameController.text.isEmpty ? name : nameController.text;
    String e = emailController.text.isEmpty ? email : emailController.text;
    String p = passwordController.text.isEmpty ? password : passwordController.text;
    //String cp= confirmpasswordController.text.isEmpty ? password : confirmpasswordController.text;
    String cn= contactnoController.text.isEmpty ? contactno : contactnoController.text;
    String ln= licensenoController.text.isEmpty ? licensenumber : licensenoController.text;
    var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$driverapiurl/update-driver')
    );
print('$n,$e,$p,$cn,$ln,$licensetype,$picture');
request.headers['Content-Type'] = 'multipart/form-data';

    request.fields['Name'] = n;
    request.fields['Email'] = e;
    request.fields['Contactno'] = cn;
    request.fields['Password'] = p;
    request.fields['LicenseType'] = licensetype;
    request.fields['LicenseNumber'] = ln;
    request.fields['Picture']=picture;
    // if (_image != null) {
    //   request.files.add(
    //       await http.MultipartFile.fromPath('Picture', _image!.path));
    // }

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver Updated Successfully')),
        );
        Navigator.push(context, MaterialPageRoute(builder: (context){
          return DriverListScreen();
        }));
        //Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to Edit Driver')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Driver'), centerTitle: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              spacing: 15,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: name,
                      border: const OutlineInputBorder()),
                ),
                TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: email,
                        border: OutlineInputBorder())),
                TextFormField(
                    controller: passwordController,
                    decoration: InputDecoration(
                        hintText: password,
                        labelText: 'Password',
                        border: const OutlineInputBorder())),
                TextFormField(
                    controller: confirmpasswordController,
                    decoration: InputDecoration(
                        hintText: password,
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder())),
                TextFormField(
                    controller: contactnoController,
                    decoration: InputDecoration(
                        labelText: 'Contact Number',
                        hintText: contactno,
                        border: OutlineInputBorder())),
                TextFormField(
                    readOnly: true,
                    controller: licensenoController,
                    decoration: InputDecoration(
                        hintText: licensenumber,
                        labelText: 'License Number',
                        border: OutlineInputBorder())),
                DropdownButtonFormField(
                  decoration: InputDecoration(
                      hintText: licensetype,
                      labelText: 'License Type',
                      border: OutlineInputBorder()),
                  items: ['LTV', 'HTV'].map((String type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      licensetype = value as String;
                    });
                  },
                ),
                SizedBox(height: 10),
                CircleAvatar(
                  radius: 50,
                  backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                      ? NetworkImage(imageUrl) // Load image from server
                      : null,
                  child: imageUrl == null || imageUrl.isEmpty
                      ? const Icon(Icons.car_rental,
                          color: Colors.grey, size: 50)
                      : null,
                ),
                TextButton(
                  onPressed: pickImage,
                  child: const Text("Choose File"),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                  ),
                  onPressed: editDriver,
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
