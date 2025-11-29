import 'package:flutter/material.dart';

/// A searchable/autocomplete dropdown widget for selecting items
/// Supports both selecting from suggestions and manual typing
class SearchableDropdown<T> extends StatefulWidget {
  /// Label text for the field
  final String label;
  
  /// Hint text when field is empty
  final String? hint;
  
  /// List of all available items
  final List<T> items;
  
  /// Function to convert item to display string
  final String Function(T) itemToString;
  
  /// Function to filter items based on search query
  final bool Function(T, String)? filterFn;
  
  /// Callback when an item is selected or text changes
  final void Function(String value, T? selectedItem)? onChanged;
  
  /// Initial value
  final String? initialValue;
  
  /// Validator function
  final String? Function(String?)? validator;
  
  /// Whether the field is enabled
  final bool enabled;
  
  /// Prefix icon
  final IconData? prefixIcon;
  
  /// Text input type
  final TextInputType? keyboardType;
  
  /// Maximum suggestions to show
  final int maxSuggestions;
  
  /// Maximum height of the dropdown overlay
  final double maxDropdownHeight;

  const SearchableDropdown({
    super.key,
    required this.label,
    this.hint,
    required this.items,
    required this.itemToString,
    this.filterFn,
    this.onChanged,
    this.initialValue,
    this.validator,
    this.enabled = true,
    this.prefixIcon,
    this.keyboardType,
    this.maxSuggestions = 5,
    this.maxDropdownHeight = 200,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  
  OverlayEntry? _overlayEntry;
  List<T> _filteredItems = [];
  T? _selectedItem;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _filteredItems = widget.items;
    
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          if (widget.filterFn != null) {
            return widget.filterFn!(item, query);
          }
          return widget.itemToString(item)
              .toLowerCase()
              .contains(query.toLowerCase());
        }).toList();
      }
    });
    _updateOverlay();
  }

  void _showOverlay() {
    if (_isOpen) return;
    
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _isOpen = true;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
  }

  void _updateOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _selectItem(T item) {
    final value = widget.itemToString(item);
    _controller.text = value;
    _selectedItem = item;
    widget.onChanged?.call(value, item);
    _removeOverlay();
    _focusNode.unfocus();
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: widget.maxDropdownHeight,
              ),
              child: _filteredItems.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'No results found',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _filteredItems.length > widget.maxSuggestions
                          ? widget.maxSuggestions
                          : _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final displayText = widget.itemToString(item);
                        final isSelected = _selectedItem == item;

                        return InkWell(
                          onTap: () => _selectItem(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue.withOpacity(0.1)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayText,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check,
                                    size: 18,
                                    color: Colors.blue,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          border: const OutlineInputBorder(),
          prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _controller.clear();
                    _selectedItem = null;
                    widget.onChanged?.call('', null);
                    _filterItems('');
                  },
                ),
              Icon(
                _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: Colors.grey,
              ),
            ],
          ),
        ),
        validator: widget.validator,
        onChanged: (value) {
          _selectedItem = null;
          widget.onChanged?.call(value, null);
          _filterItems(value);
        },
        onTap: () {
          if (!_isOpen) {
            _filterItems(_controller.text);
          }
        },
      ),
    );
  }
}

/// Simple item model for dropdown options
class DropdownItem {
  final String id;
  final String label;
  final String? subtitle;

  DropdownItem({
    required this.id,
    required this.label,
    this.subtitle,
  });

  @override
  String toString() => label;
}
