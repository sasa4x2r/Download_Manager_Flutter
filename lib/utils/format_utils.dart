class FormatUtils {
  static String bytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    return index == 0
        ? '${value.toStringAsFixed(0)} ${units[index]}'
        : '${value.toStringAsFixed(1)} ${units[index]}';
  }

  static String speed(double bytesPerSecond) =>
      '${bytes(bytesPerSecond.round())}/ث';

  static String percentage(double value) =>
      '${(value.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%';

  static String safeFileName(String value) {
    var name = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (name.isEmpty) name = 'download';
    if (name.length > 100) name = name.substring(0, 100);
    return name;
  }
}
