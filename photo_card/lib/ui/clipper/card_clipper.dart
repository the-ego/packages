import 'package:flutter/rendering.dart';

import '../../utils/util.dart';

class CardBoxClip extends CustomClipper<Path> {
  final AspectRatioEnum aspectRatio;

  CardBoxClip({
    this.aspectRatio = AspectRatioEnum.rFree,
  });

  @override
  Path getClip(Size size) {
    double? ratio = aspectRatio.ratio;
    double w = 0.0;
    double h = size.height;
    if (ratio == null) {
      w = size.width;
    } else {
      w = h * ratio;
    }

    if (w > size.width) {
      w = size.width;
      h = w / (ratio ?? 1);
    }

    Rect rect = Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)))
      ..close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}