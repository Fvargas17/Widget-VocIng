import '../services/pet_service.dart';

/// Representación visual de una mascota. Hoy es solo un emoji; es la única
/// capa que se reemplazará cuando haya pixel art con animaciones propias,
/// sin tocar el catálogo de mascotas ni `PetCompanion`.
class PetVisual {
  const PetVisual({required this.displayName, required this.emoji});

  final String displayName;
  final String emoji;
}

const Map<Pet, PetVisual> petCatalog = {
  Pet.reno: PetVisual(displayName: 'Reno', emoji: '🦌'),
  Pet.pollito: PetVisual(displayName: 'Pollito', emoji: '🐥'),
  Pet.gato: PetVisual(displayName: 'Gato', emoji: '🐱'),
};
