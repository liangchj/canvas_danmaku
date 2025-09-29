import 'models/danmaku_option.dart';
import '/models/danmaku_content_item.dart';

class DanmakuController {
  final Function(DanmakuContentItem) onAddDanmaku;
  final Function(DanmakuOption) onUpdateOption;
  final Function(int) onStart;
  final Function onPause;
  final Function onResume;
  final Function onClear;
  final Function onUpdateStartTime;
  final Function onTime;
  final Function(bool) onReset;
  DanmakuController({
    required this.onAddDanmaku,
    required this.onUpdateOption,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onClear,
    required this.onUpdateStartTime,
    required this.onTime,
    required this.onReset,
  });

  bool _running = true;

  /// 是否运行中
  /// 可以调用pause()暂停弹幕
  bool get running => _running;
  set running(e) {
    _running = e;
  }

  DanmakuOption _option = DanmakuOption();
  DanmakuOption get option => _option;
  set option(e) {
    _option = e;
  }

  /// 启动弹幕
  void start(int time) {
    onStart.call(time);
  }

  /// 暂停弹幕
  void pause() {
    onPause.call();
  }

  /// 继续弹幕
  void resume() {
    onResume.call();
  }

  /// 清空弹幕
  void clear() {
    onClear.call();
  }

  /// 添加弹幕
  void addDanmaku(DanmakuContentItem item) {
    onAddDanmaku.call(item);
  }

  /// 更新弹幕配置
  void updateOption(DanmakuOption option) {
    onUpdateOption.call(option);
  }

  /// 更新启动时间
  void updateStartTime(int time) {
    onUpdateStartTime.call(time);
  }

  int get time {
    return onTime.call();
  }

  /// 重置
  void reset({bool stop = true}) {
    onReset.call(stop);
  }
}
