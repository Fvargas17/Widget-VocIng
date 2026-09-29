import 'package:flutter/foundation.dart';

import 'pet_service.dart';

/// Mascota activa actualmente. `SettingsScreen` lo actualiza al elegir una
/// mascota nueva y `HomeScreen` lo escucha para redibujar `PetCompanion` sin
/// pasar por Navigator.
final ValueNotifier<Pet> petNotifier = ValueNotifier<Pet>(defaultPet);
