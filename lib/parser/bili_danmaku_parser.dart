import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import '../exception/danmaku_parse_exception.dart';
import '../models/danmaku_content_item.dart';
import '../models/danmaku_option.dart';
import 'base_danmaku_parser.dart';

class BiliDanmakuParseOptions {
  final String parentTag;
  final String contentTag;
  final String attrName;
  final String splitChar;
  final bool fromAssets;
  final int readAttrMinLen;

  BiliDanmakuParseOptions({
    required this.parentTag,
    required this.contentTag,
    required this.attrName,
    required this.splitChar,
    this.fromAssets = false,
    this.readAttrMinLen = 4,
  });
  BiliDanmakuParseOptions copyWith({
    String? parentTag,
    String? contentTag,
    String? attrName,
    String? splitChar,
    bool? fromAssets,
    int? readAttrMinLen,
  }) {
    return BiliDanmakuParseOptions(
      parentTag: parentTag ?? this.parentTag,
      contentTag: contentTag ?? this.contentTag,
      attrName: attrName ?? this.attrName,
      splitChar: splitChar ?? this.splitChar,
      fromAssets: fromAssets ?? this.fromAssets,
      readAttrMinLen: readAttrMinLen ?? this.readAttrMinLen,
    );
  }
}

class BiliDanmakuParser extends BaseDanmakuParser {
  late BiliDanmakuParseOptions _options;

  BiliDanmakuParser({BiliDanmakuParseOptions? options}) {
    _options = options ?? defaultOptions;
  }

  final BiliDanmakuParseOptions defaultOptions = BiliDanmakuParseOptions(
    parentTag: "i",
    contentTag: "d",
    attrName: "p",
    splitChar: ",",
  );

  @override
  Future<void> parser({
    required String path,
    required Map<int, List<DanmakuContentItem>> groupedDanmakus,
    required DanmakuOption danmakuOption,
  }) async {
    super.stateController.add(ParserState(status: ParserStatus.loading));
    try {
      super.stateController.add(ParserState(
            status: ParserStatus.parsing,
          ));
      XmlDocument? document;
      if (_options.fromAssets) {
        document = await readXmlFromAssets(path);
      } else {
        document = readXmlFromPath(path);
      }
      if (document == null) {
        super.stateController.add(ParserState(
              status: ParserStatus.error,
              exception: DanmakuParseException("无法读取XML文档"),
            ));
        return;
      }
      for (XmlElement xmlElement in document.childElements) {
        // 需要是指定（i）标签下的
        if (xmlElement.localName == _options.parentTag) {
          for (XmlElement element in xmlElement.childElements) {
            DanmakuContentItem? danmakuItem =
                getDanmakuItemByXmlElement(element);
            if (danmakuItem == null ||
                danmakuItem.text.isEmpty ||
                danmakuItem.time == null) {
              continue;
            }
            int timeGroup = (danmakuItem.time! ~/ danmakuOption.intervalTime) *
                danmakuOption.intervalTime;
            var list = groupedDanmakus[timeGroup] ?? [];
            list.add(danmakuItem);
            groupedDanmakus[timeGroup] = list;
          }
        } else {
          DanmakuContentItem? danmakuItem =
              getDanmakuItemByXmlElement(xmlElement);
          if (danmakuItem == null ||
              danmakuItem.text.isEmpty ||
              danmakuItem.time == null) {
            continue;
          }
          int timeGroup = (danmakuItem.time! ~/ danmakuOption.intervalTime) *
              danmakuOption.intervalTime;
          var list = groupedDanmakus[timeGroup] ?? [];
          list.add(danmakuItem);
          groupedDanmakus[timeGroup] = list;
        }
      }
      super.stateController.add(ParserState(status: ParserStatus.completed));
    } on DanmakuParseException catch (e) {
      super
          .stateController
          .add(ParserState(status: ParserStatus.error, exception: e));
    } catch (e) {
      super.stateController.add(ParserState(
            status: ParserStatus.error,
            exception: DanmakuParseException(
              "弹幕解析错误",
              details: e.toString(),
              originalError: e,
            ),
          ));
    }
  }

  /// 读取assets文件
  Future<XmlDocument?> readXmlFromAssets(String xmlPath) async {
    String xmlStr = await rootBundle.loadString(xmlPath);
    if (xmlStr.isEmpty) {
      return Future.value(null);
    }
    XmlDocument document = XmlDocument.parse(xmlStr);
    return document;
  }

  /// 读取本地文件
  XmlDocument? readXmlFromPath(String xmlPath) {
    try {
      var file = File(xmlPath);
      if (!file.existsSync()) {
        throw DanmakuParseException(
          "弹幕文件已不存在",
          details: "File not found: $xmlPath",
          originalError: FileSystemException('File not found', xmlPath),
        );
      }
      String xmlStr = File(xmlPath).readAsStringSync();
      if (xmlStr.isEmpty) {
        return null;
      }

      XmlDocument document = XmlDocument.parse(xmlStr);
      return document;
    } on PathAccessException catch (e) {
      throw DanmakuParseException(
        "弹幕文件访问权限不足",
        details: e.toString(),
        originalError: e,
      );
    } on FileSystemException catch (e) {
      // 处理文件系统相关异常
      throw DanmakuParseException(
        "弹幕文件系统错误",
        details: e.toString(),
        originalError: e,
      );
    } catch (e) {
      // 处理其他异常
      throw DanmakuParseException(
        "弹幕解析错误",
        details: e.toString(),
        originalError: e,
      );
    }
  }

  DanmakuContentItem? getDanmakuItemByXmlElement(XmlElement element) {
    // 只读取指定（d）标签，且没有子节点，内容不为空，有指定属性
    if (element.localName != _options.contentTag ||
        element.childElements.isNotEmpty ||
        element.getAttribute(_options.attrName) == null ||
        element.innerText.isEmpty) {
      return null;
    }
    String readAttrText = element.getAttribute(_options.attrName)!;
    List<String> readAttrTextList = readAttrText.split(_options.splitChar);
    // 属性长度
    if (readAttrTextList.isEmpty ||
        readAttrTextList.length < _options.readAttrMinLen) {
      return null;
    }
    return createDanmakuModel(readAttrTextList, element.innerText);
  }

  /// 生成弹幕内容
  DanmakuContentItem? createDanmakuModel(
    List<String> readAttrTextList,
    String text,
  ) {
    // <d p="490.19100,1,25,16777215,1584268892,0,a16fe0dd,29950852386521095">从结尾回来看这里，更感动了！</d>
    // 0 视频内弹幕出现时间	float	秒

    // 1 弹幕类型	int32	1 2 3：普通弹幕
    //                  4：底部弹幕
    //                  5：顶部弹幕
    //                  6：逆向弹幕
    //                  7：高级弹幕
    //                  8：代码弹幕
    //                  9：BAS弹幕（pool必须为2）

    // 2	弹幕字号	int32	18：小
    //                  25：标准
    //                  36：大

    // 3	弹幕颜色	int32	十进制RGB888值

    // 4	弹幕发送时间	int32	时间戳

    // 5	弹幕池类型	int32	0：普通池
    //                      1：字幕池
    //                      2：特殊池（代码/BAS弹幕）

    // 6	发送者mid的HASH	string	用于屏蔽用户和查看用户发送的所有弹幕 也可反查用户id
    // 7	弹幕dmid	int64	唯一 可用于操作参数
    // 8	弹幕的屏蔽等级	int32	0-10，低于用户设定等级的弹幕将被屏蔽 （新增，下方样例未包含）
    double? time;
    // 	弹幕类型
    int? mode;
    DanmakuItemType? danmakuItemType;
    // 弹幕字号
    double? fontSize;
    // 弹幕颜色（十进制RGB888值）
    int? color;
    // 弹幕发送时间	时间戳
    int? createTime;
    // 弹幕池类型
    String? poolType;
    // 发送者mid的HASH	string	用于屏蔽用户和查看用户发送的所有弹幕 也可反查用户id
    String? sendUserId;
    // 弹幕dmid	int64	唯一 可用于操作参数
    String? danmakuId;
    // 弹幕的屏蔽等级
    late int level;
    for (int i = 0; i < readAttrTextList.length; i++) {
      if (i > 9) {
        return null;
      }
      String value = readAttrTextList[i].trim();
      try {
        switch (i) {
          case 0:
            time = double.parse(value);
            break;
          case 1:
            mode = int.tryParse(value) ?? 1;
            break;
          case 2:
            fontSize = double.parse(value);
            if (fontSize <= 0) {
              return null;
            }
            break;
          case 3:
            color = int.parse(value);
            break;
          case 4:
            createTime = int.tryParse(value);
            break;
          case 5:
            poolType = value;
            break;
          case 6:
            sendUserId = value;
            break;
          case 7:
            danmakuId = value;
            break;
          case 8:
            level = int.parse(value);
            break;
        }
      } catch (e) {
        return null;
      }
    }

    if (time == null) {
      return null;
    }

    switch (mode) {
      case 4:
        danmakuItemType = DanmakuItemType.bottom;
        break;
      case 5:
        danmakuItemType = DanmakuItemType.top;
        break;
      case 7:
        danmakuItemType = DanmakuItemType.special;
        break;
      default:
        danmakuItemType = DanmakuItemType.scroll;
    }
    int timeMs = Duration(milliseconds: (time * 1000).floor()).inMilliseconds;
    Color colors = color == null ? Colors.white : Color(color | 0xFF000000);
    if (danmakuItemType == DanmakuItemType.special) {
      if (fontSize == null) {
        return null;
      }
      try {
        return SpecialDanmakuContentItem.fromList(
          colors,
          fontSize,
          text.split(","),
          time: timeMs,
        );
      } catch (e) {
        return null;
      }
    }
    return DanmakuContentItem(
      text,
      color: colors,
      type: danmakuItemType,
      time: timeMs,
    );
  }
}
