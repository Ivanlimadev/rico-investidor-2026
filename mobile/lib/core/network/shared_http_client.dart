import 'package:http/http.dart' as http;

/// Cliente HTTP compartilhado — reutiliza conexões entre API e auth.
final sharedHttpClient = http.Client();
