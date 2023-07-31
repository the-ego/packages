library image_editor_plus;

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_editor/layers/draggable_resizable.dart';
import 'package:image_editor/layers/layer.dart';
import 'package:image_editor/loading_screen.dart';
import 'package:image_editor/modules/sticker.dart';
import 'package:image_editor/theme.dart';
import 'package:image_editor/utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screenshot/screenshot.dart';

import 'modules/blur.dart';
import 'modules/drawing_page.dart';
import 'modules/text.dart';

// List of global variables
List<Layer> layers = [], undoLayers = [], removedLayers = [];
Key? selectedAssetId;
final GlobalKey editGlobalKey = GlobalKey();
const Key backgroundKey = Key('base_layer');

class ImageEditor extends StatefulWidget {
  final Directory? savePath;
  final Uint8List? image;
  final List<String> stickers;
  final AspectRatioOption aspectRatio;

  const ImageEditor({
    super.key,
    this.savePath,
    this.image,
    this.stickers = const [],
    this.aspectRatio = AspectRatioOption.r16x9,
  });
  @override
  State<ImageEditor> createState() => _ImageEditorState();
}

class _ImageEditorState extends State<ImageEditor> {
  final scaffoldGlobalKey = GlobalKey<ScaffoldState>();
  ScreenshotController screenshotController = ScreenshotController();
  Uint8List? currentImage;
  Widget baseLayer = const SizedBox.shrink();
  Size viewportSize = const Size(0, 0);

  LinearGradient cardColor = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.transparent,
      Colors.transparent,
    ],
  );
  final picker = ImagePicker();

  @override
  void dispose() {
    layers.clear();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.image != null) {
      loadImage(widget.image!);
    }
  }

  resetTransformation() {
    setState(() {});
  }

  Future<void> loadImage(dynamic imageFile) async {
    currentImage = await _loadImage(imageFile);
    if (currentImage != null) {
      ColorScheme newScheme = await ColorScheme.fromImageProvider(provider: MemoryImage(currentImage!));
      setState(() {
        baseLayer = Image.memory(currentImage!, fit: BoxFit.cover);
        //cardColor gradient
        cardColor = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            newScheme.primary,
            newScheme.secondary,
          ],
        );
        layers.clear();
      });
    }
  }

  Future<Uint8List> _loadImage(dynamic imageFile) async {
    if (imageFile is Uint8List) {
      return imageFile;
    } else if (imageFile is File || imageFile is XFile) {
      final image = await imageFile.readAsBytes();

      return image;
    }

    return Uint8List.fromList([]);
  }

  @override
  Widget build(BuildContext context) {
    viewportSize = MediaQuery.of(context).size;
    return Theme(
      data: theme,
      child: GestureDetector(
        key: const Key('background_gestureDetector'),
        onTap: () {
          selectedAssetId = null;
          setState(() {});
        },
        child: Scaffold(
          key: scaffoldGlobalKey,
          backgroundColor: Colors.grey,
          body: buildScreenshotWidget(context),
          bottomNavigationBar: bottomBar,
        ),
      ),
    );
  }

  Widget buildScreenshotWidget(BuildContext context) {
    double statusBarHeight = MediaQuery.of(context).padding.top;
    return Center(
      child: RepaintBoundary(
        key: editGlobalKey,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8.0, statusBarHeight + 8.0, 8.0, 8.0),
          child: Screenshot(
            controller: screenshotController,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              child: Container(
                decoration: BoxDecoration(
                  gradient: cardColor,
                ),
                child: AspectRatio(
                  aspectRatio: widget.aspectRatio.ratio ?? 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                          child: Align(
                              alignment: Alignment.center,
                              child: BaseLayerWidget(
                                key: backgroundKey,
                                base: baseLayer,
                                size: const Size(400, 600),
                                canTransform: selectedAssetId == backgroundKey ? true : false,
                                onDragStart: () {
                                  setState(() {
                                    selectedAssetId = backgroundKey;
                                  });
                                },
                                onDragEnd: () {
                                  setState(() {
                                    selectedAssetId = null;
                                  });
                                },
                              ))),
                      ...layers.map((layer) {
                        if (layer is BlurLayerData) {
                          return BackdropFilter(
                            key: const Key('blurLayer_gestureDetector'),
                            filter: ImageFilter.blur(
                              sigmaX: layer.radius,
                              sigmaY: layer.radius,
                            ),
                            child: Container(
                              color: layer.color.withOpacity(layer.opacity),
                            ),
                          );
                        } else if (layer is LayerData) {
                          return DraggableResizable(
                            key: Key('${layer.key}_draggableResizable_asset'),
                            canTransform: selectedAssetId == layer.key ? true : false,
                            onLayerTapped: () {
                              selectedAssetId = layer.key;
                              var listLength = layers.length;
                              var index = layers.indexOf(layer);
                              if (index != listLength) {
                                layers.remove(layer);
                                layers.add(layer);
                              }
                              setState(() {});
                            },
                            onDragEnd: () {
                              selectedAssetId = null;
                              setState(() {});
                            },
                            onDelete: () async {
                              layers.remove(layer);
                              setState(() {});
                            },
                            layer: layer,
                          );
                        } else {
                          return Container();
                        }
                      }).toList(),
                      Positioned(top: 0, right: 0, child: buildAppBar())
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  //---------------------------------//

  Widget buildAppBar() {
    return SingleChildScrollView(
      reverse: true,
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        const BackButton(),
        /** 
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: Icon(Icons.undo, color: layers.length > 1 || removedLayers.isNotEmpty ? Colors.white : Colors.grey),
          onPressed: () {
            if (removedLayers.isNotEmpty) {
              layers.add(removedLayers.removeLast());
              setState(() {});
              return;
            }

            if (layers.length <= 1) return; // do not remove image layer

            undoLayers.add(layers.removeLast());

            setState(() {});
          },
        ),
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: Icon(Icons.redo, color: undoLayers.isNotEmpty ? Colors.white : Colors.grey),
          onPressed: () {
            if (undoLayers.isEmpty) return;

            layers.add(undoLayers.removeLast());

            setState(() {});
          },
        ),
        */
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(Icons.photo),
          onPressed: () async {
            var image = await picker.pickImage(source: ImageSource.gallery);

            if (image == null) return;

            loadImage(image);
          },
        ),
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(Icons.camera_alt),
          onPressed: () async {
            var image = await picker.pickImage(source: ImageSource.camera);

            if (image == null) return;

            loadImage(image);
          },
        ),
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(Icons.check),
          onPressed: () async {
            selectedAssetId = null;
            resetTransformation();

            setState(() {});

            LoadingScreen(scaffoldGlobalKey).show();

            var binaryIntList = await screenshotController.capture();

            LoadingScreen(scaffoldGlobalKey).hide();

            if (mounted) Navigator.pop(context, binaryIntList);
          },
        ),
      ]),
    );
  }

  Widget get bottomBar => Container(
        height: const ButtonThemeData().height * 2,
        color: Colors.black,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit),
                    Text(
                      'Brush',
                    )
                  ],
                ),
                onPressed: () async {
                  LayerData? layer = await Navigator.of(context).push(
                    PageRouteBuilder(
                      opaque: false, // set to false
                      pageBuilder: (_, __, ___) => const BrushPainter(),
                    ),
                  );
                  if (layer == null) return;
                  undoLayers.clear();
                  removedLayers.clear();

                  layers.add(layer);

                  setState(() {});
                },
              ),
              ElevatedButton(
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.text_fields),
                    Text(
                      'Text',
                    )
                  ],
                ),
                onPressed: () async {
                  LayerData? layer = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TextEditorImage(),
                    ),
                  );
                  if (layer == null) return;
                  undoLayers.clear();
                  removedLayers.clear();
                  layers.add(layer);
                  setState(() {});
                },
              ),
              ElevatedButton(
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.blur_on),
                    Text(
                      'Blur',
                    )
                  ],
                ),
                onPressed: () async {
                  var blurLayer = BlurLayerData(
                    color: Colors.transparent,
                    radius: 0.0,
                    opacity: 0.0,
                  );
                  undoLayers.clear();
                  removedLayers.clear();
                  layers.add(blurLayer);
                  setState(() {});
                  showModalBottomSheet(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(topRight: Radius.circular(10), topLeft: Radius.circular(10)),
                    ),
                    context: context,
                    builder: (context) {
                      return Blur(
                        blurLayer: blurLayer,
                        onSelected: (BlurLayerData updatedBlurLayer) {
                          setState(() {
                            layers.removeWhere((element) => element is BlurLayerData);
                            layers.add(updatedBlurLayer);
                          });
                        },
                      );
                    },
                  );
                },
              ),
              ElevatedButton(
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.face_5_outlined),
                    Text(
                      'Sticker',
                    )
                  ],
                ),
                onPressed: () async {
                  LayerData? layer = await showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.black,
                    builder: (BuildContext context) {
                      return Stickers(
                        stickers: widget.stickers,
                      );
                    },
                  );
                  if (layer == null) return;
                  undoLayers.clear();
                  removedLayers.clear();
                  layers.add(layer);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      );
}