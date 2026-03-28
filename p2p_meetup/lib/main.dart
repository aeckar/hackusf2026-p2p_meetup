import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/gemini_service.dart'; // Ensure this file exists

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pemnwlmnxjgpqognkrwf.supabase.co',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  runApp(const HackUSFApp());
}

final supabase = Supabase.instance.client;

class HackUSFApp extends StatelessWidget {
  const HackUSFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USF Connect',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF006747), // USF Green
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006747),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const CampusFeedScreen(),
    );
  }
}

class CampusFeedScreen extends StatefulWidget {
  const CampusFeedScreen({super.key});

  @override
  State<CampusFeedScreen> createState() => _CampusFeedScreenState();
}

class _CampusFeedScreenState extends State<CampusFeedScreen> {
  final _usernameController = TextEditingController();
  final _interestsController = TextEditingController();
  String _selectedBuilding = 'ENB';

  // Real-time Stream from Supabase
  final Stream<List<Map<String, dynamic>>> _userStream = supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('is_online', true)
      .order('updated_at', ascending: false);

  Future<void> _checkIn() async {
    final user = supabase.auth.currentUser;
    // For Hackathon speed: If not logged in, we use a fixed ID or Auth flow.
    // Assuming you have a basic Auth setup or are using a Guest ID for testing.
    await supabase.from('profiles').upsert({
      'id': user?.id ?? 'guest-id-123',
      'username': _usernameController.text,
      'interests': _interestsController.text
          .split(',')
          .map((e) => e.trim())
          .toList(),
      'campus_location': _selectedBuilding,
      'is_online': true,
      'updated_at': DateTime.now().toIso8601String(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checked in! You are now visible on campus.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('USF Live Meetup')),
      body: Column(
        children: [
          // 1. Profile / Check-in Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    TextField(
                      controller: _interestsController,
                      decoration: const InputDecoration(
                        labelText: 'Interests (comma separated)',
                      ),
                    ),
                    DropdownButton<String>(
                      value: _selectedBuilding,
                      isExpanded: true,
                      items: ['ENB', 'MSC', 'Library', 'Marshall Center']
                          .map(
                            (b) => DropdownMenuItem(value: b, child: Text(b)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedBuilding = val!),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _checkIn,
                      child: const Text('Check In Live'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
          const Text(
            "Students Nearby",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          // 2. Real-time List Section
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _userStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final users = snapshot.data!;
                if (users.isEmpty)
                  return const Center(
                    child: Text("No one is online yet. Be the first!"),
                  );

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final person = users[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(person['username'] ?? 'Anonymous'),
                      subtitle: Text(
                        "${person['campus_location']} • Interests: ${person['interests']?.join(', ')}",
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.bolt, color: Colors.amber),
                        onPressed: () {
                          // This is where you'd call GeminiService.getIcebreaker()
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
