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

  // палитра светлой темы
  final List<Color> lightColors = [
    Colors.deepPurple,
    Colors.redAccent,
    Colors.blue,
    Colors.teal,
    Colors.orange,
    Colors.pinkAccent,
  ];

  // приглушенная/серая палитра для темной темы
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

  void toggleTheme(bool value, Offset tapPosition) {
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
        colorSchemeSeed: primaryColor,
        useMaterial3: true,
      ),
      home: isRegistered
          ? HomeScreen(userName: userName)
          : OnboardingScreen(),
    );
  }
}

// анимация перехода между экранами
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

// 1. экран онбординга
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
              
              // блок функций (выровнен по размеру с блоком ниже)
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

              // блок ввода данных
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3EDF7),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAlignment.start,
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
              
              // кнопка продолжить
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
            crossAxisAlignment: CrossAlignment.start,
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

// 2. отдельный экран приветствия (показывается ровно 1 раз после регистрации)
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

// 3. главный экран приложения
class HomeScreen extends StatelessWidget {
  final String userName;

  const HomeScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context)!;
    final isDark = appState.isDark;

    return Scaffold(
      appBar: AppBar(
        title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
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
            // карточка мечты
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEFE7F4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 48, color: appState.primaryColor),
                  const SizedBox(height: 8),
                  Text('Нажмите, чтобы выбрать фото из галереи', style: TextStyle(color: appState.primaryColor, fontSize: 12)),
                  const Spacer(),
                  const Text('Моя первая мечта', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text('0 / 50000 ₽', style: TextStyle(color: appState.primaryColor, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Собрано 0.0% (Цель 1 из 2)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // кнопки пополнения
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
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('Пополнить'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_outlined),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.all(14),
                  ),
                )
              ],
            ),
            const SizedBox(height: 16),

            // блок доната (сердечко окрашивается динамически)
            _buildActionCard(
              context: context,
              icon: Icons.favorite,
              iconColor: appState.primaryColor, // динамический цвет сердечка
              title: 'Поддержать проект',
              subtitle: 'Приложение абсолютно бесплатное и без подписок!',
              buttonText: 'Отправить донат',
            ),
            const SizedBox(height: 12),

            // блок телеграм (иконка подстроена)
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

// 4. экран настроек с M3 Switch и Circular Reveal
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Offset tapPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context)!;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Listener(
            onPointerDown: (event) {
              tapPosition = event.position;
            },
            child: SwitchListTile.adaptive(
              title: const Text('Тёмная тема', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Использовать тёмное оформление'),
              value: appState.isDark,
              onChanged: (val) {
                // вызов Circular Reveal переключения
                Navigator.of(context).push(
                  PageRouteBuilder(
                    opaque: false,
                    transitionDuration: const Duration(milliseconds: 500),
                    pageBuilder: (context, animation, secondaryAnimation) {
                      appState.toggleTheme(val, tapPosition);
                      return CircularRevealTransition(
                        fraction: animation.value,
                        center: tapPosition,
                        child: const SizedBox.expand(),
                      );
                    },
                  ),
                );
              },
            ),
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

// аниматор эффекта Circular Reveal
class CircularRevealTransition extends StatelessWidget {
  final double fraction;
  final Offset center;
  final Widget child;

  const CircularRevealTransition({
    super.key,
    required this.fraction,
    required this.center,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: CircularRevealClipper(fraction: fraction, center: center),
      child: child,
    );
  }
}

class CircularRevealClipper extends CustomClipper<Path> {
  final double fraction;
  final Offset center;

  CircularRevealClipper({required this.fraction, required this.center});

  @override
  Path getClip(Size size) {
    final maxRadius = sqrt(size.width * size.width + size.height * size.height);
    final radius = maxRadius * fraction;
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant CircularRevealClipper oldClipper) {
    return oldClipper.fraction != fraction;
  }
}
