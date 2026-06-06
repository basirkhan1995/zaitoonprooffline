import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiServices {
  static final ApiServices _instance = ApiServices._internal();
  factory ApiServices() => _instance;
  ApiServices._internal();

  late Dio _dio;

  // IMPORTANT: Use 127.0.0.1 instead of localhost
  static const String defaultBaseUrl = "http://127.0.0.1/rapi";
  static const String defaultImageUrl = "http://127.0.0.1/images/personal/";

  String? _savedIP;
  String? _savedPort;
  bool _isLocalhost = true;
  bool _skipConnectivityCheck = false;

  // Initialize with 127.0.0.1 by default
  void init({String? baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? defaultBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Cache-Control": "no-cache",
      },
      validateStatus: (status) => status != null && status < 500,
    ));

    // Add logging interceptor for debugging
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));
  }

  Dio get client => _dio;
  bool get isLocalhost => _isLocalhost;
  String? get savedIP => _savedIP;
  String? get savedPort => _savedPort;

  // Check if current device is the server
  Future<bool> isServerDevice() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2),
        validateStatus: (status) => status != null && status < 500,
      ));

      // Try both 127.0.0.1 and localhost
      for (final host in ['127.0.0.1', 'localhost']) {
        try {
          final response = await dio.get('http://$host/rapi/get_ip.php');
          if (response.statusCode == 200) {
            final data = response.data;
            if (data is Map && data['success'] == true) {
              _isLocalhost = true;
              _skipConnectivityCheck = true;
              return true;
            }
          }
        } catch (e) {
          continue;
        }
      }
      return false;
    } catch (e) {
      _isLocalhost = false;
      _skipConnectivityCheck = false;
      return false;
    }
  }

  // Set server IP and update base URL
  Future<void> setServerIP(String ip, {String port = '80'}) async {
    _savedIP = ip;
    _savedPort = port;
    _isLocalhost = (ip == 'localhost' || ip == '127.0.0.1' || ip == '::1');

    final newUrl = _isLocalhost
        ? 'http://127.0.0.1/rapi'  // Always use 127.0.0.1 for local connections
        : 'http://$ip:$port/rapi';

    _dio.options.baseUrl = newUrl;

    // Skip connectivity checks for localhost
    _skipConnectivityCheck = _isLocalhost;

    final prefs = await SharedPreferences.getInstance();
    if (!_isLocalhost) {
      await prefs.setString('server_ip', ip);
      await prefs.setString('server_port', port);
    } else {
      // Clear saved IP when using localhost
      await prefs.remove('server_ip');
      await prefs.remove('server_port');
    }

  }

  // ==================== THESE METHODS WERE MISSING ====================

  // Get saved server IP for display
  Future<String?> getSavedServerIP() async {
    if (_isLocalhost) return null;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('server_ip');
  }

  // Get saved server port
  Future<String?> getSavedServerPort() async {
    if (_isLocalhost) return null;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('server_port');
  }

  // ===================================================================

  // Get image URL based on current server
  String get imageUrl {
    if (_isLocalhost) {
      return 'http://127.0.0.1/images/personal/';
    }

    final base = _dio.options.baseUrl;
    return base.replaceAll('/rapi', '/images/personal/');
  }

  // Build complete image URL for a specific image
  String getImageUrl(String imagePath) {
    // Remove any leading slash
    final cleanPath = imagePath.startsWith('/') ? imagePath.substring(1) : imagePath;

    if (_isLocalhost) {
      return 'http://127.0.0.1/images/personal/$cleanPath';
    }

    final ip = _savedIP ?? '127.0.0.1';
    final port = _savedPort ?? '80';
    return 'http://$ip:$port/images/personal/$cleanPath';
  }

  /* -------------------------------------------------------------------------- */
  /*                            Connectivity Check                               */
  /* -------------------------------------------------------------------------- */

  Future<void> _checkConnectivity() async {
    // Skip connectivity check for localhost connections
    if (_skipConnectivityCheck || _isLocalhost) {
      return;
    }

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        // Check if we're trying to connect to localhost
        if (_dio.options.baseUrl.contains('127.0.0.1') ||
            _dio.options.baseUrl.contains('localhost')) {
          return;
        }
        throw Exception('No internet connection');
      }
    } catch (e) {
      // Don't throw for localhost connections
      if (!_isLocalhost) {
        rethrow;
      }
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                              Error Handling                                */
  /* -------------------------------------------------------------------------- */

  String _handleError(DioException e) {

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out. Please check if XAMPP is running.';
      case DioExceptionType.receiveTimeout:
        return 'Server took too long to respond. Please try again.';
      case DioExceptionType.sendTimeout:
        return 'Request timed out while sending data.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.connectionError:
        return 'Cannot connect to server. Is XAMPP running?';
      case DioExceptionType.badResponse:
        switch (e.response?.statusCode) {
          case 400:
            return 'Bad request. Please check the data sent.';
          case 401:
            return 'Unauthorized access. Please login again.';
          case 403:
            return 'Access forbidden.';
          case 404:
            return 'Requested resource not found.';
          case 405:
            return 'Method not allowed.';
          case 500:
            return 'Internal server error. Please try again later.';
          case 503:
            return 'Service unavailable. Please try again later.';
          default:
            return 'Server error: ${e.response?.statusCode}';
        }
      default:
        return 'Network error occurred. Please check your connection.';
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                                   GET                                      */
  /* -------------------------------------------------------------------------- */

  Future<Response> get({
    required String endpoint,
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
  }) async {
    try {
      await _checkConnectivity();
      return await _dio.get(
        endpoint,
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw e.toString();
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                                   POST                                     */
  /* -------------------------------------------------------------------------- */

  Future<Response> post({
    required String endpoint,
    required dynamic data,
    CancelToken? cancelToken,
  }) async {
    try {
      await _checkConnectivity();
      return await _dio.post(
        endpoint,
        data: data,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw e.toString();
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                                   PUT                                      */
  /* -------------------------------------------------------------------------- */

  Future<Response> put({
    required String endpoint,
    required dynamic data,
    CancelToken? cancelToken,
  }) async {
    try {
      await _checkConnectivity();
      return await _dio.put(
        endpoint,
        data: data,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw e.toString();
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                                  DELETE                                    */
  /* -------------------------------------------------------------------------- */

  Future<Response> delete({
    required String endpoint,
    dynamic data,
    CancelToken? cancelToken,
  }) async {
    try {
      await _checkConnectivity();
      return await _dio.delete(
        endpoint,
        data: data,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw e.toString();
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                               FILE UPLOAD                                  */
  /* -------------------------------------------------------------------------- */

  Future<Response> uploadFile({
    required String endpoint,
    required FormData data,
    CancelToken? cancelToken,
  }) async {
    try {
      await _checkConnectivity();
      return await _dio.post(
        endpoint,
        data: data,
        cancelToken: cancelToken,
        options: Options(contentType: 'multipart/form-data'),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw e.toString();
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                              FILE DOWNLOAD                                 */
  /* -------------------------------------------------------------------------- */

  Future<Response> downloadFile({
    required String endpoint,
    required String savePath,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      await _checkConnectivity();
      return await _dio.download(
        endpoint,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw e.toString();
    }
  }
}