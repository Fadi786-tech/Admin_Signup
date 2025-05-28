import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'MainDashboard.dart';

class Adminprofile extends StatefulWidget {
  const Adminprofile({super.key});

  @override
  State<Adminprofile> createState() => _AdminprofileState();
}

final _formKey = GlobalKey<FormState>();
var name, email, password, aemail, companyname;

class _AdminprofileState extends State<Adminprofile> {
  File? _image;
  String? _profilePictureUrl;
  //var profilePicture;
  @override
  void initState() {
    super.initState();
    _fetchDetails();
    //fetchProfileImage();

    //setState(() {
    //});
  }

  String? imageUrl;
  Future<void> _fetchDetails() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      email = prefs.getString('Email');

      if (email == null) {
        //print("No email stored in SharedPreferences");
        return;
      }

      final response = await http.post(Uri.parse('$apiurl/get-details'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            name = data['data']['name'];
            aemail = data['data']['aemail'];
            password = data['data']['password'];
            imageUrl = data['data']['picture'];
            print(imageUrl);
            if (imageUrl != null && imageUrl!.isNotEmpty) {
              imageUrl = '$apiurl$imageUrl'; // Full server URL
            }
            print(imageUrl);
          });
          // SharedPreferences pref= await SharedPreferences.getInstance();// as SharedPreferences;
          // pref.setString('name', name);
          // print("Profile details fetched successfully");
        } else {
          print("Error: ${data['message']}");
        }
      } else {
        print("Error fetching details: ${response.body}");
      }
    } catch (e) {
      print("Exception while fetching details: $e");
    }
  }

  // Future<void> fetchProfileImage() async {
  //   try {
  //     final response = await http.get(Uri.parse("$apiurl/get-profile-picture/$email"));
  //
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       setState(() {
  //         imageUrl = data["imageUrl"];
  //         print("Image URL: $imageUrl");
  //       });
  //     } else {
  //       print("Failed to load image");
  //     }
  //   } catch (e) {
  //     print("Error fetching image: $e");
  //   }
  // }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });

      await _uploadImage(_image!);
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    String? email = pref.getString('Email');

    if (email == null) {
      print("No email found in SharedPreferences");
      return;
    }

    var uri = Uri.parse("$apiurl/upload-picture");
    var request = http.MultipartRequest('POST', uri);

    request.files.add(await http.MultipartFile.fromPath(
      'profilePicture',
      imageFile.path,
      contentType:
          MediaType.parse(lookupMimeType(imageFile.path) ?? 'image/jpeg'),
    ));

    request.fields['email'] = email;

    var response = await request.send();

    if (response.statusCode == 200) {
      var responseBody = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseBody);

      setState(() {
        _profilePictureUrl = jsonResponse['filePath']; // Update UI
      });

      print("Image uploaded successfully");
      Navigator.push(context, MaterialPageRoute(builder: (context) {
        return Maindashboard();
      }));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image uploaded successfully')),
      );
    } else {
      print("Failed to upload image");
    }
  }

  void _showDialog(BuildContext context) async {
    final TextEditingController text1Controller = TextEditingController();
    //SharedPreferences pref=await SharedPreferences.getInstance(); // as SharedPreferences;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Name"),
          content: TextField(
            controller: text1Controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: name,
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () {
                var input = text1Controller.text;
                changeName(input, email); // Call the API
                print("User Input: $input");
                print("email: $email");
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text(
                "Save",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDialogForcompanyName(BuildContext context) async {
    final TextEditingController text1Controller = TextEditingController();
    //SharedPreferences pref=await SharedPreferences.getInstance(); // as SharedPreferences;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Enter Company Name"),
          content: TextField(
            controller: text1Controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter Company Name',
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () {
                var input = text1Controller.text;
                AddCompanyName(input, email); // Call the API
                print("User Input: $input");
                print("email: $email");
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text(
                "Save",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text("Profile"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              // Display Profile Picture or Default Icon
              CircleAvatar(
                radius: 80,
                backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
                    ? NetworkImage(imageUrl!) // Load image from server
                    : null, // No image available
                child: imageUrl == null || imageUrl!.isEmpty
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
              const SizedBox(height: 20),
              // Edit Profile Picture Button
              ElevatedButton.icon(
                onPressed: () {
                  _pickImage();
                },
                icon: Icon(Icons.edit),
                label: Text("Edit Profile Picture"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                ),
              ),

              SizedBox(height: 20),
              buildTextField(name ?? "Loading...", false),
              buildTextField(aemail ?? "Loading...", false),
              TextFields(
                label: password,
                isPassword: true,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Handle edit action
                  _showDialog(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text("Edit"),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Handle edit action
                  _showDialogForcompanyName(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text("Enter Company Name"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> AddCompanyName(var email, var name) async {
    try {
      final response = await http.post(Uri.parse('$apiurl/Add-company-name'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'Name': name}));
      if (response.statusCode == 200) {
        print("Company name added successfully");
        companyname = email;
      } else {
        print("Error fetching details: ${response.body}");
      }
      // setState(() {
      //   _fetchDetails();
      // });
    } catch (e) {
      print("Exception while fetching details: $e");
    }
  }

  Future<void> changeName(var email, var name) async {
    try {
      final response = await http.put(Uri.parse('$apiurl/change-name'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'newName': name}));
      if (response.statusCode == 200) {
        print("Admin name updated successfully");
      } else {
        print("Error fetching details: ${response.body}");
      }
      setState(() {
        _fetchDetails();
      });
    } catch (e) {
      print("Exception while fetching details: $e");
    }
  }
}

Widget buildTextField(String? label, bool isPassword) {
  bool _obscureText = true;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: TextField(
      readOnly: true,
      obscureText: isPassword,
      decoration: InputDecoration(
        hintText:
            label ?? "Loading...", // Provide a default value if label is null
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  // No setState here since this is a stateless function
                },
              )
            : null,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

class TextFields extends StatefulWidget {
  final String? label; // Allow null values
  final bool isPassword;

  const TextFields({
    Key? key,
    required this.label,
    required this.isPassword,
  }) : super(key: key);

  @override
  _TextFieldsState createState() => _TextFieldsState();
}

class _TextFieldsState extends State<TextFields> {
  bool _obscureText = true; // State to manage password visibility

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        readOnly: true,
        obscureText:
            widget.isPassword ? _obscureText : false, // Toggle visibility
        decoration: InputDecoration(
          hintText: widget.isPassword && _obscureText
              ? '********' // Show asterisks for password
              : widget.label ??
                  "Loading...", // Provide a default value if label is null
          border: const OutlineInputBorder(),
          suffix: IconButton(
              onPressed: () {
                //_showPasswordDialog(context);
                _showDialogpass(context);
              },
              icon: const Icon(Icons.edit)),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText; // Toggle the state
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }
}

final TextEditingController newPassword = TextEditingController();
final TextEditingController confirmPassword = TextEditingController();
final TextEditingController currentPassword = TextEditingController();
void _showDialogpass(BuildContext context) async {
  //SharedPreferences pref=await SharedPreferences.getInstance(); // as SharedPreferences;
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Change Password"),
        content: Container(
          height: MediaQuery.sizeOf(context).height * 0.3,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                spacing: 10,
                children: [
                  TextFormField(
                    controller: currentPassword,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Enter Current Password',
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please enter the password';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: newPassword,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Enter New Password',
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please enter the password';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: confirmPassword,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Confirm Password',
                    ),
                    validator: (val) {
                      if (val != newPassword.text) {
                        return 'Both fields do not matched';
                      }
                      if (val == null || val.isEmpty) {
                        return 'Please enter the password';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _changePassword(context);
                currentPassword.text = '';
                newPassword.text = '';
                confirmPassword.text = '';
              }
            },
            child: Text(
              "Save",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _changePassword(BuildContext context) async {
  String url = '$apiurl/change-password';
  String cp = currentPassword.text;
  String np = newPassword.text;
  try {
    final response = await http.put(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {'email': email, 'currentPassword': cp, 'newPassword': np}),
    );

    print('Response: ${response.body}'); // Debug log

    if (response.statusCode == 200) {
      currentPassword.text = '';
      newPassword.text = '';
      confirmPassword.text = '';
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password is incorrect.')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('An error occurred: $e')),
    );
  }
}
