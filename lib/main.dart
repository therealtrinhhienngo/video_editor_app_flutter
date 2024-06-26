import 'package:demo_project/screens/demo_pick_sound_screen.dart';
import 'package:demo_project/screens/video_picker_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class Routes {
  static String pickVideo = "/videoPicker";
  static String videoEditor = "/videoEditor";
  static String soundDemo = "/soundDemo";
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: Routes.pickVideo,
      routes: {
        Routes.pickVideo: (context) => const VideoPickerScreen(),
        Routes.soundDemo: (context) => const DemoMusicScreen()
      },
    );
  }
}
