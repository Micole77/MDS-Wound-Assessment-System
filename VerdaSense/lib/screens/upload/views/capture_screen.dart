import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdasense/components/main_bottom_nav.dart';
import 'package:verdasense/components/my_app_bar.dart';
import 'package:verdasense/screens/upload/blocs/upload_bloc.dart';
import 'package:verdasense/screens/upload/views/bounding_box_screen.dart';
import 'package:verdasense/screens/upload/views/reference_object.dart';

/// Screen to capture a wound image using the in-app camera with a reference overlay.
class CaptureScreen extends StatefulWidget {
  final VoidCallback onAnalysisRequested;

  const CaptureScreen({super.key, required this.onAnalysisRequested});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  // ReferenceType _referenceType = ReferenceType.coin;

  // Camera initialization
  @override
  void initState() {
    super.initState();
    _initFuture = _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras(); // Fetches available cameras
    final camera = cameras.first; // Select the first one (typically back camera)
    final controller = CameraController(camera, ResolutionPreset.high, enableAudio: false);
    _controller = controller;
    await controller.initialize();
    if (mounted) setState(() {});
  }

  // Always dispose camera resources to prevent memory leaks
  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppBar(title: 'Camera'),
      body: SafeArea(
        child: Column(
          children: [
            // Camera preview
            Expanded(
              // Waits for camera initialization
              child: FutureBuilder(
                future: _initFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done || _controller == null || !_controller!.value.isInitialized) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_controller!), // real-time camera view
                    ],
                  );
                },
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ShutterButton(onPressed: () async {
                    if (_controller == null || !_controller!.value.isInitialized) return;
                    try {
                      final file = await _controller!.takePicture(); // returns an image file
                      final imageFile = File(file.path);
                      if (!mounted) return;
                      context.read<UploadBloc>().add(UploadImageCaptured(imageFile));
                      if (!mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<UploadBloc>(),
                            child: ReferenceObjectScreen(
                              onAnalysisRequested: widget.onAnalysisRequested,
                            ),
                          ),
                        ),
                      );
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to capture image')),
                      );
                    }
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ShutterButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.camera_alt_outlined, 
          color: Colors.white, 
          size:24
        ),
      ),
    );
  }
}


