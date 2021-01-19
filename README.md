# radiko_ripper
command-line tool for radiko programmed by Delphi 6 or 7
Radiko用のコマンドラインツール、Delphi 6/7用です。
Windows 7 32bitで動作確認しています。

## 必要なもの 
- Delphi 6/7ソースをコンパイルできる環境
- wget
- OpenSSL dll (libeay32.dll ssleay32.dll) バージョンは1.0.2pで動作確認しました
- ffmpeg

## コンパイルの方法
radiko_ripper.dprがソース本体です。これをコンパイルしてください。
Delphi用のプロジェクトファイルでもあり、ソースでもあります。
コマンドラインのCUIツールは、この１つのファイルだけで済みます。

## 使い方 how to use
- リアルタイム録音するとき radiko_ripper <放送局名> <録音時間 分>
- 例) radiko_ripper FMT 25

- タイムフリー録音するとき radiko_ripper <放送局名> <番組開始時間 年月日時分秒 yyyymmddhhmmss> <番組終了時間 年月日時分秒 yyyymmddhhmmss>
- 例）radiko_ripper FMT 20210118000000 20210118003000

- 引数を与えずに単に radiko_ripper を起動すると、使い方を表示します。

## 開発秘話的なもの
もともとこのツールは、数年前に和ジオ(geocities.jp)でフリーソフトとして公開していたものでしたが、
和ジオが無料ホームページサービスを終了したのに伴い、ネット上から消滅していました。
それ以降は自分専用のラジコ録音ツールとして使っていましたが、2021年1月、ふと気が向いて、オープンソースで公開することにしました。
1月13日のラジコの仕様変更に対応しました。
元々はWindows 2000環境用の設計でしたが、今はWindows 7用にしています。
面倒臭くてWin10 64bit環境の動作テストはしていませんが、たぶん動くでしょう。

## License
[MIT License](LICENSE)
