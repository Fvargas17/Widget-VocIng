import '../l10n/app_locale.dart';
import '../services/pet_service.dart';

/// Representación visual de una mascota. Hoy es solo un emoji; es la única
/// capa que se reemplazará cuando haya pixel art con animaciones propias,
/// sin tocar el catálogo de mascotas ni `PetCompanion`.
class PetVisual {
  const PetVisual({required this.displayName, required this.emoji});

  /// El nombre vive aquí (y no en `AppStrings`) para que agregar una mascota
  /// siga siendo una sola entrada en este catálogo.
  final LocalizedText displayName;
  final String emoji;
}

const Map<Pet, PetVisual> petCatalog = {
  Pet.reno: PetVisual(
    displayName: LocalizedText(es: 'Reno', en: 'Reindeer'),
    emoji: '🦌',
  ),
  Pet.pollito: PetVisual(
    displayName: LocalizedText(es: 'Pollito', en: 'Chick'),
    emoji: '🐥',
  ),
  Pet.gato: PetVisual(
    displayName: LocalizedText(es: 'Gato', en: 'Cat'),
    emoji: '🐱',
  ),
};
