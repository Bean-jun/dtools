import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:encrypt/encrypt.dart';
import 'package:translates/translate_proivder/translate.dart';

// ignore: dangling_library_doc_comments, slash_for_doc_comments
/**
 * netease 网易翻译解析
 * 1. 走一个请求，获取翻译使用的签名key, aes解密的iv及key
 * https://dict.youdao.com/webtranslate/key?keyid=webfanyi-key-getter&sign=68d4007944af8f89365a1addfcecc3f6&client=fanyideskweb&product=webfanyi&appVersion=1.0.0&vendor=web&pointParam=client,mysticTime,product&mysticTime=1730078168758&keyfrom=fanyi.web&mid=1&screen=1&model=1&network=wifi&abtest=0&yduuid=abcdefg
 * 
 * 响应说明：
 * {'data': {'secretKey': 'fsdsogkndfokasodnaso', 'aesKey': 'ydsecret://query/key/B*RGygVywfNBwpmBaZg*WT7SIOUP2T0C9WHMZN39j^DAdaZhAnxvGcCY6VYFwnHl', 'aesIv': 'ydsecret://query/iv/C@lZe2YzHtZ2CYgaXKSVfsb7Y4QWHjITPPZ0nQp87fBeJ!Iv6v^6fvi2WN@bYpJ4'}, 'code': 0, 'msg': 'OK'}
 * 
 * 2. 走一个请求，通过上一步的签名key生成签名，携带固定cookies请求，并通过上一轮的aes秘钥解密
 * https://dict.youdao.com/webtranslate
 * 
 * 请求体：
 *     "i":"待翻译文本",
 *     "from":"auto",
 *     "to":"",
 *     "useTerm":"false",
 *     "domain":"0",
 *     "dictResult":"true",
 *     "keyid":"webfanyi",
 *     "sign": 签名,
 *     "client":"fanyideskweb",
 *     "product":"webfanyi",
 *     "appVersion":"1.0.0",
 *     "vendor":"web",
 *     "pointParam":"client,mysticTime,product",
 *     "mysticTime": 请求时间戳,
 *     "keyfrom":"fanyi.web",
 *     "mid":"1",
 *     "screen":"1",
 *     "model":"1",
 *     "network":"wifi",
 *     "abtest":"0",
 *     "yduuid":"abcdefg"
 *
 * 请求cookies:
 * "OUTFOX_SEARCH_USER_ID": "17913718@127.0.0.1"
 * 
 * 响应结果：
 * {"code":0,"dictResult":{"ec":{"exam_type":["初中","高中","CET4","CET6","考研","IELTS","商务英语"],"word":{"usphone":"saɪn","ukphone":"saɪn","ukspeech":"sign&type=1","trs":[{"pos":"n.","tran":"指示牌，标志；迹象，征兆；示意动作， 
手势；手语动作；符号，记号；踪迹，踪影；（医）征，体征；神迹（主要用于《圣经》和文学作品中）；<美>（野生动物的）足迹，臭迹；（占星）（黄道12宫中的）宫，星座；（数）正负号；暗号，信号；（表示某人状况或经历的）动作，反应"},{"pos":"v.","tran":"签名，署名；（与机构、公司等）签约；示意，打手势；打手语；用标志杆（或其他记号）表示"}],"wfs":[{"wf":{"name":"复数","value":"signs"}},{"wf":{"name":"第三人称单数","value":"signs"}},{"wf":{"name":"现在分词","value":"signing"}},{"wf":{"name":"过去式","value":"signed"}},{"wf":{"name":"过去分词","value":"signed"}}],"return-phrase":"sign","usspeech":"sign&type=2"}}},"translateResult":[[{"tgt":"标志","src":"sign","tgtPronounce":"biāozhì"}]],"type":"en2zh-CHS"}
 */

class NeteaseTranslateProivder implements TranslateProivder {
  final _userAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0";
  final _url = "https://dict.youdao.com/webtranslate";
  String? secretKey;
  String? aesKey;
  String? aesIv;

  // 解析秘钥
  void _parseRequestKey(String page) {
    try {
      final data = jsonDecode(page);
      if (data["code"] == null) {
        print("[ERROR] _parseRequestKey Code : null");
        return;
      }
      secretKey = data["data"]!["secretKey"];
      aesKey = data["data"]!["aesKey"];
      aesIv = data["data"]!["aesIv"];
    } catch (e) {
      print("[ERROR] _parseRequestKey ${e.toString()}");
      return;
    }
  }

  // 获取签名
  String _getSign(int timeTick, String key,
      {String client = "fanyideskweb", String product = "webfanyi"}) {
    var str = "client=$client&mysticTime=$timeTick&product=$product&key=$key";
    var content = Utf8Encoder().convert(str);
    return md5.convert(content).toString();
  }

// 获取请求秘钥
  Future<bool> _getRequestKey() async {
    print("开始申请秘钥");
    final dio = Dio(BaseOptions(headers: {
      "referrer": "https://fanyi.youdao.com/",
      "user-agent": _userAgent,
    }));

    var timeTick = DateTime.now().millisecondsSinceEpoch;
    var key = "asdjnjfenknafdfsdfsd";
    var sign = _getSign(timeTick, key);
    var url =
        "$_url/key?keyid=webfanyi-key-getter&sign=$sign&client=fanyideskweb&product=webfanyi&appVersion=1.0.0&vendor=web&pointParam=client,mysticTime,product&mysticTime=$timeTick&keyfrom=fanyi.web&mid=1&screen=1&model=1&network=wifi&abtest=0&yduuid=abcdefg";

    Response res = await dio.get(url);
    _parseRequestKey(res.toString());
    dio.close();
    return true;
  }

  // 获取翻译结果
  Future<Response> _translate(String info) async {
    // print("获取翻译结果：$info, $aesIv, $aesKey, $secretKey");
    final dio = Dio(BaseOptions(headers: {
      "Host": "dict.youdao.com",
      "Accept-Encoding": "gzip, deflate",
      "accept": "*/*",
      "Connection": "keep-alive",
      "referer": "https://fanyi.youdao.com/",
      "User-Agent": _userAgent,
      "content-type": "application/x-www-form-urlencoded",
    }, responseType: ResponseType.plain));

    var timeTick = DateTime.now().millisecondsSinceEpoch;
    var dataReq = {
      "i": info,
      "from": "auto", // zh-CHS, en
      "to": "", // zh-CHS, en
      "useTerm": "false",
      "domain": "0",
      "dictResult": "true",
      "keyid": "webfanyi",
      "sign": _getSign(timeTick, secretKey!),
      "client": "fanyideskweb",
      "product": "webfanyi",
      "appVersion": "1.0.0",
      "vendor": "web",
      "pointParam": "client,mysticTime,product",
      "mysticTime": timeTick.toString(),
      "keyfrom": "fanyi.web",
      "mid": "1",
      "screen": "1",
      "model": "1",
      "network": "wifi",
      "abtest": "0",
      "yduuid": "abcdefg",
    };

    // 创建 CookieJar
    final cookieJar = CookieJar();
    dio.interceptors.add(CookieManager(cookieJar));

    // 设置初始 Cookie
    final cookie = Cookie('OUTFOX_SEARCH_USER_ID', '17913718@127.0.0.1');
    cookieJar.saveFromResponse(Uri.parse(_url), [cookie]);

    Response res = await dio.post(
      _url,
      data: dataReq,
      // options: Options(
      //     validateStatus: (status) {
      //       print("validateStatus: $status");
      //       return true;
      //     },
      //     responseType: ResponseType.plain)
    );
    // print(res.data);
    dio.close();
    return res;
  }

  // ignore: non_constant_identifier_names
  String _decode_result(Response response) {
    var result = "";
    try {
      final encrypted = Encrypted(base64Url.decode(response.data));
      final encrypter = Encrypter(AES(
          Key(Uint8List.fromList(md5.convert(utf8.encode(aesKey!)).bytes)),
          mode: AESMode.cbc,
          padding: 'PKCS7'));

      result = encrypter.decrypt(encrypted,
          iv: IV(Uint8List.fromList(md5.convert(utf8.encode(aesIv!)).bytes)));
    } catch (e) {
      print("_decode_result error: ${e.toString()}");
    }
    return result;
  }

  // 解析翻译结果
  String parseTranslate(Response response) {
    var result = _decode_result(response);
    try {
      var result_ = jsonDecode(result);
      return result_["translateResult"]![0]![0]['tgt'];
    } catch (e) {
      print("parseTranslate error: ${e.toString()}");
    }
    return "";
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
