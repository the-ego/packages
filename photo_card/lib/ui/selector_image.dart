import 'package:flutter/material.dart';

import '../utils/global.dart';

class SelectorFirstItem {
  final Widget? child;
  final VoidCallback? onTap;
  SelectorFirstItem({this.child, this.onTap});
}

class ImageSelector extends StatefulWidget {
  final List<ImageProvider> items;
  final ValueChanged<ImageProvider?> onItemSelected;
  final double aspectRatio;
  final SelectorFirstItem? firstItem;
  const ImageSelector({
    Key? key,
    required this.aspectRatio,
    required this.items,
    this.firstItem,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  ImageSelectorState createState() => ImageSelectorState();
}

class ImageSelectorState extends State<ImageSelector> {
  int? selectedItemIndex;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: false,
      physics: const ClampingScrollPhysics(),
      scrollDirection: Axis.vertical,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8.0,
        crossAxisSpacing: 4.0,
        childAspectRatio: widget.aspectRatio,
      ),
      padding: const EdgeInsets.all(8.0),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        Widget? item;
        if (index == 0 && widget.firstItem != null) {
          item = GestureDetector(
            onTap: widget.firstItem?.onTap,
            child: Container(
              decoration: BoxDecoration(
                color: bottomItem,
                borderRadius: BorderRadius.circular(4),
              ),
              child: widget.firstItem?.child,
            ),
          );
        } else {
          int itemIndex = index - (widget.firstItem == null ? 0 : 1);
          ImageProvider child = widget.items[itemIndex];

          item = GestureDetector(
            onTap: () {
              widget.onItemSelected(child);
              setState(() {
                selectedItemIndex = index;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: bottomItem,
                borderRadius: BorderRadius.circular(4),
                image: DecorationImage(
                  image: child,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        }

        return item;
      },
    );
  }
}
