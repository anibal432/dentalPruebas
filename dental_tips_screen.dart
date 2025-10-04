// lib/screens/dental_tips_screen.dart
import 'package:flutter/material.dart';
import '../models/dental_tip.dart';
import '../services/dental_tips_service.dart';
import 'tip_detail_screen.dart';

class DentalTipsScreen extends StatefulWidget {
  const DentalTipsScreen({super.key});

  @override
  State<DentalTipsScreen> createState() => _DentalTipsScreenState();
}

class _DentalTipsScreenState extends State<DentalTipsScreen> {
  final DentalTipsService _service = DentalTipsService();
  String? _selectedCategory;
  List<String> _categories = ['Todos'];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      List<String> categories = await _service.getCategories();
      if (mounted) {
        setState(() {
          _categories = ['Todos', ...categories];
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _categories = [
            'Todos',
            'Niños',
            'Adultos',
            'Higiene',
            'Prevención',
            'Emergencias'
          ];
          _isLoadingCategories = false;
        });
      }
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'niños':
        return Colors.blue;
      case 'adultos':
        return Colors.green;
      case 'higiene':
        return Colors.purple;
      case 'prevención':
        return Colors.orange;
      case 'emergencias':
        return Colors.red;
      default:
        return Colors.teal;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'niños':
        return Icons.child_care;
      case 'adultos':
        return Icons.person;
      case 'higiene':
        return Icons.cleaning_services;
      case 'prevención':
        return Icons.health_and_safety;
      case 'emergencias':
        return Icons.medical_services;
      default:
        return Icons.tips_and_updates;
    }
  }

  Widget _buildCategoryFilter() {
    if (_isLoadingCategories) {
      return Container(
        height: 60,
        color: Colors.white,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: Colors.teal),
          ),
        ),
      );
    }

    return Container(
      height: 60,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category ||
              (_selectedCategory == null && category == 'Todos');

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category == 'Todos' ? null : category;
                });
              },
              selectedColor: Colors.teal.withAlpha(76),
              checkmarkColor: Colors.teal,
              backgroundColor: Colors.grey[100],
              labelStyle: TextStyle(
                color: isSelected ? Colors.teal : Colors.grey[700],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTipItem(DentalTip tip) {
    final categoryColor = _getCategoryColor(tip.category);
    final categoryIcon = _getCategoryIcon(tip.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TipDetailScreen(tip: tip),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(categoryIcon, color: categoryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip.category,
                          style: TextStyle(
                            color: categoryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tip.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tip.description,
                style: TextStyle(color: Colors.grey[700], height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${tip.createdAt.day}/${tip.createdAt.month}/${tip.createdAt.year}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Consejos Dentales'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildCategoryFilter(),
          Expanded(
            child: StreamBuilder<List<DentalTip>>(
              stream: _selectedCategory == null
                  ? _service.getAllTips()
                  : _service.getTipsByCategory(_selectedCategory!),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 60, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'Error al cargar consejos',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  );
                }

                final tips = snapshot.data ?? [];

                if (tips.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _selectedCategory == null
                              ? 'No hay consejos disponibles'
                              : 'No hay consejos en "$_selectedCategory"',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: tips.length,
                  itemBuilder: (context, index) => _buildTipItem(tips[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
