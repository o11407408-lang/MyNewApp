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
    print('Firebase init failed: $e');
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
                    _buildFeatureItem(Icons.image_outlined, 'Визуализация мечты', 'Добавляй фото целей.', appState.primaryColor),
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
      appBar: AppBar(
        // 2) Кнопка назад в левом верхнем углу
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
                  'Здравствуйте, $fullName!\nПоздравляем с окончанием цели!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int currentGoalIndex = 0;
  final PageController _pageController = PageController();

  int _nameTapCount = 0;
  bool _devModeEnabled = false;

  List<GoalData> goals = [
    GoalData(currentAmount: 0, targetAmount: 0, goalTitle: 'Первая мечта', history: []),
    GoalData(currentAmount: 0, targetAmount: 0, goalTitle: 'Вторая мечта', history: []),
  ];

  // 6) История желаний (перемещаются сюда после сброса/достижения)
  List<Map<String, String>> completedWishesHistory = [];
  // 9) Список писем разработчику
  List<Map<String, String>> developerMessages = [];

  // 4) Контроллер для плавной двунаправленной анимации истории операций
  bool _isHistoryExpanded = false;
  late AnimationController _historyAnimController;
  late Animation<double> _historyAnimation;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _historyAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _historyAnimation = CurvedAnimation(
      parent: _historyAnimController,
      curve: Curves.easeInOut,
    );
    _loadAllGoals();
  }

  @override
  void dispose() {
    _historyAnimController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _toggleHistoryAnimation() {
    setState(() {
      _isHistoryExpanded = !_isHistoryExpanded;
      if (_isHistoryExpanded) {
        _historyAnimController.forward();
      } else {
        _historyAnimController.reverse();
      }
    });
  }

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
    
    // Загрузка истории желаний
    final savedWishesTitles = prefs.getStringList('completed_wishes_titles') ?? [];
    final savedWishesDates = prefs.getStringList('completed_wishes_dates') ?? [];
    completedWishesHistory = List.generate(savedWishesTitles.length, (i) => {
      'title': savedWishesTitles[i],
      'date': savedWishesDates[i],
    });

    // Загрузка писем разработчику
    final savedMsgTexts = prefs.getStringList('dev_msg_texts') ?? [];
    final savedMsgTimes = prefs.getStringList('dev_msg_times') ?? [];
    developerMessages = List.generate(savedMsgTexts.length, (i) => {
      'message': savedMsgTexts[i],
      'time': savedMsgTimes[i],
    });

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
    } else {
      await prefs.remove('goal_image_path_$index');
    }
    if (goals[index].dailyAllowance != null) {
      await prefs.setDouble('daily_allowance_$index', goals[index].dailyAllowance!);
    } else {
      await prefs.remove('daily_allowance_$index');
    }
    await prefs.setString('goal_currency_$index', goals[index].currency);
  }

  Future<void> _saveCompletedWishes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('completed_wishes_titles', completedWishesHistory.map((e) => e['title']!).toList());
    await prefs.setStringList('completed_wishes_dates', completedWishesHistory.map((e) => e['date']!).toList());
  }

  Future<void> _saveDevMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dev_msg_texts', developerMessages.map((e) => e['message']!).toList());
    await prefs.setStringList('dev_msg_times', developerMessages.map((e) => e['time']!).toList());
  }

  // 5) Кнопка удаления/сброса цели в кнопке «Изменить»
  void _resetCurrentGoal() {
    setState(() {
      final oldTitle = goals[currentGoalIndex].goalTitle;
      completedWishesHistory.add({
        'title': oldTitle,
        'date': DateTime.now().toString().substring(0, 10),
      });
      _saveCompletedWishes();

      goals[currentGoalIndex].goalTitle = _ordinalGoalName(currentGoalIndex + 1);
      goals[currentGoalIndex].targetAmount = 0.0;
      goals[currentGoalIndex].currentAmount = 0.0;
      goals[currentGoalIndex].imagePath = null;
      goals[currentGoalIndex].history.clear();
      goals[currentGoalIndex].dailyAllowance = null;
    });
    _saveGoalData(currentGoalIndex);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Цель сброшена до стандартных параметров и перенесена в историю желаний')),
    );
  }

  // 7) Сортировка таблицы лидеров: по сумме (убывание), при равенстве — по имени (алфавит)
  List<Map<String, dynamic>> _getSortedLeaderboard() {
    List<Map<String, dynamic>> allOps = [];
    for (int i = 0; i < goals.length; i++) {
      for (var entry in goals[i].history) {
        if (entry.startsWith('+')) {
          final parts = entry.split(' ');
          if (parts.length >= 2) {
            final amount = double.tryParse(parts[1]) ?? 0.0;
            // Имя доната (берем оставшуюся часть строки или дефолт)
            final name = parts.length > 2 ? parts.skip(2).join(' ') : 'Аноним';
            allOps.add({'name': name, 'amount': amount});
          }
        }
      }
    }
    allOps.sort((a, b) {
      int cmp = (b['amount'] as double).compareTo(a['amount'] as double);
      if (cmp != 0) return cmp;
      return (a['name'] as String).compareTo(b['name'] as String);
    });
    return allOps;
  }

  // 10) Ввод пароля разработчика с крестиком и защитой от случайного закрытия
  void _showDevPasswordDialog() {
    final TextEditingController passController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false, // Защита от закрытия тапом вне окна
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Режим разработчика'),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context), // Выход только по крестику
              ),
            ],
          ),
          content: TextField(
            controller: passController,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Введите пароль'),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (passController.text == '1234') {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('dev_mode_enabled', true);
                  setState(() {
                    _devModeEnabled = true;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Режим разработчика успешно активирован!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Неверный пароль')),
                  );
                }
              },
              child: const Text('Войти'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context)!;
    final currentGoal = goals[currentGoalIndex];
    final leaderboard = _getSortedLeaderboard();

    return Scaffold(
      appBar: AppBar(
        // 10) Нажатие на имя 10 раз вызывает окно пароля
        title: GestureDetector(
          onTap: () {
            if (!_devModeEnabled) {
              _nameTapCount++;
              if (_nameTapCount >= 10) {
                _nameTapCount = 0;
                _devModeEnabled ? null : _showDevPasswordDialog();
              }
            }
          },
          child: Text('${widget.userName} (${currentGoal.goalTitle})'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                createAnimatedRoute(SettingsScreen(
                  userName: widget.userName,
                  userLastName: widget.userLastName,
                  completedWishesHistory: completedWishesHistory,
                  developerMessages: developerMessages,
                  devModeEnabled: _devModeEnabled,
                  onDevModeChanged: (val) async {
                    setState(() {
                      _devModeEnabled = val;
                    });
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('dev_mode_enabled', val);
                  },
                  onDeleteDonation: (goalIdx, historyIdx) {
                    setState(() {
                      goals[goalIdx].history.removeAt(historyIdx);
                    });
                    _saveGoalData(goalIdx);
                  },
                  goals: goals,
                  onResetGoal: _resetCurrentGoal,
                )),
              );
              _loadAllGoals();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Карточка цели
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.between,
                        children: [
                          Text(currentGoal.goalTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              // Диалог изменения/сброса цели
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Управление целью'),
                                  content: const Text('Хотите сбросить текущую цель и перенести ее в историю желаний?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Отмена'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _resetCurrentGoal();
                                      },
                                      child: const Text('Сбросить цель (Удалить)'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('${currentGoal.currentAmount} / ${currentGoal.targetAmount} ${currentGoal.currency}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      
                      // 4) Плавная двунаправленная анимация истории операций
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('История операций', style: TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: Icon(_isHistoryExpanded ? Icons.expand_less : Icons.expand_more),
                            onPressed: _toggleHistoryAnimation,
                          ),
                        ],
                      ),
                      SizeTransition(
                        sizeFactor: _historyAnimation,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: currentGoal.history.isEmpty
                              .toString() == 'true' && currentGoal.history.isEmpty
                              ? const Text('История пуста')
                              : Column(
                                  children: currentGoal.history.map((h) => ListTile(
                                    title: Text(h),
                                    dense: true,
                                  )).toList(),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 7) Таблица лидеров (сортированная)
              const Text('Таблица лидеров', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              leaderboard.isEmpty
                  ? const Text('Пока нет донатов')
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: leaderboard.length,
                      itemBuilder: (context, index) {
                        final item = leaderboard[index];
                        return ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(item['name']),
                          trailing: Text('${item['amount']} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
              const SizedBox(height: 30),

              // Пасхалка с версией
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      createAnimatedRoute(const VersionEasterEggScreen()),
                    );
                  },
                  child: const Text('Версия 1.0.0 (Пасхалка)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 2) Экран пасхалки с версией и кнопкой Назад слева вверху
class VersionEasterEggScreen extends StatelessWidget {
  const VersionEasterEggScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Пасхалка версии'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Поздравляем с окончанием цели! Вы великолепны и успешно добрались до пасхалки!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// Экран настроек
class SettingsScreen extends StatefulWidget {
  final String userName;
  final String userLastName;
  final List<Map<String, String>> completedWishesHistory;
  final List<Map<String, String>> developerMessages;
  final bool devModeEnabled;
  final ValueChanged<bool> onDevModeChanged;
  final Function(int goalIndex, int historyIndex) onDeleteDonation;
  final List<GoalData> goals;
  final VoidCallback onResetGoal;

  const SettingsScreen({
    super.key,
    required this.userName,
    required this.userLastName,
    required this.completedWishesHistory,
    required this.developerMessages,
    required this.devModeEnabled,
    required this.onDevModeChanged,
    required this.onDeleteDonation,
    required this.goals,
    required this.onResetGoal,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _msgController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 3) Кнопка выхода из режима разработчика в настройках
          if (widget.devModeEnabled)
            Card(
              color: Colors.green.withOpacity(0.1),
              child: ListTile(
                title: const Text('Режим разработчика активен', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () {
                    widget.onDevModeChanged(false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Режим разработчика выключен')),
                    );
                  },
                  child: const Text('Выйти'),
                ),
              ),
            ),
          const SizedBox(height: 10),

          // 6) История желаний в настройках
          const Text('История желаний', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          widget.completedWishesHistory.isEmpty
              .toString() == 'true' && widget.completedWishesHistory.isEmpty
              ? const Text('Пока нет завершенных целей')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.completedWishesHistory.length,
                  itemBuilder: (context, index) {
                    final wish = widget.completedWishesHistory[index];
                    return ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(wish['title'] ?? ''),
                      subtitle: Text('Дата достижения/сброса: ${wish['date']}'),
                    );
                  },
                ),
          const Divider(height: 30),

          // 9) Сообщение разработчику (недоступно если режим разработчика включен)
          const Text('Сообщение разработчику', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          widget.devModeEnabled
              ? const Text('Функция отправки недоступна, так как включен режим разработчика.', style: TextStyle(color: Colors.orange))
              : Column(
                  children: [
                    TextField(
                      controller: _msgController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Опишите баг или предложите идею...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (_msgController.text.trim().isNotEmpty) {
                          widget.developerMessages.add({
                            'message': _msgController.text.trim(),
                            'time': DateTime.now().toString().substring(0, 16),
                          });
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setStringList('dev_msg_texts', widget.developerMessages.map((e) => e['message']!).toList());
                          await prefs.setStringList('dev_msg_times', widget.developerMessages.map((e) => e['time']!).toList());
                          _msgController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Сообщение успешно отправлено разработчику!')),
                          );
                          setState(() {});
                        }
                      },
                      child: const Text('Отправить'),
                    ),
                  ],
                ),

          // 9) История писем для разработчика в настройках
          if (widget.devModeEnabled) ...[
            const Divider(height: 30),
            const Text('История входящих писем (Режим разработчика)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple)),
            const SizedBox(height: 8),
            widget.developerMessages.isEmpty
                ? const Text('Писем пока нет')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.developerMessages.length,
                    itemBuilder: (context, index) {
                      final msg = widget.developerMessages[index];
                      return Card(
                        child: ListTile(
                          title: Text(msg['message'] ?? ''),
                          subtitle: Text(msg['time'] ?? ''),
                        ),
                      );
                    },
                  ),
          ],

          // 1) Удаление донатов в режиме разработчика
          if (widget.devModeEnabled) ...[
            const Divider(height: 30),
            const Text('Управление донатами (Режим разработчика)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.goals.length,
              itemBuilder: (context, goalIndex) {
                final goal = widget.goals[goalIndex];
                if (goal.history.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Цель: ${goal.goalTitle}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ...List.generate(goal.history.length, (histIndex) {
                      final hist = goal.history[histIndex];
                      return ListTile(
                        title: Text(hist),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            widget.onDeleteDonation(goalIndex, histIndex);
                            setState(() {});
                          },
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
