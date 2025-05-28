import 'package:admin_signup/Screens/MainDashboard.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationHistoryScreen extends StatefulWidget {
  final int drivervehicleid;

  const LocationHistoryScreen({Key? key, required this.drivervehicleid})
      : super(key: key);

  @override
  _LocationHistoryScreenState createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  List<dynamic> locationHistory = [];

  @override
  void initState() {
    super.initState();
    fetchLocationHistory();
  }

  Future<void> fetchLocationHistory() async {
    final url = Uri.parse(
        '${vehicledriverurl}/location-history/${widget.drivervehicleid}');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      setState(() {
        locationHistory = json.decode(response.body);
      });
    } else {
      print("Error fetching location history");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Location History")),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: locationHistory.isEmpty
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text("Source Area")),
                    DataColumn(label: Text("Destination Area")),
                    DataColumn(label: Text("Date")),
                    DataColumn(label: Text("Time")),
                  ],
                  rows: locationHistory.map((item) {
                    return DataRow(cells: [
                      DataCell(Text(item['source_area'])),
                      DataCell(Text(item['destination_area'])),
                      DataCell(Text(item['date'])),
                      DataCell(Text(item['time'])),
                    ]);
                  }).toList(),
                ),
              ),
      ),
    );
  }
}
