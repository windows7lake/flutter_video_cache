import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Download Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Download Manager'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final DownloadManager _manager = DownloadManager(maxConcurrentDownloads: 2);
  final Map<String, double> _progress = {};
  final List<String> links = [
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/v6/main.mp4',
    'https://mirrors.edge.kernel.org/linuxmint/stable/20.3/linuxmint-20.3-xfce-64bit.iso',
    'https://filesamples.com/samples/video/mp4/sample_960x400_ocean_with_audio.mp4',
    'https://filesamples.com/samples/video/mp4/sample_1280x720_surfing_with_audio.mp4',
    'https://filesamples.com/samples/video/mp4/sample_3840x2160.mp4',
    'https://filesamples.com/samples/video/mp4/sample_2560x1440.mp4',
    'https://filesamples.com/samples/video/mp4/sample_1920x1080.mp4',
    'https://filesamples.com/samples/video/mp4/sample_1280x720.mp4',
    // 'https://download.blender.org/release/Blender3.4/blender-3.4.1-windows-x64.msi',
    // 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
  ];
  int index = 0;

  @override
  void initState() {
    super.initState();
    _initTasks();
    // _addTaskMore();
  }

  void _initTasks() async {
    _manager.stream.listen((task) {
      if (task.status == DownloadTaskStatus.COMPLETED) {
        _progress.remove(task.id);
      } else {
        _progress[task.id] = task.progress;
      }
      setState(() {});
    });
  }

  void _addTaskMore() async {
    for (var i = 0; i < 6; i++) {
      await _manager.addTask(DownloadTask(url: links[i], priority: i));
    }
    await _manager.processTask();
    setState(() {});
  }

  Future _addTask() async {
    await _manager.executeTask(DownloadTask(
      url: links[index],
      priority: index,
    ));
    if (++index >= links.length) {
      index = 0;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: _manager.allTasks.map((task) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Task ${task.id}',
                    style: const TextStyle(fontSize: 20),
                  ),
                  Text(
                    'Status: ${task.status.name}',
                    style: TextStyle(color: _getStatusColor(task.status)),
                  ),
                  Text(
                    'Priority: ${task.priority}',
                    style: TextStyle(color: Colors.blue),
                  ),
                  LinearProgressIndicator(value: task.progress),
                  Text(progressText(task)),
                  ElevatedButton(
                    onPressed: () {
                      switch (task.status) {
                        case DownloadTaskStatus.DOWNLOADING:
                          _manager.pauseTaskById(task.id);
                          break;
                        case DownloadTaskStatus.PAUSED:
                          _manager.resumeTaskById(task.id);
                          break;
                        default:
                          _manager.cancelTaskById(task.id);
                      }
                    },
                    child: Text(_getButtonText(task.status)),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String progressText(DownloadTask task) {
    return task.progress > 1
        ? '${(task.progress / 1000 / 1000).toStringAsFixed(2)}MB'
        : '${(task.progress * 100).toStringAsFixed(2)}%';
  }

  Color _getStatusColor(DownloadTaskStatus status) {
    switch (status) {
      case DownloadTaskStatus.DOWNLOADING:
        return Colors.blue;
      case DownloadTaskStatus.PAUSED:
        return Colors.orange;
      case DownloadTaskStatus.COMPLETED:
        return Colors.green;
      case DownloadTaskStatus.CANCELLED:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getButtonText(DownloadTaskStatus status) {
    switch (status) {
      case DownloadTaskStatus.DOWNLOADING:
        return 'Pause';
      case DownloadTaskStatus.PAUSED:
        return 'Resume';
      default:
        return 'Cancel';
    }
  }
}
