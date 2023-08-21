import 'package:flutter/widgets.dart';

import 'global.dart';

enum LayerType { sticker, text, drawing, background, frame }

LayerItem? selectedLayerItem;

class LayerItem {
  final Key key;
  final LayerType type;
  final dynamic object;
  final Offset offset;
  final Size size;
  final double angle;
  bool get isFixed {
    return type == LayerType.frame || type == LayerType.drawing;
  }

  LayerItem(
    this.key, {
    required this.type,
    required this.object,
    required this.size,
    Offset? offset,
    this.angle = 0,
  }) : offset = offset ?? cardBoxRect.center;

  LayerItem copyWith({
    Offset? offset,
    Size? size,
    double? rotation,
    dynamic object,
  }) {
    return LayerItem(
      key,
      type: type,
      object: object ?? this.object,
      offset: offset ?? this.offset,
      size: size ?? this.size,
      angle: rotation ?? this.angle,
    );
  }
}

class LayerManager {
  List<LayerItem> undoLayers = [];
  List<LayerItem> removedLayers = [];
  LayerItem? _backgroundLayer;
  LayerItem? _frameLayer;
  LayerItem? _drawingLayer;
  List<LayerItem> _otherLayers = [];

  List<LayerItem> get layers {
    List<LayerItem> layers = [];
    if (_backgroundLayer != null) {
      layers.add(_backgroundLayer!);
    }
    if (_frameLayer != null) {
      layers.add(_frameLayer!);
    }
    layers.addAll(_otherLayers);
    if (_drawingLayer != null) {
      layers.add(_drawingLayer!);
    }
    return layers;
  }

  void addLayer(LayerItem item) {
    switch (item.type) {
      case LayerType.background:
        _backgroundLayer = item;
        break;
      case LayerType.frame:
        _frameLayer = item;
        break;
      case LayerType.drawing:
        _drawingLayer = item;
        break;
      case LayerType.text:
      case LayerType.sticker:
        _otherLayers.add(item);
        break;
    }
  }

  void moveLayerToFront(LayerItem layer) {
    int index = _otherLayers.indexOf(layer);
    if (index != -1) {
      _otherLayers.removeAt(index);
      _otherLayers.add(layer);
    }
  }

  void _removeLayer(LayerItem layer) {
    int index = layers.indexWhere((item) => item.key == layer.key);
    if (index != -1) {
      removedLayers.add(layers[index]);
      layers.removeAt(index);
    }
  }

  void removeLayerByKey(Key key) {
    LayerItem? layer;
    if (_backgroundLayer?.key == key) {
      layer = _backgroundLayer;
      _backgroundLayer = null;
    } else if (_frameLayer?.key == key) {
      layer = _frameLayer;
      _frameLayer = null;
    } else if (_drawingLayer?.key == key) {
      layer = _drawingLayer;
      _drawingLayer = null;
    } else {
      layer = _otherLayers.firstWhere((item) => item.key == key);
      _otherLayers.remove(layer);
    }
    if (layer != null) {
      _removeLayer(layer);
    }
  }

  /// Remove layer by type background, frame, drawing
  void removeLayerByType(LayerType type) {
    LayerItem? layer;
    switch (type) {
      case LayerType.background:
        layer = _backgroundLayer;
        _backgroundLayer = null;
        break;
      case LayerType.frame:
        layer = _frameLayer;
        _frameLayer = null;
        break;
      case LayerType.drawing:
        layer = _drawingLayer;
        _drawingLayer = null;
        break;
      default:
        break;
    }
    if (layer != null) {
      _removeLayer(layer);
    }
  }

  /// old Layer.object new object
  void updateLayer(LayerItem layer) {
    int index = layers.indexWhere((item) => item.key == layer.key);
    if (index != -1) {
      layers[index] = layer;
    }
  }

  void undo() {
    if (removedLayers.isNotEmpty) {
      layers.add(removedLayers.removeLast());
    } else if (layers.isNotEmpty) {
      undoLayers.add(layers.removeLast());
    }
  }

  void redo() {
    if (undoLayers.isNotEmpty) {
      layers.add(undoLayers.removeLast());
    }
  }
}