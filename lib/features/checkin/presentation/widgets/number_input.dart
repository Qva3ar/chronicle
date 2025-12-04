import 'package:chrono/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Number input widget for metrics like steps, minutes, etc.
class NumberInput extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final String? unit;
  final int? previousValue;

  const NumberInput({
    Key? key,
    required this.value,
    required this.onChanged,
    this.unit,
    this.previousValue,
  }) : super(key: key);

  @override
  State<NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<NumberInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(NumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate change info
    IconData? changeIcon;
    Color? changeColor;
    if (widget.previousValue != null) {
      if (widget.value > widget.previousValue!) {
        changeIcon = Icons.arrow_upward;
        changeColor = Colors.green;
      } else if (widget.value < widget.previousValue!) {
        changeIcon = Icons.arrow_downward;
        changeColor = Colors.red;
      } else {
        changeIcon = Icons.remove;
        changeColor = Colors.grey;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Input field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: MyColors.secondaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: MyColors.forthyColor,
                    ),
                  ),
                  onChanged: (value) {
                    final intValue = int.tryParse(value) ?? 0;
                    widget.onChanged(intValue);
                  },
                ),
              ),
            ),

            // Unit text
            if (widget.unit != null) ...[
              const SizedBox(width: 12),
              Text(
                widget.unit!,
                style: const TextStyle(
                  color: MyColors.fivyColor,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),

        // Previous value comparison
        if (widget.previousValue != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Прошлый раз: ${widget.previousValue}${widget.unit != null ? ' ${widget.unit}' : ''}',
                style: TextStyle(
                  color: MyColors.fivyColor.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              if (changeIcon != null) ...[
                const SizedBox(width: 8),
                Icon(
                  changeIcon,
                  size: 14,
                  color: changeColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '${(widget.value - widget.previousValue!).abs()}',
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
