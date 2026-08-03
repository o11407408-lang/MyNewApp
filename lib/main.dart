import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = false;
  Color primaryColor = Colors.red;

  // 7. цвета темы по порядку радуги (красный, оранжевый, зеленый, голубой, синий, фиолетовый)
  final List<Color> rainbowColors = [
    Colors.red,
    Colors.orange,
    Colors.green,
    Colors.lightBlue,
    Colors.blue,
    Colors.purple,
  ];

  void changeTheme(Color color) {
    setState(() {
      primaryColor = color;
    });
  }

  void toggleDarkMode(bool val) {
    setState(() {
      isDarkMode = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Я коплю',
      theme: ThemeData(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: isDarkMode ? Brightness.dark : Brightness.light,
          primary: primaryColor,
        ),
        useMaterial3: true,
      ),
      home: RegistrationScreen(
        rainbowColors: rainbowColors,
        onComplete: (name, color) {
          setState(() {
            primaryColor = color;
          });
        },
      ),
    );
  }
}

// 6 & 12. экран регистрации
class RegistrationScreen extends StatefulWidget {
  final List<Color> rainbowColors;
  final Function(String, Color) onComplete;

  const RegistrationScreen({
    super.key,
    required final this.rainbowColors,
    required final this.onComplete,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  late Color selectedColor;

  @override
  void initState() {
    super.initState();
    // 6. изначально тема красная
    selectedColor = widget.rainbowColors[0];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: selectedColor.withOpacity(0.15),
                child: Icon(Icons.savings, size: 40, color: selectedColor),
              ),
              const SizedBox(height: 16),
              // 9. текст с заглавной буквы
              const Text(
                "Добро пожаловать в «Я коплю»",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Твой личный помощник для достижения любых целей и мечт.",
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  // 12. поле только для имени (без фамилии)
                  labelText: "Ваше имя *",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Выберите цвет темы", style: TextStyle(fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 12),
              // 7 & 12. динамическая смена цвета при выборе в регистрации
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: widget.rainbowColors.map((color) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedColor = color;
                      });
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: color,
                      child: selectedColor == color
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    if (_nameController.text.trim().isNotEmpty) {
                      widget.onComplete(_nameController.text.trim(), selectedColor);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomeScreen(
                            userName: _nameController.text.trim(),
                            primaryColor: selectedColor,
                            rainbowColors: widget.rainbowColors,
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text("Продолжить", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// главный экран
class HomeScreen extends StatefulWidget {
  final String userName;
  final Color primaryColor;
  final List<Color> rainbowColors;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.primaryColor,
    required this.rainbowColors,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Color currentColor;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  String goalName = "Моя первая мечта";
  // 10. изначальная цена мечты — 0 рублей
  double targetAmount = 0.0;
  double currentAmount = 0.0;

  List<Map<String, dynamic>> operations = [];

  @override
  void initState() {
    super.initState();
    currentColor = widget.primaryColor;
  }

  // 2. рабочая функция выбора фото из галереи
  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  // 11. поздравление при достижении цели
  void _checkGoalReached() {
    if (targetAmount > 0 && currentAmount >= targetAmount) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Icon(Icons.emoji_events, size: 60, color: currentColor),
              const SizedBox(height: 16),
              Text(
                "Поздравляю с достижением цели, ${widget.userName}",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "ты молодец!",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: currentColor),
                onPressed: () => Navigator.pop(context),
                child: const Text("Ура!", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // карточка цели
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // 2 & 3. фото с автоматической адаптацией под его физические пропорции (16:9, 1:1 и т.д.)
                    GestureDetector(
                      onTap: _pickImage,
                      child: _imageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(_imageFile!, fit: BoxFit.contain),
                            )
                          : Container(
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: currentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, color: currentColor, size: 36),
                                  const SizedBox(height: 8),
                                  Text("Нажмите, чтобы выбрать фото цели", style: TextStyle(color: currentColor, fontSize: 12)),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    // 8. название цели без старой кнопки карандаша
                    Text(goalName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      "${currentAmount.toInt()} / ${targetAmount.toInt()} ₽",
                      style: TextStyle(fontSize: 20, color: currentColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 8. кнопки действий с уменьшенной кнопкой потратил и кружочком изменения
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentColor,
                      padding: const EdgeInsets.vertical(12),
                    ),
                    onPressed: () => _showAddMoneyDialog(),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text("Пополнить", style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                // 4 & 8. уменьшенная кнопка потратил с прозрачным фоном и цветной обводкой
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: currentColor, width: 2),
                      backgroundColor: Colors.transparent,
                      padding: const EdgeInsets.vertical(12),
                    ),
                    onPressed: () => _showSpendMoneyDialog(),
                    child: Text("Потратил", style: TextStyle(color: currentColor, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                // 8. круглая кнопка с карандашиком для изменения цели
                GestureDetector(
                  onTap: () => _showEditGoalDialog(),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: currentColor,
                    child: const Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 5. история операций всегда на экране
            Align(
              alignment: Alignment.centerLeft,
              child: const Text("История операций", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: operations.isEmpty
                    // 5. надпись если нет операций
                    ? const Center(
                        child: Text("Операций пока нет", style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: operations.length,
                        itemBuilder: (context, index) {
                          final item = operations[index];
                          return ListTile(
                            title: Text(item['title']),
                            trailing: Text(
                              "${item['isAdd'] ? '+' : '-'}${item['amount']} ₽",
                              style: TextStyle(
                                color: item['isAdd'] ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 10. проверка возможности изменения баланса (нельзя если цена цели = 0)
  void _showAddMoneyDialog() {
    if (targetAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Сначала укажите цену мечты!")),
      );
      return;
    }
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. без эмодзи
            const Text("Пополнить копилку", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Сумма (в рублях)"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: currentColor),
              onPressed: () {
                double val = double.tryParse(controller.text) ?? 0;
                if (val > 0) {
                  setState(() {
                    currentAmount += val;
                    operations.insert(0, {'title': 'Пополнение', 'amount': val, 'isAdd': true});
                  });
                  Navigator.pop(context);
                  _checkGoalReached();
                }
              },
              child: const Text("Добавить", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  void _showSpendMoneyDialog() {
    if (targetAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Сначала укажите цену мечты!")),
      );
      return;
    }
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. без эмодзи
            const Text("Потратил из копилки", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Сумма (в рублях)"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: currentColor),
              onPressed: () {
                double val = double.tryParse(controller.text) ?? 0;
                if (val > 0) {
                  setState(() {
                    currentAmount -= val;
                    operations.insert(0, {'title': 'Списание', 'amount': val, 'isAdd': false});
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text("Списать", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  void _showEditGoalDialog() {
    final nameController = TextEditingController(text: goalName);
    final targetController = TextEditingController(text: targetAmount.toString());

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. без эмодзи
            const Text("Изменить цель", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Название цели"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Целевая сумма (в рублях)"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: currentColor),
              onPressed: () {
                setState(() {
                  goalName = nameController.text.trim();
                  targetAmount = double.tryParse(targetController.text) ?? 0.0;
                });
                Navigator.pop(context);
              },
              child: const Text("Сохранить", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. без эмодзи
            const Text("Настройки", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // 7. выбор цвета темы радугой
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: widget.rainbowColors.map((color) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      currentColor = color;
                    });
                    Navigator.pop(context);
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: color,
                    child: currentColor == color
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
