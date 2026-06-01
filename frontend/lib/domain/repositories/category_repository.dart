import 'package:expense_manager/domain/models/category.dart';

abstract class CategoryRepository {
  Future<Category> create(CategoryCreateData data);
  Future<Category> getById(int id);
  Future<List<Category>> getAll({String? type});
  Future<Category> update(int id, CategoryCreateData data);
  Future<void> delete(int id);
}

class CategoryCreateData {
  final String name;
  final String? description;
  final String? icon;
  final String type;

  CategoryCreateData({
    required this.name,
    this.description,
    this.icon,
    required this.type,
  });
}
