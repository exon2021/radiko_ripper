# radiko_ripper
command-line tool for radiko programmed by Delphi 6 or 7
Radiko用のコマンドラインツール、Delphi 6/7用です。
Windows 7 32bitで動作確認しています。

## 必要なもの 
- Delphi 6/7ソースをコンパイルできる環境
- wget
- OpenSSL dll (a.dll b.dll)
- ffmpeg

## 使い方 how to use
- リアルタイム録音するとき radiko_ripper <放送局名> <録音時間 分>
- 例) radiko_ripper FMT 25

- タイムフリー録音するとき radiko_ripper <放送局名> <番組開始時間 年月日時分秒 yyyymmddhhmmss> <番組終了時間 年月日時分秒 yyyymmddhhmmss>
- 例）radiko_ripper FMT 20210118000000 20210118003000

## License
[MIT License](LICENSE)
