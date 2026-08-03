import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isRegistered = prefs.getBool('is_registered') ?? false;
  final savedName = prefs.getString('user_name') ?? '';
  final isDark = prefs.getBool('is_dark') ?? false;
  final colorIndex = prefs.getInt('color_index') ?? 0;

  runApp(MyApp(
    isRegistered: isRegistered,
    savedName: savedName,
    initialIsDark: isDark,
    initialColorIndex: colorIndex,
  ));
}

class MyApp extends StatefulWidget {
  final bool isRegistered;
  final String savedName;
  final bool initialIsDark;
  final int initialColorIndex;

  const MyApp({
    super.key,
    required this.isRegistered,
    required this.savedName,
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
  late bool isRegistered;
  bool isRainbowMode = false;

  final List<Color> lightColors = [
    Colors.deepPurple,
    Colors.redAccent,
    Colors.blue,
    Colors.teal,
    Colors.orange,
    Colors.pinkAccent,
  ];

  final List<Color> darkColors = [
    const Color(0xFF9575CD),
    const Color(0xFFE57373),
    const Color(0xFF64B5F6),
    const Color(0xFF4DB6AC),
    const Color(0xFFFFB74D),
    const Color(0xFFF06292),
  ];

  @override
  void initState() {
    super.initState();
    isDark = widget.initialIsDark;
    selectedColorIndex = widget.initialColorIndex;
    userName = widget.savedName;
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

  void enableRainbowMode() {
    setState(() {
      isRainbowMode = true;
    });
  }

  void registerUser(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setBool('is_registered', true);
    setState(() {
      userName = name;
      isRegistered = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Я коплю',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFBF8FF),
        colorSchemeSeed: isRainbowMode ? Colors.purple : primaryColor,
        useMaterial3: true,
      ),
      home: isRegistered
          ? HomeScreen(userName: userName)
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

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context)!;
    final isDark = appState.isDark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 10),
              CircleAvatar(
                radius: 35,
                backgroundColor: appState.primaryColor.withOpacity(0.15),
                child: Icon(Icons.savings_outlined, size: 36, color: appState.primaryColor),
              ),
              const SizedBox(height: 16),
              const Text(
                'Добро пожаловать в\n«Я коплю»',
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
                    _buildFeatureItem(Icons.person_outline, 'Персонализация', 'Указывай своё имя для удобства.', appState.primaryColor),
                    const Divider(height: 16),
                    _buildFeatureItem(Icons.image_outlined, 'Визуализация мечты', 'Добавляй фото целей из галереи.', appState.primaryColor),
                    const Divider(height: 16),
                    _buildFeatureItem(Icons.palette_outlined, 'Дизайн и темы', 'Material You палитра под настроение.', appState.primaryColor),
                    const Divider(height: 16),
                    _buildFeatureItem(Icons.all_inclusive, 'Без подписок', 'Весь функционал абсолютно бесплатен.', appState.primaryColor),
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
                    const SizedBox(height: 10),
                    TextField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Фамилия (необязательно)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Выберите цвет темы', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(
                        appState.lightColors.length,
                        (index) => GestureDetector(
                          onTap: () => appState.setColor(index),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: isDark ? appState.darkColors[index] : appState.lightColors[index],
                            child: appState.selectedColorIndex == index
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
                    backgroundColor: appState.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    if (_nameController.text.trim().isNotEmpty) {
                      final name = _nameController.text.trim();
                      appState.registerUser(name);
                      Navigator.pushReplacement(
                        context,
                        createAnimatedRoute(WelcomeGreetingScreen(userName: name)),
                      );
                    }
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

  const WelcomeGreetingScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              Center(
                child: Text(
                  'Здравствуйте, $userName!',
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
                      createAnimatedRoute(HomeScreen(userName: userName)),
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

class HomeScreen extends StatefulWidget {
  final String userName;

  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double currentAmount = 0.0;
  double targetAmount = 50000.0;
  String goalTitle = 'Моя первая мечта';
  List<String> history = [];

  @override
  void initState() {
    super.initState();
    _loadSavedMoneyData();
  }

  Future<void> _loadSavedMoneyData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentAmount = prefs.getDouble('current_amount') ?? 0.0;
      targetAmount = prefs.getDouble('target_amount') ?? 50000.0;
      goalTitle = prefs.getString('goal_title') ?? 'Моя первая мечта';
      history = prefs.getStringList('history_list') ?? [];
    });
  }

  Future<void> _updateMoney(double delta) async {
    setState(() {
      currentAmount += delta;
      if (currentAmount < 0) currentAmount = 0;
      final type = delta > 0 ? '+' : '-';
      final entry = '$type ${delta.abs().toStringAsFixed(0)} ₽';
      history.insert(0, entry);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('current_amount', currentAmount);
    await prefs.setStringList('history_list', history);
  }

  void _showTransactionBottomSheet(bool isAdding) {
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
                isAdding ? 'Пополнить копилку 🟢' : 'Потратил из копилки 🔴',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
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
                    backgroundColor: isAdding ? appState.primaryColor : Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    final val = double.tryParse(controller.text.trim()) ?? 0;
                    if (val > 0) {
                      _updateMoney(isAdding ? val : -val);
                      Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context)!;
    final isDark = appState.isDark;
    double progress = targetAmount > 0 ? (currentAmount / targetAmount) : 0;
    if (progress > 1.0) progress = 1.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.userName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: appState.isRainbowMode ? Colors.purpleAccent : null,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () {
              Navigator.push(context, createAnimatedRoute(const CalculatorScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(context, createAnimatedRoute(const SettingsScreen()));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Карточка мечты со шкалой прогресса
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEFE7F4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 44, color: appState.primaryColor),
                  const SizedBox(height: 6),
                  Text('Нажмите, чтобы выбрать фото цели', style: TextStyle(color: appState.primaryColor, fontSize: 12)),
                  const SizedBox(height: 16),
                  Text(goalTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(
                    '${currentAmount.toStringAsFixed(0)} / ${targetAmount.toStringAsFixed(0)} ₽',
                    style: TextStyle(color: appState.primaryColor, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                      color: appState.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Собрано ${(progress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Кнопки "Пополнить" и "Потратил"
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appState.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _showTransactionBottomSheet(true),
                    icon: const Icon(Icons.add),
                    label: const Text('Пополнить'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.15),
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.redAccent, width: 1.5),
                      ),
                    ),
                    onPressed: () => _showTransactionBottomSheet(false),
                    icon: const Icon(Icons.remove),
                    label: const Text('Потратил'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // История операций
            if (history.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F2FA),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('История операций', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: history.length > 5 ? 5 : history.length,
                      itemBuilder: (context, index) {
                        final item = history[index];
                        final isAdd = item.startsWith('+');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(isAdd ? 'Пополнение' : 'Списание', style: const TextStyle(fontSize: 13)),
                              Text(
                                item,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isAdd ? Colors.green : Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Блок доната
            _buildActionCard(
              context: context,
              icon: Icons.favorite,
              iconColor: appState.primaryColor,
              title: 'Поддержать проект',
              subtitle: 'Приложение абсолютно бесплатное и без подписок!',
              buttonText: 'Отправить донат',
            ),
            const SizedBox(height: 12),

            // Блок телеграм
            _buildActionCard(
              context: context,
              icon: Icons.send_rounded,
              iconColor: appState.primaryColor,
              title: 'Наш телеграм канал',
              subtitle: 'Сообщайте о багах, делитесь идеями и следите за обновлениями!',
              buttonText: 'Сообщить о баге / Идеи',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonText,
  }) {
    final isDark = MyApp.of(context)!.isDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F2FA),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {},
            child: Text(buttonText),
          )
        ],
      ),
    );
  }
}

// 🤫 Секретный калькулятор с пасхалкой
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String input = '0';

  void _onKeyPress(String val) {
    setState(() {
      if (val == 'C') {
        input = '0';
      } else if (input == '0') {
        input = val;
      } else {
        input += val;
      }

      // Секретный код пасхалки (например "777")
      if (input == '777') {
        MyApp.of(context)!.enableRainbowMode();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Пасхалка открыта! Активирован радужный режим!')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context)!;
    final keys = ['7', '8', '9', '4', '5', '6', '1', '2', '3', 'C', '0', '='];

    return Scaffold(
      appBar: AppBar(title: const Text('Калькулятор')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: appState.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3EDF7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                input,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: appState.isRainbowMode ? Colors.purpleAccent : appState.primaryColor,
                ),
              ),
            ),
            const Spacer(),
            GridView.builder(
              shrinkWrap: true,
              itemCount: keys.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final k = keys[index];
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    backgroundColor: k == 'C' ? Colors.redAccent.withOpacity(0.2) : null,
                  ),
                  onPressed: () => _onKeyPress(k),
                  child: Text(k, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                );
              },
            ),
          ],
        ),
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
  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context)!;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile.adaptive(
            title: const Text('Тёмная тема', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Использовать тёмное оформление'),
            value: appState.isDark,
            onChanged: (val) {
              appState.toggleTheme(val);
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Выбор цвета темы', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              appState.lightColors.length,
              (index) => GestureDetector(
                onTap: () => appState.setColor(index),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: appState.isDark
                      ? appState.darkColors[index]
                      : appState.lightColors[index],
                  child: appState.selectedColorIndex == index
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
