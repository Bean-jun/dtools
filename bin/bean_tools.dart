import 'package:bean_tools/translate_proivder/impl/bing.dart';
import 'package:bean_tools/translate_proivder/impl/netease.dart';
import 'package:bean_tools/translate_proivder/translate.dart';

void main(List<String> arguments) async {
  List<TranslateProivder> proivderList = [
    BingTranslateProivder(),
    NeteaseTranslateProivder()
  ];

  for (var proivder in proivderList) {
    print("proivder: ${proivder.toString()}");
    trans(proivder, "china");
    Future.delayed(Duration(seconds: 5), () {
      print('程序睡眠结束，继续执行');
      trans(proivder, "assert");
    });
  }
}

Future<String> trans(TranslateProivder proivder, String info) async {
  return await proivder.translate(info);
}
