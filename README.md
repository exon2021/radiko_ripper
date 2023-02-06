# radiko_ripper
command-line tool for radiko programmed by Delphi 6 or 7
Radiko用のコマンドラインツール、Delphi 6/7用です。
Windows 7 32bitで動作確認しています。

## 必要なもの 
- Delphi 6/7ソースをコンパイルできる環境
- wget.exe (version 1.21.3 で動作確認しました)
- OpenSSLのlibssl-1_1.dll、libcrypto-1_1.dll (version 1.1.1s で動作確認しました)
- ffmpeg.exe (version 5.2-564-e4ac156 で動作確認しました)

## コンパイルの方法
radiko_ripper.dprがソース本体です。これをコンパイルしてください。
Delphi用のプロジェクトファイルでもあり、ソースでもあります。
コマンドラインのCUIツールは、この１つのファイルだけで済みます。

## 使い方 how to use
- リアルタイム録音するとき radiko_ripper <放送局名> <録音時間 分>
- 例) radiko_ripper FMT 25

- タイムフリー録音するとき radiko_ripper <放送局名> <番組開始時間 年月日時分秒 yyyymmddhhmmss> <番組終了時間 年月日時分秒 yyyymmddhhmmss>
- 例）radiko_ripper FMT 20230207000000 20230207003000

- 引数を与えずに単に radiko_ripper を起動すると、使い方を表示します。

## 放送局についての注意点
関東の放送局のリストを標準にしています。お住まいの地域と、放送局が一致しないと 403 エラーが生じて
通信に失敗することがあります。ラジコプレミアムには対応していないツールなのでそうなるのです。
たとえば大阪にお住まいなら MBS はご存知ですよね。radiko_ripper MBS 30 を試してみてください。

## 開発秘話的なもの
もともとこのツールは、数年前に和ジオ(geocities.jp)でフリーソフトとして公開していたものでしたが、
和ジオが無料ホームページサービスを終了したのに伴い、ネット上から消滅していました。
それ以降は自分専用のラジコ録音ツールとして使っていましたが、2021年1月、ふと気が向いて、オープンソースで公開することにしました。
1月13日のラジコの仕様変更に対応しました。
元々はWindows 2000環境用の設計でしたが、今はWindows 7用にしています。
面倒臭くてWin10 64bit環境の動作テストはしていませんが、たぶん動くでしょう。

## ソースについて補足
radiko_ripper.dprは、untZLIBとuntGZIPは今は不要のはずなのでusesからコメントアウトでいいはずです。
GZIP圧縮されたデータを扱うためのライブラリです。
元々は2chブラウザ用のライブラリなので、もしそれが新規に必要ならその界隈を探してください。
文字列マッチングでuntRegExprを使っているので、それが必要ですが、他のものに置き換えてもいいですよ。

## License
[MIT License](LICENSE)
