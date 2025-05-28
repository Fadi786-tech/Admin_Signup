import 'dart:convert';
import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:admin_signup/Screens/login.dart';
import 'package:admin_signup/speedlimitbound/add_speedlimit.dart';
import 'package:admin_signup/speedlimitbound/edit_speedlimit.dart';
import 'package:admin_signup/speedlimitbound/view_speedlimitarea.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BoundSpeedlimit extends StatefulWidget {
  const BoundSpeedlimit({super.key});

  @override
  State<BoundSpeedlimit> createState() => _BoundSpeedlimitState();
}

var speedboundid;

class _BoundSpeedlimitState extends State<BoundSpeedlimit> {
  List speedboundlist = [];
  List filteredspeedboundlist = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchSpeedlimitareas();
    searchController.addListener(() {
      filterSpeedlimitareas();
    });
  }

  Future<void> fetchSpeedlimitareas() async {
    final response = await http.get(Uri.parse('$apiurl/speedbounds/$adminid'));
    if (response.statusCode == 200) {
      setState(() {
        speedboundlist = json.decode(response.body);
        filteredspeedboundlist = speedboundlist;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load speed bounds')),
      );
    }
  }

  void filterSpeedlimitareas() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredspeedboundlist = speedboundlist.where((speedbound) {
        return speedbound['areaname'].toLowerCase().contains(query) ||
            speedbound['speedlimit'].toString().toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _deactivatearea(
      BuildContext context, var speedboundid, var areaname) async {
    final url = Uri.parse('$apiurl/delete-speedbounds/$speedboundid');
    final response = await http.put(url);

    //Navigator.of(context).pop();
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return Maindashboard();
    }));
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to deactivate Speedbound area.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$areaname has been deactivated.")),
      );
    }
    setState(() {});
  }

  void _showDeactivateDialog(
      BuildContext context, var speedboundid, var areaname) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Do You Want to Deactivate this area?"),
          content: Text(areaname),
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
                _deactivatearea(context, speedboundid, areaname);
                Navigator.of(context).pop();
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

  Future<void> _fetchSpeedZoneAndNavigateToEdit(int speedboundid) async {
    try {
      setState(() {
        isLoading = true;
      });

      // Make API call to get detailed speed zone data
      final response = await http.get(
        Uri.parse('$apiurl/speedzone/$speedboundid'),
      );

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract needed data
        int id = data['speedboundid'] is int
            ? data['speedboundid']
            : int.parse(data['speedboundid'].toString());

        String areaname = data['areaname'] ?? '';

        // Handle speedlimit parsing
        double speedlimit = 0.0;
        var rawSpeedlimit = data['speedlimit'];
        if (rawSpeedlimit != null) {
          if (rawSpeedlimit is double) {
            speedlimit = rawSpeedlimit;
          } else if (rawSpeedlimit is int) {
            speedlimit = rawSpeedlimit.toDouble();
          } else {
            speedlimit = double.tryParse(rawSpeedlimit.toString()) ?? 0.0;
          }
        }

        // Get polygon data
        var boundarypoints = data['boundarypoints'];
        Map<String, dynamic> polygon;

        if (boundarypoints is String) {
          polygon = json.decode(boundarypoints);
        } else if (boundarypoints is Map) {
          polygon = Map<String, dynamic>.from(boundarypoints);
        } else {
          throw Exception('Invalid boundary points format');
        }

        // Log extracted data
        print('Navigating to EditSpeedlimit with:');
        print('ID: $id');
        print('Area name: $areaname');
        print('Speed limit: $speedlimit');
        print('Polygon: $polygon');

        // Navigate to edit screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditSpeedlimit(
              speedboundid: id,
              areaname: areaname,
              speedlimit: speedlimit,
              polygon: polygon,
            ),
          ),
        );
      } else {
        throw Exception('Failed to load speed zone data');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching speed zone data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading speed zone data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bound Speed Limit'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Search by id or area name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filteredspeedboundlist.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          speedboundid =
                              filteredspeedboundlist[index]['speedboundid'];
                          Navigator.push(context,
                              MaterialPageRoute(builder: (builder) {
                            return ViewSpeedlimitarea(
                                speedboundid: speedboundid);
                          }));
                        },
                        child: ListTile(
                          title:
                              Text(filteredspeedboundlist[index]['areaname']),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.edit),
                            onSelected: (value) async {
                              if (value == 'Edit') {
                                // Extract the speedboundid
                                var rawSpeedboundid =
                                    filteredspeedboundlist[index]
                                        ['speedboundid'];
                                int speedboundid = rawSpeedboundid is int
                                    ? rawSpeedboundid
                                    : int.parse(rawSpeedboundid.toString());
                                // Use the dedicated method to fetch details and navigate
                                await _fetchSpeedZoneAndNavigateToEdit(
                                    speedboundid);
                              } else if (value == 'Delete') {
                                // speedboundid = int.parse(
                                //     filteredspeedboundlist[index]
                                //         ['speedboundid']);
                                String areaname =
                                    filteredspeedboundlist[index]['areaname'];
                                // Handle delete functionality
                                _showDeactivateDialog(
                                    context, speedboundid, areaname);
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
                            builder: (context) => AddSpeedLimitArea()),
                      );
                    },
                    child: const Text(
                      'Add Speedlimit Area',
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
