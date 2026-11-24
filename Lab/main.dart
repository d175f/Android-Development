import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

const Color primaryBlue = Color(0xFF4169E1);
const Color backgroundColor = Color(0xFFF4F6FA);
const Color paleBlue = Color(0xFFEEF3FF);

void main() {
  runApp(const PhotoDiaryApp());
}

class PhotoDiaryApp extends StatelessWidget {
  const PhotoDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Photo Diary',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
          foregroundColor: Color(0xFF202A44),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: backgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: primaryBlue,
              width: 1.5,
            ),
          ),
        ),
      ),
      home: const PhotoDiaryScreen(),
    );
  }
}

class PhotoDiaryScreen extends StatefulWidget {
  const PhotoDiaryScreen({super.key});

  @override
  State<PhotoDiaryScreen> createState() => _PhotoDiaryScreenState();
}

class _PhotoDiaryScreenState extends State<PhotoDiaryScreen> {
  final ImagePicker picker = ImagePicker();
  final TextEditingController captionController = TextEditingController();

  File? selectedImage;
  Position? currentPosition;

  bool loading = false;
  int selectedIndex = 0;

  List<Map<String, dynamic>> entries = [];

  @override
  void initState() {
    super.initState();
    loadEntries();
  }

  Future<void> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('photo_entries');

    if (saved != null) {
      setState(() {
        entries = List<Map<String, dynamic>>.from(
          jsonDecode(saved).map(
                (item) => Map<String, dynamic>.from(item),
          ),
        );
      });
    }
  }

  Future<void> saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('photo_entries', jsonEncode(entries));
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF202A44),
      ),
    );
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1080,
      );

      if (image != null) {
        setState(() {
          selectedImage = File(image.path);
        });
      }
    } catch (e) {
      showMessage('Could not open image: $e');
    }
  }

  Future<void> getLocation() async {
    setState(() {
      loading = true;
    });

    try {
      bool serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception('Please enable GPS on your device.');
      }

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied.');
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        currentPosition = position;
      });

      showMessage('Location successfully received!');
    } catch (e) {
      showMessage(e.toString());
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> saveEntry() async {
    if (selectedImage == null) {
      showMessage('Please select a photo first.');
      return;
    }

    if (currentPosition == null) {
      showMessage('Please get your location first.');
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();

      final fileName =
          'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final savedImage = await selectedImage!.copy(
        '${directory.path}/$fileName',
      );

      final entry = {
        'imagePath': savedImage.path,
        'caption': captionController.text.trim(),
        'date': DateTime.now().toIso8601String(),
        'latitude': currentPosition!.latitude,
        'longitude': currentPosition!.longitude,
        'altitude': currentPosition!.altitude,
        'accuracy': currentPosition!.accuracy,
      };

      setState(() {
        entries.insert(0, entry);
        selectedImage = null;
        currentPosition = null;
        captionController.clear();
      });

      await saveEntries();

      showMessage('Photo saved successfully!');

      setState(() {
        selectedIndex = 1;
      });
    } catch (e) {
      showMessage('Could not save photo: $e');
    }
  }

  Future<void> deleteEntry(int index) async {
    final entry = entries[index];

    setState(() {
      entries.removeAt(index);
    });

    await saveEntries();

    try {
      final file = File(entry['imagePath']);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    showMessage('Photo deleted.');
  }

  String formatDate(String value) {
    final date = DateTime.parse(value).toLocal();

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day.$month.$year at $hour:$minute';
  }

  @override
  void dispose() {
    captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(
              Icons.photo_camera_back_rounded,
              color: primaryBlue,
              size: 27,
            ),
            SizedBox(width: 10),
            Text(
              'Photo Diary',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 21,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 19,
              backgroundColor: paleBlue,
              child: const Icon(
                Icons.person,
                color: primaryBlue,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: [
          buildCreatePage(),
          buildDiaryPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        backgroundColor: Colors.white,
        indicatorColor: paleBlue,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_a_photo_outlined),
            selectedIcon: Icon(Icons.add_a_photo),
            label: 'Create',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'My Diary',
          ),
        ],
      ),
    );
  }

  Widget buildCreatePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Capture your moments',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Color(0xFF202A44),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Save photos with their location and memories.',
            style: TextStyle(
              color: Colors.blueGrey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.camera_alt, color: primaryBlue),
                      SizedBox(width: 9),
                      Text(
                        'Your Photo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (selectedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        selectedImage!,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      height: 175,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: paleBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            color: primaryBlue,
                            size: 48,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No photo selected',
                            style: TextStyle(
                              color: primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Take a photo or choose from gallery',
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryBlue,
                            side: const BorderSide(
                              color: primaryBlue,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (selectedImage != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            selectedImage = null;
                          });
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove photo'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit_note, color: primaryBlue),
                      SizedBox(width: 9),
                      Text(
                        'Photo Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: captionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Write something about this moment...',
                      labelText: 'Caption',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_on, color: primaryBlue),
                      SizedBox(width: 9),
                      Text(
                        'Location Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (currentPosition == null)
                    const Text(
                      'Get your current GPS coordinates to attach them to your photo.',
                      style: TextStyle(
                        color: Colors.blueGrey,
                        height: 1.5,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: paleBlue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          locationRow(
                            'Latitude',
                            currentPosition!.latitude.toStringAsFixed(6),
                          ),
                          locationRow(
                            'Longitude',
                            currentPosition!.longitude.toStringAsFixed(6),
                          ),
                          locationRow(
                            'Altitude',
                            '${currentPosition!.altitude.toStringAsFixed(1)} m',
                          ),
                          locationRow(
                            'Accuracy',
                            '${currentPosition!.accuracy.toStringAsFixed(1)} m',
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : getLocation,
                      icon: loading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.my_location),
                      label: Text(
                        loading ? 'Getting location...' : 'Get Location',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryBlue,
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                        side: const BorderSide(color: primaryBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: saveEntry,
              icon: const Icon(Icons.save_rounded),
              label: const Text(
                'Save Photo Entry',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget buildDiaryPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Memories',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF202A44),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${entries.length} saved ${entries.length == 1 ? 'memory' : 'memories'}',
                style: const TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: const BoxDecoration(
                      color: paleBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      size: 55,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Your diary is empty',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF202A44),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start capturing your favorite moments!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        selectedIndex = 0;
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final imageFile = File(entry['imagePath']);

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageFile.existsSync())
                      Image.file(
                        imageFile,
                        width: double.infinity,
                        height: 210,
                        fit: BoxFit.cover,
                      )
                    else
                      Container(
                        height: 150,
                        width: double.infinity,
                        color: paleBlue,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: primaryBlue,
                          size: 45,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (entry['caption'] as String).isEmpty
                                      ? 'Untitled memory'
                                      : entry['caption'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF202A44),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => deleteEntry(index),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: primaryBlue,
                                size: 15,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                formatDate(entry['date']),
                                style: const TextStyle(
                                  color: Colors.blueGrey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: paleBlue,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                locationRow(
                                  'Latitude',
                                  (entry['latitude'] as num)
                                      .toStringAsFixed(6),
                                ),
                                locationRow(
                                  'Longitude',
                                  (entry['longitude'] as num)
                                      .toStringAsFixed(6),
                                ),
                                locationRow(
                                  'Altitude',
                                  '${(entry['altitude'] as num).toStringAsFixed(1)} m',
                                ),
                                locationRow(
                                  'Accuracy',
                                  '${(entry['accuracy'] as num).toStringAsFixed(1)} m',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget locationRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.blueGrey,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF202A44),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
