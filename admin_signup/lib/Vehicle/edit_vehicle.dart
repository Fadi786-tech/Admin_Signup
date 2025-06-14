import 'dart:ui';

import 'package:admin_signup/Screens/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Screens/MainDashboard.dart';

class EditVehicleScreen extends StatefulWidget {
  EditVehicleScreen({super.key});

  @override
  _EditVehicleScreenState createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends State<EditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController licensePlateController = TextEditingController();
  TextEditingController modelController = TextEditingController();
  TextEditingController yearController = TextEditingController();
  String vehicleType = '';
  String status = '';
  File? _image;
  final picker = ImagePicker();
  var licenseplate, model, year, vehicletype, picture, imageUrl;

  Future<void> getdetails() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    licenseplate = pref.getString('licenseplate');
    model = pref.getString('model');
    year = pref.getInt('year');
    vehicletype = pref.getString('vehicletype');
    picture = pref.getString('picture'); // Image path or URL
    imageUrl = pref.getString('picture');

    // Ensure the URL is correctly formatted
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (!imageUrl.startsWith('http')) {
        imageUrl = '$vehicleapiurl$imageUrl'; // Prepend API URL
      }
    }
    print('$licenseplate, $model, $year, $vehicletype, $picture');

    setState(() {}); // Refresh UI with fetched data
  }

  @override
  void initState() {
    super.initState();
    getdetails();
    setState(() {});
  }

  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> editVehicle() async {
    String m = modelController.text.isEmpty ? model : modelController.text;
    String yy = yearController.text.toString();
    String? y = yy.isEmpty ? year.toString() : yy;
    String vt = vehicleType.isEmpty ? vehicletype : vehicleType;

    var request = http.MultipartRequest(
        'PUT', Uri.parse('$vehicleapiurl/update-vehicle/$adminid'));

    request.headers['Content-Type'] = 'multipart/form-data';

    request.fields['LicensePlate'] = licenseplate;
    request.fields['Model'] = m;
    request.fields['Year'] = y;
    request.fields['VehicleType'] = vt;

    // Only send the old picture field if no new image is selected
    if (_image == null) {
      request.fields['Picture'] = picture ?? '';
    }

    // Add the new image file if selected - FIXED: Uncommented and corrected field name
    if (_image != null) {
      request.files.add(
          await http.MultipartFile.fromPath('vehiclePicture', _image!.path));
    }

    try {
      print(
          '$licenseplate,$m,$y,$vt,${_image != null ? 'New Image Selected' : picture}');
      var response = await request.send();
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle Updated Successfully')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to Edit Vehicle')),
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
      appBar: AppBar(title: const Text('Edit Vehicle'), centerTitle: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              spacing: 15,
              children: [
                TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                        labelText: 'LicensePlate no',
                        hintText: licenseplate,
                        border: OutlineInputBorder())),
                TextFormField(
                    controller: modelController,
                    decoration: InputDecoration(
                        labelText: 'Model',
                        hintText: model,
                        border: OutlineInputBorder())),
                TextFormField(
                    controller: yearController,
                    decoration: InputDecoration(
                        labelText: 'Year',
                        hintText: year.toString(),
                        border: OutlineInputBorder())),
                DropdownButtonFormField(
                  decoration: InputDecoration(
                      hintText: vehicletype.toString(),
                      border: OutlineInputBorder()),
                  items: ['LTV', 'HTV'].map((String type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      vehicleType = value as String;
                    });
                  },
                ),
                const SizedBox(height: 10),
                CircleAvatar(
                  radius: 50,
                  backgroundImage: _image != null
                      ? FileImage(_image!) // Show newly selected image
                      : (imageUrl != null && imageUrl.isNotEmpty
                          ? NetworkImage(
                              imageUrl) // Show existing image from server
                          : null),
                  child:
                      _image == null && (imageUrl == null || imageUrl.isEmpty)
                          ? const Icon(Icons.car_rental,
                              color: Colors.grey, size: 50)
                          : null,
                ),
                TextButton(
                  onPressed: pickImage,
                  child: Text(_image != null ? "Change Image" : "Choose File"),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                  ),
                  onPressed: editVehicle,
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
