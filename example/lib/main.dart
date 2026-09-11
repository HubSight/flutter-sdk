import 'package:flutter/material.dart';
import 'package:hubsight_sdk/hubsight_sdk.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HubSightDemoApp());
}

class HubSightDemoApp extends StatelessWidget {
  const HubSightDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HubSight CCTV Mobile SDK Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.tealAccent,
        ),
      ),
      home: const EnrollmentScreen(),
    );
  }
}

/// Example implementation of a UI Localization Error Resolver.
/// The SDK provides pure, machine-readable [HubSightErrorCode]s, while the UI app
/// translates them into human-readable strings based on user locale.
class AppErrorLocalizer implements HubSightErrorResolver {
  @override
  String resolve(HubSightErrorCode code) {
    switch (code) {
      case HubSightErrorCode.configInvalidPinFormat:
        return 'Mã PIN bảo mật phải gồm đúng 6 chữ số.';
      case HubSightErrorCode.configDecryptionFailed:
        return 'Mã PIN không chính xác hoặc gói cấu hình bị lỗi.';
      case HubSightErrorCode.configInvalidHeader:
      case HubSightErrorCode.configCorrupted:
        return 'Tệp cấu hình không hợp lệ hoặc đã bị hư hỏng.';
      case HubSightErrorCode.networkTimeout:
        return 'Hết thời gian kết nối tới máy chủ. Vui lòng kiểm tra đường truyền.';
      case HubSightErrorCode.networkUnreachable:
        return 'Không thể kết nối đến máy chủ CCTV HubSight. Vui lòng kiểm tra mạng.';
      case HubSightErrorCode.authInvalidCredentials:
        return 'Tên đăng nhập hoặc mật khẩu không chính xác.';
      case HubSightErrorCode.authInvalidTwoFactorCode:
        return 'Mã xác thực 2 bước (2FA) không chính xác hoặc đã hết hạn.';
      case HubSightErrorCode.authSessionExpired:
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      case HubSightErrorCode.appKeyRequired:
      case HubSightErrorCode.appKeyInvalidOrRevoked:
        return 'Khóa API ứng dụng không hợp lệ hoặc đã bị vô hiệu hóa.';
      case HubSightErrorCode.systemMaintenance:
        return 'Hệ thống hiện đang tạm dừng để bảo trì.';
      case HubSightErrorCode.cameraStopped:
        return 'Camera này hiện đang tạm dừng hoạt động.';
      default:
        return 'Đã xảy ra lỗi (${code.wireCode}). Vui lòng thử lại.';
    }
  }

  static String fromError(Object error) {
    if (error is HubSightException) {
      return AppErrorLocalizer().resolve(error.code);
    }
    return 'Lỗi: $error';
  }
}

/// Screen 1: Zero-Config Enrollment (.hscfg or Preset)
class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({super.key});

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  final _gatewayCtrl = TextEditingController(text: 'https://cctv.quoctran.space');
  final _apiKeyCtrl = TextEditingController(text: 'hs_mob_client_default');
  final _pinCtrl = TextEditingController(text: '123456');

  bool _isLoading = false;
  String? _error;

  Future<void> _initWithPreset() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final config = HubSightAppConfig(
        urls: HubSightUrls(
          gatewayUrl: _gatewayCtrl.text.trim(),
          apiBaseUrl: '${_gatewayCtrl.text.trim()}/api',
          relayWsUrl: 'wss://${Uri.parse(_gatewayCtrl.text.trim()).host}/relay',
          webrtcBaseUrl: 'https://${Uri.parse(_gatewayCtrl.text.trim()).host}:8555',
        ),
        key: HubSightClientKey(
          clientId: _apiKeyCtrl.text.trim(),
          clientSecret: 'demo_secret',
          clientName: 'Demo Mobile App',
        ),
        metadata: const HubSightConfigMetadata(
          formatVersion: '1.0',
          configId: 'demo_cfg',
          name: 'Demo Preset HQ',
        ),
      );

      final sdk = await HubSightSDK.initialize(
        config: config,
        onMaintenance: (m) {
          final text = AppErrorLocalizer().resolve(m.code);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('[BẢO TRÌ] $text (Thử lại sau ${m.retryAfterSeconds}s)'),
              backgroundColor: Colors.redAccent,
            ),
          );
        },
        onSessionExpired: () {
          final text = AppErrorLocalizer().resolve(HubSightErrorCode.authSessionExpired);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(text),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        },
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => LoginScreen(sdk: sdk)),
        );
      }
    } catch (e) {
      setState(() => _error = AppErrorLocalizer.fromError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HubSight Enrollment')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.security_rounded, size: 64, color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text(
                  'Thiết lập Cấu hình Ứng dụng',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hỗ trợ giải mã container bảo mật .hscfg bằng mã PIN 6 số hoặc kết nối trực tiếp qua API Gateway.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _gatewayCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Gateway URL',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'App Client API Key (X-API-Key)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.vpn_key),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Mã PIN 6 số (.hscfg)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pin),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _initWithPreset,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Khởi tạo SDK & Tiếp tục'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen 2: Authentication Screen
class LoginScreen extends StatefulWidget {
  final HubSightSDK sdk;
  const LoginScreen({super.key, required this.sdk});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController(text: 'Admin@123456');
  final _totpCtrl = TextEditingController();

  bool _isLoading = false;
  bool _requires2FA = false;
  String? _preAuthToken;
  String? _error;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_requires2FA) {
        final res = await widget.sdk.auth.verify2FA(
          preAuthToken: _preAuthToken!,
          code: _totpCtrl.text.trim(),
        );
        if (res.isSuccess) {
          _navigateToHome();
        }
      } else {
        final res = await widget.sdk.auth.login(
          username: _userCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );

        if (res.requires2FA) {
          setState(() {
            _requires2FA = true;
            _preAuthToken = res.preAuthToken;
          });
        } else if (res.isSuccess) {
          _navigateToHome();
        }
      }
    } catch (e) {
      setState(() => _error = AppErrorLocalizer.fromError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(sdk: widget.sdk)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập HubSight')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.videocam, size: 60, color: Colors.blueAccent),
                const SizedBox(height: 16),
                if (!_requires2FA) ...[
                  TextField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Vui lòng nhập mã xác thực 2 bước (TOTP):',
                    style: TextStyle(fontSize: 14, color: Colors.amber),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _totpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Mã xác thực 6 số',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pin),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_requires2FA ? 'Xác thực 2FA' : 'Đăng nhập'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen 3: Home & Surveillance Cameras Overview
class HomeScreen extends StatefulWidget {
  final HubSightSDK sdk;
  const HomeScreen({super.key, required this.sdk});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  List<Camera> _cameras = [];
  int _unreadCount = 0;
  bool _isLoading = true;
  String? _userToken;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      _userToken = await widget.sdk.storage.getAccessToken();
      final cameras = await widget.sdk.cameras.listCameras();
      final unread = await widget.sdk.notifications.getUnreadCount();

      if (mounted) {
        setState(() {
          _cameras = cameras;
          _unreadCount = unread;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HubSight CCTV Live'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  // Open notifications screen
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await widget.sdk.auth.logout();
              if (!mounted) return;
              navigator.pushReplacement(
                MaterialPageRoute(builder: (_) => LoginScreen(sdk: widget.sdk)),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tabIndex == 0
              ? _buildCameraGrid()
              : _buildMultiViewGrid(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: 'Danh sách Snapshots',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_customize),
            label: 'Multi-View WebRTC',
          ),
        ],
      ),
    );
  }

  Widget _buildCameraGrid() {
    if (_cameras.isEmpty) {
      return const Center(child: Text('Không có camera nào trong hệ thống.'));
    }

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _cameras.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 16 / 10,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          final cam = _cameras[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                HubSightCameraThumbnail(
                  gatewayUrl: widget.sdk.config.urls.gatewayUrl,
                  thumbnailUrl: cam.thumbnailUrl,
                  apiKey: widget.sdk.config.apiKey,
                  token: _userToken ?? '',
                  isStopped: cam.isStopped,
                  refreshInterval: const Duration(seconds: 4),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            cam.name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          cam.isStreaming ? Icons.circle : Icons.stop_circle,
                          color: cam.isStreaming ? Colors.greenAccent : Colors.redAccent,
                          size: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMultiViewGrid() {
    final activeIds = _cameras.where((c) => c.isStreaming).map((c) => c.id).take(4).toList();
    if (activeIds.isEmpty) {
      return const Center(child: Text('Không có camera nào đang hoạt động để xem multi-view.'));
    }

    final session = widget.sdk.createMultiViewSession();
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: HubSightMultiViewGrid(
        session: session,
        cameraIds: activeIds,
        crossAxisCount: 2,
      ),
    );
  }
}
