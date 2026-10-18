import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_manager/app/theme.dart';
import 'package:money_manager/app/widgets/amount_text.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/transaction.dart';

/// A single transaction row for the transactions list.
///
/// 56-high row with leading category circle, title, muted subtitle,
/// trailing amount. Swipe-to-delete handled by the parent list.
class TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TransactionListItem({
    super.key,
    required this.transaction,
    this.category,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d');
    final timeFormat = DateFormat('hh:mm a');

    return Dismissible(
      key: ValueKey(transaction.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Theme.of(context).colorScheme.error,
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Theme.of(context).colorScheme.error,
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor:
              (category != null
                      ? Theme.of(context).extension<MoneyColors>()?.expense
                      : Theme.of(context).colorScheme.error)
                  ?.withValues(alpha: 0.15) ??
              Theme.of(context).colorScheme.error.withValues(alpha: 0.15),
          child: Icon(
            _iconFor(category),
            size: 20,
            color:
                (category != null
                    ? Theme.of(context).extension<MoneyColors>()?.expense
                    : Theme.of(context).colorScheme.error) ??
                Theme.of(context).colorScheme.error,
          ),
        ),
        title: Text(
          category?.name ?? 'Unknown',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          '${dateFormat.format(transaction.date)}  ${timeFormat.format(transaction.date)}',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        trailing: AmountText(
          amount: transaction.amount,
          currency: transaction.currency,
          showSign: true,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        onTap: onTap,
      ),
    );
  }

  IconData _iconFor(Category? category) {
    switch (category?.name) {
      case 'Food':
        return Icons.restaurant;
      case 'Transport':
        return Icons.directions;
      case 'Rent':
        return Icons.home;
      case 'Airtime & Internet':
        return Icons.sim_card;
      case 'Utilities':
        return Icons.lightbulb;
      case 'Health':
        return Icons.local_hospital;
      case 'Education':
        return Icons.school;
      case 'Shopping':
        return Icons.shopping_cart;
      case 'Family':
        return Icons.people;
      case 'Salary':
        return Icons.work;
      case 'Business':
        return Icons.business;
      case 'Gift':
        return Icons.card_giftcard;
      default:
        return Icons.more_horiz;
    }
  }
}
