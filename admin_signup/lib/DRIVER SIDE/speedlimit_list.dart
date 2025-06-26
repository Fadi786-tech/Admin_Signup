import 'dart:convert';
import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:admin_signup/Screens/login.dart';
import 'package:admin_signup/speedlimitbound/add_speedlimit.dart';
import 'package:admin_signup/speedlimitbound/edit_speedlimit.dart';
import 'package:admin_signup/speedlimitbound/view_speedlimitarea.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Speedlimit extends StatefulWidget {
  final Adminid;

  Speedlimit({super.key, required this.Adminid});

  @override
  State<Speedlimit> createState() => _SpeedlimitState();
}

var speedboundid;

class _SpeedlimitState extends State<Speedlimit> {
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
    final response =
        await http.get(Uri.parse('$apiurl/speedbounds/${widget.Adminid}'));
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
        title: const Text('Speed Limit Areas'),
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
