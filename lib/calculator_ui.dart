import 'package:flutter/material.dart';

import 'calculator_logic.dart';
import 'updater_service.dart';
import 'secret_login.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
  String _history = '';
  final CalculatorLogic _logic = CalculatorLogic();

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  void _checkForUpdates() async {
    // Red Error Fix: Directly calling the static method
    await UpdaterService.checkForUpdate(context);
  }

  void _onButtonPressed(String buttonText) {
    setState(() {
      if (buttonText == 'C') {
        _display = '0';
        _history = '';
      } else if (buttonText == '⌫') {
        _display = _display.length > 1
            ? _display.substring(0, _display.length - 1)
            : '0';
      } else if (buttonText == '=') {
        // Vault Opening Logic
        if (_display == '8055') {
          _display = '0';
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SecretLogin()),
          );
        } else {
          // Red Error Fix: Passing all 3 arguments
          _history = _display;
          _display = _logic.processInput('=', _display, _history);
        }
      } else if (buttonText == '( )') {
        if (_display == '0') {
          _display = '(';
        } else {
          _display += '(';
        }
      } else {
        if (_display == '0' && buttonText != '.') {
          _display = buttonText;
        } else {
          _display += buttonText;
        }
      }
    });
  }

  Widget _buildButton(
    String text, {
    Color textColor = Colors.white,
    Color? bgColor,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: () => _onButtonPressed(text),
          customBorder: const CircleBorder(),
          child: Ink(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor ?? const Color(0xFF1E1E1E), // Dark Grey Background
            ),
            child: Center(
              child: text == '⌫'
                  ? Icon(
                      Icons.backspace_outlined,
                      color: textColor,
                      size: 24,
                    ) // Backspace icon
                  : Text(
                      text,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 28,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Premium Pitch Black
      body: SafeArea(
        child: Column(
          children: [
            // Display Area
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _history,
                      style: const TextStyle(color: Colors.grey, fontSize: 24),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _display,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Keypad Area exactly like the image provided
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildButton('C', textColor: Colors.redAccent),
                      _buildButton('⌫', textColor: Colors.redAccent),
                      _buildButton('%'),
                      _buildButton('÷'),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('7'),
                      _buildButton('8'),
                      _buildButton('9'),
                      _buildButton('×'),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('4'),
                      _buildButton('5'),
                      _buildButton('6'),
                      _buildButton('-'),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('1'),
                      _buildButton('2'),
                      _buildButton('3'),
                      _buildButton('+'),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('( )'),
                      _buildButton('0'),
                      _buildButton('.'),
                      _buildButton(
                        '=',
                        bgColor: const Color(0xFF007A5E),
                      ), // Teal Green color
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
