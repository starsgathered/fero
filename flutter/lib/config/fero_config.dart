enum Environment { dev, staging, prod }

class FeroConfig {
  FeroConfig._internal();
  static final FeroConfig _instance = FeroConfig._internal();
  factory FeroConfig() => _instance;

  late Environment env;
  late String apiBaseUrl;
  late String socketHost;
  late int? socketPort;
  late bool useHttps;

  void initialize({required Environment environment}) {
    env = environment;
    switch (env) {
      case Environment.dev:
        apiBaseUrl = 'http://192.168.43.150:3002/api';
        socketHost = '192.168.43.150';
        socketPort = 3003;
        useHttps = false;
        break;
      case Environment.staging:
        apiBaseUrl = 'https://staging.example.com/api';
        socketHost = 'staging.example.com';
        socketPort = null;
        useHttps = true;
        break;
      case Environment.prod:
        apiBaseUrl = 'https://api.example.com';
        socketHost = 'api.example.com';
        socketPort = null;
        useHttps = true;
        break;
    }
  }
}
