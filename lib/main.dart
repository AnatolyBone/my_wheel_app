import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- 1. МОДЕЛЬ ДАННЫХ ---
class WheelModel {
  String id;
  String title;
  List<String> items;
  int colorIndex;

  WheelModel({
    required this.id,
    required this.title,
    required this.items,
    this.colorIndex = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'items': items,
      'colorIndex': colorIndex,
    };
  }

  factory WheelModel.fromMap(Map<String, dynamic> map) {
    return WheelModel(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Без названия',
      items: List<String>.from(map['items'] ?? []),
      colorIndex: map['colorIndex'] ?? 0,
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bottle+',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050816),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFC857),
          secondary: Color(0xFF4FB0C6),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// --- 2. ГЛАВНЫЙ ЭКРАН (БИБЛИОТЕКА) ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<WheelModel> wheels = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWheels();
  }

  Future<void> _loadWheels() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedData = prefs.getString('my_wheels_list_v2');

    if (storedData != null) {
      try {
        final List<dynamic> decoded = jsonDecode(storedData);
        if (!mounted) return;
        setState(() {
          wheels = decoded.map((e) => WheelModel.fromMap(e)).toList();
          isLoading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          wheels = _defaultWheels();
          isLoading = false;
        });
        _saveWheels();
      }
    } else {
      // СОЗДАЕМ ПРЕСЕТЫ ПРИ ПЕРВОМ ЗАПУСКЕ
      if (!mounted) return;
      setState(() {
        wheels = _defaultWheels();
        isLoading = false;
      });
      _saveWheels();
    }
  }

  List<WheelModel> _defaultWheels() {
    return [
      WheelModel(id: '1', title: '🍕 Что поесть?', items: ['Пицца', 'Суши', 'Бургер', 'Салат', 'Шаурма'], colorIndex: 0),
      WheelModel(id: '2', title: '🔥 Правда или Действие', items: ['Расскажи секрет', 'Поцелуй соседа', 'Выпей шот', 'Станцуй', 'Сними одну вещь'], colorIndex: 2),
      WheelModel(id: '3', title: '🍓 Для пары (18+)', items: ['Массаж 5 мин', 'Поцелуй в шею', 'Шлепок', 'Укус', 'Стриптиз'], colorIndex: 1),
      WheelModel(id: '4', title: '🎬 Что посмотреть', items: ['Ужастик', 'Комедия', 'Боевик', 'Аниме', 'Драма'], colorIndex: 3),
    ];
  }

  Future<void> _saveWheels() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(wheels.map((e) => e.toMap()).toList());
    await prefs.setString('my_wheels_list_v2', encoded);
  }

  void _addNewWheel() {
    final newWheel = WheelModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Новое колесо',
      items: ['Да', 'Нет'],
      colorIndex: Random().nextInt(5),
    );
    setState(() {
      wheels.add(newWheel);
    });
    _saveWheels();
    _openGameScreen(newWheel); // Сразу открываем для редактирования
  }

  void _deleteWheel(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text("Удалить колесо?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
          TextButton(
            onPressed: () {
              setState(() {
                wheels.removeAt(index);
              });
              _saveWheels();
              Navigator.pop(ctx);
            },
            child: const Text("Удалить", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openGameScreen(WheelModel wheel) async {
    // Ждем, пока юзер вернется, чтобы сохранить возможные изменения
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GameScreen(wheel: wheel)),
    );
    if (!mounted) return;
    setState(() {}); // Обновляем UI
    _saveWheels();   // Сохраняем изменения в базу
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bottle+ 🎡')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: wheels.length + 1,
              itemBuilder: (context, index) {
                // КНОПКА ДОБАВИТЬ
                if (index == wheels.length) {
                  return InkWell(
                    onTap: _addNewWheel,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12, width: 2, style: BorderStyle.solid),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, size: 40, color: Color(0xFF4FB0C6)),
                          SizedBox(height: 8),
                          Text("Создать", style: TextStyle(color: Color(0xFF4FB0C6), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                }

                // КАРТОЧКА КОЛЕСА
                final wheel = wheels[index];
                final colors = [Colors.orange, Colors.purpleAccent, Colors.redAccent, Colors.blueAccent, Colors.greenAccent];
                final color = colors[wheel.colorIndex % colors.length];

                return InkWell(
                  onTap: () => _openGameScreen(wheel),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: color.withOpacity(0.5), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(Icons.donut_large, color: color),
                            GestureDetector(
                              onTap: () => _deleteWheel(index),
                              child: const Icon(Icons.delete_outline, size: 20, color: Colors.white30),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          wheel.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${wheel.items.length} вариантов",
                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// --- 3. ЭКРАН ИГРЫ ---
class GameScreen extends StatefulWidget {
  final WheelModel wheel;
  const GameScreen({super.key, required this.wheel});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final StreamController<int> _selected = StreamController<int>.broadcast();
  late ConfettiController _confettiController;
  int? _lastIndex;
  bool _isSpinning = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _selected.close();
    _confettiController.dispose();
    super.dispose();
  }

  void _spin() {
    if (_isSpinning || widget.wheel.items.length < 2) return;
    HapticFeedback.selectionClick();
    setState(() => _isSpinning = true);
    
    final random = Random();
    final index = random.nextInt(widget.wheel.items.length);
    _lastIndex = index;
    _selected.add(index);
  }

  Future<void> _openEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditScreen(wheel: widget.wheel)),
    );
    setState(() {}); // Обновляем, если изменили название или пункты
  }

  Future<void> _showResultDialog(String result) async {
    _confettiController.play();
    HapticFeedback.heavyImpact();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Text(result, style: const TextStyle(fontSize: 28, color: Color(0xFFFFC857), fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4FB0C6)),
                child: const Text('ПРОДОЛЖИТЬ', style: TextStyle(color: Colors.black)),
              )
            ],
          ),
        );
      },
    );

    if (mounted) setState(() => _isSpinning = false);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.wheel.items;
    final sectorColors = [
      const Color(0xFFFFC857), const Color(0xFF4FB0C6), const Color(0xFFF95D6A),
      const Color(0xFF6EE7B7), const Color(0xFF9F7AEA)
    ];

    // Если вариантов меньше 2 - показываем заглушку
    if (items.length < 2) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.wheel.title), actions: [IconButton(icon: const Icon(Icons.edit), onPressed: _openEdit)]),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Мало вариантов для игры"),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _openEdit, child: const Text("Добавить варианты")),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.wheel.title),
        actions: [IconButton(icon: const Icon(Icons.edit), onPressed: _openEdit)],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const Spacer(),
              SizedBox(
                height: 340,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FortuneWheel(
                      selected: _selected.stream,
                      animateFirst: false,
                      physics: CircularPanPhysics(duration: const Duration(seconds: 4), curve: Curves.decelerate),
                      indicators: const <FortuneIndicator>[
                        FortuneIndicator(alignment: Alignment.topCenter, child: TriangleIndicator(color: Colors.white)),
                      ],
                      onAnimationEnd: () {
                        if (_lastIndex != null) _showResultDialog(items[_lastIndex!]);
                      },
                      items: [
                        for (int i = 0; i < items.length; i++)
                          FortuneItem(
                            style: FortuneItemStyle(
                              color: sectorColors[i % sectorColors.length],
                              borderColor: const Color(0xFF050816),
                              borderWidth: 2,
                              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            child: Text(items[i]),
                          ),
                      ],
                    ),
                    Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]), child: const Icon(Icons.star, color: Colors.orange, size: 30)),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity, height: 60,
                  child: ElevatedButton(
                    onPressed: _isSpinning ? null : _spin,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF95D6A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: Text(_isSpinning ? 'КРУТИМ...' : 'КРУТИТЬ', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
          Align(alignment: Alignment.topCenter, child: ConfettiWidget(confettiController: _confettiController, blastDirectionality: BlastDirectionality.explosive, shouldLoop: false)),
        ],
      ),
    );
  }
}

// --- 4. ЭКРАН РЕДАКТИРОВАНИЯ ---
class EditScreen extends StatefulWidget {
  final WheelModel wheel;
  const EditScreen({super.key, required this.wheel});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late TextEditingController _titleController;
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.wheel.title);
    _controllers = widget.wheel.items.map((e) => TextEditingController(text: e)).toList();
    if (_controllers.isEmpty) _controllers.add(TextEditingController());
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var c in _controllers) c.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    final items = _controllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Название не может быть пустым')),
      );
      return;
    }

    if (items.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте минимум 2 варианта')),
      );
      return;
    }

    widget.wheel.title = title;
    widget.wheel.items = items;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактор'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Название колеса", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            decoration: const InputDecoration(
              filled: true, fillColor: Color(0xFF111827),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Варианты", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          ...List.generate(_controllers.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controllers[index],
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        filled: true, fillColor: Color(0xFF111827),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      if (_controllers.length == 1) return;
                      final controller = _controllers.removeAt(index);
                      controller.dispose();
                      setState(() {});
                    },
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => setState(() => _controllers.add(TextEditingController())),
            icon: const Icon(Icons.add),
            label: const Text("Добавить строку"),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
          ),
        ],
      ),
    );
  }
}
