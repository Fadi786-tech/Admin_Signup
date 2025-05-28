import 'dart:convert';
import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:admin_signup/Screens/login.dart';
import 'package:admin_signup/Vehicle/edit_vehicle.dart';
import 'package:admin_signup/main.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'add_vehicle.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  _VehicleListScreenState createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  List vehicles = [];
  List filteredVehicles = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchVehicles();
    searchController.addListener(() {
      filterVehicles();
    });
  }

  Future<void> fetchVehicles() async {
    final response =
        await http.get(Uri.parse('$vehicleapiurl/get-vehicle/${adminid}'));
    if (response.statusCode == 200) {
      setState(() {
        vehicles = json.decode(response.body);
        filteredVehicles = vehicles;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load vehicles')),
      );
    }
  }

  void filterVehicles() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredVehicles = vehicles.where((vehicle) {
        return vehicle['model'].toLowerCase().contains(query) ||
            vehicle['licenseplate'].toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _deactivateVehicle(
      BuildContext context, var LicensePlate) async {
    final url = Uri.parse('$vehicleapiurl/delete-Vehicle');
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'LicensePlate': LicensePlate}),
    );

    //Navigator.of(context).pop();
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return Maindashboard();
    }));
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$LicensePlate has been deactivated.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to deactivate vehicle.")),
      );
    }
    setState(() {});
  }

  void _showDeactivateDialog(BuildContext context, var LicensePlate) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Do You Want to Deactivate Vehicle?"),
          content: Text(LicensePlate),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                _deactivateVehicle(context, LicensePlate);
                setState(() {});
              },
              child: const Text("Deactivate",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Search by License Plate or Model',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filteredVehicles.length,
                    itemBuilder: (context, index) {
                      // Construct the full image URL
                      String? imageUrl = filteredVehicles[index]['picture'];
                      print(imageUrl);
                      if (imageUrl != null && imageUrl.isNotEmpty) {
                        imageUrl = '$vehicleapiurl$imageUrl'; // Full server URL
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: imageUrl != null &&
                                  imageUrl.isNotEmpty
                              ? NetworkImage(imageUrl) // Load image from server
                              : null, // No image available
                          child: imageUrl == null || imageUrl.isEmpty
                              ? const Icon(Icons.directions_car,
                                  color: Colors.grey)
                              : null,
                        ),
                        title: Text(filteredVehicles[index]['model']),
                        subtitle: Text(
                            "${filteredVehicles[index]['licenseplate']} | ${filteredVehicles[index]['vehicletype']}"),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.edit),
                          onSelected: (value) async {
                            SharedPreferences pref =
                                await SharedPreferences.getInstance();
                            pref.setString('licenseplate',
                                filteredVehicles[index]['licenseplate']);
                            pref.setString(
                                'model', filteredVehicles[index]['model']);
                            pref.setInt(
                                'year', filteredVehicles[index]['year']);
                            pref.setString('vehicletype',
                                filteredVehicles[index]['vehicletype']);
                            pref.setString('picture',
                                filteredVehicles[index]['picture'] ?? '');

                            if (value == 'Edit') {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          EditVehicleScreen())).then((_) {
                                fetchVehicles();
                              });
                            } else if (value == 'Delete') {
                              // Handle delete functionality
                              _showDeactivateDialog(context,
                                  filteredVehicles[index]['licenseplate']);
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'Edit',
                              child: ListTile(
                                leading: Icon(Icons.edit),
                                title: Text('Edit'),
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'Delete',
                              child: ListTile(
                                leading: Icon(Icons.delete),
                                title: Text('Delete'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.black),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AddVehicleScreen(
                                onVehicleAdded: fetchVehicles)),
                      );
                    },
                    child: const Text(
                      'Add Vehicle',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
