import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:admin_signup/Screens/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

class AddDriverScreen extends StatefulWidget {
  final Function onDriverAdded;

  AddDriverScreen({required this.onDriverAdded});

  @override
  _AddDriverScreenState createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends State<AddDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmpasswordController = TextEditingController();
  TextEditingController contactnoController = TextEditingController();
  TextEditingController licensenoController = TextEditingController();
  String licenseType = '';
  //String status = '';
  File? _image;
  final picker = ImagePicker();

  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  String? _profilePictureUrl;
  Future<void> addDriver(File imageFile) async {
    var uri = Uri.parse("$driverapiurl/add-driver/$adminid");
    var request = http.MultipartRequest('POST', uri);

    // Add image file
    request.files.add(await http.MultipartFile.fromPath(
      'driverPicture', // Field name must match 'upload.single("vehiclePicture")'
      imageFile.path,
      contentType:
          MediaType.parse(lookupMimeType(imageFile.path) ?? 'image/jpeg'),
    ));
    //Name, Email, Contactno, Picture, Password, LicenseType, LicenseNumber
    // Add other form fields
    request.fields['Name'] = nameController.text;
    request.fields['Email'] = emailController.text;
    request.fields['Contactno'] = contactnoController.text;
    request.fields['Password'] = passwordController.text;
    request.fields['LicenseType'] = licenseType;
    request.fields['LicenseNumber'] = licensenoController.text;

    try {
      var response = await request.send();

      if (response.statusCode == 201) {
        var responseBody = await response.stream.bytesToString();
        var jsonResponse = jsonDecode(responseBody);

        setState(() {
          _profilePictureUrl = jsonResponse['filePath']; // Update UI
        });

        print("Driver added successfully");
        widget.onDriverAdded();
        Navigator.pop(context);
      } else {
        print("Failed to add driver");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add driver')),
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
      appBar: AppBar(
        title: const Text('Add driver'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              spacing: 20,
              children: [
                TextFormField(
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your Name';
                    }
                    return null;
                  },
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Name', border: OutlineInputBorder()),
                ),
                TextFormField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your Email';
                      }
                      return null;
                    },
                    controller: emailController,
                    decoration: const InputDecoration(
                        labelText: 'Email', border: OutlineInputBorder())),
                TextFormField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your Password';
                      }
                      return null;
                    },
                    controller: passwordController,
                    decoration: const InputDecoration(
                        labelText: 'Password', border: OutlineInputBorder())),
                TextFormField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please re-enter your password';
                      }
                      if (confirmpasswordController.text !=
                          passwordController.text) {
                        return 'Confirm Password doesnot match the Password';
                      }
                      return null;
                    },
                    controller: confirmpasswordController,
                    decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder())),
                TextFormField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your Contact no';
                      }
                      return null;
                    },
                    controller: contactnoController,
                    decoration: const InputDecoration(
                        labelText: 'Contact no', border: OutlineInputBorder())),
                TextFormField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your License no';
                      }
                      return null;
                    },
                    controller: licensenoController,
                    decoration: const InputDecoration(
                        labelText: 'License no', border: OutlineInputBorder())),
                DropdownButtonFormField(
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your License Type';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                      labelText: 'License Type', border: OutlineInputBorder()),
                  items: ['LTV', 'HTV'].map((String type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      licenseType = value as String;
                    });
                  },
                ),
                SizedBox(height: 10),
                _image == null
                    ? Text("No Image Selected")
                    : Image.file(_image!, height: 100),
                TextButton(
                  onPressed: pickImage,
                  child: Text("Choose File"),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      if (_image != null) {
                        // Ensure an image is selected
                        await addDriver(_image!);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please select an image')),
                        );
                      }
                    }
                  },
                  child: Text(
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
