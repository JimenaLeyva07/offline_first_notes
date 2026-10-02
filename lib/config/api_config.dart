class ApiConfig {
  static const String jsonBinBaseUrl = 'https://api.jsonbin.io/v3/b';

  // Bin ID que creaste en jsonbin.io
  static const String jsonBinId = '';

  // X-Master-Key de jsonbin.io
  static const String jsonBinMasterKey = r'';

  static bool get isJsonBinConfigured =>
      jsonBinId == '' && jsonBinMasterKey == r'';

  static bool get isConfigured => isJsonBinConfigured;
}
