import 'dart:io';

import 'package:crypto/crypto.dart';

Future<String> calculateSha256(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();
