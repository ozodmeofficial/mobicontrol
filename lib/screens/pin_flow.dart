import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/schedule.dart';
import '../services/pin.dart';

/// PIN va sovish davri (cooldown) bilan bog'liq dialoglar.
class PinFlow {
  PinFlow._();

  /// PIN o'rnatilgan bo'lsa uni so'raydi. To'g'ri kiritilsa (yoki PIN yo'q
  /// bo'lsa) `true` qaytaradi.
  static Future<bool> unlock(BuildContext context, Config config) async {
    if (!config.hasPin) return true;
    final pin = await _enterPin(context, title: 'PIN kodni kiriting');
    if (pin == null) return false;
    if (Pin.verify(pin, config.pinHash)) return true;
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("PIN noto'g'ri")));
    }
    return false;
  }

  /// Yangi PIN o'rnatadi (ikki marta tasdiqlash bilan). Hash qaytaradi yoki
  /// bekor qilinsa `null`.
  static Future<String?> setNewPin(BuildContext context) async {
    final pin = await _enterPin(
      context,
      title: 'Yangi PIN (4–8 raqam)',
      minLength: 4,
    );
    if (pin == null || !context.mounted) return null;
    final confirm = await _enterPin(context, title: 'PIN kodni takrorlang');
    if (confirm == null) return null;
    if (pin != confirm) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PIN kodlar mos kelmadi')));
      }
      return null;
    }
    return Pin.hash(pin);
  }

  static Future<String?> _enterPin(
    BuildContext context, {
    required String title,
    int minLength = 1,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(counterText: ''),
          onSubmitted: (v) {
            if (v.length >= minLength) Navigator.pop(context, v);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.length >= minLength) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Sovish davri: [minutes] daqiqa kutilgach «Tasdiqlash» tugmasi ochiladi.
  /// Kutishga sabr qilib tasdiqlansa `true`, bekor qilinsa `false`.
  ///
  /// Bu — cheklovni impulsiv ravishda o'chirib yuborishdan ushlab turuvchi
  /// ataylab qo'yilgan «to'siq». Kutish tugmagunча o'chirish amalga oshmaydi.
  static Future<bool> waitCooldown(
    BuildContext context, {
    required int minutes,
    required String title,
    required String message,
  }) async {
    if (minutes <= 0) return true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CooldownDialog(
        totalSeconds: minutes * 60,
        title: title,
        message: message,
      ),
    );
    return result ?? false;
  }
}

class _CooldownDialog extends StatefulWidget {
  const _CooldownDialog({
    required this.totalSeconds,
    required this.title,
    required this.message,
  });

  final int totalSeconds;
  final String title;
  final String message;

  @override
  State<_CooldownDialog> createState() => _CooldownDialogState();
}

class _CooldownDialogState extends State<_CooldownDialog> {
  late int _remaining = widget.totalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 0) {
        _timer?.cancel();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _clock {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final done = _remaining <= 0;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message),
          const SizedBox(height: 24),
          if (!done) ...[
            Text(_clock, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: widget.totalSeconds == 0
                  ? 1
                  : 1 - _remaining / widget.totalSeconds,
            ),
            const SizedBox(height: 8),
            Text(
              'Fikringiz o‘zgargan bo‘lsa, hozir bekor qilishingiz mumkin.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ] else
            const Text('Endi tasdiqlashingiz mumkin.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          onPressed: done ? () => Navigator.pop(context, true) : null,
          child: const Text('Tasdiqlash'),
        ),
      ],
    );
  }
}
