import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:verdasense/components/action_card.dart';
import 'package:verdasense/screens/analysis/blocs/analysis_bloc.dart';
import 'package:verdasense/screens/home/views/app_shell.dart';
import 'package:verdasense/screens/upload/blocs/upload_bloc.dart';
import 'package:verdasense/screens/upload/views/capture_screen.dart';
import 'package:verdasense/screens/upload/views/bounding_box_screen.dart';
import 'package:verdasense/screens/upload/views/reference_object.dart';
import 'package:wound_repository/wound_repository.dart';

// Main Upload screen with two actions (Capture or Upload) and a tips section.
class UploadMainScreen extends StatelessWidget {
  const UploadMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UploadBloc(woundRepository: context.read<WoundRepository>()),
      child: const _UploadMainView(),
    );
  }
}

class _UploadMainView extends StatelessWidget {
  const _UploadMainView();

  @override
  Widget build(BuildContext context) {

    final width = MediaQuery.of(context).size.width * 0.85;

    void navigateToAnalysis() {
      // Navigate to Analysis Tab after the segmentation is completed
      final appShell = AppShell.of(context);

      // Clear the entire navigation stack (Remove Box, Ref, Capture screens)
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      // Switch the tab
      if (appShell != null) {
        appShell.switchTab(2);
        // Optional: Trigger refresh here if needed
        context.read<AnalysisBloc>().add(const AnalysisRefreshRequested());
      }
    }
  
    // Allows vertical scrolling if the content exceeds screen height
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      
      // Organized vertically
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Section 1 & 2: Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,

            children: [
              Center(
                child: SizedBox(
                  width: width, // both cards same fixed width
                  child: ActionCard(
                    icon: Icons.camera_alt,
                    title: 'Capture New Image',
                    caption: "Use your device's camera to take a new photo of the wound.",
                    onTap: () async {
                      
                      // Notify UploadBloc that user selected "Camera"
                      context.read<UploadBloc>().add(const UploadSourceSelected(UploadSource.camera));
                      
                      // Navigate to CaptureScreen
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<UploadBloc>(),
                            child: CaptureScreen(onAnalysisRequested: navigateToAnalysis),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20), // space between two cards

              Center(
                child: SizedBox(
                  width: width, // both cards same fixed width
                  child: ActionCard(
                    icon: Icons.photo_library,
                    title: 'Upload From Gallery',
                    caption: "Select a wound image from your photo gallery for analysis.",
                    onTap: () async {
                      
                      // Notify UploadBloc that user selected "Gallery"
                      context.read<UploadBloc>().add((const UploadSourceSelected(UploadSource.gallery)));
                      
                      // Launch the image picker
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(source: ImageSource.gallery);
                      
                      if (picked == null) return; // if user cancels, just return
                      
                      if(!context.mounted) return; // ensure the widget is still mounted before using the context again

                      // Send the picked image file to the UploadBloc
                      context.read<UploadBloc>().add(UploadImageCaptured(File(picked.path)));
                      
                      if (!context.mounted) return;
                      // Navigate to BoundingBoxScreen
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<UploadBloc>(),
                            child: ReferenceObjectScreen(onAnalysisRequested: navigateToAnalysis),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),


            ],
          ),

          const SizedBox(height: 24),
          const Text('Tips: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
          const SizedBox(height: 8),
          _TipsCard(
            tips: const [
              'Ensure good lighting and avoid shadows.',
              'Keep the camera parallel to the wound surface.',
              'Avoid motion blur, hold steadily while capturing.',
            ],
          ),
        ],
      ),
    );
  }
}

// To show multiple short tips for good wound images
class _TipsCard extends StatelessWidget {
  final List<String> tips;
  const _TipsCard({required this.tips});

  @override
  Widget build(BuildContext context) {
    
    // Outer Card Styling
    return Container(
      width: double.infinity, // Stretch horizontally
      padding: const EdgeInsets.all(12), // Padding 12 pixels all around
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      
      // Arrange tips vertically
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tip in tips) // loop through each string in the tips list
            Padding(
              padding: const EdgeInsets.only(bottom: 6), // Add space below each tip
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '), // bullet point symbol
                  Expanded(child: Text(tip)), // The actual tip text
                ],
              ),
            ),
        ],
      ),
    );
  }
}


