program radiko_ripper;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Windows,
  ShellAPI,
  Classes,
  Forms,
  untRegExpr in 'untRegExpr.pas',
  jconvert in 'Jconvert.pas',
  untZLIB,
  untGZIP,
  TlHelp32;

const
  TEISU_DEFAULT_REC_SEC = 30 * 60;
  TEISU_MAX = 11;
  TEISU_PLAYER = 'player.swf';
  TEISU_SWF = 'https://radiko.jp/apps/js/flash/myplayer-release.swf';
  //ラジコプレミアムでログインしない形が_fms
  TEISU_AUTH1 = 'https://radiko.jp/v2/api/auth1_fms';
  TEISU_AUTH2 = 'https://radiko.jp/v2/api/auth2_fms';
  //ログインする形
  //TEISU_AUTH1 = 'https://radiko.jp/v2/api/auth1';
  //TEISU_AUTH2 = 'https://radiko.jp/v2/api/auth2';

  TEISU_PLAYLIST = 'https://radiko.jp/v2/api/ts/playlist.m3u8';
  //TEISU_USERAGENT = 'Mozilla/5.0 (compatible; MSIE 11.0; Windows NT 6.1; Trident/7.0)';
  TEISU_USERAGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:100.2) Gecko/20100101 Firefox/100.2';

var
  //グローバル変数
  FSWF_str: WideString;
  FTime_Length: Word;
  //局名
  tune_name: Array [0..11] of AnsiString
  = ( '',
      'TBSラジオ',
      '文化放送',
      'ニッポン放送',
      'ラジオNIKKEI',
      'InterFM',
      'TOKYO FM',
      'J-WAVE',
      'ラジオ日本',
      'BayFM78',
      'Nack5',
      'FM横浜');

  //局名２
  tune_alpha: Array [0..11] of AnsiString
  = ( '',
      'TBS',
      'QRR',
      'LFR',
      'NSB',
      'INT',
      'FMT',
      'FMJ',
      'JORF',
      'BAYFM78',
      'NACK5',
      'YFM');
  //ループカウンタ
  i: Cardinal;
  //画面入力文字
  inputstr: AnsiString;
  //選択した放送局名
  tuned_name: AnsiString;
  //録音時間(sec)
  rec_sec: Word;
  strA: AnsiString;
  exitcode: Cardinal;
  regexpr: TRegExpr;
  strList: TStringList;
  keylength: Word;     //SSLキーの長さ
  keyoffset: Cardinal; //SSLキーオフセット
  SSLToken: AnsiString;//SSL認証トークン
  SSLKey: AnsiString;  //SSLキー
  fs: TFileStream;
  readlength: Integer; //ファイル読み込みをした結果のサイズ
  poutbuffer: Pointer; //Z形式デコード済みバッファ
  outbuffersize: Integer; //デコード済みバッファサイズ
  filesize: Int64;
  fileposition: Int64;
  jpgposition: Int64;
  FBuffer: TMemoryStream;
  FBuffer2: TMemoryStream;
  FGZipStream: TGzipDecompressStream;
  pbuf: PChar;
  handle: THandle;
  outputfilename: AnsiString;
  srec: TSearchRec;
  intRetry: Byte;
  starttime: AnsiString;
  endtime: AnsiString;
  Snap: Cardinal;
  tp: TProcessEntry32;
  processname: AnsiString;
  processID: Cardinal;
  fdwAccess: Cardinal;
  hProcess: Integer;
  label CHECK1;
  label CHECK2;
  label CHECK3;

procedure MyShellExecute(filename: PChar; param: PChar);
var
  sei:TShellExecuteInfo;
begin

  //シェルで実行する

  FillChar(sei,SizeOf(TShellExecuteInfo),#0);

  sei.cbSize := SizeOf(TShellExecuteInfo);
  sei.fMask  := SEE_MASK_NOCLOSEPROCESS;
  sei.Wnd    := GetCurrentProcess;
  sei.lpVerb := 'open';
  sei.lpFile := filename;
  sei.lpParameters := param;
  sei.lpDirectory := nil;
  sei.nShow  := SW_HIDE;

  if ShellExecuteEx(@sei) then
  begin

    //しばらく待つ
    repeat

        //Sleepで待つやり方は、厳密には正しくない
        //なるべく使わずに処理する
        //Sleep(1000);
        Application.ProcessMessages;

        GetExitCodeProcess(sei.hProcess, exitcode);


    until (exitcode <> STILL_ACTIVE);

  end;

  TerminateProcess(sei.hProcess,0);

  //しばらく待つ
  repeat
     Application.ProcessMessages;
     GetExitCodeProcess(sei.hProcess, exitcode);
  until (exitcode <> STILL_ACTIVE);

  CloseHandle(sei.hProcess);

  //しばらく待つ
  repeat
     Application.ProcessMessages;
     GetExitCodeProcess(sei.hProcess, exitcode);
  until (exitcode <> STILL_ACTIVE);

end;


function DeleteMS(ms:TMemoryStream;InitPos,EndPos:integer):Boolean;
var
  tmp:TMemoryStream;
begin
  result := false;
  if (InitPos>EndPos) or (EndPos>ms.Size-1) then exit;
  tmp := TMemoryStream.Create;
  try
    try
      ms.Position := 0;
      tmp.Write(ms.Memory^,InitPos);
      tmp.Write(pointer(PChar(ms.Memory)+EndPos+1)^,ms.Size-EndPos-1);
      tmp.Position := 0;
      ms.LoadFromStream(tmp);
      ms.Position := 0;
      result := true;
    except
      result := false;
      exit;
    end;
  finally
    tmp.Free;
  end;
end;


//メインルーチン---------------------------------------------
begin

  i := 0;
  readlength := 0;
  outbuffersize := 0;
  filesize := 0;
  fileposition := 0;
  jpgposition := 0;
  tuned_name := '';
  starttime := '';
  endtime := '';

  //録音時間デフォルトは30分
  rec_sec := TEISU_DEFAULT_REC_SEC;

  //引数を解析する
  //　直接起動ではなくて引数が渡されていて、
  //  １文字目に radiko_ripper となっているとき
  //　batファイル経由ならそうなるはず
  if (CmdLine <> '') then
  if (Pos('radiko_ripper',CmdLine) = 1) then
  begin
      regexpr := TRegExpr.Create;

      //20200713 タイムフリー用の設定を追加
      regexpr.Expression := 'radiko_ripper +([0-9A-Z]+) ([0-9]+) ([0-9]+)';
      if (regexpr.Exec(CmdLine)) then
      begin
          writeln('== Time Free mode ==');
          writeln('CmdLine=' + CmdLine);

          tuned_name := regexpr.Match[1];
          starttime := regexpr.Match[2];
          endtime := regexpr.Match[3];
          regexpr.Free;
          //選択画面を飛ばす
          goto CHECK2;
      end;

      //20161225 Win7環境ではなぜかradiko_ripper  FMT 30と、空白が２つ入る現象あり
      regexpr.Expression := 'radiko_ripper +([0-9A-Z]+) ([0-9]+)';

      if (regexpr.Exec(CmdLine) = false) then
      begin
          //ヘルプを表示して終了

          writeln('ffmpeg front-end "radiko_ripper" programmed by exon@2023');
          writeln('<how to use>');
          writeln('radiko_ripper [放送局名] [録音時間]');
          writeln('radiko_ripper [放送局名] [放送開始時間] [放送終了時間]');
          writeln(' ');
          writeln('放送局名はチャンネルを示す英数字です');
          writeln('例) TOKYO FM -> FMT');
          writeln('録音時間は1分単位で指定します');
          writeln(' ');
          writeln('何も指定しなければ放送局の選択画面を表示します');
          writeln('録音時間のデフォルトは30分になっています');
          writeln('ffmpeg実行中はいつでもCTRL+Cで中止できます');
          writeln(' ');
          writeln('<使用例1> TOKYO FMを25分録音するとき');
          writeln('radiko_ripper FMT 25');
          writeln(' ');
          writeln('<使用例2> BAYFMをタイムフリー録音するとき');
          writeln('日付は年月日時分秒で指定します');
          writeln('radiko_ripper BAYFM78 20210118000100 20210118000300');
          writeln(' ');
          writeln('Enterキーで終了します');
          writeln('hit enter key to quit.');
          readln(inputstr);
          exit;
      end;

      //放送局名を設定
      tuned_name := regexpr.Match[1];
      //録音時間 秒単位なので６０倍
      rec_sec := StrToInt(regexpr.Match[2]) * 60;

      //解放
      regexpr.Free;

      //選択画面を飛ばす
      goto CHECK2;
  end;

  //ラジオ局一覧を表示する

  writeln('===== ffmpegによるラジコの録音 =====');

  for i:=1 to TEISU_MAX do
      writeln('[' + IntToStr(i) + ']' + ' ' + tune_name[i]);

CHECK1:

  writeln('放送局を選んでください。>');
  readln(inputstr);

  for i:=1 to TEISU_MAX do
  begin

     if (inputstr = IntToStr(i)) then
         tuned_name := tune_alpha[i];
  end;

  //エラーチェック
  if (tuned_name = '') then goto CHECK1;

  //リトライカウンタ初期化
  intRetry := 0;

CHECK2:

  //ステップ１　プレイヤーをDLする

  //20201212 プレイヤーは一切使わないのでDLや存在チェックが不要
  //全部コメントアウト
{

  strA := '-q --user-agent="' + TEISU_USERAGENT + '" -O player.swf ' + TEISU_SWF;

  //空状態にしておく
  strList := TStringList.Create;
  strList.SaveToFile(TEISU_PLAYER);
  strList.Free;

  MyShellExecute(PChar('wget.exe'),PChar(strA));

  //player.swfのファイルサイズを調べる

  FindFirst(TEISU_PLAYER, faAnyFile, srec);
  if (srec.Size < 8) then
  begin
      writeln(TEISU_PLAYER + ' の準備に失敗しました');
      exit;
  end;
  FindClose(srec.FindHandle);
}

  //ステップ２ SSL認証

  strA := '-q --user-agent="' + TEISU_USERAGENT + '"';
  strA := strA + ' --header="pragma: no-cache" --header="X-Radiko-App: pc_html5" --header="X-Radiko-App-Version: 0.0.1"';
  strA := strA + ' --header="X-Radiko-User: dummy_user" --header="X-Radiko-Device: pc" --post-data="\r\n"';
  strA := strA + ' --no-check-certificate --save-headers -O auth1.txt ';
  strA := strA + TEISU_AUTH1;

  //Sleep(500);
  //Application.ProcessMessages;

  //空状態にしておく
  strList := TStringList.Create;
  strList.SaveToFile('auth1.txt');
  strList.Free;

  myShellExecute(PChar('wget.exe'),PChar(strA));

  //SSLのファイルが無事に作れたか調べる

  FindFirst('auth1.txt', faAnyFile, srec);
  if (srec.Size < 8) then
  begin
      writeln('auth1.txtの作成に失敗しました');
      exit;
  end;
  FindClose(srec.FindHandle);


  //ステップ３ SSL認証のつづき

  strList := TStringList.Create;
  strList.LoadFromFile('auth1.txt');

  regexpr := TRegExpr.Create;

  sslToken := '';
  keylength := 0;
  keyoffset := 0;

  for i:=0 to strList.Count -1 do
  begin

      //SSLトークンは２つのパターンがあるので２回チェックする
      if (sslToken = '') then
      begin
        regexpr.Expression := 'X-Radiko-AuthToken: (.*)';
        if (regexpr.Exec(strList[i])) then
            sslToken := regexpr.Match[1];
      end;

      if (sslToken = '') then
      begin
        regexpr.Expression := 'X-RADIKO-AUTHTOKEN: (.*)';
        if (regexpr.Exec(strList[i])) then
            sslToken := regexpr.Match[1];
      end;

      if (keylength = 0) then
      begin
        regexpr.Expression := 'X-Radiko-KeyLength: ([0-9]+)';
        if (regexpr.Exec(strList[i])) then
            keylength := StrToInt(regexpr.Match[1]);
      end;

      if (keyoffset = 0) then
      begin
        regexpr.Expression := 'X-Radiko-KeyOffset: ([0-9]+)';
        if (regexpr.Exec(strList[i])) then
            keyoffset := StrToInt(regexpr.Match[1]);
      end;

  end;

  strList.Free;
  //regexpr.Free;

  //20201212 パーシャルキーは以前はPlayer.swfの中を解析していたけれど
  //今はその必要がなくなった。元になる値と keyoffset、keylengthがわかれば十分

  //例）SSL認証キーをbase64でエンコード
  //strA := 'bcd151073c03b352e1ef2fd66c32209da9ca0afa';
  //strA := Copy(strA,keyoffset,keylength);
  //SSLKey := EncodeBase64(strA);

{
  //Playerを解析する
  fs := TFileStream.Create(TEISU_PLAYER, fmOpenRead);

  //ファイルサイズ
  filesize := fs.Size;

  //デコードのメモリを準備
  GetMem(poutbuffer, filesize);

  //メモリに読み込む
  FBuffer := TMemoryStream.Create;
  FBuffer.LoadFromStream(fs);

  //先頭８バイトを捨てる
  DeleteMS(FBuffer,0,7);

  //ZLIB形式でデコード
  try
     DecompressBuf(FBuffer.Memory,filesize,0,poutbuffer,outbuffersize);
  except
     //何もしない
     filesize := filesize;
  end;

  FBuffer.Free;
  FBuffer2 := TMemoryStream.Create;

  fileposition := 0;
  SSLKey := '';

  //画像を探す
  while (fileposition < outbuffersize) do
  begin
      FBuffer2.Write(PChar(poutbuffer)[fileposition],1);
      Inc(fileposition);

      //キーを拾う
      //if (fileposition >= $13370 + keyoffset) then
      //if (fileposition < $13370 + keyoffset + keylength) then
      //    SSLKey := SSLKey + PChar(poutbuffer)[fileposition];

      //20121024
      //画像ファイルを探す 10進で85557の位置に発見
      if (PChar(poutbuffer)[fileposition] = 'J') then
      if (PChar(poutbuffer)[fileposition+1] = 'F') then
      if (PChar(poutbuffer)[fileposition+2] = 'I') then
      if (PChar(poutbuffer)[fileposition+3] = 'F') then
      begin
          //85557 - 6として６バイト前が正しい位置となる
          jpgposition := fileposition -6;
          fileposition := jpgposition;
          break;
      end;

  end;

  while (fileposition < outbuffersize) do
  begin

      if (jpgposition = 0) then break;

      FBuffer2.Write(PChar(poutbuffer)[fileposition],1);
      Inc(fileposition);

      //SSLKeyを拾う
      if (fileposition >= jpgposition + keyoffset) then
      if (fileposition < jpgposition + keyoffset + keylength) then
          SSLKey := SSLKey + PChar(poutbuffer)[fileposition];

  end;

  //デバッグ用ファイル出力
  //FBuffer2.SaveToFile('player.swf.uncompressed');
  FBuffer2.Free;

  //SSL認証キーをbase64でエンコード
  SSLKey := EncodeBase64(SSLKey);

  fs.free;
  regexpr.Free;
}

  //ステップ４ 取得できた情報を表示

  //playerCommon.jsで定義されているパーシャルキーの値
  strA := 'bcd151073c03b352e1ef2fd66c32209da9ca0afa';

  //オフセットは+1するのが正しいようだ
  strA := Copy(strA,keyoffset+1,keylength);
  SSLKey := EncodeBase64(strA);

  writeln('SSL token: ' + SSLToken);
  writeln('keyoffset: ' + IntToStr(keyoffset));
  writeln('keylength: ' + IntToStr(keylength));
  writeln('SSL Key: ' + SSLKey);

  //ステップ５ SSL認証を完了する

  //20201212 リクエストヘッダはradikoJSPlayer.js の定義が参考になった

  strA := '-q --user-agent="' + TEISU_USERAGENT + '"';
  strA := strA + ' --header="X-Radiko-App: pc_html5" --header="X-Radiko-App-Version: 0.0.1"';
  strA := strA + ' --header="X-Radiko-AuthToken: ' + SSLToken + '"';
  strA := strA + ' --header="X-Radiko-PartialKey: ' + SSLKey + '"';
  strA := strA + ' --header="X-Radiko-User: dummy_user"';
  strA := strA + ' --header="X-Radiko-Device: pc"';
  strA := strA + ' --post-data="\r\n"';
  strA := strA + ' --server-response --trust-server-names';

  //この --server-response で、もし認証エラー401ならpartialkeyの異常がわかる

  strA := strA + ' --no-check-certificate --save-headers -O auth2.txt ';
  strA := strA + TEISU_AUTH2;

  //空状態にしておく
  strList := TStringList.Create;
  strList.SaveToFile('auth2.txt');
  strList.Free;

  //少し待つ
  Application.ProcessMessages;

  //リトライカウンタ初期化
  intRetry := 0;

  myShellExecute(PChar('wget.exe'),PChar(strA));

  //少し待つ
  Sleep(500);
  Application.ProcessMessages;

  //SSLのファイルが無事に作れたか調べる

  FindFirst('auth2.txt', faAnyFile, srec);
  if (srec.Size < 8) then
  begin
      writeln('auth2.txtの作成に失敗しました');

      Inc(intRetry);

      //２回リトライする
      if (intRetry > 2) then exit;

      writeln('リトライします');

      //しばらく待機してリトライ
      Sleep(2000);
      Application.ProcessMessages;

      FindClose(srec.FindHandle);
      goto CHECK2;
  end;
  FindClose(srec.FindHandle);

  //ステップ６ すべて準備完了、いよいよラジコからダウンロード

  //20200713 タイムフリー録音の場合を追加
  if (starttime <> '') then
  if (endtime <> '') then
      goto CHECK3;

  //出力ファイル名
  outputfilename := tuned_name + '_' + FormatDateTime('yyyymmdd_hhnnss',Now) + '.aac';

  //20210117 ラジコが13日に仕様変更してrtmpdumpでは取れなくなった
  //Flashサポートを2020年で終了した影響のようだ
  //rtmpdumpから、ffmpegのHLS通信に変更する必要がある

  //URL
  //strA := '/c start /low rtmpdump -r "rtmpe://203.211.199.180:1935"';
  //strA := strA + ' --playpath "simul-stream.stream" --app "' + tuned_name + '/_definst_"';
  //strA := strA + ' -W ' + TEISU_SWF + ' -C S:"" -C S:"" -C S:"" -C S:' + SSLToken;
  //strA := strA + ' --live --flv ' + outputfilename + ' --stop ' + IntToStr(rec_sec);

  strA := '/c start /low ffmpeg -headers "X-Radiko-AuthToken: ' + SSLToken + '"';
  strA := strA + ' -i "http://f-radiko.smartstream.ne.jp/' + tuned_name + '/_definst_/simul-stream.stream/playlist.m3u8"';
  strA := strA + ' -acodec copy';
  strA := strA + ' ' + outputfilename;

  //少し待機
  Sleep(2000);

  myShellExecute(PChar('cmd.exe'),PChar(strA));

  //ffmpegを閉じるために待機する

  i := 0;
  repeat
    Sleep(1000);
    Inc(i);
  //ffmpegの起動に15秒ほどかかるので足しておく
  //until (i > rec_sec);
  until (i > rec_sec +15);

  //ffmpegのプロセスを探して、閉じる
  Snap := CreateToolHelp32Snapshot(TH32CS_SNAPPROCESS, 0);

  tp.dwSize := Sizeof(TProcessEntry32);
  if (Process32First(Snap, tp) = false) then
  begin
      Sleep(5000);
      Snap := CreateToolHelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  end;

  while (Process32Next(Snap, tp)) do
  begin
        processname := tp.szExeFile;
        processname := LowerCase(processname);

        if (processname = 'ffmpeg.exe') then
        begin
            //debug
            writeln('ffmpegを発見。閉じます');

            processID := tp.th32ProcessID;
            fdwAccess := PROCESS_ALL_ACCESS or PROCESS_VM_READ;
            hProcess  := OpenProcess(fdwAccess,False,processID);
            TerminateProcess(hProcess,0);
        end;
  end;

  CloseHandle(Snap);

  //debug
  //writeln('画面を閉じます');
  //readln(inputstr);

  exit;

CHECK3:


  //20210118 タイムフリーに対応

  //debug
  writeln('タイムフリー録音をします');

  strA := '/c start /low ffmpeg -headers "X-Radiko-AuthToken: ' + SSLToken + '"';
  strA := strA + ' -i "https://radiko.jp/v2/api/ts/playlist.m3u8';
  strA := strA + '?station_id=' + tuned_name + '&l=15';
  strA := strA + '&ft=' + starttime;
  strA := strA + '&to=' + endtime + '"';
  strA := strA + ' -acodec copy';

  //出力ファイル名
  outputfilename := tuned_name + '_' + starttime + '.aac';

  strA := strA + ' ' + outputfilename;

  //少し待機
  Sleep(2000);

  myShellExecute(PChar('cmd.exe'),PChar(strA));


//メインルーチン終了-----------------------------------------
end.




