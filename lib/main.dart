import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
// (4) Push/локальные уведомления полностью убраны из приложения — они
// так и не заработали надёжно, поэтому вместо очередной попытки чинить
// весь блок кода и UI, связанный с напоминаниями, удалён.

// Код доступа к режиму разработчика больше НЕ отправляется на сервер и
// не хранится открытым текстом — он побайтово обфусцирован (XOR)
// прямо в коде приложения. Это не защита военного уровня (при желании
// обфускацию можно снять реверс-инжинирингом APK), но простой текстовый
// поиск ("838995") по декомпилированному коду больше ничего не найдёт.
const List<int> _obfuscatedDevCode = [23, 28, 23, 22, 22, 26];
const int _devCodeXorKey = 47;

String _decodedDevCode() {
  return String.fromCharCodes(_obfuscatedDevCode.map((b) => b ^ _devCodeXorKey));
}

// (7) Быстрая проверка реального соединения с интернетом через
// принудительное серверное обращение к Firestore (без локального кэша).
// Используется там, где "пустой" список Firestore-стрима иначе не
// отличить от "нет сети": в обоих случаях снапшот приходит с 0
// документов, а пользователю нужно понимать разницу.
Future<bool> _hasInternetConnection() async {
  try {
    await FirebaseFirestore.instance
        .collection('app_stats')
        .doc('downloads')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 6));
    return true;
  } catch (e) {
    return false;
  }
}

// --- Счётчик уникальных установок приложения (через Firestore) ---
// Идентификатор устройства (Android ID / iOS identifierForVendor)
// используется как ключ документа, поэтому повторная установка на то
// же самое устройство (после удаления) не увеличивает счётчик снова.
Future<String?> _getDeviceId() async {
  try {
    final deviceInfoPlugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await deviceInfoPlugin.androidInfo;
      return 'android_${info.id}';
    } else if (Platform.isIOS) {
      final info = await deviceInfoPlugin.iosInfo;
      return info.identifierForVendor != null
          ? 'ios_${info.identifierForVendor}'
          : null;
    }
  } catch (e) {
    // ignore: avoid_print
    print('Не удалось получить ID устройства: $e');
  }
  return null;
}

Future<void> _trackAppInstall() async {
  try {
    final deviceId = await _getDeviceId();
    if (deviceId == null || deviceId.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    final installDocRef = firestore.collection('installs').doc(deviceId);
    final statsDocRef = firestore.collection('app_stats').doc('downloads');

    await firestore.runTransaction((transaction) async {
      final installSnap = await transaction.get(installDocRef);
      if (installSnap.exists) {
        // Это устройство уже учтено ранее (даже если приложение удаляли
        // и ставили заново) — повторно не считаем.
        return;
      }
      final statsSnap = await transaction.get(statsDocRef);
      final currentCount =
          (statsSnap.data()?['count'] as num?)?.toInt() ?? 0;

      transaction.set(installDocRef, {
        'installed_at': FieldValue.serverTimestamp(),
      });
      transaction.set(statsDocRef, {'count': currentCount + 1});
    });
  } catch (e) {
    // ignore: avoid_print
    print('Отслеживание установки не удалось: $e');
  }
}

// Порог неактивности в днях: если пользователь месяц не заходил в
// приложение, устройство считается "отписавшимся" для статистики.
const int _inactivityThresholdDays = 30;

// Учитывает неактивность пользователя в статистике разработчика: если с
// последнего входа прошёл месяц (и дольше), устройство сначала списывается
// из счётчика скачиваний (минус 1), как будто оно "отписалось". Дальше, раз
// приложение всё же открыли (и есть интернет), оно тут же снова
// засчитывается как новое устройство через _trackAppInstall() — при этом
// локальные данные пользователя (цели, история и т.д.) никак не трогаются
// и не сбрасываются.
Future<void> _handleInactivityAndInstallTracking() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastOpenMs = prefs.getInt('last_open_ms');
    final now = DateTime.now().millisecondsSinceEpoch;

    if (lastOpenMs != null) {
      final daysSinceLastOpen = (now - lastOpenMs) / (1000 * 60 * 60 * 24);
      if (daysSinceLastOpen >= _inactivityThresholdDays) {
        final deviceId = await _getDeviceId();
        if (deviceId != null && deviceId.isNotEmpty) {
          final firestore = FirebaseFirestore.instance;
          final installDocRef = firestore.collection('installs').doc(deviceId);
          final statsDocRef = firestore.collection('app_stats').doc('downloads');
          await firestore.runTransaction((transaction) async {
            final installSnap = await transaction.get(installDocRef);
            if (!installSnap.exists) return;
            final statsSnap = await transaction.get(statsDocRef);
            final currentCount = (statsSnap.data()?['count'] as num?)?.toInt() ?? 0;
            transaction.delete(installDocRef);
            transaction.set(statsDocRef, {'count': currentCount > 0 ? currentCount - 1 : 0});
          });
        }
      }
    }

    await prefs.setInt('last_open_ms', now);
    // Устройство либо новое, либо было только что списано выше из-за
    // неактивности — в обоих случаях документ installs/{deviceId} не
    // существует, поэтому это снова засчитается как новое скачивание.
    await _trackAppInstall();
  } catch (e) {
    // ignore: avoid_print
    print('Отслеживание неактивности не удалось: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase нужен для режима разработчика (пожертвования видны на всех
  // устройствах). Если проект ещё не настроен через `flutterfire configure`,
  // оборачиваем в try/catch, чтобы остальное приложение работало без сбоев.
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCzk8zYO8vszPKBBomeeLx3cAiS9FSQNGs",
        appId: "1:161097149149:web:1e836cc3814c5d5a81c934",
        messagingSenderId: "161097149149",
        projectId: "yakoplyu",
        storageBucket: "yakoplyu.firebasestorage.app",
      ),
    );
  } catch (e) {
    // ignore: avoid_print
    print('Firebase init failed (ещё не настроен?): $e');
  }
  // Не блокирует запуск: считает уникальные устройства в фоне и учитывает
  // месяц неактивности (см. _handleInactivityAndInstallTracking).
  _handleInactivityAndInstallTracking();

  final prefs = await SharedPreferences.getInstance();
  final isRegistered = prefs.getBool('is_registered') ?? false;
  final savedName = prefs.getString('user_name') ?? '';
  final savedLastName = prefs.getString('user_last_name') ?? '';
  final isDark = prefs.getBool('is_dark') ?? false;
  final colorIndex = prefs.getInt('color_index') ?? 0;

  runApp(MyApp(
    isRegistered: isRegistered,
    savedName: savedName,
    savedLastName: savedLastName,
    initialIsDark: isDark,
    initialColorIndex: colorIndex,
  ));
}

// (1) Свайп вниз закрывает любое всплывающее окно (настройки, вход в режим
// разработчика, таблица лидеров и т.д.) — даже когда палец находится не над
// "ручкой", а прямо над содержимым, и даже если внутри окна прокручиваемый
// список уже докручен доверху. Для обычного контента ловим вертикальный
// драг напрямую; для прокручиваемых списков (SingleChildScrollView/ListView)
// в момент, когда дальше скроллить некуда, дополнительное движение вниз
// приходит как OverscrollNotification — его тоже засчитываем.
class _SwipeDownToClose extends StatefulWidget {
  final Widget child;
  const _SwipeDownToClose({required this.child});

  @override
  State<_SwipeDownToClose> createState() => _SwipeDownToCloseState();
}

class _SwipeDownToCloseState extends State<_SwipeDownToClose> {
  double _dragDistance = 0;
  static const double _closeThreshold = 60;

  void _tryClose() {
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      _dragDistance = 0;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<OverscrollNotification>(
      onNotification: (notification) {
        if (notification.overscroll < 0) {
          _dragDistance += -notification.overscroll;
          if (_dragDistance > _closeThreshold) {
            _tryClose();
          }
        }
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (details) {
          final delta = details.primaryDelta;
          if (delta != null && delta > 0) {
            _dragDistance += delta;
            if (_dragDistance > _closeThreshold) {
              _tryClose();
            }
          } else {
            _dragDistance = 0;
          }
        },
        onVerticalDragEnd: (_) => _dragDistance = 0,
        onVerticalDragCancel: () => _dragDistance = 0,
        child: widget.child,
      ),
    );
  }
}

// (3) Короткое всплывающее уведомление снизу экрана (замена стандартного
// SnackBar): появляется, поднимаясь снизу и проявляясь, а через паузу
// явно "уплывает" вниз и растворяется — вместо мгновенного исчезновения.
class _FlyingToast extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final VoidCallback onDismissed;

  const _FlyingToast({
    required this.message,
    required this.backgroundColor,
    required this.onDismissed,
  });

  @override
  State<_FlyingToast> createState() => _FlyingToastState();
}

class _FlyingToastState extends State<_FlyingToast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _offset = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _scheduleDismiss();
  }

  Future<void> _scheduleDismiss() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    // Проигрываем анимацию появления в обратном порядке — тост уходит
    // вниз экрана и растворяется, а не исчезает мгновенно.
    await _controller.reverse();
    if (!mounted) return;
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _opacity,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Text(
              widget.message,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  final bool isRegistered;
  final String savedName;
  final String savedLastName;
  final bool initialIsDark;
  final int initialColorIndex;

  const MyApp({
    super.key,
    required this.isRegistered,
    required this.savedName,
    required this.savedLastName,
    required this.initialIsDark,
    required this.initialColorIndex,
  });

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool isDark;
  late int selectedColorIndex;
  late String userName;
  late String userLastName;
  late bool isRegistered;

  // Убран один из двух одинаковых по смыслу голубых/синих оттенков —
  // осталось 5 цветов вместо 6.
  final List<Color> lightColors = [
    Colors.red,
    Colors.orange,
    Colors.green,
    Colors.blue,
    Colors.purple,
  ];

  final List<Color> darkColors = [
    const Color(0xFFE57373),
    const Color(0xFFFFB74D),
    const Color(0xFF81C784),
    const Color(0xFF64B5F6),
    const Color(0xFFBA68C8),
  ];

  @override
  void initState() {
    super.initState();
    isDark = widget.initialIsDark;
    selectedColorIndex = widget.initialColorIndex;
    userName = widget.savedName;
    userLastName = widget.savedLastName;
    isRegistered = widget.isRegistered;
  }

  Color get primaryColor =>
      isDark ? darkColors[selectedColorIndex] : lightColors[selectedColorIndex];

  void toggleTheme(bool value) {
    setState(() {
      isDark = value;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('is_dark', isDark);
    });
  }

  void setColor(int index) {
    setState(() {
      selectedColorIndex = index;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('color_index', index);
    });
  }

  void registerUser(String name, String lastName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_last_name', lastName);
    await prefs.setBool('is_registered', true);
    setState(() {
      userName = name;
      userLastName = lastName;
      isRegistered = true;
    });
  }

  void resetAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      isRegistered = false;
      userName = '';
      userLastName = '';
      isDark = false;
      selectedColorIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Я Коплю: мечты',
      debugShowCheckedModeBanner: false,
      // (4) Весь стандартный UI (в т.ч. системные диалоги вроде выбора
      // времени) теперь тоже на русском — приложение всегда открывается
      // на русской локали, независимо от языка телефона.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
      ],
      locale: const Locale('ru'),
      theme: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFBF8FF),
        colorSchemeSeed: primaryColor,
        useMaterial3: true,
      ),
      home: isRegistered
          ? HomeScreen(userName: userName, userLastName: userLastName)
          : const OnboardingScreen(),
    );
  }
}

Route createAnimatedRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          ),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  int? tempSelectedColorIndex;

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context)!;
    final isDark = appState.isDark;
    final bool canContinue = tempSelectedColorIndex != null;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 10),
              CircleAvatar(
                radius: 35,
                backgroundColor: tempSelectedColorIndex != null 
                    ? (isDark ? appState.darkColors[tempSelectedColorIndex!] : appState.lightColors[tempSelectedColorIndex!]).withOpacity(0.15)
                    : Colors.grey.withOpacity(0.15),
                child: Icon(
                  Icons.savings_outlined, 
                  size: 36, 
                  color: tempSelectedColorIndex != null 
                      ? (isDark ? appState.darkColors[tempSelectedColorIndex!] : appState.lightColors[tempSelectedColorIndex!])
                      : Colors.grey
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Добро пожаловать в\n«Я Коплю: мечты»',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Твой личный помощник для достижения любых целей и мечт.',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3EDF7),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    _buildFeatureItem(Icons.person_outline, 'Персонализация', 'Указывай имя и фамилию.', _featureColor(appState, isDark)),
                    const Divider(height: 20),
                    _buildFeatureItem(Icons.image_outlined, 'Визуализация мечты', 'Добавляй фото своих целей.', _featureColor(appState, isDark)),
                    const Divider(height: 20),
                    _buildFeatureItem(Icons.palette_outlined, 'Дизайн и темы', 'Выбирай любимый цвет темы.', _featureColor(appState, isDark)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3EDF7),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Давай знакомиться', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Ваше имя *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Фамилия (необязательно)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Выберите цвет темы',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(
                        appState.lightColors.length,
                        (index) => GestureDetector(
                          onTap: () {
                            setState(() {
                              tempSelectedColorIndex = index;
                            });
                            appState.setColor(index);
                          },
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: isDark ? appState.darkColors[index] : appState.lightColors[index],
                            child: tempSelectedColorIndex == index
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                : null,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canContinue ? appState.primaryColor : Colors.grey.withOpacity(0.4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: canContinue
                      ? () {
                          if (_nameController.text.trim().isNotEmpty) {
                            final name = _nameController.text.trim();
                            final lastName = _lastNameController.text.trim();
                            appState.registerUser(name, lastName);
                            Navigator.pushReplacement(
                              context,
                              createAnimatedRoute(WelcomeGreetingScreen(userName: name, userLastName: lastName)),
                            );
                          }
                        }
                      : null,
                  child: const Text('Продолжить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Пока цвет темы не выбран, иконки функций серые (как иконка-заглушка сверху)
  Color _featureColor(_MyAppState appState, bool isDark) {
    if (tempSelectedColorIndex == null) return Colors.grey;
    return isDark ? appState.darkColors[tempSelectedColorIndex!] : appState.lightColors[tempSelectedColorIndex!];
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        )
      ],
    );
  }
}

class WelcomeGreetingScreen extends StatelessWidget {
  final String userName;
  final String userLastName;

  const WelcomeGreetingScreen({super.key, required this.userName, required this.userLastName});

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context)!;
    final fullName = userLastName.isNotEmpty ? '$userName $userLastName' : userName;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              CircleAvatar(
                radius: 35,
                backgroundColor: appState.primaryColor.withOpacity(0.15),
                child: Icon(Icons.waving_hand_rounded, size: 36, color: appState.primaryColor),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Здравствуйте, $fullName!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appState.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      createAnimatedRoute(HomeScreen(userName: userName, userLastName: userLastName)),
                    );
                  },
                  child: const Text('Продолжить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GoalData {
  double currentAmount;
  double targetAmount;
  String goalTitle;
  List<String> history;
  String? imagePath;
  double? dailyAllowance;
  // Период, за который начисляется сумма из dailyAllowance:
  // 'day' | 'week' | 'month' | 'year'. По умолчанию 'day' — как было раньше.
  String allowancePeriod;
  String currency;
  // Желаемая дата/время, до которого хочется накопить (вплоть до часов и
  // минут). Видна и редактируется только в настройках цели, на карточке
  // не отображается.
  DateTime? targetDate;

  GoalData({
    required this.currentAmount,
    required this.targetAmount,
    required this.goalTitle,
    required this.history,
    this.imagePath,
    this.dailyAllowance,
    this.allowancePeriod = 'day',
    this.currency = '₽',
    this.targetDate,
  });
}

// Подпись периода начисления карманных денег для интерфейса.
String allowancePeriodLabel(String period) {
  switch (period) {
    case 'week':
      return 'в неделю';
    case 'month':
      return 'в месяц';
    case 'year':
      return 'в год';
    case 'day':
    default:
      return 'в день';
  }
}

// Короткое название периода для чипов выбора в форме редактирования цели.
String allowancePeriodShortLabel(String period) {
  switch (period) {
    case 'week':
      return 'Неделя';
    case 'month':
      return 'Месяц';
    case 'year':
      return 'Год';
    case 'day':
    default:
      return 'День';
  }
}

// Прибавляет один период (день/неделю/месяц/год) к дате, аккуратно
// обрабатывая переполнение дня месяца (например, 31 января + месяц).
DateTime addAllowancePeriod(DateTime date, String period) {
  switch (period) {
    case 'week':
      return date.add(const Duration(days: 7));
    case 'month':
      final totalMonth = date.month + 1;
      final year = date.year + (totalMonth - 1) ~/ 12;
      final month = ((totalMonth - 1) % 12) + 1;
      final daysInNewMonth = DateUtils.getDaysInMonth(year, month);
      final day = date.day > daysInNewMonth ? daysInNewMonth : date.day;
      return DateTime(year, month, day, date.hour, date.minute, date.second);
    case 'year':
      final year = date.year + 1;
      final daysInNewMonth = DateUtils.getDaysInMonth(year, date.month);
      final day = date.day > daysInNewMonth ? daysInNewMonth : date.day;
      return DateTime(year, date.month, day, date.hour, date.minute, date.second);
    case 'day':
    default:
      return date.add(const Duration(days: 1));
  }
}

// Русские окончания в зависимости от числа (1 год / 2 года / 5 лет и т.д.)
String pluralizeRu(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return few;
  return many;
}

// Форматирует разницу между `from` и `to` в человекочитаемый вид:
// "1 год 1 день", "3 месяца", "5 дней" — а если до цели остаётся меньше
// суток, то в часах/минутах (с учётом текущего времени и часового пояса
// устройства, т.к. используется DateTime.now(), который всегда локальный).
// (4) Без слова "через" в начале — просто длительность.
String formatRemainingDuration(DateTime from, DateTime to) {
  final diff = to.difference(from);
  if (diff.inHours < 24) {
    if (diff.inMinutes < 60) {
      final minutes = diff.inMinutes <= 0 ? 1 : diff.inMinutes;
      return '$minutes ${pluralizeRu(minutes, 'минуту', 'минуты', 'минут')}';
    }
    final hours = diff.inMinutes / 60.0;
    final roundedHours = hours.ceil();
    return '$roundedHours ${pluralizeRu(roundedHours, 'час', 'часа', 'часов')}';
  }

  int years = to.year - from.year;
  int months = to.month - from.month;
  int days = to.day - from.day;
  if (days < 0) {
    months -= 1;
    final prevMonthLastDay = DateTime(to.year, to.month, 0).day;
    days += prevMonthLastDay;
  }
  if (months < 0) {
    years -= 1;
    months += 12;
  }

  final parts = <String>[];
  if (years > 0) parts.add('$years ${pluralizeRu(years, 'год', 'года', 'лет')}');
  if (months > 0) parts.add('$months ${pluralizeRu(months, 'месяц', 'месяца', 'месяцев')}');
  if (days > 0 || parts.isEmpty) parts.add('$days ${pluralizeRu(days, 'день', 'дня', 'дней')}');

  return parts.join(' ');
}

// Оценка того, сколько ещё осталось копить при текущих карманных деньгах.
// Возвращает null, если карманные не заданы, сумма 0/некорректна или цель
// уже достигнута — тогда строка на карточке просто не показывается.
String? estimateRemainingToGoal(GoalData goal) {
  final amount = goal.dailyAllowance;
  if (amount == null || amount <= 0) return null;
  final remaining = goal.targetAmount - goal.currentAmount;
  if (remaining <= 0) return null;

  final periodsNeeded = (remaining / amount).ceil();
  final now = DateTime.now();
  DateTime target = now;
  for (int i = 0; i < periodsNeeded; i++) {
    target = addAllowancePeriod(target, goal.allowancePeriod);
  }
  return formatRemainingDuration(now, target);
}

class HomeScreen extends StatefulWidget {
  final String userName;
  final String userLastName;

  const HomeScreen({super.key, required this.userName, required this.userLastName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int currentGoalIndex = 0;
  final PageController _pageController = PageController();

  int _nameTapCount = 0;
  // (1) Защита от повторного открытия окна ввода кода разработчика поверх
  // уже открытого — без этого 10 тапов по имени во время открытого окна
  // открывали ещё одно поверх первого.
  bool _devCodeModalOpen = false;
  bool _devModeEnabled = false;

  // История достигнутых/удалённых целей ("История желаний" в настройках)
  List<Map<String, dynamic>> _wishHistory = [];

  List<GoalData> goals = [
    GoalData(currentAmount: 0, targetAmount: 0, goalTitle: 'Первая мечта', history: []),
    GoalData(currentAmount: 0, targetAmount: 0, goalTitle: 'Вторая мечта', history: []),
  ];

  final ImagePicker _picker = ImagePicker();

  // (1) Таймер для автоначисления карманных денег "в день" ровно в 00:00
  // (по локальному времени/часовому поясу устройства).
  Timer? _midnightAllowanceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initHomeScreenData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightAllowanceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // (1) Если приложение просто было свёрнуто (не закрыто) и полночь
    // прошла в фоне — досчитываем при возврате, а не только при
    // холодном запуске.
    if (state == AppLifecycleState.resumed) {
      _creditDueDailyAllowance();
      _scheduleMidnightAllowanceTimer();
    }
  }

  Future<void> _initHomeScreenData() async {
    await _loadAllGoals();
    // Досчитываем пропущенные полуночи (если приложение было закрыто) и
    // дальше держим таймер до следующей полуночи, пока приложение открыто.
    await _creditDueDailyAllowance();
    _scheduleMidnightAllowanceTimer();
  }

  void _scheduleMidnightAllowanceTimer() {
    _midnightAllowanceTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightAllowanceTimer = Timer(nextMidnight.difference(now), () async {
      await _creditDueDailyAllowance();
      if (mounted) _scheduleMidnightAllowanceTimer();
    });
  }

  // (1) Начисляет карманные "в день" за все прошедшие с последнего
  // начисления полуночи — если приложение было закрыто несколько дней,
  // досчитывает всё сразу, а не теряет пропущенные дни.
  Future<void> _creditDueDailyAllowance() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateUtils.dateOnly(DateTime.now());
    bool changed = false;
    for (int i = 0; i < goals.length; i++) {
      final goal = goals[i];
      if (goal.dailyAllowance == null || goal.dailyAllowance! <= 0 || goal.allowancePeriod != 'day') {
        continue;
      }
      final lastStr = prefs.getString('last_allowance_credit_$i');
      if (lastStr == null) {
        // Точки отсчёта ещё нет (например, старые данные без этого поля) —
        // фиксируем сегодняшний день и не начисляем задним числом.
        await prefs.setString('last_allowance_credit_$i', today.toIso8601String());
        continue;
      }
      final lastDate = DateUtils.dateOnly(DateTime.tryParse(lastStr) ?? today);
      final daysPassed = today.difference(lastDate).inDays;
      if (daysPassed > 0) {
        goal.currentAmount += goal.dailyAllowance! * daysPassed;
        await prefs.setDouble('current_amount_$i', goal.currentAmount);
        await prefs.setString('last_allowance_credit_$i', today.toIso8601String());
        changed = true;
      }
    }
    if (changed && mounted) {
      setState(() {});
    }
  }

  // Автоназвания для новых целей, которые пользователь добавляет через "+"
  String _ordinalGoalName(int number) {
    const names = {
      1: 'Первая мечта',
      2: 'Вторая мечта',
      3: 'Третья мечта',
      4: 'Четвертая мечта',
      5: 'Пятая мечта',
      6: 'Шестая мечта',
      7: 'Седьмая мечта',
      8: 'Восьмая мечта',
      9: 'Девятая мечта',
      10: 'Десятая мечта',
    };
    return names[number] ?? 'Мечта №$number';
  }

  Future<void> _loadAllGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('goals_count') ?? goals.length;
    final devMode = prefs.getBool('dev_mode_enabled') ?? false;
    final wishRaw = prefs.getStringList('wish_history') ?? [];
    setState(() {
      _devModeEnabled = devMode;
      _wishHistory = wishRaw
          .map((e) {
            try {
              return Map<String, dynamic>.from(jsonDecode(e) as Map);
            } catch (_) {
              return <String, dynamic>{};
            }
          })
          .where((m) => m.isNotEmpty)
          .toList();
      while (goals.length < count) {
        goals.add(GoalData(
          currentAmount: 0,
          targetAmount: 0,
          goalTitle: _ordinalGoalName(goals.length + 1),
          history: [],
        ));
      }
      for (int i = 0; i < goals.length; i++) {
        goals[i].currentAmount = prefs.getDouble('current_amount_$i') ?? 0.0;
        goals[i].targetAmount = prefs.getDouble('target_amount_$i') ?? 0.0;
        goals[i].goalTitle = prefs.getString('goal_title_$i') ?? _ordinalGoalName(i + 1);
        goals[i].history = prefs.getStringList('history_list_$i') ?? [];
        goals[i].imagePath = prefs.getString('goal_image_path_$i');
        goals[i].dailyAllowance = prefs.containsKey('daily_allowance_$i') ? prefs.getDouble('daily_allowance_$i') : null;
        goals[i].allowancePeriod = prefs.getString('allowance_period_$i') ?? 'day';
        goals[i].currency = prefs.getString('goal_currency_$i') ?? '₽';
        final targetDateStr = prefs.getString('target_date_$i');
        goals[i].targetDate = targetDateStr != null ? DateTime.tryParse(targetDateStr) : null;
      }
    });
  }

  Future<void> _saveGoalData(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('current_amount_$index', goals[index].currentAmount);
    await prefs.setDouble('target_amount_$index', goals[index].targetAmount);
    await prefs.setString('goal_title_$index', goals[index].goalTitle);
    await prefs.setStringList('history_list_$index', goals[index].history);
    if (goals[index].imagePath != null) {
      await prefs.setString('goal_image_path_$index', goals[index].imagePath!);
    }
    if (goals[index].dailyAllowance != null) {
      await prefs.setDouble('daily_allowance_$index', goals[index].dailyAllowance!);
      await prefs.setString('allowance_period_$index', goals[index].allowancePeriod);
      // (1) Если карманные заданы именно "в день" — обеспечиваем точку
      // отсчёта для автоначисления в полночь, не начисляя задним числом.
      if (goals[index].allowancePeriod == 'day') {
        if (!prefs.containsKey('last_allowance_credit_$index')) {
          await prefs.setString('last_allowance_credit_$index', DateUtils.dateOnly(DateTime.now()).toIso8601String());
        }
      } else {
        await prefs.remove('last_allowance_credit_$index');
      }
    } else {
      await prefs.remove('daily_allowance_$index');
      await prefs.remove('allowance_period_$index');
      await prefs.remove('last_allowance_credit_$index');
    }
    await prefs.setString('goal_currency_$index', goals[index].currency);
    if (goals[index].targetDate != null) {
      await prefs.setString('target_date_$index', goals[index].targetDate!.toIso8601String());
    } else {
      await prefs.remove('target_date_$index');
    }
  }

  // (7) Сохраняем список "История желаний"
  Future<void> _saveWishHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _wishHistory.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('wish_history', raw);
  }

  Future<void> _addNewGoal() async {
    final newIndex = goals.length;
    final newGoal = GoalData(
      currentAmount: 0,
      targetAmount: 0,
      goalTitle: _ordinalGoalName(newIndex + 1),
      history: [],
    );
    setState(() {
      goals.add(newGoal);
      currentGoalIndex = newIndex;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('goals_count', goals.length);
    await _saveGoalData(newIndex);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        newIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        goals[currentGoalIndex].imagePath = picked.path;
      });
      _saveGoalData(currentGoalIndex);
    }
  }

  Future<void> _updateMoney(double delta) async {
    setState(() {
      goals[currentGoalIndex].currentAmount += delta;
      if (goals[currentGoalIndex].currentAmount < 0) {
        goals[currentGoalIndex].currentAmount = 0;
      }
      final type = delta > 0 ? '+' : '-';
      final entry = '$type ${delta.abs().toStringAsFixed(0)} ${goals[currentGoalIndex].currency}';
      goals[currentGoalIndex].history.insert(0, entry);
    });
    _saveGoalData(currentGoalIndex);
    _checkGoalReached();
  }

  // (4) Удаление одной записи операции из истории — AnimatedSize, которым
  // уже обёрнут блок истории, сам плавно анимирует уменьшение высоты.
  Future<void> _deleteHistoryEntry(int index) async {
    setState(() {
      goals[currentGoalIndex].history.removeAt(index);
    });
    await _saveGoalData(currentGoalIndex);
  }

  void _quickAdd(double amount) {
    final goal = goals[currentGoalIndex];
    if (goal.targetAmount <= 0) {
      _showSetPriceFirstModal();
      return;
    }
    _updateMoney(amount);
  }

  void _shareApp() {
    // TODO: замени ссылку на реальную ссылку на google диск с apk
    const shareText =
        'Привет! \n'
        'Я пользуюсь приложением Я коплю: мечты. \n'
        'Присоединяйся - оно полностью бесплатное.\n'
        'https://drive.google.com/YOUR_APK_LINK_HERE';
    Share.share(shareText);
  }

  void _checkGoalReached() {
    final goal = goals[currentGoalIndex];
    if (goal.targetAmount > 0 && goal.currentAmount >= goal.targetAmount) {
      final appState = MyApp.of(context)!;
      Navigator.push(
        context,
        createAnimatedRoute(
          Scaffold(
            backgroundColor: appState.isDark ? const Color(0xFF121212) : Colors.white,
            body: SafeArea(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        Icon(Icons.emoji_events_rounded, size: 100, color: appState.primaryColor),
                        const SizedBox(height: 24),
                        Text(
                          'Поздравляю с достижением цели, ${widget.userName}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Ты молодец!',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appState.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Ура!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // (2) Кнопка "назад" в левом верхнем углу
                  Positioned(
                    top: 4,
                    left: 4,
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: appState.isDark ? Colors.white : Colors.black87,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _updateGoal(String newTitle, double newTarget, {double? dailyAllowance, String allowancePeriod = 'day', String? currency, DateTime? targetDate}) async {
    setState(() {
      goals[currentGoalIndex].goalTitle = newTitle;
      goals[currentGoalIndex].targetAmount = newTarget;
      goals[currentGoalIndex].dailyAllowance = dailyAllowance;
      goals[currentGoalIndex].allowancePeriod = allowancePeriod;
      goals[currentGoalIndex].targetDate = targetDate;
      if (currency != null) {
        goals[currentGoalIndex].currency = currency;
      }
    });
    _saveGoalData(currentGoalIndex);
  }

  // (5)+(6) Удаление цели: если она была достигнута — сохраняем её в
  // "Историю желаний", саму цель не удаляем из списка, а сбрасываем к
  // стандартным значениям (название, фото, сумма, карманные).
  Future<void> _deleteGoal(int index) async {
    final goal = goals[index];
    final wasAchieved = goal.targetAmount > 0 && goal.currentAmount >= goal.targetAmount;
    if (wasAchieved) {
      _wishHistory.insert(0, {
        'title': goal.goalTitle,
        'amount': goal.targetAmount,
        'currency': goal.currency,
        'date': DateTime.now().toIso8601String(),
      });
      await _saveWishHistory();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('goal_image_path_$index');
    await prefs.remove('daily_allowance_$index');
    await prefs.remove('allowance_period_$index');
    await prefs.remove('last_allowance_credit_$index');
    await prefs.remove('target_date_$index');
    setState(() {
      goals[index].goalTitle = _ordinalGoalName(index + 1);
      goals[index].targetAmount = 0;
      goals[index].currentAmount = 0;
      goals[index].imagePath = null;
      goals[index].dailyAllowance = null;
      goals[index].allowancePeriod = 'day';
      goals[index].targetDate = null;
      goals[index].currency = '₽';
      goals[index].history = [];
    });
    await _saveGoalData(index);
    _showAppSnackBar(wasAchieved ? 'Цель удалена и сохранена в истории желаний' : 'Цель сброшена');
  }

  // (3) Единый стиль коротких уведомлений — закруглённые, в цвет темы,
  // "плавающие" над низом экрана. Раньше использовался стандартный
  // ScaffoldMessenger.showSnackBar без явной анимации исчезновения —
  // теперь это собственный Overlay-тост, который явно "уплывает" вниз
  // экрана и растворяется, а не пропадает резко.
  void _showAppSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    final appState = MyApp.of(context)!;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        left: 16,
        right: 16,
        bottom: 24 + MediaQuery.of(overlayContext).padding.bottom,
        child: _FlyingToast(
          message: message,
          backgroundColor: isError ? (Colors.red[400] ?? Colors.red) : appState.primaryColor,
          onDismissed: () {
            if (entry.mounted) entry.remove();
          },
        ),
      ),
    );
    overlay.insert(entry);
  }

  void _showComingSoonBottomSheet(String title, String description) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return _SwipeDownToClose(child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_top_rounded, size: 48, color: appState.primaryColor),
              const SizedBox(height: 12),
              const Text('Скоро появится', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: appState.primaryColor)),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appState.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Понятно', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ));
      },
    );
  }

  // (1)+(7) Таблица лидеров: сортировка по убыванию суммы (при равенстве —
  // по имени А-Я) и удаление доната доступно только в режиме разработчика.
  void _showLeaderboardModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return _SwipeDownToClose(child: Container(
          padding: const EdgeInsets.all(24.0),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.volunteer_activism_rounded, size: 48, color: appState.primaryColor),
              const SizedBox(height: 12),
              const Text('Таблица лидеров', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Пожертвования', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: appState.primaryColor)),
              const SizedBox(height: 8),
              const Text(
                'Сравните',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('donations').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Ошибка загрузки данных'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs.toList() ?? [];
                    if (docs.isEmpty) {
                      // (7) "Пустой список" от Firestore при отсутствии
                      // интернета выглядит так же, как реально пустой
                      // список — проверяем реальное соединение отдельно,
                      // чтобы не вводить в заблуждение.
                      return FutureBuilder<bool>(
                        future: _hasInternetConnection(),
                        builder: (context, connSnapshot) {
                          if (connSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (connSnapshot.data == false) {
                            // (6) Раньше было красным и жирным — слишком
                            // тревожно для обычного отсутствия сети,
                            // приводим к тому же спокойному серому стилю,
                            // что и остальные статусные надписи здесь.
                            return const Center(
                              child: Text(
                                'Нет соединения с интернетом',
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }
                          return const Center(
                            child: Text('Пока нет пожертвований', style: TextStyle(color: Colors.grey)),
                          );
                        },
                      );
                    }
                    // Сортировка: сумма по убыванию, при равенстве — имя А-Я
                    docs.sort((a, b) {
                      final da = a.data() as Map<String, dynamic>;
                      final db = b.data() as Map<String, dynamic>;
                      final amtA = (da['amount'] ?? 0) as num;
                      final amtB = (db['amount'] ?? 0) as num;
                      if (amtB != amtA) return amtB.compareTo(amtA);
                      final nameA = (da['name'] ?? '').toString().toLowerCase();
                      final nameB = (db['name'] ?? '').toString().toLowerCase();
                      return nameA.compareTo(nameB);
                    });
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final name = data['name'] ?? 'Аноним';
                        final amount = data['amount'] ?? 0;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: appState.primaryColor.withOpacity(0.15),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(color: appState.primaryColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$amount ₽',
                                style: TextStyle(color: appState.primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              if (_devModeEnabled) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _confirmDeleteDonation(docs[index].id),
                                  child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appState.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Понятно', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ));
      },
    );
  }

  // (1) Подтверждение удаления доната (доступно только в режиме разработчика)
  void _confirmDeleteDonation(String docId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return _SwipeDownToClose(child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text('Удалить пожертвование?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Это действие нельзя отменить.', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: appState.primaryColor,
                          side: BorderSide(color: appState.primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Отмена', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            await FirebaseFirestore.instance.collection('donations').doc(docId).delete();
                          } catch (e) {
                            _showAppSnackBar('Ошибка удаления: $e', isError: true);
                          }
                        },
                        child: const Text('Удалить', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ));
      },
    );
  }

  // (1b) Подтверждение удаления сообщения от пользователя (только в dev-режиме)
  void _confirmDeleteMessage(String docId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return _SwipeDownToClose(child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text('Удалить сообщение?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Это действие нельзя отменить.', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: appState.primaryColor,
                          side: BorderSide(color: appState.primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Отмена', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            await FirebaseFirestore.instance.collection('developer_messages').doc(docId).delete();
                          } catch (e) {
                            _showAppSnackBar('Ошибка удаления: $e', isError: true);
                          }
                        },
                        child: const Text('Удалить', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ));
      },
    );
  }

  void _showSupportModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return _SwipeDownToClose(child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite, size: 48, color: appState.primaryColor),
              const SizedBox(height: 12),
              const Text('Спасибо!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Поддержать проект', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: appState.primaryColor)),
              const SizedBox(height: 8),
              // Номер карты виден как обычный текст, копирование — только
              // по явной кнопке-иконке (а не по тапу в произвольном месте).
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: appState.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Сбербанк: 2202206253667492',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: '2202206253667492'));
                      },
                      child: Icon(Icons.copy_rounded, size: 18, color: appState.primaryColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appState.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Понятно', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ));
      },
    );
  }

  // Всплывающее окно "Сначала укажите цену мечты!" — в стиле "Поддержать
  // проект", но с восклицательным знаком и без строки с картой (окно чуть меньше).
  void _showSetPriceFirstModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return _SwipeDownToClose(child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.priority_high_rounded, size: 48, color: appState.primaryColor),
              const SizedBox(height: 12),
              const Text('Сначала укажите цену мечты', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Для пополнения / траты баланса', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: appState.primaryColor)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appState.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Понятно', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ));
      },
    );
  }

  // Пасхалка: 10 тапов по имени в шапке открывают ввод кода разработчика —
  // но только если имя пользователя указано как "Марат" (с большой буквы,
  // без опечаток). Для всех остальных имён тапы никакого эффекта не имеют.
  void _handleNameTap() {
    if (widget.userName != 'Марат') return;
    if (_devCodeModalOpen) return;
    _nameTapCount++;
    if (_nameTapCount >= 10) {
      _nameTapCount = 0;
      _showDevCodeModal();
    }
  }

  // Блокировка при переборе кода разработчика хранится не локально
  // (SharedPreferences), а в Firestore по аппаратному ID устройства —
  // поэтому её не сбросить ни кнопкой "Сбросить все настройки" (она чистит
  // только SharedPreferences), ни очисткой кэша/данных приложения, ни
  // переустановкой, ни перезагрузкой телефона: счётчик живёт на сервере и
  // привязан к самому устройству, а не к данным приложения на нём.
  Future<DocumentReference<Map<String, dynamic>>?> _devCodeLockoutDocRef() async {
    final deviceId = await _getDeviceId();
    if (deviceId == null || deviceId.isEmpty) return null;
    return FirebaseFirestore.instance.collection('dev_code_lockout').doc(deviceId);
  }

  Future<Duration?> _devCodeLockoutRemaining() async {
    try {
      final docRef = await _devCodeLockoutDocRef();
      if (docRef == null) return null;
      final snap = await docRef.get();
      final lockoutUntilMs = (snap.data()?['lockout_until_ms'] as num?)?.toInt() ?? 0;
      final remainingMs = lockoutUntilMs - DateTime.now().millisecondsSinceEpoch;
      if (remainingMs <= 0) return null;
      return Duration(milliseconds: remainingMs);
    } catch (e) {
      // ignore: avoid_print
      print('Не удалось проверить блокировку кода разработчика: $e');
      return null;
    }
  }

  Future<Duration?> _registerWrongDevCodeAttempt() async {
    try {
      final docRef = await _devCodeLockoutDocRef();
      if (docRef == null) return null;
      return await FirebaseFirestore.instance.runTransaction<Duration?>((transaction) async {
        final snap = await transaction.get(docRef);
        final failCount = ((snap.data()?['fail_count'] as num?)?.toInt() ?? 0) + 1;
        final update = <String, dynamic>{'fail_count': failCount};
        Duration? lockout;
        if (failCount >= 5) {
          final lockoutMinutes = (failCount - 4) * 5;
          final lockoutUntil = DateTime.now().add(Duration(minutes: lockoutMinutes));
          update['lockout_until_ms'] = lockoutUntil.millisecondsSinceEpoch;
          lockout = Duration(minutes: lockoutMinutes);
        }
        transaction.set(docRef, update, SetOptions(merge: true));
        return lockout;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Не удалось зафиксировать неверную попытку кода разработчика: $e');
      return null;
    }
  }

  Future<void> _resetDevCodeAttempts() async {
    try {
      final docRef = await _devCodeLockoutDocRef();
      if (docRef == null) return;
      await docRef.set({'fail_count': 0, 'lockout_until_ms': 0});
    } catch (e) {
      // ignore: avoid_print
      print('Не удалось сбросить счётчик кода разработчика: $e');
    }
  }

  // (1) Функция принудительной онлайн-проверки удалена: код разработчика
  // проверяется полностью локально, вход больше не требует интернета.

  String _formatLockoutDuration(Duration d) {
    final totalMinutes = (d.inSeconds / 60).ceil();
    return '$totalMinutes ${pluralizeRu(totalMinutes, 'минуту', 'минуты', 'минут')}';
  }

  // (10) Модалка ввода кода не закрывается случайно от тапа по фону
  // (isDismissible: false) и от системного drag-хендла (enableDrag: false),
  // но осознанный свайп вниз (через _SwipeDownToClose) по-прежнему закрывает
  // её, как и все остальные всплывающие окна — так же, как и крестик.
  void _showDevCodeModal() async {
    if (_devCodeModalOpen) return;
    _devCodeModalOpen = true;
    final codeController = TextEditingController();
    bool showWrongCodeError = false;
    String? errorMessage;
    // Если устройство уже заблокировано с прошлого раза — сразу показываем
    // оставшееся время, не дожидаясь новой неверной попытки.
    final existingLockout = await _devCodeLockoutRemaining();
    if (existingLockout != null) {
      showWrongCodeError = true;
      errorMessage = 'Слишком много попыток. Попробуйте через ${_formatLockoutDuration(existingLockout)}';
    }
    if (!mounted) {
      _devCodeModalOpen = false;
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return _SwipeDownToClose(child: StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 8,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    // Небольшой сдвиг влево, чтобы крестик был ближе к краю окна
                    child: Transform.translate(
                      offset: const Offset(-14, 0),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: appState.primaryColor.withOpacity(0.15),
                    child: Icon(Icons.lock_outline_rounded, size: 28, color: appState.primaryColor),
                  ),
                  const SizedBox(height: 16),
                  const Text('Режим разработчика', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                    'Введите код доступа',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: codeController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onChanged: (_) {
                      if (showWrongCodeError) {
                        setModalState(() {
                          showWrongCodeError = false;
                          errorMessage = null;
                        });
                      }
                    },
                  ),
                  // Ошибка/блокировка — красным текстом внутри окна,
                  // не зависит от темы (всегда красный). Сообщение
                  // приходит с сервера (неверный код / кол-во оставшихся
                  // попыток / временная блокировка при переборе).
                  if (showWrongCodeError) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMessage ?? 'Неверный код!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appState.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        // Проверяем блокировку заново на случай, если она
                        // наступила уже после открытия окна.
                        final lockout = await _devCodeLockoutRemaining();
                        if (lockout != null) {
                          setModalState(() {
                            showWrongCodeError = true;
                            errorMessage = 'Слишком много попыток. Попробуйте через ${_formatLockoutDuration(lockout)}';
                          });
                          return;
                        }
                        if (codeController.text.trim() == _decodedDevCode()) {
                          // (1) Если уже в режиме разработчика — не
                          // активируем повторно и не пишем "активирован",
                          // а честно говорим, что уже вошли.
                          if (_devModeEnabled) {
                            if (context.mounted) Navigator.pop(context);
                            _showAppSnackBar('Вы уже вошли в режим разработчика!');
                            return;
                          }
                          // (3) Проверка кода — полностью локальная, без
                          // обращения к серверу: интернет для входа в
                          // режим разработчика больше не требуется.
                          setModalState(() {
                            showWrongCodeError = false;
                            errorMessage = null;
                          });
                          await _resetDevCodeAttempts();
                          if (context.mounted) Navigator.pop(context);
                          _enableDevMode();
                        } else {
                          final newLockout = await _registerWrongDevCodeAttempt();
                          setModalState(() {
                            showWrongCodeError = true;
                            errorMessage = newLockout != null
                                ? 'Слишком много попыток. Попробуйте через ${_formatLockoutDuration(newLockout)}'
                                : 'Неверный код!';
                          });
                        }
                      },
                      child: const Text('Подтвердить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        ));
      },
    ).then((_) {
      // Окно закрылось (любым способом) — снова разрешаем открыть его.
      _devCodeModalOpen = false;
    });
  }

  Future<void> _enableDevMode() async {
    setState(() {
      _devModeEnabled = true;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dev_mode_enabled', true);
    _showAppSnackBar('Режим разработчика активирован!');
  }

  // (3) Выход из режима разработчика (кнопка в настройках)
  Future<void> _disableDevMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dev_mode_enabled', false);
    setState(() {
      _devModeEnabled = false;
    });
    _showAppSnackBar('Режим разработчика выключен');
  }

  // Добавление пожертвования в общую базу (Firestore) — видно на всех
  // устройствах, а не только локально.
  void _showAddDonationModal() {
    final donorNameController = TextEditingController();
    final donorAmountController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return _SwipeDownToClose(child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Добавить пожертвование', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: donorNameController,
                decoration: InputDecoration(
                  labelText: 'Кто отправил',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: donorAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Сумма (в рублях)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appState.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final name = donorNameController.text.trim();
                    final amount = double.tryParse(donorAmountController.text.trim()) ?? 0;
                    if (name.isEmpty || amount <= 0) return;
                    try {
                      await FirebaseFirestore.instance.collection('donations').add({
                        'name': name,
                        'amount': amount,
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        _showAppSnackBar('Пожертвование добавлено для всех пользователей');
                      }
                    } catch (e) {
                      _showAppSnackBar('Ошибка: Firebase не настроен ($e)', isError: true);
                    }
                  },
                  child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ));
      },
    );
  }

  // (9) Сообщение разработчику: недоступно, если сам режим разработчика
  // включён на этом устройстве.
  void _showMessageDeveloperModal() {
    final messageController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return _SwipeDownToClose(child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Сообщить о баге / Идеи', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Опишите проблему или идею — сообщение увидит разработчик.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                minLines: 1,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Сообщение',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appState.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final text = messageController.text.trim();
                    if (text.isEmpty) return;
                    final fullName = widget.userLastName.isNotEmpty
                        ? '${widget.userName} ${widget.userLastName}'
                        : widget.userName;
                    try {
                      await FirebaseFirestore.instance.collection('developer_messages').add({
                        'name': fullName,
                        'message': text,
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        _showAppSnackBar('Сообщение отправлено, спасибо!');
                      }
                    } catch (e) {
                      _showAppSnackBar('Ошибка отправки: $e', isError: true);
                    }
                  },
                  child: const Text('Отправить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ));
      },
    );
  }

  // (9) Для разработчика: история всех сообщений от пользователей
  void _showDeveloperMessagesModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return _SwipeDownToClose(child: Container(
          padding: const EdgeInsets.all(24.0),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mail_outline_rounded, size: 48, color: appState.primaryColor),
              const SizedBox(height: 12),
              const Text('Сообщения от пользователей', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('developer_messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Ошибка загрузки данных'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      // (7) Та же проверка: не путаем "сообщений пока нет"
                      // с "нет интернета".
                      return FutureBuilder<bool>(
                        future: _hasInternetConnection(),
                        builder: (context, connSnapshot) {
                          if (connSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (connSnapshot.data == false) {
                            return const Center(
                              child: Text(
                                'Нет соединения с интернетом',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            );
                          }
                          return const Center(child: Text('Сообщений пока нет', style: TextStyle(color: Colors.grey)));
                        },
                      );
                    }
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (context, index) => const Divider(height: 20),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final name = data['name'] ?? 'Аноним';
                        final message = data['message'] ?? '';
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: appState.primaryColor)),
                                  const SizedBox(height: 4),
                                  Text(message, style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _confirmDeleteMessage(docs[index].id),
                              child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appState.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Понятно', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ));
      },
    );
  }

  // (6) "История желаний" — достигнутые и позже удалённые цели
  void _showWishHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return _SwipeDownToClose(child: Container(
          padding: const EdgeInsets.all(24.0),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 48, color: appState.primaryColor),
              const SizedBox(height: 12),
              const Text('История желаний', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Достигнутые и удалённые мечты',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _wishHistory.isEmpty
                    ? const Center(child: Text('Пока пусто', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _wishHistory.length,
                        separatorBuilder: (context, index) => const Divider(height: 20),
                        itemBuilder: (context, index) {
                          final item = _wishHistory[index];
                          final title = item['title'] ?? '';
                          final amount = item['amount'] ?? 0;
                          final currency = item['currency'] ?? '₽';
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(title.toString(), style: const TextStyle(fontWeight: FontWeight.w500)),
                              ),
                              Text(
                                '$amount $currency',
                                style: TextStyle(color: appState.primaryColor, fontWeight: FontWeight.bold),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appState.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Понятно', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ));
      },
    );
  }

  Future<void> _showSettingsModal() async {
    // (1) Затухание внизу списка теперь отслеживает прокрутку: как только
    // пользователь долистал до самого конца — прятать нечего, и градиент
    // отключается полностью (без него список выглядит просто обрезанным
    // по нижнему краю окна, а не "выцветшим").
    final settingsScrollController = ScrollController();
    bool showBottomFade = true;
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return _SwipeDownToClose(child: StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              // (5) Окно настроек в режиме разработчика получает дополнительные
              // блоки (скачивания, донаты, сообщения, выход), из-за чего без
              // ограничения высоты лист растягивался почти на весь экран.
              // Ограничиваем максимальную высоту, чтобы окно оставалось
              // компактным как обычно, а всё, что не поместилось, было
              // доступно прокруткой внутри (SingleChildScrollView ниже).
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                // (1) Раньше последняя строка списка обрезалась резкой
                // линией по краю окна. ShaderMask плавно "растворяет"
                // последние ~18px в прозрачность — короткий, ненавязчивый
                // переход (а не треть окна), и полностью выключается, когда
                // список докручен до конца (см. NotificationListener ниже).
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    final metrics = notification.metrics;
                    final atBottom = metrics.maxScrollExtent <= 0 ||
                        metrics.pixels >= metrics.maxScrollExtent - 2;
                    if (atBottom == showBottomFade) {
                      setModalState(() => showBottomFade = !atBottom);
                    }
                    return false;
                  },
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      if (!showBottomFade) {
                        // Докручено до конца — градиент полностью
                        // непрозрачный, эффект затухания не виден.
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black, Colors.black],
                        ).createShader(rect);
                      }
                      // Совсем небольшое затухание — раньше 18px тоже
                      // казалось многовато, теперь всего 8px.
                      const fadeHeight = 8.0;
                      final fadeStart = (1 - (fadeHeight / rect.height)).clamp(0.0, 1.0);
                      return LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: const [Colors.black, Colors.black, Colors.transparent],
                        stops: [0.0, fadeStart, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: SingleChildScrollView(
                      controller: settingsScrollController,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    const Text('Настройки', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Тёмная тема'),
                      value: appState.isDark,
                      onChanged: (val) {
                        appState.toggleTheme(val);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Выберите цвет темы', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(
                        appState.lightColors.length,
                        (index) => GestureDetector(
                          onTap: () {
                            appState.setColor(index);
                            Navigator.pop(context);
                          },
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: appState.isDark ? appState.darkColors[index] : appState.lightColors[index],
                            child: appState.selectedColorIndex == index
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: appState.primaryColor,
                          side: BorderSide(color: appState.primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _shareApp,
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Поделиться приложением', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    // (6) История желаний — доступна всем пользователям
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: appState.primaryColor,
                          side: BorderSide(color: appState.primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showWishHistoryModal();
                        },
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('История желаний', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (_devModeEnabled) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.verified_user_rounded, size: 16, color: appState.primaryColor),
                          const SizedBox(width: 6),
                          Text(
                            'Режим разработчика',
                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: appState.primaryColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // (10) Счётчик уникальных скачиваний приложения — считает
                      // устройства (Firestore), повторная установка на то же
                      // устройство счётчик не увеличивает.
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('app_stats')
                            .doc('downloads')
                            .snapshots(),
                        builder: (context, snapshot) {
                          final data = snapshot.data?.data() as Map<String, dynamic>?;
                          final count = (data?['count'] as num?)?.toInt();
                          final displayValue = snapshot.connectionState == ConnectionState.waiting
                              ? '…'
                              : (count?.toString() ?? '—');
                          // (5) Раньше этот пункт был залит сплошным фоном
                          // (F7F2FA/1E1E1E), а остальные пункты режима
                          // разработчика ("Добавить пожертвование" и т.д.) —
                          // OutlinedButton с прозрачным фоном и обводкой.
                          // Приводим к тому же стилю: прозрачный фон, рамка
                          // цвета темы, та же высота 48, как у кнопок ниже.
                          return Container(
                            width: double.infinity,
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: appState.primaryColor),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.download_rounded, size: 18, color: appState.primaryColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Скачиваний приложения',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: appState.primaryColor),
                                    ),
                                  ],
                                ),
                                Text(
                                  displayValue,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: appState.primaryColor),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: appState.primaryColor,
                            side: BorderSide(color: appState.primaryColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showAddDonationModal();
                          },
                          icon: const Icon(Icons.volunteer_activism_outlined),
                          label: const Text('Добавить пожертвование', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      // (9) История сообщений от пользователей — только в dev-режиме
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: appState.primaryColor,
                            side: BorderSide(color: appState.primaryColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showDeveloperMessagesModal();
                          },
                          icon: const Icon(Icons.mail_outline_rounded),
                          label: const Text('Сообщения от пользователей', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      // (3) Выход из режима разработчика
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _disableDevMode();
                          },
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Выйти из режима разработчика', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          appState.resetAllData();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                          );
                        },
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: const Text('Сбросить все настройки', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    ],
                  ),
                ),
                ),
                ),
              ),
            );
          },
        ));
      },
    );
  }

  // (6) Модалка «Информация о цели» — открывается по кнопке-информации в
  // правом нижнем углу карточки цели.
  void _showGoalInfoModal(GoalData goal) {
    final estimate = estimateRemainingToGoal(goal);
    final remaining = goal.targetAmount - goal.currentAmount;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return _SwipeDownToClose(child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: appState.primaryColor, size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Информация о цели', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _goalInfoRow('Название', goal.goalTitle),
              _goalInfoRow('Накоплено', '${goal.currentAmount.toInt()} ${goal.currency}'),
              _goalInfoRow('Цель', '${goal.targetAmount.toInt()} ${goal.currency}'),
              _goalInfoRow('Осталось накопить', '${remaining > 0 ? remaining.toInt() : 0} ${goal.currency}'),
              if (goal.dailyAllowance != null && goal.dailyAllowance! > 0)
                _goalInfoRow(
                  'Карманные',
                  '${goal.dailyAllowance!.toInt()} ${goal.currency} ${allowancePeriodLabel(goal.allowancePeriod)}',
                ),
              if (estimate != null) _goalInfoRow('Осталось копить', estimate),
              if (goal.targetDate != null)
                _goalInfoRow(
                  'Желаемая дата',
                  '${goal.targetDate!.day.toString().padLeft(2, '0')}.${goal.targetDate!.month.toString().padLeft(2, '0')}.${goal.targetDate!.year}',
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appState.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Понятно', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ));
      },
    );
  }

  Widget _goalInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditGoalModal() {
    final goal = goals[currentGoalIndex];
    final titleController = TextEditingController(text: goal.goalTitle);
    final targetController = TextEditingController(text: goal.targetAmount.toStringAsFixed(0));
    final allowanceController = TextEditingController(
      text: goal.dailyAllowance != null ? goal.dailyAllowance!.toStringAsFixed(0) : '',
    );
    String selectedCurrency = goal.currency;
    String selectedAllowancePeriod = goal.allowancePeriod;
    DateTime? selectedTargetDate = goal.targetDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return _SwipeDownToClose(child: StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'Изменить цель "${goal.goalTitle}"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        // (3) Убрал IconButton совсем: у Material-кнопки
                        // внутри всегда зарезервирован "холст" под тап-зону
                        // и ripple, из-за чего сама иконка почти никогда не
                        // лежит точно по краю бокса, сколько её ни двигай.
                        // GestureDetector + Icon рисует иконку ровно в
                        // границах своего size — она физически совпадает с
                        // правым краем поля «Название цели» ниже.
                        GestureDetector(
                          onTap: () => _showGoalInfoModal(goal),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 2),
                            child: Icon(Icons.info_outline_rounded, color: appState.primaryColor, size: 24),
                          ),
                        ),
                      ],
                    ),
                    // (2) Между заголовком "Изменить цель ..." и полем
                    // "Название цели" был слишком маленький отступ (4px) —
                    // увеличен, чтобы окно не выглядело слипшимся.
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Название цели',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: targetController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Целевая сумма',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Валюта цели', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 8),
                    Row(
                      children: ['₽', '€', '\$'].map((cur) {
                        final selected = cur == selectedCurrency;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setModalState(() => selectedCurrency = cur),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected ? appState.primaryColor : appState.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                cur,
                                style: TextStyle(
                                  color: selected ? Colors.white : appState.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: allowanceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Карманные (необязательно)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    // (1) Период, за который приходят карманные деньги —
                    // день/неделя/месяц/год. По умолчанию "День", как и было.
                    const SizedBox(height: 12),
                    const Text('Как часто приходят карманные', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 8),
                    Row(
                      children: ['day', 'week', 'month', 'year'].map((period) {
                        final selected = period == selectedAllowancePeriod;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setModalState(() => selectedAllowancePeriod = period),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected ? appState.primaryColor : appState.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                allowancePeriodShortLabel(period),
                                style: TextStyle(
                                  color: selected ? Colors.white : appState.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    // (5)/(6) Желаемая дата накопления редактируется
                    // только здесь (в "Изменить цель"); в информации о
                    // цели она показывается уже неизменяемым параметром.
                    // Только дата, без конкретного времени — время не
                    // спрашиваем и не показываем.
                    const SizedBox(height: 16),
                    const Text('Желаемая дата накопления (необязательно)', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: selectedTargetDate ?? DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(DateTime.now().year + 50),
                              );
                              if (pickedDate == null) return;
                              setModalState(() {
                                selectedTargetDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: appState.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.event_outlined, size: 18, color: appState.primaryColor),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      selectedTargetDate != null
                                          ? '${selectedTargetDate!.day.toString().padLeft(2, '0')}.${selectedTargetDate!.month.toString().padLeft(2, '0')}.${selectedTargetDate!.year}'
                                          : 'Не выбрана',
                                      style: TextStyle(color: appState.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (selectedTargetDate != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => setModalState(() => selectedTargetDate = null),
                            icon: const Icon(Icons.close_rounded),
                            color: Colors.grey,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appState.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          final newTitle = titleController.text.trim();
                          final newTarget = double.tryParse(targetController.text.trim()) ?? goal.targetAmount;
                          final allowanceText = allowanceController.text.trim();
                          final newAllowance = allowanceText.isEmpty ? null : double.tryParse(allowanceText);
                          if (newTitle.isNotEmpty && newTarget >= 0) {
                            _updateGoal(
                              newTitle,
                              newTarget,
                              dailyAllowance: newAllowance,
                              allowancePeriod: selectedAllowancePeriod,
                              currency: selectedCurrency,
                              targetDate: selectedTargetDate,
                            );
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    // (5) Удаление цели — сбрасывает название/сумму/фото,
                    // саму цель (её слот) не удаляет полностью.
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Text('Удалить цель?'),
                              content: const Text(
                                'Название, сумма и фото сбросятся к стандартным. Если цель была достигнута, она сохранится в «Истории желаний».',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Отмена'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    Navigator.pop(context);
                                    _deleteGoal(currentGoalIndex);
                                  },
                                  child: const Text('Удалить', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Удалить цель', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ));
      },
    );
  }

  void _showTransactionBottomSheet(bool isAdding) {
    final goal = goals[currentGoalIndex];
    if (goal.targetAmount <= 0) {
      _showSetPriceFirstModal();
      return;
    }

    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return _SwipeDownToClose(child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAdding ? 'Пополнить копилку' : 'Потратить из копилки',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Сумма',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appState.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    final val = double.tryParse(controller.text.trim()) ?? 0;
                    if (val > 0) {
                      Navigator.pop(context);
                      _updateMoney(isAdding ? val : -val);
                    }
                  },
                  child: Text(isAdding ? 'Добавить' : 'Списать', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ));
      },
    );
  }

  int _versionTapCount = 0;

  void _handleVersionTap() {
    _versionTapCount++;
    if (_versionTapCount >= 5) {
      _versionTapCount = 0;
      _showEasterEggScreen();
    }
  }

  void _showEasterEggScreen() {
    final appState = MyApp.of(context)!;
    Navigator.push(
      context,
      createAnimatedRoute(
        Scaffold(
          backgroundColor: appState.isDark ? const Color(0xFF121212) : Colors.white,
          body: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: appState.primaryColor.withOpacity(0.15),
                        child: Icon(Icons.beach_access_rounded, size: 36, color: appState.primaryColor),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Марат, главный разработчик этого приложения, заслуживает отдых на Бали',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appState.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Согласен', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: appState.primaryColor, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          // Специально ничего не делает при нажатии — кнопка
                          // "для вида", а не для реального выбора.
                          onPressed: () {},
                          child: Text(
                            'Нет',
                            style: TextStyle(color: appState.primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // (2) Кнопка "назад" в левом верхнем углу
                Positioned(
                  top: 4,
                  left: 4,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: appState.isDark ? Colors.white : Colors.black87,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context)!;
    final isDark = appState.isDark;
    final fullName = widget.userLastName.isNotEmpty ? '${widget.userName} ${widget.userLastName}' : widget.userName;
    final bool onAddSlide = currentGoalIndex >= goals.length;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _handleNameTap,
          behavior: HitTestBehavior.opaque,
          child: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                appState.primaryColor.withOpacity(0.35),
                isDark ? const Color(0xFF121212) : const Color(0xFFFBF8FF),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: _showLeaderboardModal,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettingsModal,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Свайпаемый блок целей + последний слайд — добавление новой цели
            SizedBox(
              height: 300,
              child: PageView.builder(
                controller: _pageController,
                itemCount: goals.length + 1,
                onPageChanged: (index) {
                  // (6) Вибро-отклик при смене цели — и при свайпе, и при
                  // переключении тапом по точке (см. ниже), так как оба
                  // способа приводят сюда же.
                  HapticFeedback.selectionClick();
                  setState(() {
                    currentGoalIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  if (index == goals.length) {
                    // Слайд с кнопкой добавления новой цели
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Center(
                          child: GestureDetector(
                            onTap: _addNewGoal,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 32,
                                  backgroundColor: appState.primaryColor.withOpacity(0.12),
                                  child: Icon(Icons.add, size: 36, color: appState.primaryColor),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Добавить цель',
                                  style: TextStyle(color: appState.primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final goal = goals[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: goal.imagePath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // Размытая увеличенная копия фото — заполняет весь блок
                                          Image.file(
                                            File(goal.imagePath!),
                                            fit: BoxFit.cover,
                                          ),
                                          BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                                            child: Container(
                                              color: Colors.black.withOpacity(0.12),
                                            ),
                                          ),
                                          // Чёткое фото поверх, без обрезки
                                          Center(
                                            child: Image.file(
                                              File(goal.imagePath!),
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: appState.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_a_photo_outlined, color: appState.primaryColor, size: 36),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Цель ${index + 1}: Нажмите для фото',
                                            style: TextStyle(color: appState.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            goal.goalTitle,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          // (3) Карманные и оценка срока накопления — теперь
                          if (goal.dailyAllowance != null && goal.dailyAllowance! > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Карманные: ${goal.dailyAllowance!.toInt()} ${goal.currency} ${allowancePeriodLabel(goal.allowancePeriod)}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            '${goal.currentAmount.toInt()} / ${goal.targetAmount.toInt()} ${goal.currency}',
                            style: TextStyle(fontSize: 18, color: appState.primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // (4)/(6) Индикатор точек для свайпа целей (включая слайд
            // добавления) — теперь ещё и кликабелен (тап по точке сразу
            // переключает на неё), а сама смена ширины/цвета анимирована
            // (AnimatedContainer), из-за чего активная точка визуально
            // "перетекает" в соседнюю, а не переключается скачком.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(goals.length + 1, (index) {
                return GestureDetector(
                  onTap: () {
                    if (index == currentGoalIndex) return;
                    HapticFeedback.selectionClick();
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Padding(
                    // Увеличенная зона нажатия вокруг маленькой точки —
                    // сам визуальный размер точки не меняется.
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: currentGoalIndex == index ? 16 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: currentGoalIndex == index ? appState.primaryColor : Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            if (!onAddSlide) ...[
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appState.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => _showTransactionBottomSheet(true),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Пополнить', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: BorderSide(color: appState.primaryColor, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => _showTransactionBottomSheet(false),
                        child: Text(
                          'Потратил',
                          style: TextStyle(color: appState.primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showEditGoalModal,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: appState.primaryColor,
                      child: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Кнопки быстрого пополнения
              Row(
                children: <int>[100, 500, 1000].map((amount) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: BorderSide(color: appState.primaryColor.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => _quickAdd(amount.toDouble()),
                        child: Text(
                          '+$amount ${goals[currentGoalIndex].currency}',
                          style: TextStyle(color: appState.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              const Text('История операций', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              // AnimatedSize — плавно меняет высоту блока и при увеличении, и
              // при уменьшении истории (например, после свайп-удаления записи).
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: goals[currentGoalIndex].history.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              'Операций пока нет',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: goals[currentGoalIndex].history.length,
                          separatorBuilder: (context, index) => const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final item = goals[currentGoalIndex].history[index];
                            final isAdd = item.startsWith('+');
                            // (4) Свайп влево — удалить запись; общая высота
                            // блока (AnimatedSize) плавно уменьшится сама.
                            return Dismissible(
                              key: ValueKey('hist_${currentGoalIndex}_${index}_$item'),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => _deleteHistoryEntry(index),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 4),
                                child: const Icon(Icons.delete_outline, color: Colors.red),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isAdd ? 'Пополнение' : 'Списание',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    item,
                                    style: TextStyle(
                                      color: isAdd ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ] else ...[
              Center(
                child: Text(
                  'Нажмите «+», чтобы добавить новую цель',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Карточка «Поддержать проект»
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F2FA),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Icon(Icons.favorite, color: appState.primaryColor, size: 36),
                  const SizedBox(height: 12),
                  const Text(
                    'Поддержать проект',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Приложение абсолютно бесплатное и без подписок!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: BorderSide(color: isDark ? Colors.white38 : Colors.grey[700]!),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _devModeEnabled ? null : _showSupportModal,
                    child: Text(
                      _devModeEnabled ? 'Недоступно (вы разработчик)' : 'Отправить донат',
                      style: TextStyle(color: isDark ? Colors.white : Colors.brown[800], fontWeight: FontWeight.w600),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Карточка «Наш телеграм канал» — теперь кнопка реально отправляет
            // сообщение разработчику; недоступна на устройстве самого разработчика.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F2FA),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Icon(Icons.send_rounded, color: appState.primaryColor, size: 36),
                  const SizedBox(height: 12),
                  const Text(
                    'Сообщить о багах / идее',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Сообщайте о багах, делитесь идеями и следите за обновлениями!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: BorderSide(color: isDark ? Colors.white38 : Colors.grey[700]!),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _devModeEnabled
                        ? null
                        : _showMessageDeveloperModal,
                    child: Text(
                      _devModeEnabled ? 'Недоступно (вы разработчик)' : 'Сообщить о баге / Идеи',
                      style: TextStyle(color: isDark ? Colors.white : Colors.brown[800], fontWeight: FontWeight.w600),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Строка с версией приложения в самом низу — 5 тапов открывают пасхалку
            Center(
              child: GestureDetector(
                onTap: _handleVersionTap,
                behavior: HitTestBehavior.opaque,
                child: const Text(
                  'Я Коплю: мечты v.2.3 (beta)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
