import 'package:flutter/material.dart';
import 'package:image_editor/data/layer.dart';
import 'package:image_editor/image_editor_plus.dart';

class Stickers extends StatefulWidget {
  const Stickers({super.key, required this.stickers});
  final List<String> stickers;
  @override
  createState() => _StickersState();
}

class _StickersState extends State<Stickers> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(0.0),
        height: 400,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              blurRadius: 10.9,
              color: Color.fromRGBO(0, 0, 0, 0.1),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(
                i18n('Select Sticker'),
                style: const TextStyle(color: Colors.white),
              ),
            ]),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Container(
              height: 315,
              padding: const EdgeInsets.all(0.0),
              child: GridView(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                scrollDirection: Axis.vertical,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  mainAxisSpacing: 0.0,
                  maxCrossAxisExtent: 60.0,
                ),
                children: widget.stickers.map((String sticker) {
                  Widget object = Image.asset(
                    'assets/$sticker',
                    height: 100,
                    width: 100,
                  );
                  return GridTile(
                      child: GestureDetector(
                    onTap: () {
                      Navigator.pop(
                        context,
                        LayerData(
                          object: object,
                          size: 100.0,
                        ),
                      );
                    },
                    child: object,
                  ));
                }).toList(),
              ),
            )
          ],
        ),
      ),
    );
  }
}
