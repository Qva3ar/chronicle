class ApiKeyOption {
  final String label;
  final String value;
  final double price;

  ApiKeyOption({
    required this.label,
    required this.value,
    required this.price,
  });
}

final List<ApiKeyOption> apiKeyOptions = [
  ApiKeyOption(label: '', value: '', price: 0),
  // Latest recommended models (v5)
  ApiKeyOption(label: 'GPT-5', value: 'gpt-5', price: 0),
  ApiKeyOption(label: 'GPT-5 mini', value: 'gpt-5-mini', price: 0),
  ApiKeyOption(label: 'GPT-5 nano', value: 'gpt-5-nano', price: 0),
  // Latest recommended models (v4o)
  ApiKeyOption(label: 'GPT-4o', value: 'gpt-4o', price: 0.005), // Цена за входные токены (per 1K)
  ApiKeyOption(
      label: 'GPT-4o mini',
      value: 'gpt-4o-mini',
      price: 0.00015), // Цена за входные токены (per 1K)
  // Backward-compatible/legacy entries (kept to avoid breaking saved selections)
  ApiKeyOption(
      label: 'GPT-4 Turbo', value: 'gpt-4-1106-preview', price: 0.00001), // Цена за входные токены
  ApiKeyOption(label: 'GPT-4', value: 'gpt-4', price: 0.03), // Оставил прежнюю цену
  ApiKeyOption(
      label: 'GPT-4o mini (old alias)',
      value: 'gpt-4o-mini-2024-07-18',
      price: 0.00015), // Старый алиас для совместимости
  ApiKeyOption(
      label: 'GPT-3 Turbo', value: 'gpt-3.5-turbo-1106', price: 0.0012), // Обновленная цена
];
