part of 'photo_card.dart';

class _PhotoEditor extends StatefulWidget {
  final List<Uint8List> stickers;
  final List<ImageProvider> backgrounds;
  final List<ImageProvider> frames;
  final AspectRatioEnum aspectRatio;
  final List<String> fonts;
  final List<LayerItem> tempSavedLayers;
  final Widget completedButton;
  final Function(List<LayerItem>)? onReturnLayers;
  const _PhotoEditor({
    Key? key,
    this.stickers = const [],
    this.backgrounds = const [],
    this.frames = const [],
    this.aspectRatio = AspectRatioEnum.photoCard,
    this.fonts = const [],
    this.tempSavedLayers = const [],
    this.completedButton = const Text('Complete'),
    this.onReturnLayers,
  }) : super(key: key);
  @override
  State<_PhotoEditor> createState() => _ImageEditorState();
}

class _ImageEditorState extends State<_PhotoEditor> with WidgetsBindingObserver, TickerProviderStateMixin {
  final scaffoldGlobalKey = GlobalKey<ScaffoldState>();
  var layerManager = LayerManager();
  LayerType? _selectedLayer;
  LinearGradient? cardColor;
  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;
  double get statusBarHeight => MediaQuery.of(context).padding.top;
  @override
  void initState() {
    super.initState();
    fontFamilies = widget.fonts;
    layerManager.loadLayers(widget.tempSavedLayers);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureRect();
    });
  }

  @override
  void didChangeMetrics() {
    bottomInsetNotifier.value = MediaQuery.of(context).viewInsets.bottom;
  }

  @override
  void dispose() {
    layerManager.clearLayers();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _captureRect() {
    GlobalRect()
      ..cardRect = GlobalRect().getRect(GlobalRect().cardAreaKey)
      ..objectRect = GlobalRect().getRect(GlobalRect().objectAreaKey)
      ..statusBarSize = statusBarHeight;
  }

  Future<void> _loadImageColor(Uint8List? imageFile) async {
    if (imageFile != null) {
      ColorScheme newScheme = await ColorScheme.fromImageProvider(provider: MemoryImage(imageFile));
      setState(() {
        cardColor = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
          colors: [
            newScheme.primaryContainer,
            newScheme.primary,
          ],
        );
      });
    } else {
      cardColor = null;
    }
  }

  Future<Uint8List> _loadImage(dynamic imageFile) async {
    if (imageFile is Uint8List) return imageFile;
    final image = await (imageFile as dynamic).readAsBytes();
    return image;
  }

  @override
  Widget build(BuildContext context) {
    log(layerManager.layers.toString());
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        key: scaffoldGlobalKey,
        body: Stack(
          children: [
            GestureDetector(
              onTap: () => swapWidget(null),
              child: Container(
                color: background,
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                double space = kToolbarHeight / 3;
                int cardFlex = 70;
                double maxWidth = (constraints.maxHeight) * cardFlex / 100 * (widget.aspectRatio.ratio ?? 1);

                return Center(
                  child: SizedBox(
                    width: maxWidth,
                    child: Column(
                      children: [
                        SizedBox(
                          height: statusBarHeight,
                        ),
                        const SizedBox(
                          height: kToolbarHeight,
                        ),
                        SizedBox(
                          height: space,
                        ),
                        Expanded(
                          flex: cardFlex,
                          child: GestureDetector(
                            onTap: () => swapWidget(null),
                            child: Padding(
                              padding: cardPadding,
                              child: ClipPath(
                                key: GlobalRect().cardAreaKey,
                                clipper: CardBoxClip(aspectRatio: widget.aspectRatio),
                                child: buildImageLayer(context),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 100 - cardFlex,
                          child: Container(
                            padding: EdgeInsets.only(top: space),
                            child: ClipPath(
                              key: GlobalRect().objectAreaKey,
                              clipper: CardBoxClip(),
                              child: Stack(
                                children: [
                                  IgnorePointer(
                                    ignoring: _animationController.isAnimating,
                                    child: buildItemArea(),
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(microseconds: 100),
                                    child: SlideTransition(
                                      position: _offsetAnimation,
                                      child: switchingWidget(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildImageLayer(BuildContext context) {
    return Container(
      decoration: cardColor != null
          ? BoxDecoration(
              gradient: cardColor,
            )
          : const BoxDecoration(color: Colors.white),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ...layerManager.layers.map((layer) => buildLayerWidgets(layer)),
        ],
      ),
    );
  }

  Widget buildLayerWidgets(LayerItem layer) {
    return DraggableResizable(
      key: Key('${layer.key}_draggableResizable'),
      isFocus: layerManager.selectedLayerItem?.key == layer.key ? true : false,
      onLayerTapped: (LayerItem item) async {
        if (item.type is TextType) {
          setState(() {
            layerManager.removeLayerByKey(item.key);
          });
          (TextBoxInput, Offset)? result = await showGeneralDialog(
              context: context,
              barrierColor: Colors.transparent,
              pageBuilder: (context, animation, secondaryAnimation) {
                return TextEditor(
                  textEditorStyle: item.object as TextBoxInput,
                );
              });

          if (result != null) {
            layerManager.addLayer(
              item.copyWith(
                object: result.$1,
                rect: (item.rect.topLeft & result.$1.size),
              ),
            );
          } else {
            layerManager.addLayer(item);
          }
        }
        setState(() {
          if (item.type.isObject) {
            layerManager.swap(item);
          }
        });
      },
      onDragStart: (LayerItem item) {
        setState(() {
          layerManager.selectedLayerItem = item;
          if (item.type.isObject) {
            layerManager.swap(item);
          }
        });
      },
      onDragEnd: (LayerItem item) {
        layerManager.updateLayer(item);
        setState(() {
          layerManager.selectedLayerItem = null;
        });
      },
      onDelete: (layerItem) => layerManager.removeLayerByKey(layerItem.key),
      layerItem: layer,
    );
  }

  Widget buildItemArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CircleIconButton(
                iconData: DUIcons.picture,
                onPressed: () {
                  swapWidget(const BackgroundType());
                },
              ),
              CircleIconButton(
                iconData: DUIcons.tool_marquee,
                onPressed: () {
                  swapWidget(FrameType());
                },
              ),
              CircleIconButton(
                iconData: DUIcons.sticker,
                onPressed: () {
                  swapWidget(StickerType());
                },
              ),
              CircleIconButton(
                iconData: DUIcons.letter_case,
                onPressed: () {
                  switchingDialog(TextType(), context);
                },
              ),
              CircleIconButton(
                iconData: DUIcons.paint_brush,
                onPressed: () {
                  switchingDialog(DrawingType(), context);
                },
              ),
            ],
          ),
        ),
        const SizedBox(
          height: 16,
        ),
        bottomButtons(),
      ],
    );
  }

  Padding bottomButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50.0),
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          CircleIconButton(
            iconData: DUIcons.back,
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Save Changes?'),
                    content: const Text('Do you want to save your changes temporarily?'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('NO'),
                        onPressed: () {
                          widget.onReturnLayers?.call([]);
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: const Text('YES'),
                        onPressed: () {
                          widget.onReturnLayers?.call(layerManager.layers);
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
              Navigator.canPop(context) ? Navigator.pop(context) : null;
            },
          ),
          InkWell(
            onTap: () {
              widget.onReturnLayers?.call(layerManager.layers);
              Navigator.canPop(context) ? Navigator.pop(context) : null;
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: widget.completedButton,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void swapWidget(LayerType? type) {
    if (!_animationController.isAnimating) {
      if (type == null) {
        _animationController.reverse().then((value) => setState(() {
              _selectedLayer = null;
            }));
      } else {
        _animationController.forward(from: 0.0);
        setState(() {
          _selectedLayer = type;
        });
      }
    }
  }

  void switchingDialog(LayerType type, BuildContext context) async {
    setState(() {
      _selectedLayer = type;
    });
    switch (type) {
      case TextType():
        (TextBoxInput, Offset)? result = await showGeneralDialog(
          context: context,
          barrierColor: Colors.transparent,
          pageBuilder: (context, animation, secondaryAnimation) {
            return const TextEditor();
          },
        );

        setState(() {});

        if (result == null) break;
        var layer = LayerItem(
          UniqueKey(),
          type: TextType(),
          object: result.$1,
          rect: result.$2 & result.$1.size,
        );
        layerManager.addLayer(layer);
        setState(() {});
        break;
      case DrawingType():
        (Uint8List?, Size?)? data = await showGeneralDialog(
          context: context,
          barrierColor: Colors.transparent,
          pageBuilder: (context, animation, secondaryAnimation) {
            return const BrushPainter();
          },
        );

        if ((data != null && data.$1 != null)) {
          setState(() {
            var layer = LayerItem(
              UniqueKey(),
              type: DrawingType(),
              object: data.$1!,
              rect: GlobalRect().cardRect.zero,
            );
            layerManager.addLayer(layer);
          });
        }
        break;
      default:
        break;
    }
  }

  Widget switchingWidget() {
    switch (_selectedLayer) {
      case BackgroundType():
        return Container(
          decoration: const BoxDecoration(
            color: bottomSheet,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: StatefulBuilder(
            builder: (context, dialogSetState) {
              LayerItem? background =
                  layerManager.layers.where((element) => element.type is BackgroundType).firstOrNull;
              Color? value = background == null
                  ? Colors.white
                  : background.type.background == Background.color
                      ? (background.object as Color)
                      : null;
              return Column(
                children: [
                  ColorBar(
                    value: value,
                    onColorChanged: (color) async {
                      await _loadImageColor(null);
                      LayerItem layer = LayerItem(
                        UniqueKey(),
                        type: const BackgroundType.color(),
                        object: color,
                        rect: GlobalRect().cardRect.zero,
                      );
                      layerManager.addLayer(layer);
                      dialogSetState(() {
                        value = color; // <-- Update the local color here
                      });
                      setState(() {});
                    },
                  ),
                  Expanded(
                    child: ImageSelector(
                      items: widget.backgrounds,
                      firstItem: GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            var value = await picker.pickImage(source: ImageSource.gallery);
                            if (value == null) return;
                            Uint8List? loadImage = await _loadImage(value);
                            await _loadImageColor(loadImage);
                            LayerItem imageBackground = LayerItem(
                              UniqueKey(),
                              type: const BackgroundType.gallery(),
                              object: Image.memory(loadImage),
                              rect: GlobalRect().cardRect.zero,
                            );
                            dialogSetState(
                              () {
                                value = null; // <-- Reset the local color here
                              },
                            );
                            setState(() {});
                            layerManager.addLayer(imageBackground);
                          },
                          child: const Icon(
                            DUIcons.picture,
                            color: Colors.white,
                          )),
                      onItemSelected: (child) async {
                        await _loadImageColor(null);
                        LayerItem layer = LayerItem(
                          UniqueKey(),
                          type: const BackgroundType.image(),
                          object: child,
                          rect: GlobalRect().cardRect.zero,
                        );
                        dialogSetState(
                          () {
                            value = null; // <-- Reset the local color here
                          },
                        );
                        setState(() {});
                        layerManager.addLayer(layer);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      case FrameType():
        return Container(
          decoration: const BoxDecoration(
            color: bottomSheet,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: ImageSelector(
            items: widget.frames,
            firstItem: GestureDetector(
              onTap: () {
                layerManager.removeLayerByType(FrameType());
                setState(() {});
              },
              child: const Icon(
                DUIcons.ban,
                color: Colors.white,
              ),
            ),
            onItemSelected: (child) {
              LayerItem layer = LayerItem(
                UniqueKey(),
                type: FrameType(),
                object: child,
                rect: GlobalRect().cardRect.zero,
              );
              layerManager.addLayer(layer);
              setState(() {});
            },
          ),
        );
      case StickerType():
        return Container(
          decoration: const BoxDecoration(
            color: bottomSheet,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: StickerSelector(
            items: widget.stickers,
            onSelected: (child) {
              if (child == null) return;

              Size size = const Size(150, 150);
              Offset offset = Offset(GlobalRect().cardRect.size.width / 2 - size.width / 2,
                  GlobalRect().cardRect.size.height / 2 - size.height / 2);

              LayerItem layer = LayerItem(
                UniqueKey(),
                type: StickerType(),
                object: child,
                rect: (offset & size),
              );
              layerManager.addLayer(layer);
              setState(() {});
            },
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}