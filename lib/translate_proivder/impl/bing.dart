import 'package:dio/dio.dart';
import 'package:translates/translate_proivder/translate.dart';

// ignore: slash_for_doc_comments, dangling_library_doc_comments
/**
 * bing 翻译解析
 * 1. 走一个请求，用来获取当前翻译的payload认证参数
 * https://cn.bing.com/search?q=翻译
 * 参数："cookie": "SRCHHPGUSR=SRCHLANG=zh-Hans&HV={当前时间戳}",
 * 响应：params_AbusePreventionHelper [1729823321678,"woYfsCiKMemvEnmS23JqrqZICP6u_qN-",3600000]
 * 说明：1729823321678 翻译请求时间戳，woYfsCiKMemvEnmS23JqrqZICP6u_qN- 翻译请求token，3600000 翻译有效时间
 * 
 * 2. 走一个请求，用来获取当前数据的翻译
 * https://cn.bing.com/ttranslatev3?&IG=B3C3891EDE7B49E3870147033600E830&IID=SERP.5687
 * 参数："content-type": "application/x-www-form-urlencoded"
 *      请求体：      data: {
 *      "fromLang": "en",
 *      "to": "zh-Hans",
 *      "token": 上一步的token,
 *      "key": 上一步的key,
 *      "text": "code",
 *      "tryFetchingGenderDebiasedTranslations": "true",
 *    });
 * 
 * 3. 翻译解析
 */

class BingKey {
  late int reqTime;
  late String reqToken;
  late int reqExpire;
  late bool keyExpire;
  late int generateTime;

  BingKey(int reqtime, String reqtoken, int reqexpire) {
    reqTime = reqtime;
    reqToken = reqtoken;
    reqExpire = reqexpire;

    keyExpire = false;
    generateTime = DateTime.now().microsecondsSinceEpoch;
  }

  /// 当前key是否有效
  bool isValid() {
    if (keyExpire) {
      return false;
    }
    if ((generateTime + reqExpire) > DateTime.now().microsecondsSinceEpoch) {
      keyExpire = false;
      return false;
    }
    return true;
  }
}

class BingTranslateProivder implements TranslateProivder {
  final _userAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0";
  final _getKeyUri = "https://cn.bing.com/search?q=%E7%BF%BB%E8%AF%91";
  final _getKeyPattern = RegExp(
      r'params_AbusePreventionHelper\s*=\s*\[\s*(\d+)\s*,\s*"([^"]+)"\s*,\s*(\d+)\s*\]');
  final _getTransUri =
      "https://cn.bing.com/ttranslatev3?&IG=B3C3891EDE7B49E3870147033600E830&IID=SERP.5687";
  BingKey? bingKey;

  // 解析秘钥
  void _parseRequestKey(String page) {
    var matches = _getKeyPattern.firstMatch(page);
    if (matches == null) {
      print("解析秘钥失败");
      return;
    }
    print("解析秘钥成功");
    int reqtime = int.parse(matches.group(1)!);
    String reqtoken = matches.group(2)!;
    int reqexpire = int.parse(matches.group(3)!);
    bingKey = BingKey(reqtime, reqtoken, reqexpire);
  }

// 获取请求秘钥
  Future<bool> _getRequestKey() async {
    var valid = bingKey?.isValid();
    if (valid != null && valid) {
      // 表明已经获取过一次秘钥了 且 有效
      print("秘钥有效，不再重复申请秘钥");
      return true;
    }

    print("秘钥无效，开始申请秘钥");
    final dio = Dio(BaseOptions(headers: {
      "referrer": "https://cn.bing.com/",
      "user-agent": _userAgent,
      "cookie":
          "SRCHHPGUSR=SRCHLANG=zh-Hans&HV=${DateTime.now().microsecondsSinceEpoch ~/ 1000}",
    }));
    Response res = await dio.get(_getKeyUri);
    _parseRequestKey(res.data);
    dio.close();
    return true;
  }

  // 获取翻译结果
  Future<Response> _translate(String info) async {
    print("获取翻译结果：$info");
    final dio = Dio(BaseOptions(headers: {
      "referrer": "https://cn.bing.com/",
      "user-agent": _userAgent,
      "content-type": "application/x-www-form-urlencoded",
    }));

    Response res = await dio.post(_getTransUri, data: {
      "fromLang": "en",
      "to": "zh-Hans",
      "token": bingKey?.reqToken,
      "key": bingKey?.reqTime,
      "text": info,
      "tryFetchingGenderDebiasedTranslations": "true",
    });
    dio.close();
    return res;
  }

  // 解析翻译结果
  String parseTranslate(Response response) {
    var result = "";
    try {
      result = response.data[0]['translations'][0]['text'];
    } catch (e) {
      print("parseTranslate error: ${e.toString()}");
    }
    return result;
  }

  @override
  Future<String> translate(String info) async {
    if (await _getRequestKey()) {
      Response result = await _translate(info);
      print("translate result: ${parseTranslate(result)}");
      return parseTranslate(result);
    }
    return "";
  }
}
