import 'dart:async';

import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import '../exception/danmaku_parse_exception.dart';
import '../models/danmaku_option.dart';

// 定义解析状态枚举
enum ParserStatus { idle, loading, parsing, completed, error }

class ParserState {
  final ParserStatus status;
  final double progress;
  final DanmakuParseException? exception;

  ParserState({
    required this.status,
    this.progress = 0.0,
    this.exception,
  });
}

abstract class BaseDanmakuParser {
  Future<void> parser({
    required String path,
    required Map<int, List<DanmakuContentItem>> groupedDanmakus,
    required DanmakuOption danmakuOption,
  });

  final StreamController<ParserState> stateController =
      StreamController<ParserState>.broadcast();

  Stream<ParserState> get stateStream => stateController.stream;

  void dispose() {
    stateController.close();
  }
}
