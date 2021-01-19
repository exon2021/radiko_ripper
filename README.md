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

## License
[MIT License](LICENSE)
