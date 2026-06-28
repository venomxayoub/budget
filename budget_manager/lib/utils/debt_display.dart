import 'package:flutter/material.dart';

Color debtBalanceColor(int balanceCents) {
  if (balanceCents < 0) return Colors.red;
  if (balanceCents > 0) return Colors.blue;
  return Colors.green;
}

String debtBalanceLabel(int balanceCents) {
  if (balanceCents < 0) return 'You owe them';
  if (balanceCents > 0) return 'They owe you';
  return 'Settled';
}
