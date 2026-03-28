import 'package:google_generative_ai/google_generative_ai.dart'; 

class GeminiService {
  final GenerativeModel _model;

  GeminiService(String apiKey)
    : _model = GenerativeModel(
        model: 'gemini-1.5-flash', // Fast & Cheap for Hackathons
        apiKey: apiKey,
      );

  Future<String> getIcebreaker(List<String> userAInterests, List<String> userBInterests) async {
    final prompt =
        'User A likes: ${userAInterests.join(", ")}. User B likes: ${userBInterests.join(", ")}. '
        'Write a 1-sentence, casual icebreaker for them to meet on campus at'
        'The University of South Florida, Tampa.  '
        'Keep it under 15 words and friendly.';

    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text ?? "Hey! Looks like you both have cool interests.";
  }
}
