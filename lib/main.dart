import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:confetti/confetti.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- 1. МОДЕЛЬ ДАННЫХ ---
class WheelModel {
  String id;
  String title;
  List<String> items;
  int colorIndex;
  String sectorStyle;
  bool radialText;
  int gradientFrom;
  int gradientTo;

  WheelModel({
    required this.id,
    required this.title,
    required this.items,
    this.colorIndex = 0,
    this.sectorStyle = 'rainbow',
    this.radialText = false,
    this.gradientFrom = 0,
    this.gradientTo = 4,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'items': items,
      'colorIndex': colorIndex,
      'sectorStyle': sectorStyle,
      'radialText': radialText,
      'gradientFrom': gradientFrom,
      'gradientTo': gradientTo,
    };
  }

  factory WheelModel.fromMap(Map<String, dynamic> map) {
    return WheelModel(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Без названия',
      items: List<String>.from(map['items'] ?? []),
      colorIndex: map['colorIndex'] ?? 0,
      sectorStyle: map['sectorStyle'] ?? 'rainbow',
      radialText: map['radialText'] ?? false,
      gradientFrom: map['gradientFrom'] ?? 0,
      gradientTo: map['gradientTo'] ?? 4,
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
                            Hero(
                              tag: 'wheel_icon_${wheel.id}',
                              child: Icon(Icons.donut_large, color: color),
                            ),
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
  static const String _globalSpinsKey = 'stats_total_spins';
  static const String _achievementsKey = 'achievements_unlocked_v1';
  static const String _shakeEnabledKey = 'settings_shake_enabled_v1';

  final StreamController<int> _selected = StreamController<int>.broadcast();
  late ConfettiController _confettiController;
  StreamSubscription<AccelerometerEvent>? _shakeSubscription;
  Timer? _titleTimer;

  List<String> _runtimeItems = [];
  List<String> _players = [];
  final List<String> _spinPhrases = const ['Анализирую…', 'Считываю мысли…', 'Звезды говорят…', 'Щас решим…'];
  final Set<String> _achievements = {};

  int? _lastIndex;
  bool _isSpinning = false;
  bool _partyMode = false;
  bool _battleMode = false;
  bool _shakeEnabled = true;
  int? _forcedIndex;
  String? _selectedPlayer;
  String _appBarTitle = '';
  int _globalSpins = 0;
  int _wheelSpins = 0;
  String? _lastResultText;
  int _sameResultStreak = 0;
  DateTime _lastShakeAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _runtimeItems = List<String>.from(widget.wheel.items);
    _appBarTitle = widget.wheel.title;
    _loadMeta();
    _bindShakeListener();
  }

  @override
  void dispose() {
    _selected.close();
    _confettiController.dispose();
    _shakeSubscription?.cancel();
    _titleTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _globalSpins = prefs.getInt(_globalSpinsKey) ?? 0;
      _wheelSpins = prefs.getInt('wheel_spins_${widget.wheel.id}') ?? 0;
      _shakeEnabled = prefs.getBool(_shakeEnabledKey) ?? true;
      _achievements.addAll(prefs.getStringList(_achievementsKey) ?? <String>[]);
    });
  }

  void _bindShakeListener() {
    _shakeSubscription = accelerometerEvents.listen((event) {
      if (!_shakeEnabled || _isSpinning) return;
      final acceleration = event.x.abs() + event.y.abs() + event.z.abs();
      final now = DateTime.now();
      if (acceleration > 34 && now.difference(_lastShakeAt).inMilliseconds > 1200) {
        _lastShakeAt = now;
        _spin();
      }
    });
  }

  Future<void> _saveShakeSetting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shakeEnabledKey, _shakeEnabled);
  }

  List<String> get _activeItems => _battleMode ? _runtimeItems : widget.wheel.items;

  void _spin() {
    final items = _activeItems;
    if (_isSpinning || items.length < 2) return;
    HapticFeedback.selectionClick();
    setState(() => _isSpinning = true);

    _titleTimer?.cancel();
    _titleTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isSpinning || !mounted) {
        timer.cancel();
        return;
      }
      setState(() => _appBarTitle = _spinPhrases[Random().nextInt(_spinPhrases.length)]);
    });

    final random = Random();
    final index = _forcedIndex ?? random.nextInt(items.length);
    _forcedIndex = null;
    if (_partyMode && _players.isNotEmpty) {
      _selectedPlayer = _players[random.nextInt(_players.length)];
    } else {
      _selectedPlayer = null;
    }
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
    final text = _partyMode && _selectedPlayer != null ? 'Выпало: $_selectedPlayer → $result' : result;

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
              const Text('Результат:', style: TextStyle(color: Colors.white60, fontSize: 16)),
              const SizedBox(height: 12),
              Text(text, style: const TextStyle(fontSize: 30, color: Color(0xFFFFC857), fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Результат скопирован')),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF374151)),
                icon: const Icon(Icons.share, color: Colors.white),
                label: const Text('Скопировать', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK', style: TextStyle(color: Color(0xFF4FB0C6), fontSize: 28, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    setState(() {
      _isSpinning = false;
      _appBarTitle = widget.wheel.title;
      if (_battleMode && _activeItems.length > 1) {
        _runtimeItems.remove(result);
      }
    });
    _titleTimer?.cancel();
  }

  Future<void> _completeSpin(String result) async {
    final prefs = await SharedPreferences.getInstance();
    final globalSpins = (prefs.getInt(_globalSpinsKey) ?? 0) + 1;
    final wheelSpinsKey = 'wheel_spins_${widget.wheel.id}';
    final wheelSpins = (prefs.getInt(wheelSpinsKey) ?? 0) + 1;
    await prefs.setInt(_globalSpinsKey, globalSpins);
    await prefs.setInt(wheelSpinsKey, wheelSpins);

    _wheelSpins = wheelSpins;
    _globalSpins = globalSpins;

    final newStreak = _lastResultText == result ? _sameResultStreak + 1 : 1;
    _sameResultStreak = newStreak;
    _lastResultText = result;

    _checkAchievement('Новичок', wheelSpins >= 10);
    _checkAchievement('Фанат рандома', globalSpins >= 100);
    _checkAchievement('Карма', newStreak >= 3);

    await _showResultDialog(result);
  }

  Future<void> _checkAchievement(String name, bool reached) async {
    if (!reached || _achievements.contains(name) || !mounted) return;
    _achievements.add(name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_achievementsKey, _achievements.toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🏆 Новое достижение: $name')),
    );
  }

  Future<void> _openPartyPlayersDialog() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF111827),
              title: const Text('Игроки для Пати'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._players.map((player) => ListTile(
                          dense: true,
                          title: Text(player),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setDialogState(() => _players.remove(player)),
                          ),
                        )),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: 'Имя игрока',
                              filled: true,
                              fillColor: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            final name = controller.text.trim();
                            if (name.isEmpty) return;
                            setDialogState(() => _players.add(name));
                            controller.clear();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Готово'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showPrankPicker() async {
    final items = _activeItems;
    if (items.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      builder: (context) => ListView(
        children: [
          const ListTile(
            title: Text('😈 Режим пранк'),
            subtitle: Text('Выбери, что выпадет при следующем вращении'),
          ),
          ...List.generate(items.length, (index) {
            return ListTile(
              title: Text(items[index]),
              onTap: () {
                setState(() => _forcedIndex = index);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Пранк активирован: ${items[index]}')),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Future<void> _showStatsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          title: const Text('Статистика'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Прокрутов этого колеса: $_wheelSpins'),
              Text('Прокрутов всего: $_globalSpins'),
              const SizedBox(height: 12),
              const Text('Достижения', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_achievements.isEmpty) const Text('Пока нет'),
              ..._achievements.map((e) => Text('• $e')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  List<Color> _basePalette() {
    return const [
      Color(0xFFFF7A18),
      Color(0xFF6C63FF),
      Color(0xFF22C55E),
      Color(0xFFEC4899),
      Color(0xFFF4C95D),
      Color(0xFF06B6D4),
      Color(0xFFEF4444),
      Color(0xFFA855F7),
      Color(0xFF8B5CF6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF3B82F6),
    ];
  }

  List<Color> _resolveSectorColors(int length) {
    final palette = _basePalette();
    if (widget.wheel.sectorStyle == 'striped') {
      final c1 = palette[widget.wheel.colorIndex % palette.length];
      final c2 = palette[(widget.wheel.colorIndex + 5) % palette.length];
      return List.generate(length, (i) => i.isEven ? c1 : c2);
    }
    if (widget.wheel.sectorStyle == 'gradient') {
      final from = palette[widget.wheel.gradientFrom % palette.length];
      final to = palette[widget.wheel.gradientTo % palette.length];
      if (length <= 1) return [from];
      return List.generate(length, (i) {
        final t = i / (length - 1);
        return Color.lerp(from, to, t) ?? from;
      });
    }
    return List.generate(length, (i) => palette[i % palette.length]);
  }

  Future<void> _openAppearanceSettings() async {
    final palette = _basePalette();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Настроить вид', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  const Text('Стиль секторов'),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'rainbow', label: Text('Радужные')),
                      ButtonSegment(value: 'gradient', label: Text('Градиент')),
                      ButtonSegment(value: 'striped', label: Text('Полосатые')),
                    ],
                    selected: {widget.wheel.sectorStyle},
                    onSelectionChanged: (value) {
                      setState(() => widget.wheel.sectorStyle = value.first);
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Направление текста'),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('По кругу')),
                      ButtonSegment(value: true, label: Text('По радиусу')),
                    ],
                    selected: {widget.wheel.radialText},
                    onSelectionChanged: (value) {
                      setState(() => widget.wheel.radialText = value.first);
                      setModalState(() {});
                    },
                  ),
                  if (widget.wheel.sectorStyle == 'gradient') ...[
                    const SizedBox(height: 16),
                    const Text('Цвета градиента'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(palette.length, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() => widget.wheel.gradientFrom = index);
                            setModalState(() {});
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: palette[index],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.wheel.gradientFrom == index ? Colors.white : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(palette.length, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() => widget.wheel.gradientTo = index);
                            setModalState(() {});
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: palette[index],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.wheel.gradientTo == index ? const Color(0xFFFFC857) : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Готово'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _activeItems;
    final sectorColors = _resolveSectorColors(items.length);

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
        title: Text(_appBarTitle),
        actions: [
          IconButton(icon: const Icon(Icons.bar_chart), onPressed: _showStatsDialog),
          IconButton(icon: const Icon(Icons.settings), onPressed: _openAppearanceSettings),
          IconButton(icon: const Icon(Icons.edit), onPressed: _openEdit),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(value: false, label: Text('Обычный')),
                          ButtonSegment<bool>(value: true, label: Text('Пати')),
                        ],
                        selected: {_partyMode},
                        onSelectionChanged: (newSelection) async {
                          final isParty = newSelection.first;
                          if (isParty && _players.length < 2) {
                            await _openPartyPlayersDialog();
                          }
                          setState(() => _partyMode = isParty && _players.length >= 2);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _openPartyPlayersDialog,
                      icon: const Icon(Icons.group),
                    ),
                  ],
                ),
              ),
              SwitchListTile.adaptive(
                dense: true,
                title: const Text('Shake-to-spin'),
                value: _shakeEnabled,
                onChanged: (value) {
                  setState(() => _shakeEnabled = value);
                  _saveShakeSetting();
                },
              ),
              SwitchListTile.adaptive(
                dense: true,
                title: const Text('Королевская битва (на выбывание)'),
                value: _battleMode,
                onChanged: (value) {
                  setState(() {
                    _battleMode = value;
                    _runtimeItems = List<String>.from(widget.wheel.items);
                  });
                },
              ),
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
                        if (_lastIndex != null) _completeSpin(items[_lastIndex!]);
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
                            child: widget.wheel.radialText
                                ? RotatedBox(quarterTurns: 1, child: Text(items[i]))
                                : Text(items[i]),
                          ),
                      ],
                    ),
                    Hero(
                      tag: 'wheel_icon_${widget.wheel.id}',
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                        ),
                        child: const Icon(Icons.star, color: Colors.orange, size: 30),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity, height: 60,
                  child: GestureDetector(
                    onLongPress: _showPrankPicker,
                    child: ElevatedButton(
                      onPressed: _isSpinning ? null : _spin,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF95D6A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: Text(_isSpinning ? 'КРУТИМ...' : 'КРУТИТЬ', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
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
