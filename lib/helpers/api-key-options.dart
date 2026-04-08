/// См. ориентиры по задержке до первого токена (TTFT):
/// - [Artificial Analysis — Latency](https://artificialanalysis.ai/models) (TTFT / «Time To First Answer Token»;
///   у reasoning-моделей включает время «размышления» до ответа).
/// - [OpenAI — Latency optimization](https://platform.openai.com/docs/guides/latency-optimization)
///   (меньшие модели обычно быстрее по инференсу).
/// Фактические секунды зависят от нагрузки API и сети.
class ApiKeyOption {
  final String label;
  final String value;
  final double price;
  final int? tpm; // Tokens per minute
  final int? rpm; // Requests per minute
  final int? tpd; // Tokens per day
  final String provider; // openai or gemini

  /// Краткая метка относительно других моделей в этом списке (TTFT / ожидание до стрима).
  final String? speedLabel;

  ApiKeyOption({
    required this.label,
    required this.value,
    required this.price,
    this.tpm,
    this.rpm,
    this.tpd,
    this.speedLabel,
    this.provider = 'openai',
  });

  /// Подпись для UI (выпадающий список и т.п.).
  String get displayLabel =>
      speedLabel == null || speedLabel!.isEmpty ? label : '$label · $speedLabel';
}

final List<ApiKeyOption> apiKeyOptions = [
  ApiKeyOption(label: '', value: '', price: 0),
  // Gemini options
  ApiKeyOption(
    label: 'Gemini 2.5 Pro',
    value: 'gemini-2.5-pro',
    price: 0,
    provider: 'gemini',
    speedLabel: 'самый мощный',
  ),
  ApiKeyOption(
    label: 'Gemini 2.5 Flash',
    value: 'gemini-2.5-flash',
    price: 0,
    provider: 'gemini',
    speedLabel: 'очень быстрый',
  ),
  ApiKeyOption(
    label: 'Gemini 1.5 Pro',
    value: 'gemini-1.5-pro',
    price: 0,
    provider: 'gemini',
    speedLabel: 'мощный',
  ),
  ApiKeyOption(
    label: 'Gemini 1.5 Flash',
    value: 'gemini-1.5-flash',
    price: 0,
    provider: 'gemini',
    speedLabel: 'быстрый',
  ),
  // Latest recommended models (v5)
  ApiKeyOption(
    label: 'GPT-5',
    value: 'gpt-5',
    price: 0,
    tpm: 500000,
    rpm: 500,
    tpd: 1500000,
    speedLabel: 'долгий старт (reasoning)',
  ),
  ApiKeyOption(
    label: 'GPT-5 mini',
    value: 'gpt-5-mini',
    price: 0,
    tpm: 500000,
    rpm: 500,
    tpd: 5000000,
    speedLabel: 'долгий старт (reasoning)',
  ),
  ApiKeyOption(
    label: 'GPT-5 nano',
    value: 'gpt-5-nano',
    price: 0,
    tpm: 200000,
    rpm: 500,
    tpd: 2000000,
    speedLabel: 'долгий старт (reasoning)',
  ),
  // Latest recommended models (v4o)
  ApiKeyOption(
    label: 'GPT-4o',
    value: 'gpt-4o',
    price: 0.005,
    speedLabel: 'средняя пауза',
  ), // Цена за входные токены (per 1K)
  ApiKeyOption(
    label: 'GPT-4o mini',
    value: 'gpt-4o-mini',
    price: 0.00015,
    speedLabel: 'быстрый старт',
  ), // Цена за входные токены (per 1K)
  // Backward-compatible/legacy entries (kept to avoid breaking saved selections)
  ApiKeyOption(
    label: 'GPT-4 Turbo',
    value: 'gpt-4-1106-preview',
    price: 0.00001,
    speedLabel: 'средняя пауза',
  ),
  ApiKeyOption(
    label: 'GPT-4',
    value: 'gpt-4',
    price: 0.03,
    speedLabel: 'средняя пауза',
  ),
  ApiKeyOption(
    label: 'GPT-4o mini (old alias)',
    value: 'gpt-4o-mini-2024-07-18',
    price: 0.00015,
    speedLabel: 'быстрый старт',
  ),
  ApiKeyOption(
    label: 'GPT-3 Turbo',
    value: 'gpt-3.5-turbo-1106',
    price: 0.0012,
    speedLabel: 'быстрый старт',
  ),
];
