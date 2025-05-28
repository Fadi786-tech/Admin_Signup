import 'dart:convert';
import 'package:admin_signup/Screens/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Screens/MainDashboard.dart';
import 'edit_geofence.dart';
import 'view_geofence.dart';
import 'add_geofence.dart';

class GeofencesScreen extends StatefulWidget {
  @override
  _GeofencesScreenState createState() => _GeofencesScreenState();
}

class _GeofencesScreenState extends State<GeofencesScreen> {
  List<Map<String, dynamic>> geofences = [];
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    fetchGeofences();
  }

  Future<void> deleteGeofence(int geoid) async {
    try {
      final response = await http.put(
        Uri.parse(
            "$apiUrl/delete-geofences/$geoid"), // Use DELETE instead of PUT
      );

      if (response.statusCode == 200) {
        setState(() {
          geofences.removeWhere((g) => g["id"] == geoid); // Remove from UI
        });
        _showSuccess("Geofence deactivated successfully");
      } else {
        _showError("Failed to deactivate geofence");
      }
    } catch (e) {
      _showError("Error deactivating geofence: $e");
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> fetchGeofences() async {
    try {
      final response =
          await http.get(Uri.parse("$apiUrl/geofences/${adminid}"));
      print(adminid);
      SharedPreferences pref = await SharedPreferences.getInstance();

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          geofences = data
              .map((e) => {
                    "id": e["geoid"], // Store geofence ID
                    "name": e["name"],
                    "boundary_points":
                        e["boundary_points"], // Store boundary points
                  })
              .toList();
          for (int i = 0; i < data.length; i++) {
            print(data[i]);
          }
          // Store geofence IDs in SharedPreferences (optional)
          List<int> geoidList =
              data.map<int>((e) => e["geoid"] as int).toList();
          pref.setString('geoid_list', jsonEncode(geoidList));
        });
      } else {
        _showError("Failed to load geofences");
      }
    } catch (e) {
      _showError("Error fetching data: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredGeofences = geofences
        .where(
            (g) => g["name"].toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text("Geofences")),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.brown.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: "Search",
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.brown),
                ),
              ),
            ),
            SizedBox(height: 16),

            // Geofence List
            Expanded(
              child: geofences.isEmpty
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: filteredGeofences.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            // Navigate to ViewGeofenceScreen with selected geofence data
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ViewGeofenceScreen(
                                  geofence: filteredGeofences[index],
                                ),
                              ),
                            );
                          },
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading:
                                  Icon(LucideIcons.mapPin, color: Colors.brown),
                              title: Text(filteredGeofences[index]["name"]),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.edit),
                                onSelected: (value) async {
                                  if (value == 'Edit') {
                                    int geoid = geofences[index][
                                        "id"]; // Ensure geofence ID is retrieved
                                    Navigator.push(context,
                                        MaterialPageRoute(builder: (context) {
                                      return EditGeofenceScreen(
                                          geofence: geofences[index]);
                                    }));
                                  } else if (value == 'Delete') {
                                    int geoid = geofences[index][
                                        "id"]; // Ensure geofence ID is retrieved

                                    showDialog(
                                        context: context,
                                        builder: (BuildContext build) {
                                          return AlertDialog(
                                            title: Text("Confirm Deletion"),
                                            content: Text(
                                                "Are you sure you want to deactivate this geofence?"),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: Text("Cancel"),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  deleteGeofence(
                                                      geoid); // Pass the correct geofence ID
                                                },
                                                child: Text("Deactivate"),
                                              ),
                                            ],
                                          );
                                        });
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
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Add Geofence Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown.shade100,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // Add geofence functionality
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) {
                      return GeoFenceScreen();
                    }),
                  );
                },
                child: Text("Add GeoFence"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
