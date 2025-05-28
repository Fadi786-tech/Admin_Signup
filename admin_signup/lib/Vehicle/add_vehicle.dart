import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:admin_signup/Screens/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

class AddVehicleScreen extends StatefulWidget {
  final Function onVehicleAdded;

  AddVehicleScreen({required this.onVehicleAdded});

  @override
  _AddVehicleScreenState createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController licensePlateController = TextEditingController();
  TextEditingController modelController = TextEditingController();
  TextEditingController yearController = TextEditingController();
  String vehicleType = '';
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
  Future<void> addVehicle(File imageFile) async {
    var uri = Uri.parse("$vehicleapiurl/add-vehicle/${adminid}");
    var request = http.MultipartRequest('POST', uri);

    // Add image file
    request.files.add(await http.MultipartFile.fromPath(
      'vehiclePicture', // Field name must match 'upload.single("vehiclePicture")'
      imageFile.path,
      contentType:
          MediaType.parse(lookupMimeType(imageFile.path) ?? 'image/jpeg'),
    ));

    // Add other form fields
    request.fields['VehicleType'] = vehicleType;
    request.fields['LicensePlate'] = licensePlateController.text;
    request.fields['Model'] = modelController.text;
    request.fields['Year'] = yearController.text;

    try {
      var response = await request.send();

      if (response.statusCode == 201) {
        var responseBody = await response.stream.bytesToString();
        var jsonResponse = jsonDecode(responseBody);

        setState(() {
          _profilePictureUrl = jsonResponse['filePath']; // Update UI
        });

        print("Vehicle added successfully");
        widget.onVehicleAdded();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle Added Successfully')),
        );
      } else {
        print("Failed to add vehicle");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add vehicle')),
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
        title: const Text('Add Vehicle'),
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
                  controller: licensePlateController,
                  decoration: const InputDecoration(
                      labelText: 'License Plate', border: OutlineInputBorder()),
                ),
                TextFormField(
                    controller: modelController,
                    decoration: const InputDecoration(
                        labelText: 'Model', border: OutlineInputBorder())),
                TextFormField(
                    controller: yearController,
                    decoration: const InputDecoration(
                        labelText: 'Year', border: OutlineInputBorder())),
                DropdownButtonFormField(
                  decoration: const InputDecoration(
                      labelText: 'Vehicle Type', border: OutlineInputBorder()),
                  items: ['LTV', 'HTV'].map((String type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      vehicleType = value as String;
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
                    if (_image != null) {
                      // Ensure an image is selected
                      await addVehicle(_image!);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select an image')),
                      );
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
