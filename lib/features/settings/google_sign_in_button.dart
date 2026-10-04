import 'package:flutter/material.dart';

import 'google_sign_in_button_stub.dart'
    if (dart.library.js_interop) 'google_sign_in_button_web.dart' as platform;

Widget buildGoogleSignInButton({required VoidCallback onPressed}) => platform.buildGoogleSignInButton(onPressed: onPressed);