import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_video_cache/ext/int_ext.dart';

import '../download/download_manager.dart';
import '../download/download_task.dart';
import '../ext/log_ext.dart';
import '../ext/socket_ext.dart';
import '../ext/string_ext.dart';
import '../global/config.dart';
import '../memory/video_memory_cache.dart';
import '../sqlite/table_video.dart';

/// 本地代理服务器
class LocalProxyServer {
  /// 本地代理服务器
  LocalProxyServer({this.ip, this.port}) {
    Config.ip = ip ?? Config.ip;
    Config.port = port ?? Config.port;
  }

  /// 代理服务器IP
  final String? ip;

  /// 代理服务器端口
  final int? port;

  /// 代理服务
  ServerSocket? server;

  /// 下载管理器
  DownloadManager downloadManager = DownloadManager(maxConcurrentDownloads: 4);

  /// 启动代理服务器
  Future<void> start() async {
    try {
      final InternetAddress internetAddress = InternetAddress(Config.ip);
      server = await ServerSocket.bind(internetAddress, Config.port);
      logD('Proxy server started ${server?.address.address}:${server?.port}');
      server?.listen(_handleConnection);
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 98) {
        Config.port = Config.port + 1;
        start();
      }
    }
  }

  /// 关闭代理服务器
  Future<void> close() async {
    await server?.close();
  }

  /// 处理连接
  Future<void> _handleConnection(Socket socket) async {
    try {
      logV('_handleConnection start');
      final StringBuffer buffer = StringBuffer();
      await for (final Uint8List data in socket) {
        buffer.write(String.fromCharCodes(data));
        // 检测头部结束标记（空行 \r\n\r\n）
        if (buffer.toString().contains(httpTerminal)) {
          final String rawHeaders = buffer.toString().split(httpTerminal).first;
          final Map<String, String> headers = _parseHeaders(rawHeaders, socket);
          logD("传入请求头： $headers");
          if (headers.isEmpty) {
            await send400(socket);
            return;
          }
          final String rangeHeader = headers['Range'] ?? '';
          final String url = headers['redirect'] ?? '';
          final Uri originUri = url.toOriginUri();
          logD('传入链接 Origin url：$originUri');
          final Uint8List? data =
              await parseData(socket, originUri, rangeHeader);
          if (data == null) {
            // await send404(socket);
            break;
          }
          if (originUri.path.endsWith('m3u8')) {
            await _sendM3u8(socket, data);
          } else {
            await _sendContent(socket, data);
          }
          break;
        }
      }
    } catch (e) {
      // await send500(socket);
      logE('⚠ ⚠ ⚠ 传输异常: $e');
    } finally {
      await socket.close(); // 确保连接关闭
      logD('连接关闭\n');
    }
  }

  /// 解析请求头
  Map<String, String> _parseHeaders(String rawHeaders, Socket socket) {
    final List<String> lines = rawHeaders.split('\r\n');
    if (lines.isEmpty) {
      return <String, String>{};
    }

    // 解析请求行（兼容非标准请求）
    final List<String> requestLine = lines.first.split(' ');
    final String method = requestLine[0];
    final String path = requestLine.length > 1 ? requestLine[1] : '/';
    final String protocol =
        requestLine.length > 2 ? requestLine[2] : 'HTTP/1.1';
    logD('protocol: $protocol, method: $method, path: $path');

    // 提取关键头部（如 Range、User-Agent）
    final Map<String, String> headers = <String, String>{};
    for (final String line in lines.skip(1)) {
      final int index = line.indexOf(':');
      if (index > 0) {
        final String key = line.substring(0, index).trim().toLowerCase();
        final String value = line.substring(index + 1).trim();
        headers[key] = value;
      }
    }

    final String redirectUrl = path.replaceAll('/?url=', '');
    headers['redirect'] = redirectUrl;

    return headers;
  }

  /// 解析并返回对应的文件
  Future<Uint8List?> parseData(Socket socket, Uri uri, String range) async {
    final md5 = uri.toString().generateMd5;
    Uint8List? memoryData = await VideoMemoryCache.get(md5);
    if (memoryData != null) {
      logD('从内存中获取数据: ${memoryData.lengthInBytes.toMemorySize}');
      logD('当前内存占用: ${(await VideoMemoryCache.size()).toMemorySize}');
      return memoryData;
    }
    InstanceVideo? video = await TableVideo.queryByUrl(uri.toString());
    File file;
    if (video != null && File(video.file).existsSync()) {
      logD('从数据库中获取数据');
      file = File(video.file);
    } else {
      if (video != null) {
        TableVideo.deleteByUrl(video.url);
      }
      final String fileName = uri.pathSegments.last;
      final String url = uri.toString();
      if (downloadManager.isUrlExit(url)) {
        logD('从网络中获取数据，正在下载中');
        if (downloadManager.isUrlDownloading(url)) {
          while (memoryData == null) {
            await Future.delayed(const Duration(milliseconds: 200));
            memoryData = await VideoMemoryCache.get(md5);
          }
          return memoryData;
        } else {
          return null;
        }
      } else {
        logD('从网络中获取数据');
        final DownloadTask task = await downloadManager
            .executeTask(DownloadTask(url: url, fileName: fileName));
        file = File(task.saveFile);
        while (!file.existsSync()) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    }
    if (uri.path.endsWith('m3u8')) {
      final List<String> lines = await file.readAsLines();
      final StringBuffer buffer = StringBuffer();
      String lastLine = '';
      for (final String line in lines) {
        String changeUrl = '';
        if (lastLine.startsWith("#EXTINF") ||
            lastLine.startsWith("#EXT-X-STREAM-INF")) {
          changeUrl = '?redirect=${uri.origin}';
        }
        buffer.write('$line$changeUrl\r\n');
        lastLine = line;
      }
      final Uint8List data = Uint8List.fromList(buffer.toString().codeUnits);
      TableVideo.insert(
        "",
        uri.toString(),
        file.path,
        'application/vnd.apple.mpegurl',
        file.lengthSync(),
      );
      await VideoMemoryCache.put(md5, data);
      return data;
    } else {
      final int fileSize = await file.length();
      int start = 0, end = fileSize - 1;

      if (range.isNotEmpty) {
        final List<String> parts = range.split('-');
        start = int.parse(parts[0]);
        end = parts[1].isNotEmpty ? int.parse(parts[1]) : fileSize - 1;
      }

      if (start >= fileSize || end >= fileSize) {
        await send416(socket, fileSize);
        return null;
      }

      final RandomAccessFile raf = await file.open();
      await raf.setPosition(start);
      final Uint8List data = await raf.read(end - start + 1);
      TableVideo.insert(
        "",
        uri.toString(),
        file.path,
        'video/*',
        file.lengthSync(),
      );
      await VideoMemoryCache.put(md5, data);
      return data;
    }
  }

  /// 发送m3u8文件
  Future<void> _sendM3u8(Socket socket, Uint8List data) async {
    // 构建响应头
    const int statusCode = 200;
    const String statusMessage = 'OK';
    final String headers = <String>[
      'HTTP/1.1 $statusCode $statusMessage',
      'Accept-Ranges: bytes',
      'Content-Type: application/vnd.apple.mpegurl',
      'Connection: keep-alive',
    ].join('\r\n');
    await socket.append(headers);

    await socket.append(data);
    await socket.flush();
  }

  /// 发送内容
  Future<void> _sendContent(Socket socket, Uint8List data) async {
    // logD('start: $start, end: $end, fileSize: $fileSize');

    // 构建响应头
    // final int statusCode = range.isEmpty ? 200 : 206;
    // final String statusMessage = range.isEmpty ? 'OK' : 'Partial Content';
    final String headers = <String>[
      // 'HTTP/1.1 $statusCode $statusMessage',
      'HTTP/1.1 200 OK',
      'Accept-Ranges: bytes',
      'Content-Type: video/MP2T',
      'Connection: keep-alive',
      // 'Content-Length: ${end - start + 1}',
      // 'Content-Range: bytes $start-$end/$fileSize',
    ].join('\r\n');
    await socket.append(headers);

    await socket.append(data);
    await socket.flush();
  }

  /// 发送400
  Future<void> send400(Socket socket) async {
    logD('HTTP/1.1 400 Bad Request');
    final String headers = <String>[
      'HTTP/1.1 400 Bad Request',
      'Content-Type: text/plain',
      'Bad Request'
    ].join(httpTerminal);
    await socket.append(headers);
  }

  /// 发送416
  Future<void> send416(Socket socket, int fileSize) async {
    logD('HTTP/1.1 416 Range Not Satisfiable');
    final String headers = <String>[
      'HTTP/1.1 416 Range Not Satisfiable',
      'Content-Range: bytes */$fileSize'
    ].join(httpTerminal);
    await socket.append(headers);
  }
}
