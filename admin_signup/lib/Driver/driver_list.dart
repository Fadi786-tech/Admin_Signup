import 'dart:convert';
import 'package:admin_signup/Driver/edit_driver.dart';
import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:admin_signup/Screens/login.dart';
import 'package:admin_signup/Vehicle/edit_vehicle.dart';
import 'package:admin_signup/main.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'add_driver.dart';

class DriverListScreen extends StatefulWidget {
  const DriverListScreen({super.key});

  @override
  _DriverListScreenState createState() => _DriverListScreenState();
}

class _DriverListScreenState extends State<DriverListScreen> {
  List driver = [];
  List filtereddriver = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchDrivers();
    searchController.addListener(() {
      filterDrivers();
    });
  }

  Future<void> fetchDrivers() async {
    final response =
        await http.get(Uri.parse('$driverapiurl/get-driver/$adminid'));
    if (response.statusCode == 200) {
      setState(() {
        driver = json.decode(response.body);
        filtereddriver = driver;
        isLoading = false;
        print(filtereddriver);
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

  void filterDrivers() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filtereddriver = driver.where((driver) {
        return driver['name'].toLowerCase().contains(query) ||
            driver['email'].toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _deactivateDriver(
      BuildContext context, var LicenseNumber) async {
    final url = Uri.parse('$driverapiurl/delete-driver');
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'LicenseNumber': LicenseNumber}),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$LicenseNumber has been deactivated.")),
      );
      Navigator.push(context, MaterialPageRoute(builder: (context) {
        return Maindashboard();
      }));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to deactivate vehicle.")),
      );
    }
    setState(() {});
  }

  void _showDeactivateDialog(BuildContext context, var LicenseNumber) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Do You Want to Deactivate Driver?"),
          content: Text(LicenseNumber),
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
                _deactivateDriver(context, LicenseNumber);
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

  void _showFireDriverDialog(
      BuildContext context, var drivername, var licensenumber) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Do You Want to Fire this Driver?"),
          content: Text(drivername),
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
                _fireDriver(context, drivername, licensenumber);
                setState(() {});
              },
              child: const Text("Fire Driver",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fireDriver(
      BuildContext context, var drivername, var licenseno) async {
    final url = Uri.parse('$driverapiurl/fire-driver');
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'adminid': adminid,
        'LicenseNumber': licenseno,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$drivername has been fired.")),
      );
      Navigator.push(context, MaterialPageRoute(builder: (context) {
        return Maindashboard();
      }));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to fire driver.")),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Search by name or email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filtereddriver.length,
                    itemBuilder: (context, index) {
                      // Construct the full image URL
                      String? imageUrl = filtereddriver[index]['picture'];
                      if (imageUrl != null && imageUrl.isNotEmpty) {
                        imageUrl = '$driverapiurl$imageUrl'; // Full server URL
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
                        title: Text('${filtereddriver[index]['name']}'),
                        subtitle: Text("${filtereddriver[index]['email']}"),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.edit),
                          onSelected: (value) async {
                            SharedPreferences pref =
                                await SharedPreferences.getInstance();
                            pref.setString(
                                'name', filtereddriver[index]['name']);
                            pref.setString(
                                'email', filtereddriver[index]['email']);
                            pref.setString('contactno',
                                filtereddriver[index]['contactno']);
                            pref.setString(
                                'password', filtereddriver[index]['password']);
                            pref.setString('licensetype',
                                filtereddriver[index]['licensetype']);
                            pref.setString('licensenumber',
                                filtereddriver[index]['licensenumber']);
                            pref.setString('picture',
                                filtereddriver[index]['picture'] ?? '');

                            if (value == 'Edit') {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          EditDriverScreen())).then((_) {
                                fetchDrivers();
                              });
                            } else if (value == 'Delete') {
                              // Handle delete functionality
                              _showDeactivateDialog(context,
                                  filtereddriver[index]['licensenumber']);
                            } else if (value == 'Fire Driver') {
                              _showFireDriverDialog(
                                  context,
                                  filtereddriver[index]['name'],
                                  filtereddriver[index]['licensenumber']);
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
                            const PopupMenuItem<String>(
                              value: 'Fire Driver',
                              child: ListTile(
                                leading: Icon(Icons.delete),
                                title: Text('Fire Driver'),
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
                            builder: (context) =>
                                AddDriverScreen(onDriverAdded: fetchDrivers)),
                      );
                    },
                    child: const Text(
                      'Add Driver',
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
