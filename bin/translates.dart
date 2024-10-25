import 'package:translates/translate_proivder/impl/bing.dart';
import 'package:translates/translate_proivder/translate.dart';

void main(List<String> arguments) async {
  TranslateProivder proivder = BingTranslateProivder();

  trans(proivder, "string");
  Future.delayed(Duration(seconds: 5), () {
    print('程序睡眠结束，继续执行');
    trans(proivder, "assert");
    trans(proivder, "works");
    trans(proivder, "create");
  });
}

Future<String> trans(TranslateProivder proivder, String info) async {
  return await proivder.translate(info);
}
