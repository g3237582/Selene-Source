import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/search_result.dart';
import '../models/search_resource.dart';
import '../search/special_source_access.dart';
import '../search/video_search_request.dart';
import 'user_data_service.dart';
import 'api_service.dart';
import 'downstream_service.dart';
import 'local_mode_storage_service.dart';

/// SSE 搜索服务
class SSESearchService {
  final http.Client Function()? clientFactory;
  http.Client? _client;
  StreamSubscription? _subscription;
  StreamController<List<SearchResult>>? _incrementalResultsController;
  StreamController<String>? _errorController;
  StreamController<SearchProgress>? _progressController;

  bool _isConnected = false;
  String? _currentQuery;
  final Map<String, String> _sourceErrors = {};
  String _buffer = ''; // 用于缓冲不完整的 UTF-8 字符
  int _completedSources = 0; // 跟踪完成的源数量
  int _totalSources = 0; // 总源数量
  Timer? _timeoutTimer; // 超时定时器
  bool _special = false;

  SSESearchService({this.clientFactory});

  /// 获取增量结果流
  Stream<List<SearchResult>> get incrementalResultsStream =>
      _incrementalResultsController?.stream ?? const Stream.empty();

  /// 获取错误流
  Stream<String> get errorStream =>
      _errorController?.stream ?? const Stream.empty();

  /// 获取进度流
  Stream<SearchProgress> get progressStream =>
      _progressController?.stream ?? const Stream.empty();

  /// 是否已连接
  bool get isConnected => _isConnected;

  /// 当前搜索查询
  String? get currentQuery => _currentQuery;

  /// 本地搜索
  Future<void> localSearch(String query) async {
    try {
      // 检查是否是本地模式
      final isLocalMode = await UserDataService.getIsLocalMode();

      // 获取搜索资源列表
      final allResources = isLocalMode
          ? await LocalModeStorageService.getSearchSources()
          : await ApiService.getSearchResources();

      // 过滤掉被禁用的资源
      final resources =
          allResources.where((resource) => !resource.disabled).toList();

      if (resources.isEmpty) {
        _errorController?.add('没有可用的搜索资源');
        _isConnected = false;
        return;
      }

      _totalSources = resources.length;
      _completedSources = 0;

      _progressController?.add(SearchProgress(
        totalSources: _totalSources,
        completedSources: 0,
        currentSource: null,
        isComplete: false,
      ));

      // 并发调用所有资源的搜索，每个调用增加 20 秒超时
      final searchFutures = resources.map((resource) {
        return _searchSingleResource(resource, query);
      }).toList();

      // 等待所有搜索完成
      await Future.wait(searchFutures);

      // 发送完成事件
      _progressController?.add(SearchProgress(
        totalSources: _totalSources,
        completedSources: _totalSources,
        currentSource: null,
        isComplete: true,
      ));

      _isConnected = false;
    } catch (e) {
      _errorController?.add('本地搜索异常: ${e.toString()}');
      _isConnected = false;
    }
  }

  /// 搜索单个资源
  Future<void> _searchSingleResource(
      SearchResource resource, String query) async {
    try {
      // 调用 searchFromApi 并设置 20 秒超时
      final results = await DownstreamService.searchFromApi(resource, query)
          .timeout(const Duration(seconds: 20));

      // 增加完成计数
      _completedSources++;

      // 发送结果事件
      if (results.isNotEmpty) {
        _incrementalResultsController?.add(results);
      }

      // 发送进度更新
      _progressController?.add(SearchProgress(
        totalSources: _totalSources,
        completedSources: _completedSources,
        currentSource: resource.name,
        isComplete: false,
      ));
    } on TimeoutException {
      // 超时处理
      _completedSources++;
      _sourceErrors[resource.key] = '搜索超时（20秒）';

      // 发送错误进度更新
      _progressController?.add(SearchProgress(
        totalSources: _totalSources,
        completedSources: _completedSources,
        currentSource: resource.name,
        isComplete: false,
        error: '搜索超时（20秒）',
      ));
    } catch (e) {
      // 其他错误处理
      _completedSources++;
      _sourceErrors[resource.key] = e.toString();

      // 发送错误进度更新
      _progressController?.add(SearchProgress(
        totalSources: _totalSources,
        completedSources: _completedSources,
        currentSource: resource.name,
        isComplete: false,
        error: e.toString(),
      ));
    }
  }

  /// 开始搜索。
  ///
  /// [special] 为 true 时只搜特殊采集源，并且始终走服务端 SSE。
  /// 本地搜索只属于普通源，避免把特殊源混进推荐缓存。
  Future<void> startSearch(String query, {bool special = false}) async {
    if (query.trim().isEmpty) {
      throw Exception('搜索查询不能为空');
    }

    // 如果已有连接，先关闭
    if (_isConnected) {
      await stopSearch();
    }

    // 关闭之前的流控制器
    await _incrementalResultsController?.close();
    await _errorController?.close();
    await _progressController?.close();

    _currentQuery = query.trim();
    _special = special;
    _sourceErrors.clear();
    _completedSources = 0;

    // 初始化流控制器
    _incrementalResultsController =
        StreamController<List<SearchResult>>.broadcast();
    _errorController = StreamController<String>.broadcast();
    _progressController = StreamController<SearchProgress>.broadcast();

    _isConnected = true;

    // 设置15秒超时定时器
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (_isConnected) {
        _handleTimeout();
      }
    });

    // 特殊源只走服务端。普通源才允许本地搜索。
    if (!special) {
      final isLocalMode = await UserDataService.getIsLocalMode();
      if (isLocalMode) {
        localSearch(query);
        return;
      }

      final isLocalSearch = await UserDataService.getLocalSearch();
      if (isLocalSearch) {
        localSearch(query);
        return;
      }
    }

    try {
      await _startRemoteSearch();
    } on SpecialSourceForbiddenException {
      _closeConnection();
      rethrow;
    } catch (e) {
      _isConnected = false;

      // 检查是否是连接关闭错误，如果是则静默处理
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('connection closed') ||
          errorString.contains('clientexception') ||
          errorString.contains('connection terminated')) {
        // 连接被关闭，这是正常情况，静默处理
        return;
      }

      _errorController?.add('连接失败: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> _startRemoteSearch() async {
    final baseUrl = await UserDataService.getServerUrl();
    final cookies = await UserDataService.getCookies();
    final token = VideoSearchRequest.bearerToken(
      storedToken: await UserDataService.getAuthToken(),
      cookie: cookies,
    );

    if (baseUrl == null) {
      throw Exception('服务器地址未配置，请先登录');
    }

    if ((cookies == null || cookies.isEmpty) &&
        (token == null || token.isEmpty)) {
      throw Exception('用户未登录');
    }

    final built = VideoSearchRequest.get(
      baseUrl: baseUrl,
      path: VideoSearchRequest.wsPath,
      query: _currentQuery,
      special: _special,
      token: token,
      cookie: cookies,
      headers: const {
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
      },
    );

    _client = clientFactory?.call() ?? http.Client();
    final request = http.Request('GET', built.uri);
    request.headers.addAll(built.headers);

    final response = await _client!.send(request);
    if (response.statusCode != 200) {
      final raw = await response.stream.bytesToString();
      // 403 JSON is the whole body. Do not open the SSE parser.
      if (SpecialSourceAccess.isForbiddenBody(response.statusCode, raw)) {
        _closeConnection();
        throw const SpecialSourceForbiddenException();
      }
      _errorController?.add('SSE 连接失败: ${response.statusCode}');
      _closeConnection();
      return;
    }

    _handleSSEResponse(response);
  }

  /// 处理 SSE 响应
  void _handleSSEResponse(http.StreamedResponse response) {
    if (response.statusCode != 200) {
      _errorController?.add('SSE 连接失败: ${response.statusCode}');
      return;
    }

    // 重置缓冲区
    _buffer = '';

    // 使用流式 UTF-8 解码器，自动处理跨 chunk 的多字节字符
    const utf8Decoder = Utf8Decoder(allowMalformed: false);

    _subscription = response.stream.transform(utf8Decoder).listen(
      (chunk) {
        try {
          _buffer += chunk;
          final lines = _buffer.split('\n');
          if (lines.isNotEmpty) {
            _buffer = lines.last;
            lines.removeLast();
          }
          for (final line in lines) {
            if (line.trim().isEmpty) continue;
            if (line.startsWith('data: ')) {
              _handleSSEData(line.substring(6));
            }
          }
        } catch (_) {
          // 跳过无法按 UTF-8 拼起来的半个字符块
        }
      },
      onError: _handleError,
      onDone: _handleDone,
    );
  }

  /// 处理 SSE 数据
  void _handleSSEData(String jsonStr) {
    try {
      final data = json.decode(jsonStr);

      final event = SearchEvent.fromJson(data as Map<String, dynamic>);

      switch (event.type) {
        case SearchEventType.start:
          _handleStartEvent(event as SearchStartEvent);
          break;
        case SearchEventType.sourceResult:
          _handleSourceResultEvent(event as SearchSourceResultEvent);
          break;
        case SearchEventType.sourceError:
          _handleSourceErrorEvent(event as SearchSourceErrorEvent);
          break;
        case SearchEventType.complete:
          _handleCompleteEvent(event as SearchCompleteEvent);
          break;
      }
    } catch (e) {
      _errorController?.add('消息解析失败: ${e.toString()}');
    }
  }

  /// 处理开始事件
  void _handleStartEvent(SearchStartEvent event) {
    _totalSources = event.totalSources;
    _progressController?.add(SearchProgress(
      totalSources: event.totalSources,
      completedSources: 0,
      currentSource: null,
      isComplete: false,
    ));
  }

  /// 处理搜索结果事件
  void _handleSourceResultEvent(SearchSourceResultEvent event) {
    _completedSources++;

    // 只发送增量结果更新，避免全量重渲染
    if (event.results.isNotEmpty) {
      _incrementalResultsController?.add(List.from(event.results));
    }

    // 更新进度（无论是否有结果都要更新）
    _progressController?.add(SearchProgress(
      totalSources: _totalSources,
      completedSources: _completedSources,
      currentSource: event.sourceName,
      isComplete: false,
    ));
  }

  /// 处理搜索错误事件
  void _handleSourceErrorEvent(SearchSourceErrorEvent event) {
    _sourceErrors[event.source] = event.error;

    // 错误也算源完成，累计进度
    _completedSources++;

    // 更新进度
    _progressController?.add(SearchProgress(
      totalSources: _totalSources,
      completedSources: _completedSources,
      currentSource: event.sourceName,
      isComplete: false,
      error: event.error,
    ));
  }

  /// 处理完成事件
  void _handleCompleteEvent(SearchCompleteEvent event) {
    // 如果完成源数小于总源数，说明有些源没有发送结果事件
    // 将完成源数设置为总源数
    if (_completedSources < _totalSources) {
      _completedSources = _totalSources;
    }

    // 发送最终完成状态
    _progressController?.add(SearchProgress(
      totalSources: _totalSources,
      completedSources: _completedSources,
      currentSource: null,
      isComplete: true,
    ));

    // 搜索完成，关闭连接
    _closeConnection();
  }

  /// 处理超时
  void _handleTimeout() {
    // 如果完成源数小于总源数，说明有些源没有发送结果事件
    // 将完成源数设置为总源数
    if (_completedSources < _totalSources) {
      _completedSources = _totalSources;
    }

    // 发送超时状态
    _progressController?.add(SearchProgress(
      totalSources: _totalSources,
      completedSources: _completedSources,
      currentSource: null,
      isComplete: true,
    ));

    _errorController?.add('搜索超时（15秒）');
    _closeConnection();
  }

  /// 关闭连接
  void _closeConnection() {
    _isConnected = false;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _client?.close();
    _client = null;
  }

  /// 处理 SSE 错误
  void _handleError(error) {
    _isConnected = false;

    // 检查是否是连接关闭错误，如果是则忽略
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('connection closed') ||
        errorString.contains('clientexception') ||
        errorString.contains('connection terminated')) {
      // 连接被关闭，这是正常情况，不显示错误
      print('搜索连接已关闭: ${error.toString()}');
      return;
    }

    // 其他错误才显示给用户
    _errorController?.add('SSE 错误: ${error.toString()}');
  }

  /// 处理 SSE 关闭
  void _handleDone() {
    _isConnected = false;
  }

  /// 停止搜索
  Future<void> stopSearch() async {
    await _subscription?.cancel();
    _subscription = null;

    _timeoutTimer?.cancel();
    _timeoutTimer = null;

    _client?.close();
    _client = null;

    _isConnected = false;
    _currentQuery = null;

    // 关闭流控制器
    await _incrementalResultsController?.close();
    await _errorController?.close();
    await _progressController?.close();

    _incrementalResultsController = null;
    _errorController = null;
    _progressController = null;
  }

  /// 获取源错误信息
  Map<String, String> get sourceErrors => Map.from(_sourceErrors);

  /// 释放资源
  void dispose() {
    stopSearch();
  }
}

/// 搜索进度信息
class SearchProgress {
  final int totalSources;
  final int completedSources;
  final String? currentSource;
  final bool isComplete;
  final String? error;

  SearchProgress({
    required this.totalSources,
    required this.completedSources,
    this.currentSource,
    required this.isComplete,
    this.error,
  });

  /// 获取完成百分比
  double get progressPercentage {
    if (totalSources <= 0) return 0.0;
    return (completedSources / totalSources).clamp(0.0, 1.0);
  }

  /// 是否有错误
  bool get hasError => error != null;

  /// 获取进度描述
  String get progressDescription {
    if (isComplete) {
      return '搜索完成';
    } else if (currentSource != null) {
      return '正在搜索: $currentSource';
    } else {
      return '准备搜索...';
    }
  }
}
