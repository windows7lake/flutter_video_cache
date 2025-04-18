import 'package:flutter/material.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';

import 'page/download_page.dart';
import 'page/m3u8_parser_page.dart';
import 'page/video_page_view_page.dart';
import 'page/video_play_page.dart';

class MainRoute extends StatefulWidget {
  const MainRoute({super.key});

  @override
  State<MainRoute> createState() => _MainRouteState();
}

class _MainRouteState extends State<MainRoute> {
  final Map<String, Widget> _routes = {
    'Download': const DownloadPage(),
    'M3u8Parser': const M3u8ParserPage(),
    'VideoPlay': const VideoPlayPage(),
    'VideoPageView': const VideoPageViewPage(),
  };
  final List<String> urls = [
    'https://video.591.com.tw/online/target/hls/union/2025/03/26/mobile/2171273-849283.m3u8',
    'https://video.591.com.tw/online/target/hls/union/2025/02/04/mobile/2091573-822258.m3u8',
    'https://video.591.com.tw/online/target/hls/union/2025/02/04/mobile/2091545-322856.m3u8',
    'https://video.591.com.tw/online/target/hls/union/2025/02/04/mobile/2091543-694014.m3u8',
    'https://video.591.com.tw/online/target/hls/union/2025/01/23/mobile/2087576-472697.m3u8',
    'https://video.591.com.tw/online/target/hls/union/2025/01/13/mobile/2078058-141252.m3u8',
    'https://video.591.com.tw/online/target/hls/union/2025/01/03/mobile/2065937-110120.m3u8',
    'https://images.debug.100.com.tw/short_video/2025/03/13/api_76_1741847328_sR96QRx6nz/full_hls/api_76_1741847328_sR96QRx6nz.m3u8',
    'https://images.debug.100.com.tw/short_video/2025/02/25/api_76_1740451086_YfIgNO1nAL/full_hls/api_76_1740451086_YfIgNO1nAL.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/20/api_30_1740034816_gyJD2rv5iJ.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/19/api_76_1739944065_it2uv2B37X.m3u8',
    'https://t100upload.s3.ap-northeast-1.amazonaws.com/video/hls/2024/12/26/api_1092601_1706519887_yMAyefOAuT.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/18/api_76_1739868076_TDqSBrSqQC.m3u8',
    'https://cp4.100.com.tw/video/hls/2025/01/20/api_1547501_1737362677_2U3MjWuhgH.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/20/api_30_1740041957_1mWiprwazK.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/20/api_30_1740043126_wJVXwIEOHh.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/20/api_30_1740042408_eJf8r036BT.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/20/api_30_1740041707_yOQW9ocCUX.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/18/api_76_1739860463_qHCzRqVkDd.m3u8',
    'https://cp4.100.com.tw/video/hls/2025/01/20/api_1547501_1737362677_2U3MjWuhgH.m3u8',
    'https://cp4.100.com.tw/video/hls/2025/01/20/api_1547501_1737362677_2U3MjWuhgH.m3u8',
    'https://cp4.100.com.tw/video/hls/2025/01/20/api_1547501_1737362677_2U3MjWuhgH.m3u8',
    'https://cp4.100.com.tw/video/hls/2025/01/20/api_1547501_1737362677_2U3MjWuhgH.m3u8',
  ];

  @override
  void initState() {
    super.initState();
    // for (int i = 0; i < 8; i++) {
    //   VideoPreCaching.loadM3u8(urls[i]);
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_video_cache'),
      ),
      body: ListView.builder(
        itemCount: _routes.length,
        itemBuilder: (context, index) {
          final String key = _routes.keys.elementAt(index);
          final Widget value = _routes[key]!;
          return ListTile(
            title: Text(key),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => value),
              );
            },
          );
        },
      ),
    );
  }
}
