import 'package:math_expressions/math_expressions.dart';

class CalculatorLogic {
  String processInput(String buttonText, String display, String history) {
    if (buttonText == '=') {
      try {
        // Multiply aur divide ke signs ko code format me change karna
        String finalExpr = display.replaceAll('×', '*').replaceAll('÷', '/');

        // GrammarParser use kiya taaki VS Code ka blue warning hatt jaye
        GrammarParser p = GrammarParser();
        Expression exp = p.parse(finalExpr);
        ContextModel cm = ContextModel();

        // Evaluate the expression
        double eval = exp.evaluate(EvaluationType.REAL, cm);

        // Agar result 5.0 hai toh usko 5 dikhane ke liye
        if (eval == eval.toInt()) {
          return eval.toInt().toString();
        }
        return eval.toString();
      } catch (e) {
        return 'Error';
      }
    }
    return display;
  }
}
