
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'localization_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
class ApiServices {

  static final ApiServices _instance = ApiServices._internal();
  factory ApiServices() => _instance;
  ApiServices._internal();

  late Dio _dio;

  // Default fallback - keeps your original working URL
  static const String defaultBaseUrl = "http://localhost/rapi";
  static const String defaultImageUrl = "http://localhost/images/personal/";

  // Initialize with default
  void init({String? baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? defaultBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
    ));
  }

  Dio get client => _dio;

  // Simple method to change server
  Future<void> setServerIP(String ip, {String port = '80'}) async {
    final newUrl = 'http://$ip:$port/rapi';
    _dio.options.baseUrl = newUrl;

    // Save for next app launch
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', ip);
    await prefs.setString('server_port', port);
  }

  // Get saved server on startup
  Future<String?> getSavedServerIP() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('server_ip');
  }

  // Get image URL based on current server
  String get imageUrl {
    final base = _dio.options.baseUrl;
    return base.replaceAll('/rapi', '/images/personal/');
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
      //await _checkConnectivity();
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
      //await _checkConnectivity();
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

  // Add this method to your ApiServices class after the uploadFile method:

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


