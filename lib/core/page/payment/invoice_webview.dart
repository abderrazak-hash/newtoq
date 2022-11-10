import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'package:cloud_toq_system/core/page/product/product_screen.dart';
import 'package:cloud_toq_system/main.dart';
import 'package:esc_pos_gen/esc_pos_gen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sunmi_printer_plus/enums.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import 'package:webview_flutter/webview_flutter.dart';

class InvoiceWebView extends StatefulWidget {
  final int invoiceId;
  const InvoiceWebView({Key? key, required this.invoiceId}) : super(key: key);

  @override
  State<InvoiceWebView> createState() => _InvoiceWebViewState();
}

class _InvoiceWebViewState extends State<InvoiceWebView> {
  WebViewController? ctrl;

  @override
  void initState() {
    super.initState();
    SunmiPrinter.bindingPrinter();
    SunmiPrinter.paperSize();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: WillPopScope(
        onWillPop: () async {
          Get.offAll(const ProductListScreen(), arguments: {
            'ID': sharedPreferences!.getString('Branch_Id'),
          });
          return true;
        },
        child: Scaffold(
          body: WebView(
            initialUrl:
                'https://test.6o9.live/api/Incoice/SellInvoice/${widget.invoiceId}',
            javascriptMode: JavascriptMode.unrestricted,
            onWebViewCreated: (c) {
              ctrl = c;
            },
            onPageFinished: (c) async {
              Uint8List? webConv;
              String html = await ctrl!.runJavascriptReturningResult(
                  "encodeURIComponent(document.documentElement.outerHTML)");
              html = Uri.decodeComponent(html);
              html = html.substring(1, html.length - 1);
              webConv = await WebcontentConverter.contentToImage(
                content: html,
              );
              var x = generatePaper(generateImage(webConv));
              print(x);
              // await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
              // await SunmiPrinter.startTransactionPrint(true);
              // await SunmiPrinter.printImage(webConv);
              // await SunmiPrinter.lineWrap(1);
              // await SunmiPrinter.exitTransactionPrint(true);
              // await SunmiPrinter.cut();
            },
          ),
        ),
      ),
    );
  }

  PosComponent generateImage(Uint8List imageBytes) {
    // final ByteData data = await rootBundle.load('assets/logo.png');
    // final Uint8List bytes = data.buffer.asUint8List();
    final img.Image? image = img.decodeImage(imageBytes);
    // Using `ESC *`
    PosComponent pos;
    try {
      pos = PosImage(image: image!);
    } catch (e) {
      try {
        pos = PosImage.raster(image: image!);
      } catch (f) {
        pos = PosImage.raster(
          image: image!,
          imageFn: PosImageFn.graphics,
        );
      }
    }
    // Using `GS v 0` (obsolete)
    // Using `GS ( L`
    return pos;
  }

  Future<List<int>> generatePaper(PosComponent pos) async {
    final CapabilityProfile profile = await CapabilityProfile.load();
    final Generator generator = Generator(
      PaperSize.mm58,
      profile,
    );
    final List<PosComponent> components = <PosComponent>[
      const PosSeparator(),
      pos,
      const PosSeparator(),
      const PosFeed(1),
      const PosCut(),
    ];
    final Paper paper = Paper(
      generator: generator,
      components: components,
    );
    return paper.bytes;
  }
}
