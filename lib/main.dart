import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MySavingsApp());
}

class MySavingsApp extends StatelessWidget {
  const MySavingsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class GoalModel {
  String title;
  double targetAmount;
  double savedAmount;
  String imageUrl;

  GoalModel({
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
    required this.imageUrl,
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
  final TextEditingController _welcomeNameController = TextEditingController();

  Color backgroundColor = const Color(0xFFF7F2FA);

  final List<Color> _availableColors = const [
    Color(0xFFF7F2FA),
    Color(0xFFE8F5E9),
    Color(0xFFE3F2FD),
    Color(0xFFFFF3E0),
    Color(0xFFFCE4EC),
  ];

  final PageController _pageController = PageController();
  int _currentGoalIndex = 0;

  final List<GoalModel> _goals = [
    GoalModel(
      title: "Моя первая мечта",
      targetAmount: 50000,
      savedAmount: 0,
      imageUrl: "",
    ),
    GoalModel(
      title: "Вторая цель",
      targetAmount: 100000,
      savedAmount: 15000,
      imageUrl: "",
    ),
  ];

  final List<LeaderboardItem> _leaderboard = [];

  @override
  void dispose() {
    _welcomeNameController.dispose();
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

  // 1. Приветственный экран
  Widget _buildWelcomeScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
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
                          color: Colors.deepPurple.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.savings_outlined,
                          size: 36,
                          color: Colors.deepPurple,
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
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildFeatureRow(Icons.person_outline, "Персонализация", "Указывай своё имя для удобства."),
                              const Divider(height: 16),
                              _buildFeatureRow(Icons.photo_size_select_actual_outlined, "Визуализация мечты", "Добавляй фото целей и следи за прогрессом."),
                              const Divider(height: 16),
                              _buildFeatureRow(Icons.palette_outlined, "Дизайн и темы", "Меняй цвета фона под своё настроение."),
                              const Divider(height: 16),
                              _buildFeatureRow(Icons.all_inclusive, "Без подписок", "Весь функционал абсолютно бесплатен."),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        color: Colors.white,
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
                              const SizedBox(height: 14),
                              const Text(
                                "Выберите цвет темы",
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: _availableColors.map((color) {
                                  bool isSelected = backgroundColor == color;
                                  return GestureDetector(
                                    onTap: () => setState(() => backgroundColor = color),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? Colors.deepPurple : Colors.black26,
                                          width: isSelected ? 3.0 : 1.5,
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

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: Colors.deepPurple, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  // 2. Главный экран
  Widget _buildHomeScreen(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          userName,
          style: const TextStyle(fontWeight: FontWeight.bold),
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
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _editGoal(index),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: goal.imageUrl.isNotEmpty
                                            ? Image.network(
                                                goal.imageUrl,
                                                height: screenHeight > 700 ? 150 : 110,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(screenHeight),
                                              )
                                            : _buildImagePlaceholder(screenHeight),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      goal.title,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${goal.savedAmount.toInt()} / ${goal.targetAmount.toInt()} ₽",
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Theme.of(context).colorScheme.primary,
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
                                      style: Theme.of(context).textTheme.bodySmall,
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
                              color: _currentGoalIndex == index ? Colors.deepPurple : Colors.black26,
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
                        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
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
                        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Icon(Icons.send_rounded, color: Colors.blueAccent, size: 28),
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

  Widget _buildImagePlaceholder(double screenHeight) {
    return Container(
      height: screenHeight > 700 ? 150 : 110,
      width: double.infinity,
      color: Colors.deepPurple.shade50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined, size: 36, color: Colors.deepPurple.shade300),
          const SizedBox(height: 4),
          Text(
            "Нажмите, чтобы добавить фото",
            style: TextStyle(
              color: Colors.deepPurple.shade400,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
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
    TextEditingController imageController = TextEditingController(text: goal.imageUrl);

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
              TextField(controller: imageController, decoration: const InputDecoration(labelText: "Ссылка на фото")),
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
                goal.imageUrl = imageController.text;
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
              leading: const Icon(Icons.person, color: Colors.deepPurple),
              title: const Text("Изменить имя"),
              subtitle: Text(userName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _editProfile();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.palette, color: Colors.deepPurple),
              title: const Text("Цвет фона темы"),
              subtitle: const Text("Нажмите для выбора"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _showColorPicker();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.leaderboard, color: Colors.deepPurple),
              title: const Text("Таблица лидеров"),
              subtitle: const Text("Рейтинг спонсоров проекта"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _showLeaderboardDialog();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _editProfile() {
    TextEditingController nameController = TextEditingController(text: userName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Изменить имя"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: "Ваше имя"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  userName = nameController.text.trim();
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
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 150,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Выберите цвет фона", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _availableColors.map((color) {
                bool isSelected = backgroundColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() => backgroundColor = color);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.deepPurple : Colors.black26,
                        width: isSelected ? 3.0 : 1.5,
                      ),
                    ),
                    child: CircleAvatar(backgroundColor: color, radius: 22),
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
                        backgroundColor: Colors.deepPurple.shade100,
                        child: Text(
                          "${index + 1}",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                        ),
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
    TextEditingController amountController = TextEditingController();
    TextEditingController nameController = TextEditingController(text: userName);
    bool isAnonymous = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Поддержать проект"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Сумма доната (₽)"),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text("Анонимный подарок", style: TextStyle(fontSize: 14)),
                  subtitle: const Text("Не отображать в таблице лидеров", style: TextStyle(fontSize: 11)),
                  value: isAnonymous,
                  onChanged: (val) {
                    setStateDialog(() {
                      isAnonymous = val;
                    });
                  },
                ),
                if (!isAnonymous) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Имя для таблицы лидеров"),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
            FilledButton(
              onPressed: () {
                double? amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  if (!isAnonymous) {
                    String donorName = nameController.text.trim().isNotEmpty ? nameController.text.trim() : "Аноним";
                    setState(() {
                      int existingIndex = _leaderboard.indexWhere((element) => element.name == donorName);
                      if (existingIndex >= 0) {
                        _leaderboard[existingIndex] = LeaderboardItem(
                          name: donorName,
                          amount: _leaderboard[existingIndex].amount + amount,
                        );
                      } else {
                        _leaderboard.add(LeaderboardItem(name: donorName, amount: amount));
                      }
                    });
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Спасибо за вашу поддержку!")),
                  );
                }
              },
              child: const Text("Отправить"),
            ),
          ],
        ),
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
