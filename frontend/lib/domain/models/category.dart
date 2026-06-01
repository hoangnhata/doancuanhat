import 'package:equatable/equatable.dart';

enum CategoryType { expense, income }

class Category extends Equatable {
  final int id;
  final String name;
  final String? description;
  final String? icon;
  final CategoryType type;

  const Category({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    required this.type,
  });

  @override
  List<Object?> get props => [id, name, type];
}
