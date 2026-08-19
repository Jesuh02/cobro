import 'package:flutter/material.dart';

import 'app/app_config.dart';
import 'app/cobro_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(CobroApp(config: AppConfig.fromEnvironment()));
}
