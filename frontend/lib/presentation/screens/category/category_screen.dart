import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/domain/models/category.dart';
import 'package:expense_manager/domain/repositories/category_repository.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/presentation/widgets/common/card_container.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  List<Category> _expenseCategories = [];
  List<Category> _incomeCategories = [];
  bool _isLoading = true;
  String? _error;
  bool _showExpense = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(syncServiceProvider).syncAllIfOnline();
      if (!mounted) return;
      final repo = ref.read(categoryRepositoryProvider);
      _expenseCategories = await repo.getAll(type: 'EXPENSE');
      _incomeCategories = await repo.getAll(type: 'INCOME');
      setState(() => _error = null);
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _isLoading = false);
  }

  Future<void> _showAddDialog() async {
    final nameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm danh mục'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Tên danh mục'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        await ref.read(categoryRepositoryProvider).create(
              CategoryCreateData(
                name: nameController.text.trim(),
                type: _showExpense ? 'EXPENSE' : 'INCOME',
              ),
            );
        _loadCategories();
      } catch (_) {}
    }
  }

  Future<void> _deleteCategory(Category c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa danh mục?'),
        content: Text('Bạn có chắc muốn xóa "${c.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(categoryRepositoryProvider).delete(c.id);
        _loadCategories();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _showExpense ? _expenseCategories : _incomeCategories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh mục'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCategories,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TabChip(
                    label: 'Chi tiêu',
                    isSelected: _showExpense,
                    onTap: () => setState(() => _showExpense = true),
                  ),
                  const SizedBox(width: 12),
                  _TabChip(
                    label: 'Thu nhập',
                    isSelected: !_showExpense,
                    onTap: () => setState(() => _showExpense = false),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(_error!, style: GoogleFonts.nunito(color: AppColors.accent)),
                )
              else if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
              else if (categories.isEmpty)
                CardContainer(
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.category_rounded, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          'Chưa có danh mục',
                          style: GoogleFonts.nunito(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _showAddDialog,
                          child: const Text('Thêm danh mục'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...categories.map(
                  (c) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (_showExpense ? AppColors.expense : AppColors.income).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.category_rounded,
                          color: _showExpense ? AppColors.expense : AppColors.income,
                        ),
                      ),
                      title: Text(c.name, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.accent),
                        onPressed: () => _deleteCategory(c),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
