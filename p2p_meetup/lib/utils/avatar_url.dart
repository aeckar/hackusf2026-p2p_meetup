/// DiceBear 9.x Bottts avatars (PNG for broad Flutter compatibility).
String diceBearBotttsPngUrl(String seed, {int size = 128}) {
  final s = Uri.encodeComponent(seed);
  return 'https://api.dicebear.com/9.x/bottts/png?seed=$s&size=$size';
}
