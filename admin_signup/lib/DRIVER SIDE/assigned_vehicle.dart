import 'dart:convert';

import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AssignedVehicle extends StatefulWidget {
  var email;
  AssignedVehicle({required this.email});

  @override
  State<AssignedVehicle> createState() => _AssignedVehicleState();
}

class _AssignedVehicleState extends State<AssignedVehicle> {
  var img, model, year, plate, vehicletype, licenseno;

  Future<void> fetchAssignedVehicle() async {
    // Implement the API call to fetch assigned vehicle data
    // Use the email variable to make the request
    final response = await http
        .get(Uri.parse('$vehicledriverurl/assigned-vehicle/${widget.email}'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      //data.vehicles = data['vehicles'];
      // Update the state with the fetched data
      img = data['vehicles'][0]['picture'];
      if (img != null && img.isNotEmpty) {
        img = '$vehicleapiurl$img'; // Full server URL
      }
      model = data['vehicles'][0]['model'];
      year = data['vehicles'][0]['year'];
      plate = data['vehicles'][0]['licenseplate'];
      vehicletype = data['vehicles'][0]['vehicletype'];
      licenseno = data['vehicles'][0]['licensenumber'];
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Vehicle Assigned YET!!!')),
      );
      img = "";
      model = "";
      year = "";
      plate = "";
      vehicletype = "";
      licenseno = "";
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize any data or state here if needed
    fetchAssignedVehicle();
    // Call the API to fetch assigned vehicle data
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Assigned Vehicle')),
      ),
      body: Column(
        spacing: 15,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width,
            height: 200,
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(10), // Adjust for desired corner radius
              child: img != null && img!.isNotEmpty
                  ? Image.network(
                      img ?? '', // Use a placeholder image if img is null
                      fit: BoxFit.cover, // Adjust BoxFit as needed
                    )
                  : null, // No image available
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 10,
              ),
              const Text(
                'Model:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(
                width: 170,
              ),
              Text(
                model,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 10,
              ),
              const Text(
                'Year:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(
                width: 250,
              ),
              Text(
                '$year',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 10,
              ),
              const Text(
                'License Plate:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(
                width: 130,
              ),
              Text(
                plate,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 10,
              ),
              const Text(
                'License Number:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(
                width: 70,
              ),
              Text(
                licenseno,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 10,
              ),
              const Text(
                'Vehicle Type:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(
                width: 180,
              ),
              Text(
                vehicletype,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
