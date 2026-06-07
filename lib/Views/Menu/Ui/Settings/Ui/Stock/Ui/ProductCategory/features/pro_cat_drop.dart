import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../../../../Features/Generic/zaitoon_drop.dart';
import '../../../../../../../../../Localizations/l10n/translations/app_localizations.dart';
import '../bloc/pro_cat_bloc.dart';
import '../model/pro_cat_model.dart';

class ProductCategoryDropdown extends StatefulWidget {
  /// Category ID from Product (EDIT mode)
  final int? selectedCategoryId;

  /// Whether to show "All" option in dropdown
  final bool showAllOption;

  /// Returns FULL model, null when "All" is selected (if showAllOption is true)
  final ValueChanged<ProCategoryModel?> onCategorySelected;

  const ProductCategoryDropdown({
    super.key,
    this.selectedCategoryId,
    this.showAllOption = false,
    required this.onCategorySelected,
  });

  @override
  State<ProductCategoryDropdown> createState() =>
      _ProductCategoryDropdownState();
}

class _ProductCategoryDropdownState extends State<ProductCategoryDropdown> {
  ProCategoryModel? _selectedCategory;
  List<ProCategoryModel> _categories = [];
  bool _hasNotifiedInitial = false; // Track if initial notification was sent

  @override
  void initState() {
    super.initState();

    // Load categories once after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProCatBloc>().add(LoadProCatEvent());
    });
  }

  @override
  void didUpdateWidget(covariant ProductCategoryDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    // When external selectedCategoryId becomes null (on clear)
    if (widget.selectedCategoryId == null && oldWidget.selectedCategoryId != null) {
      setState(() {
        _selectedCategory = null;
      });
      widget.onCategorySelected(null);
    }
    // When external selectedCategoryId changes to a new value, find and select it
    else if (widget.selectedCategoryId != null &&
        widget.selectedCategoryId != oldWidget.selectedCategoryId &&
        _categories.isNotEmpty) {
      _selectCategoryById(widget.selectedCategoryId!);
    }
  }

  void _selectCategoryById(int categoryId) {
    final found = _categories.firstWhere(
          (c) => c.pcId == categoryId,
      orElse: () {
        if (widget.showAllOption) {
          return _categories.firstWhere(
                (c) => c.pcId == null,
            orElse: () => _categories.first,
          );
        }
        return _categories.first;
      },
    );

    if (found != _selectedCategory) {
      setState(() {
        _selectedCategory = found;
      });

      // Notify with null for "All" option
      final valueToSend = (widget.showAllOption && found.pcId == null) ? null : found;
      widget.onCategorySelected(valueToSend);
    }
  }

  void _selectDefaultCategory() {
    if (_categories.isEmpty) return;

    ProCategoryModel? defaultCategory;

    if (widget.selectedCategoryId != null) {
      // Find by ID
      defaultCategory = _categories.firstWhere(
            (c) => c.pcId == widget.selectedCategoryId,
        orElse: () => _categories.first,
      );
    } else if (widget.showAllOption) {
      // Select "All" option
      defaultCategory = _categories.firstWhere(
            (c) => c.pcId == null,
        orElse: () => _categories.first,
      );
    } else {
      // Select first category
      defaultCategory = _categories.first;
    }

    setState(() {
      _selectedCategory = defaultCategory;
    });

    // Notify with null for "All" option
    final valueToSend = (widget.showAllOption && defaultCategory.pcId == null)
        ? null
        : defaultCategory;

    if (!_hasNotifiedInitial || _selectedCategory != defaultCategory) {
      widget.onCategorySelected(valueToSend);
      _hasNotifiedInitial = true;
    }
    }

  void _onSelect(ProCategoryModel cat) {
    setState(() => _selectedCategory = cat);
    // Pass null when "All" is selected and showAllOption is true
    widget.onCategorySelected(
      (widget.showAllOption && cat.pcId == null) ? null : cat,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProCatBloc, ProCatState>(
      listener: (context, state) {
        if (state is ProCatLoadedState) {
          setState(() {
            // Prepare items list
            _categories = [];

            // Add "All" option if enabled
            if (widget.showAllOption) {
              final allOption = ProCategoryModel(
                pcId: null,
                pcName: AppLocalizations.of(context)!.all,
              );
              _categories.add(allOption);
            }

            // Add actual categories
            _categories.addAll(state.proCategory);

            // Select default category after loading
            if (_categories.isNotEmpty) {
              _selectDefaultCategory();
            }
          });
        }
      },
      child: ZDropdown<ProCategoryModel>(
        title: AppLocalizations.of(context)!.categoryTitle,
        items: _categories,
        isLoading: _categories.isEmpty,
        selectedItem: _selectedCategory,
        itemLabel: (cat) => cat.pcName ?? "",
        onItemSelected: _onSelect,
      ),
    );
  }
}