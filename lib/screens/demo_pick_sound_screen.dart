import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';

class DemoMusicScreen extends StatefulWidget {
  const DemoMusicScreen({super.key});

  @override
  State<DemoMusicScreen> createState() => _DemoMusicScreenState();
}

class _DemoMusicScreenState extends State<DemoMusicScreen> {
  late FlutterSoundPlayer _audioPlayer;
  File? _selectedMusic;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _audioPlayer = FlutterSoundPlayer();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _audioPlayer.closePlayer();
  }

  void _addMusicToVideo() async {
    if (_selectedMusic == null) {
      // No music selected
      return;
    }

    // Add logic to merge audio and video here
    // Example: Use FFmpeg to merge audio and video
    // Execute FFmpeg command to merge audio and video
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: IconButton(
          padding: const EdgeInsets.all(5),
          onPressed: () {
            print("Click");
            _addMusicToVideo();
          },
          icon: const Icon(Icons.music_note),
          tooltip: 'Select Music',
        ),
      ),
    );
  }
}
