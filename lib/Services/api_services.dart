import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'localization_services.dart';

class ApiServices {
  static final ApiServices _instance = ApiServices._internal();
  factory ApiServices() => _instance;
  ApiServices._internal();

  late Dio _dio;

  static const String defaultBaseUrl = "http://localhost/rapi";
  static const String defaultImageUrl = "http://localhost/images/personal/";

  String? _savedIP;
  bool _isLocalhost = true;

  // Initialize with localhost by default
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
    ));
  }

  Dio get client => _dio;

  bool get isLocalhost => _isLocalhost;
  String? get savedIP => _savedIP;

  // Check if current device is the server
  Future<bool> isServerDevice() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 1),
        receiveTimeout: const Duration(seconds: 1),
        validateStatus: (status) => status != null && status < 500,
      ));

      final response = await dio.get('http://localhost/rapi/get_ip.php');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true) {
          _isLocalhost = true;
          return true;
        }
      }
      return false;
    } catch (e) {
      _isLocalhost = false;
      return false;
    }
  }

  // Set server IP and update base URL
  Future<void> setServerIP(String ip, {String port = '80'}) async {
    _savedIP = ip;
    _isLocalhost = (ip == 'localhost' || ip == '127.0.0.1' || ip == '::1');

    final newUrl = _isLocalhost
        ? 'http://localhost/rapi'
        : 'http://$ip:$port/rapi';

    _dio.options.baseUrl = newUrl;

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

  // Get image URL based on current server
  String get imageUrl {
    if (_isLocalhost) {
      return 'http://localhost/images/personal/';
    }

    final base = _dio.options.baseUrl;
    return base.replaceAll('/rapi', '/images/personal/');
  }

  // Build complete image URL for a specific image
  String getImageUrl(String imagePath) {
    // Remove any leading slash
    final cleanPath = imagePath.startsWith('/') ? imagePath.substring(1) : imagePath;

    if (_isLocalhost) {
      return 'http://localhost/images/personal/$cleanPath';
    }

    final ip = _savedIP ?? 'localhost';
    return 'http://$ip/images/personal/$cleanPath';
  }

  /* -------------------------------------------------------------------------- */
  /*                            Connectivity Check                               */
  /* -------------------------------------------------------------------------- */

  Future<void> _checkConnectivity() async {
    final locale = localizationService.loc;
    final connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw locale.noInternet;
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                              Error Handling                                */
  /* -------------------------------------------------------------------------- */

  String _handleError(DioException e) {
    final tr = localizationService.loc;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return tr.timeOutMessage;

      case DioExceptionType.cancel:
        return tr.requestCancelMessage;

      case DioExceptionType.connectionError:
        return tr.noInternet;

      case DioExceptionType.badResponse:
        switch (e.response?.statusCode) {
          case 400:
            return tr.badRequest;
          case 401:
            return tr.unAuthorized;
          case 403:
            return tr.forbidden;
          case 404:
            return tr.url404;
          case 405:
            return tr.notAllowedError;
          case 500:
            return tr.internalServerError;
          case 503:
            return tr.serviceUnavailable;
          default:
            return "${tr.serverError}: ${e.response?.statusCode}";
        }

      default:
        return tr.networkError;
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