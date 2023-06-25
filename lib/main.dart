import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

void main() {
  runApp(App());
}

class App extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maize Seed Detection',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: HomePage(),
    );
  }
}

enum ImageSourceType { gallery, camera }

class HomePage extends StatelessWidget {
  void _handleURLButtonPress(BuildContext context, var type) {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => ImageFromGalleryEx(type)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Maize Seed Detection"),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              MaterialButton(
                color: Colors.green,
                child: Text(
                  "Pick Image from Gallery",
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  _handleURLButtonPress(context, ImageSourceType.gallery);
                },
              ),
              MaterialButton(
                color: Colors.green,
                child: Text(
                  "Pick Image from Camera",
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  _handleURLButtonPress(context, ImageSourceType.camera);
                },
              ),
            ],
          ),
        ));
  }
}

class ImageFromGalleryEx extends StatefulWidget {
  final type;
  ImageFromGalleryEx(this.type);

  @override
  ImageFromGalleryExState createState() => ImageFromGalleryExState(this.type);
}

class ImageFromGalleryExState extends State<ImageFromGalleryEx> {
  var _image;
  var imagePath;
  var imagePicker;
  var type;
  late Future<ApiRes> res;

  ImageFromGalleryExState(this.type);

  @override
  void initState() {
    super.initState();
    imagePicker = new ImagePicker();
  }

  Future<ApiRes> callApi() async {
    File imagefile = File(imagePath); //convert Path to File
    Uint8List imagebytes = await imagefile.readAsBytes(); //convert to bytes
    String base64string = base64.encode(imagebytes); //convert bytes to base64 string
    final response = await http.post(
      Uri.parse('https://maize-detection-api.up.railway.app/predict'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'image': base64string,
      }),
    );

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      return ApiRes.fromJson(jsonDecode(response.body));
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      throw Exception('Failed to call api');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(type == ImageSourceType.camera
              ? "Image from Camera"
              : "Image from Gallery")),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 52,
          ),
          Center(
            child: GestureDetector(
              onTap: () async {
                var source = type == ImageSourceType.camera
                    ? ImageSource.camera
                    : ImageSource.gallery;
                XFile image = await imagePicker.pickImage(
                    source: source, imageQuality: 50, preferredCameraDevice: CameraDevice.front);
                setState(() {
                  _image = File(image.path);
                  imagePath = image.path;
                  res = callApi();
                });
              },
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.green[200]),
                width: _image != null ? null : 200,
                height: _image != null ? null : 200,
                child: _image != null
                    ? Column(
                  children: [
                    Image.file(
                      _image,
                      fit: BoxFit.fitHeight,
                    ),
                    FutureBuilder<ApiRes>(
                      future: res,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Text(
                              snapshot.data!.message,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
                          );
                        } else if (snapshot.hasError) {
                          return Text('${snapshot.error}');
                        }

                        // By default, show a loading spinner.
                        return const CircularProgressIndicator();
                      },
                    ),
                  ],
                )

                    : Container(
                  decoration: BoxDecoration(
                      color: Colors.green[200]),
                  width: _image != null ? null : 200,
                  height: _image != null ? null : 200,
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class ApiRes {
  final int code;
  final String message;

  const ApiRes({
    required this.code,
    required this.message,
  });

  factory ApiRes.fromJson(Map<String, dynamic> json) {
    return ApiRes(
      code: json['code'],
      message: json['message'],
    );
  }
}
