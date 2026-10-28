import 'progress.dart';
import 'sfx.dart';

/// App-wide services, created once at startup and passed to screens.
class Services {
  final Progress progress;
  final Sfx sfx;
  Services(this.progress, this.sfx);

  static Future<Services> create() async {
    final progress = await Progress.load();
    final sfx = Sfx(progress);
    await sfx.init();
    return Services(progress, sfx);
  }
}
