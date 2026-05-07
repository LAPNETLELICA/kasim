import 'package:freezed_annotation/freezed_annotation.dart';

part 'allowed_service.freezed.dart';
part 'allowed_service.g.dart';

@freezed
class AllowedService with _$AllowedService {
  const factory AllowedService({
    required String id,
    required String name,
    required String category,
    required List<String> hosts,
    required String iconAsset,
    @Default(false) bool isSelected,
  }) = _AllowedService;

  factory AllowedService.fromJson(Map<String, dynamic> json) =>
      _$AllowedServiceFromJson(json);
}