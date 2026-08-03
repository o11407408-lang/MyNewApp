import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    Colors.lightBlue,
    Colors.blue,
    Colors.purple,
  ];

  final List<Color> darkColors = [
    const Color(0xFFE57373),
    const Color(0xFFFFB74D),
    const Color(0xFF81C784),
    const Color(0xFF4FC3F7),
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
                      'выберете цвет темы',
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

  GoalData({
    required this.currentAmount,
    required this.targetAmount,
    required this.goalTitle,
    required this.history,
    this.imagePath,
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

  List<GoalData> goals = [
    GoalData(currentAmount: 0, targetAmount: 0, goalTitle: 'Цель 1', history: []),
    GoalData(currentAmount: 0, targetAmount: 0, goalTitle: 'Цель 2', history: []),
  ];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAllGoals();
  }

  Future<void> _loadAllGoals() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (int i = 0; i < 2; i++) {
        goals[i].currentAmount = prefs.getDouble('current_amount_$i') ?? 0.0;
        goals[i].targetAmount = prefs.getDouble('target_amount_$i') ?? 0.0;
        goals[i].goalTitle = prefs.getString('goal_title_$i') ?? (i == 0 ? 'Моя первая мечта' : 'Вторая мечта');
        goals[i].history = prefs.getStringList('history_list_$i') ?? [];
        goals[i].imagePath = prefs.getString('goal_image_path_$i');
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
      final entry = '$type ${delta.abs().toStringAsFixed(0)} ₽';
      goals[currentGoalIndex].history.insert(0, entry);
    });
    _saveGoalData(currentGoalIndex);
    _checkGoalReached();
  }

  void _checkGoalReached() {
    final goal = goals[currentGoalIndex];
    if (goal.targetAmount > 0 && goal.currentAmount >= goal.targetAmount) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final appState = MyApp.of(context)!;
          return Dialog.fullscreen(
            child: SafeArea(
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
                      'ты молодец!',
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
          );
        },
      );
    }
  }

  Future<void> _updateGoal(String newTitle, double newTarget) async {
    setState(() {
      goals[currentGoalIndex].goalTitle = newTitle;
      goals[currentGoalIndex].targetAmount = newTarget;
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
              Text(description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showAddMoneyDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final appState = MyApp.of(context)!;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Пополнить копилку'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Сумма (в рублях)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: appState.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                final val = double.tryParse(controller.text) ?? 0;
                if (val > 0) {
                  Navigator.pop(context);
                  _updateMoney(val);
                } else {
                  Navigator.pop(context);
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );
  }

  void _showSpendMoneyDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final appState = MyApp.of(context)!;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Потратить из копилки'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Сумма (в рублях)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: appState.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                final val = double.tryParse(controller.text) ?? 0;
                if (val > 0) {
                  Navigator.pop(context);
                  _updateMoney(-val);
                } else {
                  Navigator.pop(context);
                }
              },
              child: const Text('Списать'),
            ),
          ],
        );
      },
    );
  }

  void _showEditGoalDialog() {
    final currentGoal = goals[currentGoalIndex];
    final titleController = TextEditingController(text: currentGoal.goalTitle);
    final targetController = TextEditingController(text: currentGoal.targetAmount > 0 ? currentGoal.targetAmount.toStringAsFixed(0) : '');

    showDialog(
      context: context,
      builder: (context) {
        final appState = MyApp.of(context)!;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Изменить цель ${currentGoalIndex + 1}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  labelText: 'Целевая сумма (в рублях)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: appState.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                final newTitle = titleController.text.trim().isNotEmpty ? titleController.text.trim() : currentGoal.goalTitle;
                final newTarget = double.tryParse(targetController.text) ?? currentGoal.targetAmount;
                _updateGoal(newTitle, newTarget);
                Navigator.pop(context);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context)!;
    final isDark = appState.isDark;
    final currentGoal = goals[currentGoalIndex];

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 150,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    appState.primaryColor.withOpacity(isDark ? 0.25 : 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.userName,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.bar_chart_rounded),
                            onPressed: () => _showComingSoonBottomSheet('Статистика и аналитика', 'Скоро здесь появится подробная статистика ваших сбережений и графики роста.'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined),
                            onPressed: () {
                              Navigator.push(
                                context,
                                createAnimatedRoute(const SettingsScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  SizedBox(
                    height: 205,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: goals.length,
                      onPageChanged: (index) {
                        setState(() {
                          currentGoalIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final goal = goals[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
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
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  goal.goalTitle,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 95,
                                  child: GestureDetector(
                                    onTap: _pickImage,
                                    child: goal.imagePath != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: Image.file(
                                              File(goal.imagePath!),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
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
                                                Icon(Icons.add_a_photo_outlined, color: appState.primaryColor, size: 24),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Цель ${index + 1}: Нажмите для фото',
                                                  style: TextStyle(color: appState.primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${goal.currentAmount.toInt()} / ${goal.targetAmount.toInt()} ₽',
                                  style: TextStyle(fontSize: 15, color: appState.primaryColor, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      goals.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: currentGoalIndex == index ? 16 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: currentGoalIndex == index ? appState.primaryColor : Colors.grey.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appState.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _showAddMoneyDialog,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, size: 18),
                              SizedBox(width: 6),
                              Text('Пополнить', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: appState.primaryColor, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _showSpendMoneyDialog,
                          child: Text(
                            'Потратил',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: appState.primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 48,
                        width: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: BorderSide(color: appState.primaryColor, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _showEditGoalDialog,
                          child: Icon(Icons.edit_outlined, size: 20, color: appState.primaryColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'История операций',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: currentGoal.history.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text(
                                'Операций пока нет',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: currentGoal.history.length,
                            itemBuilder: (context, index) {
                              final item = currentGoal.history[index];
                              final isPlus = item.startsWith('+');
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9F6FC),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: (isPlus ? Colors.green : Colors.red).withOpacity(0.15),
                                    child: Icon(
                                      isPlus ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                      size: 16,
                                      color: isPlus ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  title: Text(
                                    item,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isPlus ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.favorite_rounded, color: appState.primaryColor, size: 32),
                        const SizedBox(height: 8),
                        const Text(
                          'Поддержать проект',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Приложение абсолютно бесплатное и без подписок!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: appState.primaryColor, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          ),
                          onPressed: () => _showComingSoonBottomSheet('Поддержать проект', 'Скоро здесь появится ссылка на донаты для поддержки разработки приложения.'),
                          child: Text(
                            'Отправить донат',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: appState.primaryColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.send_rounded, color: appState.primaryColor, size: 32),
                        const SizedBox(height: 8),
                        const Text(
                          'Наш телеграм канал',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Сообщайте о багах, делитесь идеями и следите за обновлениями!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: appState.primaryColor, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          ),
                          onPressed: () => _showComingSoonBottomSheet('Наш телеграм канал', 'Скоро здесь появится ссылка на официальный Telegram-канал проекта.'),
                          child: Text(
                            'Сообщить о баге / Идеи',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: appState.primaryColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Я Коплю: мечты v.2.3 (beta)',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _versionClickCount = 0;

  void _showBaliEasterEgg(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final appState = MyApp.of(context)!;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Пасхалка 🌴',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Марат, главный разработчик этого приложения, заслуживает отдых на Бали',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: appState.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _showEmojiFireworks(context);
                },
                child: const Text(
                  'Согласен',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEmojiFireworks(BuildContext context) {
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 3),
            onEnd: () {
              overlayEntry?.remove();
            },
            builder: (context, value, child) {
              return Stack(
                children: [
                  Positioned(
                    top: MediaQuery.of(context).size.height * (1 - value),
                    left: MediaQuery.of(context).size.width * 0.2,
                    child: const Text('🌴', style: TextStyle(fontSize: 36)),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).size.height * (0.8 - value * 0.7),
                    right: MediaQuery.of(context).size.width * 0.3,
                    child: const Text('💸', style: TextStyle(fontSize: 36)),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).size.height * (0.9 - value * 0.9),
                    left: MediaQuery.of(context).size.width * 0.5,
                    child: const Text('🎉', style: TextStyle(fontSize: 36)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Темная тема'),
            value: appState.isDark,
            onChanged: (val) {
              appState.toggleTheme(val);
            },
          ),
          const Divider(),
          const SizedBox(height: 20),
          ListTile(
            title: const Text('Выбрать цвет темы'),
            subtitle: const Text('Нажмите на цвет для смены акцента'),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              appState.lightColors.length,
              (index) => GestureDetector(
                onTap: () {
                  appState.setColor(index);
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: appState.isDark ? appState.darkColors[index] : appState.lightColors[index],
                  child: appState.selectedColorIndex == index
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              ),
            ),
          ),
          const Divider(height: 40),
          ListTile(
            title: const Text('Сбросить все данные'),
            subtitle: const Text('Удалить цели, историю и начать заново'),
            trailing: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: const Text('Сброс данных'),
                  content: const Text('Вы уверены, что хотите удалить все данные и начать с экрана приветствия?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        appState.resetAllData();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text('Сбросить'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 40),
          GestureDetector(
            onTap: () {
              setState(() {
                _versionClickCount++;
                if (_versionClickCount >= 5) {
                  _versionClickCount = 0;
                  _showBaliEasterEgg(context);
                }
              });
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: Text(
                  'Я Коплю: мечты v.2.3 (beta)',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
