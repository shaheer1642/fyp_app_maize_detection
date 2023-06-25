import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

Future<void> main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();

  // Get a specific camera from the list of available cameras.
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: App(
        // Pass the appropriate camera to the TakePictureScreen widget.
        camera: firstCamera,
      ),
    ),
  );
}

// A screen that allows users to take a picture using a given camera.
class App extends StatefulWidget {
  const App({
    super.key,
    required this.camera,
  });

  final CameraDescription camera;

  @override
  AppState createState() => AppState();
}

class AppState extends State<App> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.medium,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  void _handleURLButtonPress(BuildContext context, var type) {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => ImageFromGalleryEx(type)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a picture')),
      // You must wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner until the
      // controller has finished initializing.
      body: Center(
        child: Column(
          children: [
            FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  // If the Future is complete, display the preview.
                  return CameraPreview(_controller);
                } else {
                  // Otherwise, display a loading indicator.
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
            MaterialButton(
              color: Colors.blue,
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
              color: Colors.blue,
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
      ),
      floatingActionButton: FloatingActionButton(
        // Provide an onPressed callback.
        onPressed: () async {
          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            // Ensure that the camera is initialized.
            await _initializeControllerFuture;

            // Attempt to take a picture and get the file `image`
            // where it was saved.
            final image = await _controller.takePicture();

            if (!mounted) return;

            // If the picture was taken, display it on a new screen.
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(
                  // Pass the automatically generated path to
                  // the DisplayPictureScreen widget.
                  imagePath: image.path,
                ),
              ),
            );
          } catch (e) {
            // If an error occurs, log the error to the console.
            print(e);
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}

// A widget that displays the picture taken by the user.

class DisplayPictureScreen extends StatefulWidget {
  const DisplayPictureScreen({Key? key, required this.imagePath}) : super(key: key);
  // Step 2 <-- SEE HERE
  final String imagePath;

  @override
  State<DisplayPictureScreen> createState() => _DisplayPictureScreen();
}

class _DisplayPictureScreen extends State<DisplayPictureScreen> {
  late Future<ApiRes> res;

  void initState() {
    super.initState();
    res = callApi();
  }

  Future<ApiRes> callApi() async {
    File imagefile = File(widget.imagePath); //convert Path to File
    Uint8List imagebytes = await imagefile.readAsBytes(); //convert to bytes
    String base64string = base64.encode(imagebytes); //convert bytes to base64 string
    final response = await http.post(
      Uri.parse('http://192.168.18.25:5000/predict'),
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
            title: const Text('Display the Picture')
        ),
        // The image is stored as a file on the device. Use the `Image.file`
        // constructor with the given path to display the image.
        body: Column(
          children: [
            Image.file(File(widget.imagePath)),
            FutureBuilder<ApiRes>(
              future: res,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(snapshot.data!.message);
                } else if (snapshot.hasError) {
                  return Text('${snapshot.error}');
                }

                // By default, show a loading spinner.
                return const CircularProgressIndicator();
              },
            ),
          ],
        )
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
