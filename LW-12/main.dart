import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color primaryBlue = Color(0xFF4169E1);
const Color backgroundColor = Color(0xFFF4F6FA);


class Product extends Equatable {
  final String id;
  final String title;
  final String category;
  final double price;
  final IconData icon;

  const Product({
    required this.id,
    required this.title,
    required this.category,
    required this.price,
    required this.icon,
  });

  @override
  List<Object?> get props => [id, title, category, price, icon];
}

final List<Product> products = [
  const Product(
    id: '1',
    title: 'iPhone 16',
    category: 'Smartphones',
    price: 999,
    icon: Icons.phone_iphone,
  ),
  const Product(
    id: '2',
    title: 'MacBook Air',
    category: 'Laptops',
    price: 1299,
    icon: Icons.laptop_mac,
  ),
  const Product(
    id: '3',
    title: 'AirPods Pro',
    category: 'Accessories',
    price: 249,
    icon: Icons.headphones,
  ),
  const Product(
    id: '4',
    title: 'Apple Watch',
    category: 'Smart Watches',
    price: 399,
    icon: Icons.watch,
  ),
  const Product(
    id: '5',
    title: 'iPad Air',
    category: 'Tablets',
    price: 699,
    icon: Icons.tablet_mac,
  ),
];


class NoteItem extends Equatable {
  final String id;
  final String title;
  final String dateText;
  final bool isCompleted;

  const NoteItem({
    required this.id,
    required this.title,
    required this.dateText,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'dateText': dateText,
      'isCompleted': isCompleted,
    };
  }

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    return NoteItem(
      id: json['id'] as String,
      title: json['title'] as String,
      dateText: json['dateText'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  NoteItem copyWith({bool? isCompleted}) {
    return NoteItem(
      id: id,
      title: title,
      dateText: dateText,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        dateText,
        isCompleted,
      ];
}


abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final String username;
  final String email;

  const AuthSuccess(this.username, this.email);

  @override
  List<Object?> get props => [username, email];
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}


class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial());

  Future<void> login(String email, String password) async {
    emit(AuthLoading());

    await Future.delayed(
      const Duration(seconds: 1),
    );

    if (email == 'student@narxoz.kz' &&
        password == '123456') {
      emit(AuthSuccess('Student', email));
    } else {
      emit(const AuthError('Invalid email or password'));
    }
  }
}


abstract class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => [];
}

class AddProductEvent extends CartEvent {
  final Product product;

  const AddProductEvent(this.product);

  @override
  List<Object?> get props => [product];
}

class RemoveProductEvent extends CartEvent {
  final String productId;

  const RemoveProductEvent(this.productId);

  @override
  List<Object?> get props => [productId];
}

class ClearCartEvent extends CartEvent {}


class CartState extends Equatable {
  final List<Product> items;

  CartState({List<Product> items = const []})
      : items = List.unmodifiable(items);

  int get count => items.length;

  double get totalPrice {
    return items.fold(
      0.0,
      (sum, product) => sum + product.price,
    );
  }

  @override
  List<Object?> get props => [items];
}


class CartBloc extends Bloc<CartEvent, CartState> {
  final SharedPreferences prefs;

  CartBloc({
    required this.prefs,
    List<Product> initialItems = const [],
  }) : super(CartState(items: initialItems)) {
    on<AddProductEvent>((event, emit) async {
      final updatedItems = [
        ...state.items,
        event.product,
      ];

      emit(CartState(items: updatedItems));
      await saveCart(updatedItems);
    });

    on<RemoveProductEvent>((event, emit) async {
      final updatedItems = [...state.items];

      final index = updatedItems.indexWhere(
        (product) => product.id == event.productId,
      );

      if (index != -1) {
        updatedItems.removeAt(index);
      }

      emit(CartState(items: updatedItems));
      await saveCart(updatedItems);
    });

    on<ClearCartEvent>((event, emit) async {
      emit(CartState());
      await saveCart([]);
    });
  }


  Future<void> saveCart(List<Product> items) async {
    final cartIds = items.map((item) => item.id).toList();

    await prefs.setString(
      'saved_cart',
      jsonEncode(cartIds),
    );
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  final isDark =
      prefs.getBool('app_theme_dark_mode') ?? false;


  final username =
      prefs.getString('user_display_name') ?? 'Guest User';


  List<NoteItem> savedNotes = [];

  final notesJson = prefs.getString('saved_notes');

  if (notesJson != null) {
    try {
      final List decoded = jsonDecode(notesJson);

      savedNotes = decoded
          .map(
            (item) => NoteItem.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (error) {
      savedNotes = [];
    }
  }


  List<Product> savedCart = [];

  final cartJson = prefs.getString('saved_cart');

  if (cartJson != null) {
    try {
      final List ids = jsonDecode(cartJson);

      savedCart = ids
          .map(
            (id) => products.firstWhere(
              (product) => product.id == id,
            ),
          )
          .toList();
    } catch (error) {
      savedCart = [];
    }
  }

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => AuthCubit(),
        ),
        BlocProvider(
          create: (context) => CartBloc(
            prefs: prefs,
            initialItems: savedCart,
          ),
        ),
      ],
      child: MyApp(
        prefs: prefs,
        initialDarkMode: isDark,
        initialUsername: username,
        initialNotes: savedNotes,
      ),
    ),
  );
}


class MyApp extends StatefulWidget {
  final SharedPreferences prefs;
  final bool initialDarkMode;
  final String initialUsername;
  final List<NoteItem> initialNotes;

  const MyApp({
    super.key,
    required this.prefs,
    required this.initialDarkMode,
    required this.initialUsername,
    required this.initialNotes,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool isDarkMode;

  @override
  void initState() {
    super.initState();
    isDarkMode = widget.initialDarkMode;
  }

  void changeTheme(bool value) async {
    setState(() {
      isDarkMode = value;
    });

    await widget.prefs.setBool(
      'app_theme_dark_mode',
      value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TechStore',
      themeMode: isDarkMode
          ? ThemeMode.dark
          : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: backgroundColor,
        primaryColor: primaryBlue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: LoginScreen(
        prefs: widget.prefs,
        username: widget.initialUsername,
        initialNotes: widget.initialNotes,
        isDarkMode: isDarkMode,
        onThemeChanged: changeTheme,
      ),
    );
  }
}


class LoginScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final String username;
  final List<NoteItem> initialNotes;
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const LoginScreen({
    super.key,
    required this.prefs,
    required this.username,
    required this.initialNotes,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController(
    text: 'student@narxoz.kz',
  );

  final passwordController = TextEditingController(
    text: '123456',
  );

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(

      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        if (state is AuthSuccess) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CatalogScreen(
                prefs: widget.prefs,
                username: widget.username,
                initialNotes: widget.initialNotes,
                isDarkMode: widget.isDarkMode,
                onThemeChanged: widget.onThemeChanged,
              ),
            ),
          );
        }
      },


      builder: (context, state) {
        return Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.shopping_bag_rounded,
                        size: 60,
                        color: primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        'Welcome to TechStore',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Sign in to continue',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Email',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Password',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: state is AuthLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: primaryBlue,
                              ),
                            )
                          : ElevatedButton(
                              onPressed: () {
                                context.read<AuthCubit>().login(
                                      emailController.text.trim(),
                                      passwordController.text,
                                    );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Login'),
                            ),
                    ),
                    const SizedBox(height: 15),
                    const Center(
                      child: Text(
                        'Demo: student@narxoz.kz / 123456',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


class CatalogScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final String username;
  final List<NoteItem> initialNotes;
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const CatalogScreen({
    super.key,
    required this.prefs,
    required this.username,
    required this.initialNotes,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  int selectedIndex = 0;

  late List<NoteItem> notes;
  late TextEditingController nameController;

  final noteController = TextEditingController();

  late String username;
  late bool darkMode;

  @override
  void initState() {
    super.initState();

    notes = List.from(widget.initialNotes);
    username = widget.username;
    darkMode = widget.isDarkMode;

    nameController = TextEditingController(
      text: username == 'Guest User' ? '' : username,
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    noteController.dispose();
    super.dispose();
  }


  void saveUsername() async {
    final name = nameController.text.trim();

    if (name.isEmpty) return;

    await widget.prefs.setString(
      'user_display_name',
      name,
    );

    if (!mounted) return;

    setState(() {
      username = name;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Username saved!')),
    );
  }


  Future<void> saveNotes() async {
    final jsonString = jsonEncode(
      notes.map((note) => note.toJson()).toList(),
    );

    await widget.prefs.setString(
      'saved_notes',
      jsonString,
    );
  }


  void addNote() async {
    final title = noteController.text.trim();

    if (title.isEmpty) return;

    final newNote = NoteItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      dateText: DateTime.now().toString().substring(0, 10),
    );

    setState(() {
      notes.insert(0, newNote);
      noteController.clear();
    });

    await saveNotes();
  }


  void toggleNote(int index, bool value) async {
    setState(() {
      notes[index] = notes[index].copyWith(
        isCompleted: value,
      );
    });

    await saveNotes();
  }


  void deleteNote(int index) async {
    setState(() {
      notes.removeAt(index);
    });

    await saveNotes();
  }


  void changeDarkMode(bool value) {
    setState(() {
      darkMode = value;
    });

    widget.onThemeChanged(value);
  }


  Widget buildProductCard(Product product) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              product.icon,
              size: 32,
              color: primaryBlue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  product.category,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<CartBloc>().add(
                    AddProductEvent(product),
                  );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${product.title} added to cart'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }


  Widget buildNoteCard(int index) {
    final note = notes[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Checkbox(
            value: note.isCompleted,
            activeColor: primaryBlue,
            onChanged: (value) {
              toggleNote(index, value ?? false);
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: note.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: note.isCompleted ? Colors.grey : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note.dateText,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => deleteNote(index),
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }


  Widget buildShopTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Discover Technology',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Find your favorite devices',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 22),
        ...products.map(
          (product) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: buildProductCard(product),
          ),
        ),
      ],
    );
  }


  Widget buildCartTab() {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, state) {
        if (state.items.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 70,
                  color: Colors.grey,
                ),
                SizedBox(height: 12),
                Text(
                  'Your cart is empty',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: state.items.length,
                  separatorBuilder: (context, index) {
                    return const SizedBox(height: 12);
                  },
                  itemBuilder: (context, index) {
                    final product = state.items[index];

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            product.icon,
                            size: 35,
                            color: primaryBlue,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '\$${product.price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              context.read<CartBloc>().add(
                                    RemoveProductEvent(product.id),
                                  );
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Items'),
                        Text(
                          '${state.count}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Price',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${state.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            color: primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          context.read<CartBloc>().add(
                                ClearCartEvent(),
                              );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(14),
                        ),
                        child: const Text('Clear All'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Center(
          child: CircleAvatar(
            radius: 42,
            backgroundColor: Color(0xFFEEF3FF),
            child: Icon(
              Icons.person,
              size: 48,
              color: primaryBlue,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            username,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 25),

        const Text(
          'Personal Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saveUsername,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Profile'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'App Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Change application theme'),
            secondary: const Icon(
              Icons.dark_mode_outlined,
              color: primaryBlue,
            ),
            value: darkMode,
            onChanged: changeDarkMode,
          ),
        ),

        const SizedBox(height: 24),

        const Text(
          'My Notes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  hintText: 'Write a new note...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: addNote,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Note'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        if (notes.isEmpty)
          const Center(
            child: Text(
              'No notes yet',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ...List.generate(
            notes.length,
            (index) => buildNoteCard(index),
          ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final titles = [
      'TechStore',
      'Shopping Cart',
      'My Profile',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),


      body: IndexedStack(
        index: selectedIndex,
        children: [
          buildShopTab(),
          buildCartTab(),
          buildProfileTab(),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        selectedItemColor: primaryBlue,
        unselectedItemColor: Colors.grey,
        backgroundColor: Theme.of(context).cardColor,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Shop',
          ),
          BottomNavigationBarItem(
            icon: BlocBuilder<CartBloc, CartState>(
              builder: (context, state) {
                return Badge(
                  label: Text('${state.count}'),
                  isLabelVisible: state.count > 0,
                  child: const Icon(
                    Icons.shopping_cart_outlined,
                  ),
                );
              },
            ),
            label: 'Cart',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
