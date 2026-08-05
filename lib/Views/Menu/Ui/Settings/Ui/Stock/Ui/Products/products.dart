import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:zaitoonpro/Features/Other/extensions.dart';
import 'package:zaitoonpro/Features/Other/responsive.dart';
import 'package:zaitoonpro/Features/Widgets/status_badge.dart';
import 'package:zaitoonpro/Localizations/l10n/translations/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zaitoonpro/Views/Menu/Ui/Settings/Ui/Stock/Ui/Products/%D9%8FSingleProduct/single_product_bloc.dart';
import 'package:zaitoonpro/Views/Menu/Ui/Settings/Ui/Stock/Ui/Products/model/product_model.dart';
import '../../../../../../../../Features/Other/toast.dart';
import '../../../../../../../../Features/Widgets/outline_button.dart';
import '../../../../../../../../Features/Widgets/search_field.dart';
import 'add_edit_product.dart';
import 'bloc/products_bloc.dart';

class ProductsView extends StatelessWidget {
  const ProductsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsiveLayout(
      mobile: _MobileProductsView(),
      tablet: _TabletProductsView(),
      desktop: _DesktopProductsView(),
    );
  }
}

// Base class to share common functionality
class _BaseProductsView extends StatefulWidget {
  final bool isMobile;
  final bool isTablet;

  const _BaseProductsView({
    required this.isMobile,
    required this.isTablet,
  });

  @override
  State<_BaseProductsView> createState() => _BaseProductsViewState();
}

class _BaseProductsViewState extends State<_BaseProductsView> {
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProductsBloc>().add(LoadProductsEvent());
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void onRefresh() {
    context.read<ProductsBloc>().add(LoadProductsEvent());
  }

  // Build header for different screen sizes
  Widget _buildHeader(AppLocalizations tr, TextTheme textTheme, ColorScheme color) {
    if (widget.isMobile) {
      // Mobile header - stacked layout
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.products, style: textTheme.headlineSmall),
            Text(
              tr.manageProductTitle,
              style: textTheme.bodySmall?.copyWith(color: color.outline),
            ),
            const SizedBox(height: 16),
            ZSearchField(
              controller: searchController,
              hint: tr.search,
              title: '',
              end: searchController.text.isNotEmpty
                  ? InkWell(
                splashColor: Colors.transparent,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () {
                  setState(() {
                    searchController.clear();
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.clear, size: 15),
                ),
              )
                  : const SizedBox(),
              onChanged: (e) {
                setState(() {});
              },
              icon: FontAwesomeIcons.magnifyingGlass,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ZOutlineButton(
                    icon: Icons.refresh,
                    onPressed: onRefresh,
                    label: Text(tr.refresh),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ZOutlineButton(
                    isActive: true,
                    icon: Icons.add,
                    onPressed: () {
                      context.read<SingleProductBloc>().add(ClearSingleProductEvent());
                      showDialog(
                        context: context,
                        builder: (context) => const AddEditProductView(),
                      );
                    },
                    label: Text(tr.newKeyword),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (widget.isTablet) {
      // Tablet header - compact row layout
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr.products, style: textTheme.headlineSmall),
                      Text(
                        tr.manageProductTitle,
                        style: textTheme.bodySmall?.copyWith(color: color.outline),
                      ),
                    ],
                  ),
                ),
                ZOutlineButton(
                  width: 100,
                  icon: Icons.refresh,
                  onPressed: onRefresh,
                  label: Text(tr.refresh),
                ),
                const SizedBox(width: 8),
                ZOutlineButton(
                  width: 100,
                  isActive: true,
                  icon: Icons.add,
                  onPressed: () {
                    context.read<SingleProductBloc>().add(ClearSingleProductEvent());
                    showDialog(
                      context: context,
                      builder: (context) => const AddEditProductView(),
                    );
                  },
                  label: Text(tr.newKeyword),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ZSearchField(
              controller: searchController,
              hint: tr.search,
              title: '',
              end: searchController.text.isNotEmpty
                  ? InkWell(
                splashColor: Colors.transparent,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () {
                  setState(() {
                    searchController.clear();
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.clear, size: 15),
                ),
              )
                  : const SizedBox(),
              onChanged: (e) {
                setState(() {});
              },
              icon: FontAwesomeIcons.magnifyingGlass,
            ),
          ],
        ),
      );
    } else {
      // Desktop header
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.surface,
          border: Border(
            bottom: BorderSide(
              color: color.outline.withValues(alpha: .1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          spacing: 12,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr.products, style: textTheme.headlineMedium),
                  Text(
                    tr.manageProductTitle,
                    style: textTheme.bodySmall?.copyWith(color: color.outline),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: ZSearchField(
                controller: searchController,
                hint: tr.search,
                title: '',
                end: searchController.text.isNotEmpty
                    ? InkWell(
                  splashColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onTap: () {
                    setState(() {
                      searchController.clear();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Icon(Icons.clear, size: 15),
                  ),
                )
                    : const SizedBox(),
                onChanged: (e) {
                  setState(() {});
                },
                icon: FontAwesomeIcons.magnifyingGlass,
              ),
            ),
            ZOutlineButton(
              width: 110,
              icon: Icons.refresh,
              onPressed: onRefresh,
              label: Text(tr.refresh),
            ),
            ZOutlineButton(
              width: 110,
              isActive: true,
              icon: Icons.add,
              onPressed: () {
                context.read<SingleProductBloc>().add(ClearSingleProductEvent());
                showDialog(
                  context: context,
                  builder: (context) => const AddEditProductView(),
                );
              },
              label: Text(tr.newKeyword),
            ),
          ],
        ),
      );
    }
  }

  // Build table header for different screen sizes
  Widget _buildTableHeader(AppLocalizations tr, TextStyle? titleStyle, ColorScheme color) {
    if (widget.isMobile) {
      return const SizedBox.shrink();
    } else if (widget.isTablet) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.primary.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                tr.productName,
                style: titleStyle?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 120,
              child: Text(
                tr.status,
                style: titleStyle?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    } else {
      // Desktop header with better styling
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              color.primary,
              color.primary.withValues(alpha: .85),
            ],
          ),
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: color.primary.withValues(alpha: .2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(
                '#',
                style: titleStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color.surface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text(
                tr.productName,
                style: titleStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color.surface,
                ),
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                tr.category,
                textAlign: TextAlign.center,
                style: titleStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color.surface,
                ),
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                tr.availableTitle,
                style: titleStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color.surface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                tr.totalItems,
                style: titleStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color.surface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(
              width: 80,
              child: Text(
                tr.unit,
                style: titleStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color.surface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                tr.status,
                style: titleStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color.surface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
  }

  // Build product item based on screen size
  Widget _buildProductItem(ProductsModel product, int index, TextTheme textTheme, ColorScheme color, AppLocalizations tr) {
    if (widget.isMobile) {
      // Mobile card view with better design
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AddEditProductView(proId: product.proId),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row: Name + Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.proName ?? '',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StatusBadge(
                      status: product.proStatus ?? 1,
                      trueValue: tr.active,
                      falseValue: tr.inactive,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Code with label
                Row(
                  children: [
                    Icon(
                      Icons.code,
                      size: 14,
                      color: color.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${tr.productCode}:',
                      style: textTheme.bodySmall?.copyWith(
                        color: color.outline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.primary.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.proCode ?? '',
                          style: textTheme.bodySmall?.copyWith(
                            color: color.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Category
                Row(
                  children: [
                    Icon(
                      Icons.category,
                      size: 14,
                      color: color.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${tr.category}:',
                      style: textTheme.bodySmall?.copyWith(
                        color: color.outline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        product.pcName ?? '',
                        style: textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Stats Row: Qty, Items, Unit
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: color.primary.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              tr.qty,
                              style: textTheme.bodySmall?.copyWith(
                                color: color.outline,
                              ),
                            ),
                            Text(
                              product.totalQty?.toAmount(decimal: 0) ?? '0',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: color.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              tr.totalItems,
                              style: textTheme.bodySmall?.copyWith(
                                color: color.outline,
                              ),
                            ),
                            Text(
                              product.totalItems?.toAmount(decimal: 0) ?? '0',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: color.secondary.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              tr.unit,
                              style: textTheme.bodySmall?.copyWith(
                                color: color.outline,
                              ),
                            ),
                            Text(
                              product.proUnit ?? '',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: color.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Details if available
                if (product.proDetails != null && product.proDetails!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.surfaceContainerHighest.withValues(alpha: .3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color.outline.withValues(alpha: .1),
                      ),
                    ),
                    child: Text(
                      product.proDetails!,
                      style: textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    } else if (widget.isTablet) {
      // Tablet row view with better design
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AddEditProductView(proId: product.proId),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: index.isEven
                  ? color.surfaceContainerHighest.withValues(alpha: .3)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.proName ?? '',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.primary.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.proCode ?? '',
                          style: textTheme.bodySmall?.copyWith(
                            color: color.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Center(
                    child: StatusBadge(
                      status: product.proStatus ?? 1,
                      trueValue: tr.active,
                      falseValue: tr.inactive,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Desktop row view with better styling
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AddEditProductView(proId: product.proId),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: index.isEven
                  ? color.surfaceContainerHighest.withValues(alpha: .22)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                // ID
                SizedBox(
                  width: 60,
                  child: Text(
                    product.proId.toString(),
                    style: textTheme.bodySmall?.copyWith(
                      color: color.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Product Name
                Expanded(
                  flex: 2,
                  child: Text(
                    product.proName ?? '',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Category
                SizedBox(
                  width: 120,
                  child: Text(
                    product.pcName ?? '',
                    style: textTheme.bodyMedium?.copyWith(
                      color: color.secondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),

                // Quantity
                SizedBox(
                  width: 100,
                  child: Text(
                    product.totalQty?.toAmount(decimal: 0) ?? '0',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: product.totalItems.toString() == "0" ? color.error :  color.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Total Items
                SizedBox(
                  width: 100,
                  child: Text(
                    product.totalItems?.toAmount(decimal: 0) ?? '0',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: product.totalItems.toString() == "0" ? color.error :  Colors.green.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Unit
                SizedBox(
                  width: 80,
                  child: Text(
                    product.proUnit ?? '',
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),

                // Status
                SizedBox(
                  width: 100,
                  child: Center(
                    child: StatusBadge(
                      status: product.proStatus ?? 1,
                      trueValue: tr.active,
                      falseValue: tr.inactive,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context)!;
    TextStyle? titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: Theme.of(context).colorScheme.surface,
    );

    return Scaffold(
      backgroundColor: color.surface,
      body: Column(
        children: [
          // Header Section
          _buildHeader(tr, textTheme, color),

          if (!widget.isMobile) ...[
            const SizedBox(height: 4),
            // Table Header
            _buildTableHeader(tr, titleStyle, color),
          ],

          // Products List with BlocConsumer
          Expanded(
            child: BlocConsumer<ProductsBloc, ProductsState>(
              listener: (context, state) {
                if (state is ProductsSuccessState) {
                  ToastManager.show(
                    context: context,
                    title: "Success",
                    message: "Operation completed successfully",
                    type: ToastType.success,
                    durationInSeconds: 3,
                    position: ToastPosition.top,
                  );
                }

                if (state is ProductsErrorState) {
                  ToastManager.show(
                    context: context,
                    title: "Error",
                    message: state.message,
                    type: ToastType.error,
                    durationInSeconds: 4,
                    position: ToastPosition.top,
                  );
                }
              },
              builder: (context, state) {
                if (state is ProductsLoadingState) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: color.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr.loading,
                          style: textTheme.bodyMedium?.copyWith(
                            color: color.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (state is ProductsErrorState) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 80,
                          color: color.error.withValues(alpha: .5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.message,
                          style: textTheme.titleMedium?.copyWith(
                            color: color.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ZOutlineButton(
                          icon: Icons.refresh,
                          onPressed: onRefresh,
                          label: Text(tr.refresh),
                        ),
                      ],
                    ),
                  );
                }
                if (state is ProductsLoadedState) {
                  final query = searchController.text.toLowerCase().trim();

                  final filteredList = state.products.where((item) {
                    final code = item.proCode?.toLowerCase() ?? '';
                    final productName = item.proName?.toString().toLowerCase() ?? '';
                    final details = item.proDetails?.toLowerCase() ?? '';
                    final madeIn = item.proMadeIn?.toLowerCase() ?? '';
                    final category = item.pcName?.toLowerCase() ?? '';

                    return code.contains(query) ||
                        productName.contains(query) ||
                        details.contains(query) ||
                        madeIn.contains(query) ||
                        category.contains(query);
                  }).toList();

                  if (filteredList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 80,
                            color: color.outline.withValues(alpha: .5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            searchController.text.isNotEmpty ? tr.noDataFound : tr.noDataFound,
                            style: textTheme.titleMedium?.copyWith(
                              color: color.outline,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            searchController.text.isNotEmpty ? "Try different search" : "Try refreshing",
                            style: textTheme.bodySmall?.copyWith(
                              color: color.outline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ZOutlineButton(
                            icon: Icons.refresh,
                            onPressed: onRefresh,
                            label: Text(tr.refresh),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: widget.isMobile
                        ? const EdgeInsets.symmetric(vertical: 8)
                        : const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final product = filteredList[index];
                      return _buildProductItem(product, index, textTheme, color, tr);
                    },
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Mobile View
class _MobileProductsView extends StatelessWidget {
  const _MobileProductsView();

  @override
  Widget build(BuildContext context) {
    return const _BaseProductsView(
      isMobile: true,
      isTablet: false,
    );
  }
}

// Tablet View
class _TabletProductsView extends StatelessWidget {
  const _TabletProductsView();

  @override
  Widget build(BuildContext context) {
    return const _BaseProductsView(
      isMobile: false,
      isTablet: true,
    );
  }
}

// Desktop View
class _DesktopProductsView extends StatelessWidget {
  const _DesktopProductsView();

  @override
  Widget build(BuildContext context) {
    return const _BaseProductsView(
      isMobile: false,
      isTablet: false,
    );
  }
}