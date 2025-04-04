// 定义下载任务的状态枚举
import '../ext/log_ext.dart';

enum DownloadTaskStatus {
  IDLE,
  DOWNLOADING,
  RESUME,
  PAUSED,
  COMPLETED,
  CANCELLED
}

// 下载任务类
class DownloadTask {
  static int _autoId = 1;
  final String id;
  final String url;
  int priority;
  DownloadTaskStatus status = DownloadTaskStatus.IDLE;
  String saveFile;
  double progress = 0.0;
  int downloadedBytes = 0;
  int totalBytes = 0;
  int createAt = DateTime.now().millisecondsSinceEpoch;

  DownloadTask({
    required this.url,
    String? fileName,
    this.priority = 1,
  })  : id = _autoId.toString(),
        saveFile = fileName ?? url.split('/').last {
    _autoId++;
    if (!isValidUrl(url)) {
      throw ArgumentError('Invalid URL: $url');
    }
  }

  bool isValidUrl(String url) {
    try {
      Uri.parse(url);
      return true;
    } catch (e) {
      return false;
    }
  }

  void updateProgress() {
    if (status == DownloadTaskStatus.DOWNLOADING) {
      progress = totalBytes == 0
          ? downloadedBytes.toDouble()
          : (downloadedBytes / totalBytes);
      logIsolate(this.toString());
    }
  }

  @override
  String toString() {
    return 'Task ID: $id, URL: $url, Status: $status, Progress: ${progressText()}';
  }

  String progressText() {
    return totalBytes == 0
        ? '${(progress / 1000 / 1000).toStringAsFixed(2)}MB'
        : '${(progress * 100).toStringAsFixed(2)}%';
  }

  static void resetId() {
    _autoId = 1;
  }
}
