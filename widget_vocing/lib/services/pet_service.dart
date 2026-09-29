import 'package:shared_preferences/shared_preferences.dart';

const _petPrefsKey = 'selected_pet';

/// Mascota de compañía que camina debajo de la tarjeta en `HomeScreen`. Ver
/// `lib/pets/pet_catalog.dart` para su representación visual y
/// `lib/widgets/pet_companion.dart` para su comportamiento.
enum Pet { reno, pollito, gato }

const Pet defaultPet = Pet.reno;

Future<Pet> getPet() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(_petPrefsKey);
  return Pet.values.asNameMap()[stored] ?? defaultPet;
}

Future<void> setPet(Pet pet) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_petPrefsKey, pet.name);
}
