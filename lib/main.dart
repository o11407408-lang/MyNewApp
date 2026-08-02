import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MySavingsApp());
}

class MySavingsApp extends StatefulWidget {
  const MySavingsApp({super.key});

  static _MySavingsAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MySavingsAppState>();

  @override
  State<MySavingsApp> createState() => _MySavingsAppState();
}

class _MySavingsAppState extends State<MySavingsApp> {
  Color primarySeedColor = Colors.deepPurple;

  void updateThemeColor(Color color) {
    setState(() {
      primarySeedColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primarySeedColor,
          brightness: Brightness.light,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class GoalModel {
  String title;
  double targetAmount;
  double savedAmount;
  String imagePath;

  GoalModel({
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
    required this.imagePath,
  });
}

class LeaderboardItem {
  final String name;
  final double amount;

  LeaderboardItem({required this.name, required this.amount});
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  bool showWelcomeScreen = true;
  String userName = "";
  String userLastName = "";

  final TextEditingController _welcomeNameController = TextEditingController();
  final TextEditingController _welcomeLastNameController = TextEditingController();

  Color currentColorSeed = Colors.deepPurple;

  final List<Color> _availableColors = const [
    Colors.deepPurple,
    Colors.redAccent,
    Colors.blueAccent,
    Colors.teal,
    Colors.orangeAccent,
    Colors.pinkAccent,
  ];

  final PageController _pageController = PageController();
  int _currentGoalIndex = 0;

  late List<GoalModel> _goals;
  final List<LeaderboardItem> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _resetGoals();
  }

  void _resetGoals() {
    _goals = [
      GoalModel(
        title: "Моя первая мечта",
        targetAmount: 50000,
        savedAmount: 0,
        imagePath: "",
      ),
      GoalModel(
        title: "Вторая цель",
        targetAmount: 100000,
        savedAmount: 0,
        imagePath: "",
      ),
    ];
  }

  @override
  void dispose() {
    _welcomeNameController.dispose();
    _welcomeLastNameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (showWelcomeScreen) {
      return _buildWelcomeScreen(context);
    }
    return _buildHomeScreen(context);
  }

  Widget _buildWelcomeScreen(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth > 600 ? 48.0 : 20.0,
                vertical: 20.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.savings_outlined,
                          size: 36,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Добро пожаловать в\n«Я коплю»",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Твой личный помощник для достижения любых целей и мечт.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildFeatureRow(context, Icons.person_outline, "Персонализация", "Указывай своё имя для удобства."),
                              const Divider(height: 16),
                              _buildFeatureRow(context, Icons.photo_size_select_actual_outlined, "Визуализация мечты", "Добавляй фото целей из галереи."),
                              const Divider(height: 16),
                              _buildFeatureRow(context, Icons.palette_outlined, "Дизайн и темы", "Material You палитра под настроение."),
                              const Divider(height: 16),
                              _buildFeatureRow(context, Icons.all_inclusive, "Без подписок", "Весь функционал абсолютно бесплатен."),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Давай знакомиться",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _welcomeNameController,
                                decoration: InputDecoration(
                                  labelText: "Ваше имя *",
                                  hintText: "Введите ваше имя",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _welcomeLastNameController,
                                decoration: InputDecoration(
                                  labelText: "Фамилия (необязательно)",
                                  hintText: "Введите вашу фамилию",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                "Выберите цвет темы",
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: _availableColors.map((color) {
                                  bool isSelected = currentColorSeed == color;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() => currentColorSeed = color);
                                      MySavingsApp.of(context)?.updateThemeColor(color);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                                          width: 3.0,
                                        ),
                                      ),
                                      child: CircleAvatar(backgroundColor: color, radius: 18),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: () {
                            String enteredName = _welcomeNameController.text.trim();
                            if (enteredName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Пожалуйста, введите ваше имя!")),
                              );
                              return;
                            }
                            setState(() {
                              userName = enteredName;
                              userLastName = _welcomeLastNameController.text.trim();
                              showWelcomeScreen = false;
                            });
                          },
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "Продолжить",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHomeScreen(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    String greeting = userLastName.isNotEmpty
        ? "Здравствуйте, $userName $userLastName!"
        : "Здравствуйте, $userName!";

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          greeting,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsBottomSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: screenHeight > 700 ? 380 : 320,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _goals.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentGoalIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            final goal = _goals[index];
                            double goalProgress = goal.targetAmount > 0 
                                ? (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0) 
                                : 0.0;

                            return Card(
                              elevation: 0,
                              color: theme.colorScheme.surfaceContainerHighest,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _pickImageForGoal(index),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: goal.imagePath.isNotEmpty
                                            ? Image.file(
                                                File(goal.imagePath),
                                                height: screenHeight > 700 ? 150 : 110,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(context, screenHeight),
                                              )
                                            : _buildImagePlaceholder(context, screenHeight),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      goal.title,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${goal.savedAmount.toInt()} / ${goal.targetAmount.toInt()} ₽",
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: goalProgress,
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Собрано ${(goalProgress * 100).toStringAsFixed(1)}% (Цель ${index + 1} из 2)",
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_goals.length, (index) {
                          return Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentGoalIndex == index ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _addMoney(_currentGoalIndex),
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text("Пополнить"),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            onPressed: () => _editGoal(_currentGoalIndex),
                            icon: const Icon(Icons.edit, size: 20),
                            padding: const EdgeInsets.all(14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Icon(Icons.favorite, color: Colors.redAccent, size: 28),
                              const SizedBox(height: 6),
                              const Text(
                                "Поддержать проект",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "Приложение абсолютно бесплатное и без подписок!",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton(
                                onPressed: _showDonateDialog,
                                child: const Text("Отправить донат"),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Icon(Icons.send_rounded, color: theme.colorScheme.primary, size: 28),
                              const SizedBox(height: 6),
                              const Text(
                                "Наш телеграм канал",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "Сообщайте о багах, делитесь идеями и следите за обновлениями!",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton(
                                onPressed: _showTelegramDialog,
                                child: const Text("Сообщить о баге / Идеи"),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(BuildContext context, double screenHeight) {
    final theme = Theme.of(context);
    return Container(
      height: screenHeight > 700 ? 150 : 110,
      width: double.infinity,
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined, size: 36, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            "Нажмите, чтобы выбрать фото из галереи",
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageForGoal(int goalIndex) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _goals[goalIndex].imagePath = result.files.single.path!;
      });
    }
  }

  void _addMoney(int goalIndex) {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Добавить сумму"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Сумма (₽)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          FilledButton(
            onPressed: () {
              double? val = double.tryParse(controller.text);
              if (val != null) {
                setState(() => _goals[goalIndex].savedAmount += val);
              }
              Navigator.pop(context);
            },
            child: const Text("Сохранить"),
          ),
        ],
      ),
    );
  }

  void _editGoal(int goalIndex) {
    GoalModel goal = _goals[goalIndex];
    TextEditingController titleController = TextEditingController(text: goal.title);
    TextEditingController targetController = TextEditingController(text: goal.targetAmount.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Редактировать цель ${goalIndex + 1}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: "Название мечты")),
              TextField(controller: targetController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Целевая сумма")),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await _pickImageForGoal(goalIndex);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.photo_library),
                label: const Text("Выбрать новое фото из галереи"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          FilledButton(
            onPressed: () {
              setState(() {
                goal.title = titleController.text;
                goal.targetAmount = double.tryParse(targetController.text) ?? goal.targetAmount;
              });
              Navigator.pop(context);
            },
            child: const Text("Сохранить"),
          ),
        ],
      ),
    );
  }

  void _showSettingsBottomSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Настройки",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.person, color: theme.colorScheme.primary),
              title: const Text("Изменить имя и фамилию"),
              subtitle: Text(userLastName.isNotEmpty ? "$userName $userLastName" : userName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _editProfile();
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.palette, color: theme.colorScheme.primary),
              title: const Text("Цвет темы (Material You)"),
              subtitle: const Text("Выбрать яркую палитру"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _showColorPicker();
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.leaderboard, color: theme.colorScheme.primary),
              title: const Text("Таблица лидеров"),
              subtitle: const Text("Рейтинг спонсоров проекта"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _showLeaderboardDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.redAccent),
              title: const Text("Сбросить все настройки", style: TextStyle(color: Colors.redAccent)),
              subtitle: const Text("Стереть данные и вернуть исходный вид"),
              trailing: const Icon(Icons.chevron_right, color: Colors.redAccent),
              onTap: () {
                Navigator.pop(context);
                _resetAllData();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _resetAllData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Сброс данных"),
        content: const Text("Вы уверены, что хотите сбросить все накопления, имя и настройки темы?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                _resetGoals();
                userName = "";
                userLastName = "";
                showWelcomeScreen = true;
                currentColorSeed = Colors.deepPurple;
                MySavingsApp.of(context)?.updateThemeColor(Colors.deepPurple);
              });
              Navigator.pop(context);
            },
            child: const Text("Сбросить"),
          ),
        ],
      ),
    );
  }

  void _editProfile() {
    TextEditingController nameController = TextEditingController(text: userName);
    TextEditingController lastNameController = TextEditingController(text: userLastName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Изменить профиль"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Ваше имя *"),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: lastNameController,
              decoration: const InputDecoration(labelText: "Фамилия (необязательно)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  userName = nameController.text.trim();
                  userLastName = lastNameController.text.trim();
                });
              }
              Navigator.pop(context);
            },
            child: const Text("Сохранить"),
          ),
        ],
      ),
    );
  }

  void _showColorPicker() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 160,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Выберите яркий акцент темы", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _availableColors.map((color) {
                bool isSelected = currentColorSeed == color;
                return GestureDetector(
                  onTap: () {
                    setState(() => currentColorSeed = color);
                    MySavingsApp.of(context)?.updateThemeColor(color);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                        width: 3.0,
                      ),
                    ),
                    child: CircleAvatar(backgroundColor: color, radius: 20),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaderboardDialog() {
    _leaderboard.sort((a, b) => b.amount.compareTo(a.amount));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Таблица лидеров 🏆"),
        content: SizedBox(
          width: double.maxFinite,
          child: _leaderboard.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    "Пока никто не задонатил.\nСтаньте первым!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 15,
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _leaderboard.length,
                  itemBuilder: (context, index) {
                    final item = _leaderboard[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text("${index + 1}"),
                      ),
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text("${item.amount.toInt()} ₽", style: const TextStyle(fontWeight: FontWeight.w600)),
                    );
                  },
                ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text("Закрыть")),
        ],
      ),
    );
  }

  void _showDonateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Скоро откроется!"),
        content: const Text("Реквизиты для приема донатов временно подготавливаются. Совсем скоро функция станет доступна!"),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text("Понятно")),
        ],
      ),
    );
  }

  void _showTelegramDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Скоро откроется!"),
        content: const Text("Наш телеграм-канал находится в разработке. Совсем скоро здесь появится ссылка, куда можно будет писать о багах и предлагать идеи!"),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text("Понятно")),
        ],
      ),
    );
  }
}
