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
  //���W�R�v���~�A���Ń��O�C�����Ȃ��`��_fms
  TEISU_AUTH1 = 'https://radiko.jp/v2/api/auth1_fms';
  TEISU_AUTH2 = 'https://radiko.jp/v2/api/auth2_fms';
  //���O�C������`
  //TEISU_AUTH1 = 'https://radiko.jp/v2/api/auth1';
  //TEISU_AUTH2 = 'https://radiko.jp/v2/api/auth2';

  TEISU_PLAYLIST = 'https://radiko.jp/v2/api/ts/playlist.m3u8';
  //TEISU_USERAGENT = 'Mozilla/5.0 (compatible; MSIE 11.0; Windows NT 6.1; Trident/7.0)';
  TEISU_USERAGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:100.2) Gecko/20100101 Firefox/100.2';

var
  //�O���[�o���ϐ�
  FSWF_str: WideString;
  FTime_Length: Word;
  //�ǖ�
  tune_name: Array [0..11] of AnsiString
  = ( '',
      'TBS���W�I',
      '��������',
      '�j�b�|������',
      '���W�INIKKEI',
      'InterFM',
      'TOKYO FM',
      'J-WAVE',
      '���W�I���{',
      'BayFM78',
      'Nack5',
      'FM���l');

  //�ǖ��Q
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
  //���[�v�J�E���^
  i: Cardinal;
  //��ʓ��͕���
  inputstr: AnsiString;
  //�I�����������ǖ�
  tuned_name: AnsiString;
  //�^������(sec)
  rec_sec: Word;
  strA: AnsiString;
  exitcode: Cardinal;
  regexpr: TRegExpr;
  strList: TStringList;
  keylength: Word;     //SSL�L�[�̒���
  keyoffset: Cardinal; //SSL�L�[�I�t�Z�b�g
  SSLToken: AnsiString;//SSL�F�؃g�[�N��
  SSLKey: AnsiString;  //SSL�L�[
  fs: TFileStream;
  readlength: Integer; //�t�@�C���ǂݍ��݂��������ʂ̃T�C�Y
  poutbuffer: Pointer; //Z�`���f�R�[�h�ς݃o�b�t�@
  outbuffersize: Integer; //�f�R�[�h�ς݃o�b�t�@�T�C�Y
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

  //�V�F���Ŏ��s����

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

    //���΂炭�҂�
    repeat

        //Sleep�ő҂����́A�����ɂ͐������Ȃ�
        //�Ȃ�ׂ��g�킸�ɏ�������
        //Sleep(1000);
        Application.ProcessMessages;

        GetExitCodeProcess(sei.hProcess, exitcode);


    until (exitcode <> STILL_ACTIVE);

  end;

  TerminateProcess(sei.hProcess,0);

  //���΂炭�҂�
  repeat
     Application.ProcessMessages;
     GetExitCodeProcess(sei.hProcess, exitcode);
  until (exitcode <> STILL_ACTIVE);

  CloseHandle(sei.hProcess);

  //���΂炭�҂�
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


//���C�����[�`��---------------------------------------------
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

  //�^�����ԃf�t�H���g��30��
  rec_sec := TEISU_DEFAULT_REC_SEC;

  //��������͂���
  //�@���ڋN���ł͂Ȃ��Ĉ������n����Ă��āA
  //  �P�����ڂ� radiko_ripper �ƂȂ��Ă���Ƃ�
  //�@bat�t�@�C���o�R�Ȃ炻���Ȃ�͂�
  if (CmdLine <> '') then
  if (Pos('radiko_ripper',CmdLine) = 1) then
  begin
      regexpr := TRegExpr.Create;

      //20200713 �^�C���t���[�p�̐ݒ��ǉ�
      regexpr.Expression := 'radiko_ripper +([0-9A-Z]+) ([0-9]+) ([0-9]+)';
      if (regexpr.Exec(CmdLine)) then
      begin
          writeln('== Time Free mode ==');
          writeln('CmdLine=' + CmdLine);

          tuned_name := regexpr.Match[1];
          starttime := regexpr.Match[2];
          endtime := regexpr.Match[3];
          regexpr.Free;
          //�I����ʂ��΂�
          goto CHECK2;
      end;

      //20161225 Win7���ł͂Ȃ���radiko_ripper  FMT 30�ƁA�󔒂��Q���錻�ۂ���
      regexpr.Expression := 'radiko_ripper +([0-9A-Z]+) ([0-9]+)';

      if (regexpr.Exec(CmdLine) = false) then
      begin
          //�w���v��\�����ďI��

          writeln('ffmpeg front-end "radiko_ripper" programmed by exon@2023');
          writeln('<how to use>');
          writeln('radiko_ripper [�����ǖ�] [�^������]');
          writeln('radiko_ripper [�����ǖ�] [�����J�n����] [�����I������]');
          writeln(' ');
          writeln('�����ǖ��̓`�����l���������p�����ł�');
          writeln('��) TOKYO FM -> FMT');
          writeln('�^�����Ԃ�1���P�ʂŎw�肵�܂�');
          writeln(' ');
          writeln('�����w�肵�Ȃ���Ε����ǂ̑I����ʂ�\�����܂�');
          writeln('�^�����Ԃ̃f�t�H���g��30���ɂȂ��Ă��܂�');
          writeln('ffmpeg���s���͂��ł�CTRL+C�Œ��~�ł��܂�');
          writeln(' ');
          writeln('<�g�p��1> TOKYO FM��25���^������Ƃ�');
          writeln('radiko_ripper FMT 25');
          writeln(' ');
          writeln('<�g�p��2> BAYFM���^�C���t���[�^������Ƃ�');
          writeln('���t�͔N���������b�Ŏw�肵�܂�');
          writeln('radiko_ripper BAYFM78 20210118000100 20210118000300');
          writeln(' ');
          writeln('Enter�L�[�ŏI�����܂�');
          writeln('hit enter key to quit.');
          readln(inputstr);
          exit;
      end;

      //�����ǖ���ݒ�
      tuned_name := regexpr.Match[1];
      //�^������ �b�P�ʂȂ̂łU�O�{
      rec_sec := StrToInt(regexpr.Match[2]) * 60;

      //���
      regexpr.Free;

      //�I����ʂ��΂�
      goto CHECK2;
  end;

  //���W�I�ǈꗗ��\������

  writeln('===== ffmpeg�ɂ�郉�W�R�̘^�� =====');

  for i:=1 to TEISU_MAX do
      writeln('[' + IntToStr(i) + ']' + ' ' + tune_name[i]);

CHECK1:

  writeln('�����ǂ�I��ł��������B>');
  readln(inputstr);

  for i:=1 to TEISU_MAX do
  begin

     if (inputstr = IntToStr(i)) then
         tuned_name := tune_alpha[i];
  end;

  //�G���[�`�F�b�N
  if (tuned_name = '') then goto CHECK1;

  //���g���C�J�E���^������
  intRetry := 0;

CHECK2:

  //�X�e�b�v�P�@�v���C���[��DL����

  //20201212 �v���C���[�͈�؎g��Ȃ��̂�DL�⑶�݃`�F�b�N���s�v
  //�S���R�����g�A�E�g
{

  strA := '-q --user-agent="' + TEISU_USERAGENT + '" -O player.swf ' + TEISU_SWF;

  //���Ԃɂ��Ă���
  strList := TStringList.Create;
  strList.SaveToFile(TEISU_PLAYER);
  strList.Free;

  MyShellExecute(PChar('wget.exe'),PChar(strA));

  //player.swf�̃t�@�C���T�C�Y�𒲂ׂ�

  FindFirst(TEISU_PLAYER, faAnyFile, srec);
  if (srec.Size < 8) then
  begin
      writeln(TEISU_PLAYER + ' �̏����Ɏ��s���܂���');
      exit;
  end;
  FindClose(srec.FindHandle);
}

  //�X�e�b�v�Q SSL�F��

  strA := '-q --user-agent="' + TEISU_USERAGENT + '"';
  strA := strA + ' --header="pragma: no-cache" --header="X-Radiko-App: pc_html5" --header="X-Radiko-App-Version: 0.0.1"';
  strA := strA + ' --header="X-Radiko-User: dummy_user" --header="X-Radiko-Device: pc" --post-data="\r\n"';
  strA := strA + ' --no-check-certificate --save-headers -O auth1.txt ';
  strA := strA + TEISU_AUTH1;

  //Sleep(500);
  //Application.ProcessMessages;

  //���Ԃɂ��Ă���
  strList := TStringList.Create;
  strList.SaveToFile('auth1.txt');
  strList.Free;

  myShellExecute(PChar('wget.exe'),PChar(strA));

  //SSL�̃t�@�C���������ɍ�ꂽ�����ׂ�

  FindFirst('auth1.txt', faAnyFile, srec);
  if (srec.Size < 8) then
  begin
      writeln('auth1.txt�̍쐬�Ɏ��s���܂���');
      exit;
  end;
  FindClose(srec.FindHandle);


  //�X�e�b�v�R SSL�F�؂̂Â�

  strList := TStringList.Create;
  strList.LoadFromFile('auth1.txt');

  regexpr := TRegExpr.Create;

  sslToken := '';
  keylength := 0;
  keyoffset := 0;

  for i:=0 to strList.Count -1 do
  begin

      //SSL�g�[�N���͂Q�̃p�^�[��������̂łQ��`�F�b�N����
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

  //20201212 �p�[�V�����L�[�͈ȑO��Player.swf�̒�����͂��Ă��������
  //���͂��̕K�v���Ȃ��Ȃ����B���ɂȂ�l�� keyoffset�Akeylength���킩��Ώ\��

  //��jSSL�F�؃L�[��base64�ŃG���R�[�h
  //strA := 'bcd151073c03b352e1ef2fd66c32209da9ca0afa';
  //strA := Copy(strA,keyoffset,keylength);
  //SSLKey := EncodeBase64(strA);

{
  //Player����͂���
  fs := TFileStream.Create(TEISU_PLAYER, fmOpenRead);

  //�t�@�C���T�C�Y
  filesize := fs.Size;

  //�f�R�[�h�̃�����������
  GetMem(poutbuffer, filesize);

  //�������ɓǂݍ���
  FBuffer := TMemoryStream.Create;
  FBuffer.LoadFromStream(fs);

  //�擪�W�o�C�g���̂Ă�
  DeleteMS(FBuffer,0,7);

  //ZLIB�`���Ńf�R�[�h
  try
     DecompressBuf(FBuffer.Memory,filesize,0,poutbuffer,outbuffersize);
  except
     //�������Ȃ�
     filesize := filesize;
  end;

  FBuffer.Free;
  FBuffer2 := TMemoryStream.Create;

  fileposition := 0;
  SSLKey := '';

  //�摜��T��
  while (fileposition < outbuffersize) do
  begin
      FBuffer2.Write(PChar(poutbuffer)[fileposition],1);
      Inc(fileposition);

      //�L�[���E��
      //if (fileposition >= $13370 + keyoffset) then
      //if (fileposition < $13370 + keyoffset + keylength) then
      //    SSLKey := SSLKey + PChar(poutbuffer)[fileposition];

      //20121024
      //�摜�t�@�C����T�� 10�i��85557�̈ʒu�ɔ���
      if (PChar(poutbuffer)[fileposition] = 'J') then
      if (PChar(poutbuffer)[fileposition+1] = 'F') then
      if (PChar(poutbuffer)[fileposition+2] = 'I') then
      if (PChar(poutbuffer)[fileposition+3] = 'F') then
      begin
          //85557 - 6�Ƃ��ĂU�o�C�g�O���������ʒu�ƂȂ�
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

      //SSLKey���E��
      if (fileposition >= jpgposition + keyoffset) then
      if (fileposition < jpgposition + keyoffset + keylength) then
          SSLKey := SSLKey + PChar(poutbuffer)[fileposition];

  end;

  //�f�o�b�O�p�t�@�C���o��
  //FBuffer2.SaveToFile('player.swf.uncompressed');
  FBuffer2.Free;

  //SSL�F�؃L�[��base64�ŃG���R�[�h
  SSLKey := EncodeBase64(SSLKey);

  fs.free;
  regexpr.Free;
}

  //�X�e�b�v�S �擾�ł�������\��

  //playerCommon.js�Œ�`����Ă���p�[�V�����L�[�̒l
  strA := 'bcd151073c03b352e1ef2fd66c32209da9ca0afa';

  //�I�t�Z�b�g��+1����̂��������悤��
  strA := Copy(strA,keyoffset+1,keylength);
  SSLKey := EncodeBase64(strA);

  writeln('SSL token: ' + SSLToken);
  writeln('keyoffset: ' + IntToStr(keyoffset));
  writeln('keylength: ' + IntToStr(keylength));
  writeln('SSL Key: ' + SSLKey);

  //�X�e�b�v�T SSL�F�؂���������

  //20201212 ���N�G�X�g�w�b�_��radikoJSPlayer.js �̒�`���Q�l�ɂȂ���

  strA := '-q --user-agent="' + TEISU_USERAGENT + '"';
  strA := strA + ' --header="X-Radiko-App: pc_html5" --header="X-Radiko-App-Version: 0.0.1"';
  strA := strA + ' --header="X-Radiko-AuthToken: ' + SSLToken + '"';
  strA := strA + ' --header="X-Radiko-PartialKey: ' + SSLKey + '"';
  strA := strA + ' --header="X-Radiko-User: dummy_user"';
  strA := strA + ' --header="X-Radiko-Device: pc"';
  strA := strA + ' --post-data="\r\n"';
  strA := strA + ' --server-response --trust-server-names';

  //���� --server-response �ŁA�����F�؃G���[401�Ȃ�partialkey�ُ̈킪�킩��

  strA := strA + ' --no-check-certificate --save-headers -O auth2.txt ';
  strA := strA + TEISU_AUTH2;

  //���Ԃɂ��Ă���
  strList := TStringList.Create;
  strList.SaveToFile('auth2.txt');
  strList.Free;

  //�����҂�
  Application.ProcessMessages;

  //���g���C�J�E���^������
  intRetry := 0;

  myShellExecute(PChar('wget.exe'),PChar(strA));

  //�����҂�
  Sleep(500);
  Application.ProcessMessages;

  //SSL�̃t�@�C���������ɍ�ꂽ�����ׂ�

  FindFirst('auth2.txt', faAnyFile, srec);
  if (srec.Size < 8) then
  begin
      writeln('auth2.txt�̍쐬�Ɏ��s���܂���');

      Inc(intRetry);

      //�Q�񃊃g���C����
      if (intRetry > 2) then exit;

      writeln('���g���C���܂�');

      //���΂炭�ҋ@���ă��g���C
      Sleep(2000);
      Application.ProcessMessages;

      FindClose(srec.FindHandle);
      goto CHECK2;
  end;
  FindClose(srec.FindHandle);

  //�X�e�b�v�U ���ׂď��������A���悢�惉�W�R����_�E�����[�h

  //20200713 �^�C���t���[�^���̏ꍇ��ǉ�
  if (starttime <> '') then
  if (endtime <> '') then
      goto CHECK3;

  //�o�̓t�@�C����
  outputfilename := tuned_name + '_' + FormatDateTime('yyyymmdd_hhnnss',Now) + '.aac';

  //20210117 ���W�R��13���Ɏd�l�ύX����rtmpdump�ł͎��Ȃ��Ȃ���
  //Flash�T�|�[�g��2020�N�ŏI�������e���̂悤��
  //rtmpdump����Affmpeg��HLS�ʐM�ɕύX����K�v������

  //URL
  //strA := '/c start /low rtmpdump -r "rtmpe://203.211.199.180:1935"';
  //strA := strA + ' --playpath "simul-stream.stream" --app "' + tuned_name + '/_definst_"';
  //strA := strA + ' -W ' + TEISU_SWF + ' -C S:"" -C S:"" -C S:"" -C S:' + SSLToken;
  //strA := strA + ' --live --flv ' + outputfilename + ' --stop ' + IntToStr(rec_sec);

  strA := '/c start /low ffmpeg -headers "X-Radiko-AuthToken: ' + SSLToken + '"';
  strA := strA + ' -i "http://f-radiko.smartstream.ne.jp/' + tuned_name + '/_definst_/simul-stream.stream/playlist.m3u8"';
  strA := strA + ' -acodec copy';
  strA := strA + ' ' + outputfilename;

  //�����ҋ@
  Sleep(2000);

  myShellExecute(PChar('cmd.exe'),PChar(strA));

  //ffmpeg����邽�߂ɑҋ@����

  i := 0;
  repeat
    Sleep(1000);
    Inc(i);
  //ffmpeg�̋N����15�b�قǂ�����̂ő����Ă���
  //until (i > rec_sec);
  until (i > rec_sec +15);

  //ffmpeg�̃v���Z�X��T���āA����
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
            writeln('ffmpeg�𔭌��B���܂�');

            processID := tp.th32ProcessID;
            fdwAccess := PROCESS_ALL_ACCESS or PROCESS_VM_READ;
            hProcess  := OpenProcess(fdwAccess,False,processID);
            TerminateProcess(hProcess,0);
        end;
  end;

  CloseHandle(Snap);

  //debug
  //writeln('��ʂ���܂�');
  //readln(inputstr);

  exit;

CHECK3:


  //20210118 �^�C���t���[�ɑΉ�

  //debug
  writeln('�^�C���t���[�^�������܂�');

  strA := '/c start /low ffmpeg -headers "X-Radiko-AuthToken: ' + SSLToken + '"';
  strA := strA + ' -i "https://radiko.jp/v2/api/ts/playlist.m3u8';
  strA := strA + '?station_id=' + tuned_name + '&l=15';
  strA := strA + '&ft=' + starttime;
  strA := strA + '&to=' + endtime + '"';
  strA := strA + ' -acodec copy';

  //�o�̓t�@�C����
  outputfilename := tuned_name + '_' + starttime + '.aac';

  strA := strA + ' ' + outputfilename;

  //�����ҋ@
  Sleep(2000);

  myShellExecute(PChar('cmd.exe'),PChar(strA));


//���C�����[�`���I��-----------------------------------------
end.




