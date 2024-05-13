import 'dart:io';

import 'package:demo_project/class_support/export_service.dart';
import 'package:demo_project/components/crop_page.dart';
import 'package:demo_project/components/export_result.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_editor/video_editor.dart';

class VideoEditor extends StatefulWidget {
  final File handleFile;
  const VideoEditor({super.key, required this.handleFile});

  @override
  State<VideoEditor> createState() => _VideoEditorState();
}

class _VideoEditorState extends State<VideoEditor> {
  final _exportingProgress = ValueNotifier<double>(0.0);
  final _isExporting = ValueNotifier<bool>(false);
  final double height = 60;

  // Get video picking file
  Future<void> getVideoFile() async {}

  Future<String> _getVideoPathFromSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('videoPath') ?? '';
  }

  // Handle file
  File? file;

  // Sound picker value
  File? _selectedMusic;
  File? pickedMusicFile;

  @override
  void initState() {
    super.initState();

    setState(() {
      file = widget.handleFile;
    });

    _controller
        .initialize(aspectRatio: 9 / 16)
        .then((_) => setState(() {}))
        .catchError((error) {
      // handle minumum duration bigger than video duration error
      Navigator.pop(context);
    }, test: (e) => e is VideoMinDurationError);
  }

  @override
  void dispose() async {
    _exportingProgress.dispose();
    _isExporting.dispose();
    _controller.dispose();
    ExportService.dispose();
    super.dispose();
  }

  // Select music function
  void _selectMusic() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      setState(() {
        _selectedMusic = File(result.files.single.path!);
      });
      _mergeAudioAndVideo();
    }
  }

  Future<void> _saveMusicToSharedPreferences(String imagePath) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('musicPath', imagePath);
  }

  Future<String> _getMusicPathFromSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('musicPath') ?? '';
  }

  Future<void> getMusicFile() async {
    String musicPath = await _getMusicPathFromSharedPreferences();
    File newMusicFile = File(musicPath);

    setState(() {
      pickedMusicFile = newMusicFile;
    });
  }

  // Merging music and video function
  void _mergeAudioAndVideo() async {
    if (_selectedMusic == null) {
      // No music selected
      return;
    }

    // Save music to local storage
    await _saveMusicToSharedPreferences(_selectedMusic!.path);

    await getMusicFile();

    // Output file path (merged video with audio)
    String outputFilePath = File('storage/emulated/0/my_folder/o.mp4').path;

    // FFmpeg command to merge audio and video
    final String command =
        '-i ${pickedMusicFile!.path} -i ${file!.path} -c:v copy -c:a aac -strict experimental -shortest $outputFilePath';

    print("Check path: $pickedMusicFile");
    print("Demo Output path: $outputFilePath");

    // Execute FFmpeg command
    await FFmpegKit.executeAsync(command, (session) async {
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        // Merge successful
        print("Merge successfully");

        // Handle the merging file with music
        setState(() {
          file = File(outputFilePath);
          print("Handle complete");
        });
      } else if (ReturnCode.isCancel(returnCode)) {
        // Merge cancel
        print("Merge cancel");

        // Show error message or perform error handling
      } else {
        // Merge failed
        print("Merge failed");

        // Show error message or perform error handling
      }
    });
  }

  // Video editor controller => use to get the video file path, video thumbnail, video info, etc.
  late final VideoEditorController _controller = VideoEditorController.file(
    file ?? File(""),
    minDuration: const Duration(seconds: 1),
    maxDuration: const Duration(seconds: 10),
  );

  // Error snackbar
  void _showErrorSnackBar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 1),
        ),
      );

  // Exporting video function
  void _exportVideo() async {
    _exportingProgress.value = 0;
    _isExporting.value = true;

    final config = VideoFFmpegVideoEditorConfig(
      _controller,
      // format: VideoExportFormat.gif,
      // commandBuilder: (config, videoPath, outputPath) {
      //   final List<String> filters = config.getExportFilters();
      //   filters.add('hflip'); // add horizontal flip

      //   return '-i $videoPath ${config.filtersCmd(filters)} -preset ultrafast $outputPath';
      // },
    );

    await ExportService.runFFmpegCommand(
      await config.getExecuteConfig(),
      onProgress: (stats) {
        _exportingProgress.value =
            config.getFFmpegProgress(stats.getTime().toInt());
      },
      onError: (e, s) => _showErrorSnackBar("Error on export video :("),
      onCompleted: (file) {
        _isExporting.value = false;
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (_) => VideoResultPopup(video: file),
        );
      },
    );
  }

  // Exporting cover function
  void _exportCover() async {
    final config = CoverFFmpegVideoEditorConfig(_controller);
    final execute = await config.getExecuteConfig();
    if (execute == null) {
      _showErrorSnackBar("Error on cover exportation initialization.");
      return;
    }

    await ExportService.runFFmpegCommand(
      execute,
      onError: (e, s) => _showErrorSnackBar("Error on cover exportation :("),
      onCompleted: (cover) {
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (_) => CoverResultPopup(cover: cover),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _controller.initialized
            ? SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // Top Nav Bar
                        _topNavBar(),

                        // Main View
                        Expanded(
                          child: DefaultTabController(
                            length: 2,
                            child: Column(
                              children: [
                                Expanded(
                                  child: TabBarView(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          CropGridViewer.preview(
                                              controller: _controller),
                                          AnimatedBuilder(
                                            animation: _controller.video,
                                            builder: (_, __) => AnimatedOpacity(
                                              opacity:
                                                  _controller.isPlaying ? 0 : 1,
                                              duration: kThemeAnimationDuration,
                                              child: GestureDetector(
                                                onTap: _controller.video.play,
                                                child: Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.play_arrow,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      CoverViewer(controller: _controller)
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 200,
                                  margin: const EdgeInsets.only(top: 10),
                                  child: Column(
                                    children: [
                                      const TabBar(
                                        labelColor: Colors.white,
                                        dividerColor: Colors.white,
                                        indicatorColor: Colors.white,
                                        tabs: [
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Padding(
                                                    padding: EdgeInsets.all(5),
                                                    child: Icon(
                                                        Icons.content_cut)),
                                                Text('Trim')
                                              ]),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Padding(
                                                  padding: EdgeInsets.all(5),
                                                  child:
                                                      Icon(Icons.video_label)),
                                              Text('Cover')
                                            ],
                                          ),
                                        ],
                                      ),
                                      Expanded(
                                        child: TabBarView(
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          children: [
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: _trimSlider(),
                                            ),
                                            _coverSelection(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ValueListenableBuilder(
                                  valueListenable: _isExporting,
                                  builder: (_, bool export, Widget? child) =>
                                      AnimatedSize(
                                    duration: kThemeAnimationDuration,
                                    child: export ? child : null,
                                  ),
                                  child: AlertDialog(
                                    title: ValueListenableBuilder(
                                      valueListenable: _exportingProgress,
                                      builder: (_, double value, __) => Text(
                                        "Exporting video ${(value * 100).ceil()}%",
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  // Top navigation widget
  Widget _topNavBar() {
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            // Exit App Button
            Expanded(
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.exit_to_app,
                  color: Colors.white,
                ),
                tooltip: 'Leave editor',
              ),
            ),

            // Divider
            const VerticalDivider(
              endIndent: 22,
              indent: 22,
              color: Colors.white,
            ),

            // Rotate video to left
            Expanded(
              child: IconButton(
                onPressed: () =>
                    _controller.rotate90Degrees(RotateDirection.left),
                icon: const Icon(
                  Icons.rotate_left,
                  color: Colors.white,
                ),
                tooltip: 'Rotate unclockwise',
              ),
            ),

            // Rotate video to right
            Expanded(
              child: IconButton(
                onPressed: () =>
                    _controller.rotate90Degrees(RotateDirection.right),
                icon: const Icon(
                  Icons.rotate_right,
                  color: Colors.white,
                ),
                tooltip: 'Rotate clockwise',
              ),
            ),

            // Audio selection
            Expanded(
              child: _audioSection(),
            ),

            // Crop video button
            Expanded(
              child: IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => CropPage(controller: _controller),
                  ),
                ),
                icon: const Icon(
                  Icons.crop,
                  color: Colors.white,
                ),
                tooltip: 'Open crop screen',
              ),
            ),

            // Divider
            const VerticalDivider(
              endIndent: 22,
              indent: 22,
              color: Colors.white,
            ),

            // Save button => save video & save cover
            Expanded(
              child: PopupMenuButton(
                tooltip: 'Open export menu',
                icon: const Icon(
                  Icons.save,
                  color: Colors.white,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    onTap: _exportCover,
                    child: const Text('Export cover'),
                  ),
                  PopupMenuItem(
                    onTap: _exportVideo,
                    child: const Text('Export video'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Formatter for duration
  String formatter(Duration duration) => [
        duration.inMinutes.remainder(60).toString().padLeft(2, '0'),
        duration.inSeconds.remainder(60).toString().padLeft(2, '0')
      ].join(":");

  // Trim slider widget
  List<Widget> _trimSlider() {
    return [
      AnimatedBuilder(
        animation: Listenable.merge([
          _controller,
          _controller.video,
        ]),
        builder: (_, __) {
          final int duration = _controller.videoDuration.inSeconds;
          final double pos = _controller.trimPosition * duration;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: height / 4),
            child: Row(children: [
              Text(formatter(Duration(seconds: pos.toInt()))),
              const Expanded(child: SizedBox()),
              AnimatedOpacity(
                opacity: _controller.isTrimming ? 1 : 0,
                duration: kThemeAnimationDuration,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(formatter(_controller.startTrim)),
                  const SizedBox(width: 10),
                  Text(formatter(_controller.endTrim)),
                ]),
              ),
            ]),
          );
        },
      ),
      Container(
        width: MediaQuery.of(context).size.width,
        margin: EdgeInsets.symmetric(vertical: height / 4),
        child: TrimSlider(
          controller: _controller,
          height: height,
          horizontalMargin: height / 4,
          child: TrimTimeline(
            controller: _controller,
            padding: const EdgeInsets.only(top: 10),
          ),
        ),
      )
    ];
  }

  // Sound picker widget
  Widget _audioSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _selectedMusic != null
                  ? _selectedMusic!.path.split('/').last
                  : 'No music selected',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: _selectMusic,
            icon: const Icon(
              Icons.music_note,
              color: Colors.white,
            ),
            tooltip: 'Select Music',
          ),
        ],
      ),
    );
  }

  // Cover selection widget
  Widget _coverSelection() {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(15),
          child: CoverSelection(
            controller: _controller,
            size: height + 10,
            quantity: 8,
            selectedCoverBuilder: (cover, size) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  cover,
                  Icon(
                    Icons.check_circle,
                    color: const CoverSelectionStyle().selectedBorderColor,
                  )
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
