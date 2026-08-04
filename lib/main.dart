import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase нужен для режима разработчика (пожертвования видны на всех
  // устройствах). Если проект ещё не настроен через `flutterfire configure`,
  // оборачиваем в try/catch, чтобы остальное приложение работало без сбоев.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // ignore: avoid_print
    print('Firebase init failed (ещё не настроен?): $e');
  }
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
                    _buildFeatureItem(Icons.person_outline, 'Персонализация', 'Указывай имя и фамилию.', appState.primaryColor),
                    const Divider(height: 16),
                    _buildFeatureItem(Icons.image_outlined, 'Визуализация мечты', 'Добавляй фото двух целей.', appState.primaryColor),
                    const Divider(height: 16),
                    _buildFeatureItem(Icons.palette_outlined, 'Дизайн и темы', 'Выбирай любимый цвет темы.', appState.primaryColor),
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
                      'Выберете цвет темы',
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

  Widget _buildFeatureItem(IconData icon, String title, String subtitle, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
  String currency;

  GoalData({
    required this.currentAmount,
    required this.targetAmount,
    required this.goalTitle,
    required this.history,
    this.imagePath,
    this.dailyAllowance,
    this.currency = '₽',
  });
}

class HomeScreen extends StatefulWidget {
  final String userName;
  final String userLastName;

  const HomeScreen({super.key, required this.userName, required this.userLastName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentGoalIndex = 0;
  final PageController _pageController = PageController();

  int _nameTapCount = 0;
  bool _devModeEnabled = false;

  List<GoalData> goals = [
    GoalData(currentAmount: 0, targetAmount: 0, goalTitle: 'Первая мечта', history: []),
    GoalData(currentAmount: 0, targetAmount: 0, goalTitle: 'Вторая мечта', history: []),
  ];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAllGoals();
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
    setState(() {
      _devModeEnabled = devMode;
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
        goals[i].currency = prefs.getString('goal_currency_$i') ?? '₽';
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
    } else {
      await prefs.remove('daily_allowance_$index');
    }
    await prefs.setString('goal_currency_$index', goals[index].currency);
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

  void _quickAdd(double amount) {
    final goal = goals[currentGoalIndex];
    if (goal.targetAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала укажите цену мечты!')),
      );
      return;
    }
    _updateMoney(amount);
  }

  void _shareApp() {
    // TODO: замени ссылку на реальную ссылку на google диск с apk
    const shareText =
        'Привет! Я пользуюсь этим приложением. Присоединяйся!\n'
        'Я Коплю: мечты\n'
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
              child: Padding(
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
            ),
          ),
        ),
      );
    }
  }

  Future<void> _updateGoal(String newTitle, double newTarget, {double? dailyAllowance, String? currency}) async {
    setState(() {
      goals[currentGoalIndex].goalTitle = newTitle;
      goals[currentGoalIndex].targetAmount = newTarget;
      goals[currentGoalIndex].dailyAllowance = dailyAllowance;
      if (currency != null) {
        goals[currentGoalIndex].currency = currency;
      }
    });
    _saveGoalData(currentGoalIndex);
  }

  void _showComingSoonBottomSheet(String title, String description) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return Padding(
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
        );
      },
    );
  }

  void _showLeaderboardModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return Padding(
          padding: const EdgeInsets.all(24.0),
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
                'Сравнение накоплений и достижения других пользователей!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
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
        );
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
        return Padding(
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
              const Text(
                'Сбербанк: 2202206253667492',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
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
        );
      },
    );
  }

  // Пасхалка: 10 тапов по имени в шапке открывают ввод кода разработчика
  void _handleNameTap() {
    _nameTapCount++;
    if (_nameTapCount >= 10) {
      _nameTapCount = 0;
      _showDevCodeModal();
    }
  }

  void _showDevCodeModal() {
    final codeController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 28,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    if (codeController.text.trim() == '838995') {
                      Navigator.pop(context);
                      _enableDevMode();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Неверный код')),
                      );
                    }
                  },
                  child: const Text('Подтвердить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _enableDevMode() async {
    setState(() {
      _devModeEnabled = true;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dev_mode_enabled', true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Режим разработчика активирован!')),
      );
    }
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
        return Padding(
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Пожертвование добавлено для всех пользователей')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ошибка: Firebase не настроен ($e)')),
                        );
                      }
                    }
                  },
                  child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
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
                ],
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
        );
      },
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final appState = MyApp.of(context)!;
        return StatefulBuilder(
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
                    Text('Изменить цель ${currentGoalIndex + 1}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                        labelText: 'Карманные в день (необязательно)',
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
                          final newTitle = titleController.text.trim();
                          final newTarget = double.tryParse(targetController.text.trim()) ?? goal.targetAmount;
                          final allowanceText = allowanceController.text.trim();
                          final newAllowance = allowanceText.isEmpty ? null : double.tryParse(allowanceText);
                          if (newTitle.isNotEmpty && newTarget >= 0) {
                            _updateGoal(newTitle, newTarget, dailyAllowance: newAllowance, currency: selectedCurrency);
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTransactionBottomSheet(bool isAdding) {
    final goal = goals[currentGoalIndex];
    if (goal.targetAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала укажите цену мечты!')),
      );
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
        return Padding(
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
        );
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
            child: Padding(
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
                          const SizedBox(height: 4),
                          Text(
                            '${goal.currentAmount.toInt()} / ${goal.targetAmount.toInt()} ${goal.currency}',
                            style: TextStyle(fontSize: 18, color: appState.primaryColor, fontWeight: FontWeight.bold),
                          ),
                          if (goal.dailyAllowance != null && goal.dailyAllowance! > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Карманные: ${goal.dailyAllowance!.toInt()} ${goal.currency}/день',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // Индикатор точек для свайпа целей (включая слайд добавления)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(goals.length + 1, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentGoalIndex == index ? 16 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: currentGoalIndex == index ? appState.primaryColor : Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
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
              // AnimatedSize — плавно меняет высоту блока при переключении
              // между целями с разной длиной истории (вместо резкого скачка).
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
                            return Row(
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
                    onPressed: _showSupportModal,
                    child: Text(
                      'Отправить донат',
                      style: TextStyle(color: isDark ? Colors.white : Colors.brown[800], fontWeight: FontWeight.w600),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Карточка «Наш телеграм канал»
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
                    'Наш телеграм канал',
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
                    onPressed: () => _showComingSoonBottomSheet(
                      'Телеграм канал',
                      'Наш официальный телеграм-канал с обновлениями откроется совсем скоро!',
                    ),
                    child: Text(
                      'Сообщить о баге / Идеи',
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
