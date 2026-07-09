import 'package:flutter/material.dart';
import '../../../../../../../../Features/Generic/zaitoon_drop.dart';
import '../../../../../../../../Localizations/l10n/translations/app_localizations.dart';

class SalesFilterDropdown extends StatelessWidget {
  final String? value;
  final List<SalesFilterItem>? items;
  final ValueChanged<String?> onChanged;
  final double? height;
  final bool disable;

  const SalesFilterDropdown({
    super.key,
    required this.onChanged,
    this.items,
    this.value,
    this.height,
    this.disable = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Define the sales filter items
    final dropdownItems = items ?? [
       SalesFilterItem(null, l10n.allProducts),
       SalesFilterItem('most_sold', l10n.mostSold),
       SalesFilterItem('less_sold', l10n.lessSold),
       SalesFilterItem('not_sold', l10n.notSold),
    ];

    // Find the selected item
    SalesFilterItem? selectedItem = dropdownItems.firstWhere(
          (e) => e.value == value,
      orElse: () => dropdownItems.first,
    );

    return ZDropdown<SalesFilterItem>(
      title: l10n.salesFilter,
      items: dropdownItems,
      selectedItem: selectedItem,
      initialValue: selectedItem.label,
      disableAction: disable,
      itemLabel: (item) => item.label,
      onItemSelected: (item) => onChanged(item.value),
    );
  }
}
class SalesFilterItem {
  final String? value;
  final String label;

  const SalesFilterItem(this.value, this.label);
}