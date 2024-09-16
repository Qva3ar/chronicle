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
  ApiKeyOption(
      label: 'GPT-4 Turbo', value: 'gpt-4-1106-preview', price: 0.00001), // Цена за входные токены
  ApiKeyOption(label: 'GPT-4', value: 'gpt-4', price: 0.03), // Оставил прежнюю цену
  ApiKeyOption(
      label: 'GPT-4o', value: 'gpt-4o-mini-2024-07-18', price: 0.00015), // Обновленная цена
  ApiKeyOption(
      label: 'GPT-3 Turbo', value: 'gpt-3.5-turbo-1106', price: 0.0012), // Обновленная цена
];
