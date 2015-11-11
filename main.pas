{

MuTerm is a terminal software to communicate for devices like as Modbus or etc.
It use your Comm ports and Tcp Socket client.

It can be portable Windows or Linux. ( I tried on debian based Mint 32 Bit)

All rights reserved on me please don't use in commercial softwares.
Let's do it your self !

11.11.2015 Mehmet Ulukaya ( mehmetulukaya@gmail.com )

}
unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, SynHighlighterPas, SynEdit, SynCompletion,
  SynMemo, SynHighlighterAny,
  lNetComponents, uPSComponent, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, ComCtrls, Buttons, IniFiles, MuLibs, uPSR_std,
  uPSC_std, uPSR_stdctrls, uPSC_stdctrls, uPSR_forms, uPSC_forms, uPSC_graphics,
  uPSC_controls, uPSC_classes, uPSR_graphics, uPSR_controls, uPSR_classes,
  uPSCompiler, uPSRuntime, types, LCLType, CheckLst, EditBtn, Menus,

  StrUtils,

  lNet,
  SynaSer,
  LazSerial,
  uPSDebugger,

  SynGutterBase, SynEditMarks,  uPSUtils,
  uPSPreProcessor;

const
  EM_SCROLLCARET = $00B7;
  EM_LINEINDEX   = $00BB;

type

  { TfrmMain }

  TfrmMain = class(TForm)
    btn_Clear_Log: TButton;
    btn_Save_Log: TButton;
    btn_CommOpenClose: TButton;
    btn_Open_Log: TButton;
    btn_TcpOpenClose: TButton;
    btn_Compile: TBitBtn;
    btn_Open:    TBitBtn;
    btn_New:     TBitBtn;
    btn_Run:     TBitBtn;
    btn_Save:    TBitBtn;
    btn_Save_Settings: TButton;
    btn_Send:    TButton;
    chkRxDsrSensivity: TCheckBox;
    chkRxDtrEnable: TCheckBox;
    chkRxRtsEnable: TCheckBox;
    chkXonXoff: TCheckBox;
    chk_Hex:    TCheckBox;
    chk_SendSlowly: TCheckBox;
    // CiaCom1:    TComPort;
    cmb_Commands: TComboBox;
    cmb_TextCommands: TComboBox;
    cmb_CommBaud: TComboBox;
    cmb_CommDataBit: TComboBox;
    cmb_CommParity: TComboBox;
    cmb_CommPorts: TComboBox;
    cmb_CommStopBit: TComboBox;
    edt_TCP_Address: TEdit;
    edt_RxBuffSize: TEdit;
    edt_SendSleeper: TEdit;
    edt_TCP_Port: TEdit;
    edt_TxBuffSize: TEdit;
    file_Font: TFileNameEdit;
    file_Logs: TFileNameEdit;
    FontDialog1: TFontDialog;
    GroupBox1:  TGroupBox;
    ImageList1: TImageList;
    Label1: TLabel;
    Label10: TLabel;
    Label11: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    CiaCom1: TLazSerial;
    ListBox1:   TListBox;
    ListBox2: TListBox;
    LTCP_Port: TLTCPComponent;
    Memo2:      TMemo;
    mem_Send: TSynMemo;
    mem_General: TMemo;
    mem_Log1:   TMemo;
    mem_Log2:   TMemo;
    OpenDialog1: TOpenDialog;
    PageControl1: TPageControl;
    CommPage: TPageControl;
    Panel1:     TPanel;
    Panel2:     TPanel;
    Panel3: TPanel;
    pnl_TCP: TPanel;
    pnl_Left_All:     TPanel;
    Panel4: TPanel;
    pnl_Bottom: TPanel;
    pnl_Client: TPanel;
    pnl_Comm: TPanel;
    pnl_Left_Log: TPanel;
    pnl_Right_Log: TPanel;
    pnl_Top:    TPanel;
    pnl_Top_Bottom: TPanel;
    PSScript1:  TPSScript;
    SaveDialog1: TSaveDialog;
    SpeedButton1: TSpeedButton;
    Splitter1:  TSplitter;
    Splitter2:  TSplitter;
    Splitter3:  TSplitter;
    Splitter5:  TSplitter;
    Memo1: TSynMemo;
    SynAnySyn1: TSynAnySyn;
    SynPasSyn1: TSynPasSyn;
    TabSheet1:  TTabSheet;
    TabSheet2:  TTabSheet;
    tb_TCP: TTabSheet;
    tb_Rs232: TTabSheet;
    tmrGeneral: TTimer;
    procedure btn_Clear_LogClick(Sender: TObject);
    procedure btn_CommOpenCloseClick(Sender: TObject);
    procedure btn_CompileClick(Sender: TObject);
    procedure btn_NewClick(Sender: TObject);
    procedure btn_OpenClick(Sender: TObject);
    procedure btn_Open_LogClick(Sender: TObject);
    procedure btn_RunClick(Sender: TObject);
    procedure btn_SaveClick(Sender: TObject);
    procedure btn_Save_LogClick(Sender: TObject);
    procedure btn_Save_SettingsClick(Sender: TObject);
    procedure btn_SendClick(Sender: TObject);
    procedure btn_TcpOpenCloseClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure CiaCom1RxData(Sender: TObject);
    procedure cmb_CommandsExit(Sender: TObject);
    procedure cmb_CommandsKeyPress(Sender: TObject; var Key: char);
    procedure cmb_CommandsMouseLeave(Sender: TObject);
    procedure cmb_TextCommandsClick(Sender: TObject);
    procedure cmb_TextCommandsExit(Sender: TObject);
    procedure cmb_TextCommandsKeyPress(Sender: TObject; var Key: char);
    procedure cmb_TextCommandsMouseLeave(Sender: TObject);
    procedure edt_SendSleeperChange(Sender: TObject);
    procedure file_FontAcceptFileName(Sender: TObject; var Value: String);
    procedure file_LogsAcceptFileName(Sender: TObject; var Value: String);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Label2Click(Sender: TObject);
    procedure ListBox1DblClick(Sender: TObject);
    procedure LTCP_PortAccept(aSocket: TLSocket);
    procedure LTCP_PortConnect(aSocket: TLSocket);
    procedure LTCP_PortDisconnect(aSocket: TLSocket);
    procedure LTCP_PortError(const msg: string; aSocket: TLSocket);
    procedure LTCP_PortReceive(aSocket: TLSocket);
    procedure Memo1KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Memo1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure MemoxChange(Sender: TObject);
    procedure mem_SendDblClick(Sender: TObject);

    procedure mem_SendGutterClick(Sender: TObject; X, Y, Line: integer;
      mark: TSynEditMark);
    procedure mem_SendKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState
      );
    procedure mem_SendMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);

    procedure PSScript1Compile(Sender: TPSScript);
    procedure PSScript1CompImport(Sender: TObject; x: TPSPascalCompiler);
    procedure PSScript1ExecImport(Sender: TObject; se: TPSExec;
      x: TPSRuntimeClassImporter);
    procedure PSScript1Execute(Sender: TPSScript);
    procedure SpeedButton1Click(Sender: TObject);
    procedure tmrGeneralTimer(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
    procedure LogAdd(LogWindow: TMemo; s: string);
    procedure LogAddStr(LogWindow: TMemo; s: string);
    procedure LoadConfig;
    procedure CiaCom1_WriteStr(s: string);
    procedure LTCP_Port_SendMessage(s: string);

    procedure GetMemoRowCol(M: TMemo; var Row, Col: longint);
    procedure SetMemoRowCol(M: TMemo; Row, Col: integer);

    procedure PS_Compile(script: string);
    function FindFile(dir, filter: string): TStringList;
    procedure LoadFont(font_name:string);
    procedure RemoveFont(font_name:string);

    procedure AppException(Sender: TObject; E: Exception);

    { TODO 1 -oMU -cDevelop : StrToBaudRate and other port functions must be develop for MuTerm }
    function StrToBaudRate(baud_str:string):TBaudRate;
    function StrToDataBits(data_bits:string):TDataBits;
    function StrToParity(parity_str:string):TParity;
    function StrToStopBits(stop_bits:string):TStopBits;
    procedure EnumComPorts(lst:TStrings);

    // procedure PsOnLine(Sender: TPSDebugExec; const Name: tbtstring; Position, Row, Col: Cardinal);

  end;

var
  frmMain:   TfrmMain;
  ayar:      TIniFile;
  tcp_some,
  com_some, send_s, apppath: string;
  be_send_slow: boolean;
  be_mem_dblclk: boolean;
  snd_cnt:   integer;
  waiter:    TDateTime;
  waiter_tcp:    TDateTime;
  wait_tcp: boolean;
  wait_comm: boolean;
  mem_changed: boolean;
  scp_compiled: boolean;

  lstScript : TStringList;
  versionnum : string;
  font_handle : THANDLE;

  marker : TSynEditMark;

implementation

{$R *.lfm}

{ TfrmMain }

 // --------------------------------------------------------------------
 // script functions
procedure _formatfloat(const frmt: string; const number: extended;var res:string);
begin
  DecimalSeparator := '.';     // for float convertion
  ThousandSeparator := ',';
  Res := FormatFloat(frmt, number);
  DecimalSeparator := ',';     // for float convertion
  ThousandSeparator := '.';
end;

procedure log_add(const LogWin, s: string);
begin
  with frmMain do
    LogAdd(TMemo(FindComponent(LogWin)), s);
end;

procedure x_ViewBits(val, siz: smallint;var res:string);
begin
  Res := ViewBits(val, siz);
end;

function x_HexToByte(Hex: string): integer;
begin
  Result := HexToByte(hex);
end;

procedure x_IntToHex(Hex: integer;var res:string);
begin
  Res := IntToHex(hex, 4);
end;

procedure x_HexToStr(hex: string;var res:string);
begin
  Res := HexToStr(hex);
end;

procedure x_StrToHex(Data: string;var res:string);
begin
  Res := StrToHex(Data);
end;

procedure x_CalcFCS(ABuf: string; ABufSize: cardinal;var res:string);
begin
  Res := IntToHex(CalcFCS(Abuf, ABufSize), 4);
end;

function x_bcc(const s: string; const index, Count: integer): byte;
var
  i: integer;
begin
  //Result :=0;
  for i := index to Count do
    Result := Result xor Ord(s[i]);
end;

procedure x_CRC16(Data: String;var Res:String);
begin
  Res := CRC16(Data);
end;

procedure x_CRC16_(Data: String;var Res:String);
begin
  Res := CRC16_(Data);
end;

function cia_open_com(const com_str: string): boolean;
var
  com_name:   string;
  com_baud:   integer;
  com_byte:   integer;
  com_stop:   byte;
  com_parity: string;
begin
  // cia_open_com('COM1,19200,8,N,1');
  com_name   := GetNStr(com_str, 1, ',');
  com_baud   := StrToInt(GetNStr(com_str, 2, ','));
  com_byte   := StrToInt(GetNStr(com_str, 3, ','));
  com_stop   := StrToInt(GetNStr(com_str, 5, ','));
  com_parity := GetNStr(com_str, 4, ',');

  with frmMain do
    with CiaCom1 do
    begin
      if com_name = '' then
        Device := cmb_CommPorts.Text
      else
        Device := com_name;


      Baudrate := StrToBaudRate(GetNStr(com_str, 2, ','));
      DataBits := StrToDataBits(GetNStr(com_str, 3, ','));


      {
      if StrToInt(edt_TxBuffSize.Text) <> integer(Buffer.OutputSize) then
        Buffer.OutputSize := StrToInt(edt_TxBuffSize.Text);

      if StrToInt(edt_RxBuffSize.Text) <> integer(Buffer.InputSize) then
        Buffer.InputSize := StrToInt(edt_RxBuffSize.Text);
       }

      case com_stop of
        1: StopBits := sbOne;
        2: StopBits := sbOneAndHalf;
        3: StopBits := sbTwo;
      end;

      Parity := pNone;
      case char(com_parity[1]) of
        'N': Parity := pNone;
        'O': Parity := pOdd;
        'E': Parity := pEven;
        'M': Parity := pMark;
        'S': Parity := pSpace;
      end;

      if (frmMain.chkRxDtrEnable.Checked) or
         (frmMain.chkRxRtsEnable.Checked) or
         (frmMain.chkRxDsrSensivity.Checked) then
        FlowControl := fcHardware
      else
        FlowControl := fcNone;

      if frmMain.chkXonXoff.Checked then
      begin
        FlowControl  := fcXonXoff;
      end
      else
      begin
        FlowControl  := fcNone;
      end;

      try
        CiaCom1.Open;
      except
        Result := False;
        exit;
      end;

      if CiaCom1.Active then
      begin
        //btn_CommOpenClose.Caption := 'Comm Close';
        LogAdd(mem_General, 'COM: Opened... ');
      end
      else
        LogAdd(mem_General, 'COM: Did`t open... ');

      Result := CiaCom1.Active;
    end; //with CiaCom1 do
end;

procedure cia_recv_com(var res:string);
begin
  if com_some<>'' then
    res := com_some;
end;


procedure cia_close_com;
begin
  with frmMain do
    with CiaCom1 do
      Close;
end;

procedure cia_clear_rcv;
begin
  com_some := '';
end;


procedure cia_send_com(const s: string);
begin
  with frmMain do
    with CiaCom1 do
      WriteData(s);
end;


function tcp_connect(const tcp_addr: string;const tcp_port:word): boolean;
begin
  result := false;
  with frmMain do
  begin
    result := LTCP_Port.Connect(tcp_addr,tcp_port);
  end;
end;

procedure tcp_disconnect;
begin
  with frmMain do
  begin
    LTCP_Port.Disconnect;
  end;
end;

procedure tcp_sendmessage(const s: string);
begin
  with frmMain do
  begin
    LTCP_Port_SendMessage(s);
  end;
end;

procedure tcp_recvmessage(var res: string);
begin
  with frmMain do
  begin
    res := tcp_some;
  end;
end;

procedure tcp_clearrcv;
begin
  tcp_some := '';
end;

procedure _formatdatetime(s: string; t: double;var res:string);
begin
  Res := FormatDateTime(s, t);
end;

function _now: double;
begin
  Result := now;
end;

procedure _sleep(const ms: double);
begin
  repeat
    application.ProcessMessages;
  until now > ms;
end;

procedure _showmessage(const s: string);
begin
  ShowMessage(s);
end;


function GetFormObj(const formname: string): TComponent;
begin
  try
    Result := Application.FindComponent(formname);
  except
    Result := nil;
  end;
end;


function _strtodatetime(const s: string): double;
begin
  Result := StrToDateTime(s);
end;

// --------------------------------------------------------------------


procedure TfrmMain.GetMemoRowCol(M: TMemo; var Row, Col: longint);
begin
  // Row := SendMessage(M.Handle, EM_LINEFROMCHAR, M.SelStart, 0);
  // Col := M.SelStart - SendMessage(M.Handle, EM_LINEINDEX, Row, 0);
end;

procedure TfrmMain.SetMemoRowCol(M: TMemo; Row, Col: integer);
begin
  // M.SelStart := SendMessage(M.Handle, EM_LINEINDEX, Row, 0) + Col;
end;

procedure TfrmMain.PS_Compile(script: string);

  procedure OutputMessages;
  var
    l: longint;
    b: boolean;
  begin
    b := False;
    for l := 0 to PSScript1.CompilerMessageCount - 1 do
    begin
      Memo2.Lines.Add('Compiler: ' + PSScript1.CompilerErrorToStr(l));
      if (not b) and (PSScript1.CompilerMessages[l] is TIFPSPascalCompilerError) then
      begin
        b := True;
        Memo1.SelStart := PSScript1.CompilerMessages[l].Pos;
        Memo1.SelEnd := length(Memo1.Lines.Strings[l]);
        Memo1.SetFocus;
      end;
    end;
  end;

begin
  if (script <> '') and (pos('begin', script) > 0) and (pos('end', script) > 0) then
  begin
    Memo2.Lines.Clear;
    PSScript1.Script.Assign(Memo1.Lines);
    Memo2.Lines.Add('Compiling...');
    if PSScript1.Compile then
    begin
      OutputMessages;
      Memo2.Lines.Add('Compiled succesfully');
      scp_compiled:=true;
    end
    else
    begin
      OutputMessages;
      Memo2.Lines.Add('Compiling failed');
      scp_compiled:=false;
    end;
  end;

end;


// Recursive procedure to build a list of files
procedure FindFiles(FilesList: TStringList; StartDir, FileMask: string);
var
  SR: TSearchRec;
  DirList: TStringList;
  IsFound: boolean;
  i: integer;
begin
  if StartDir[length(StartDir)] <> '\' then
    StartDir := StartDir + '\';

  { Build a list of the files in directory StartDir
     (not the directories!)                         }

  IsFound := FindFirst(StartDir + FileMask, faAnyFile - faDirectory, SR) = 0;
  while IsFound do
  begin
    FilesList.Add({StartDir + }SR.Name);
    IsFound := FindNext(SR) = 0;
  end;
  SysUtils.FindClose(SR);

  // Build a list of subdirectories
  DirList := TStringList.Create;
  IsFound := FindFirst(StartDir + '*.*', faAnyFile, SR) = 0;
  while IsFound do
  begin
    if ((SR.Attr and faDirectory) <> 0) and (SR.Name[1] <> '.') then
      DirList.Add(StartDir + SR.Name);
    IsFound := FindNext(SR) = 0;
  end;
  SysUtils.FindClose(SR);

  // Scan the list of subdirectories
  for i := 0 to DirList.Count - 1 do
    FindFiles(FilesList, DirList[i], FileMask);

  DirList.Free;
end;


function TfrmMain.FindFile(dir, filter: string): TStringList;
var
  FilesList: TStringList;
begin
  FilesList := TStringList.Create;
  try
    FindFiles(FilesList, apppath + '\' + dir + '\', filter);
  finally
    Result := FilesList;
    //FilesList.Free;
  end;
end;

procedure TfrmMain.LoadFont(font_name: string);
begin
  {try
    RemoveFont(font_name);
    AddFontResource(Pchar(font_name)) ;
    SendMessage(HWND_BROADCAST, WM_FONTCHANGE, 0, 0) ;
  except
  end;}
end;

procedure TfrmMain.RemoveFont(font_name: string);
begin
  {RemoveFontResource(Pchar(font_name)) ;
  SendMessage(HWND_BROADCAST, WM_FONTCHANGE, 0, 0) ;}
end;

procedure TfrmMain.AppException(Sender: TObject; E: Exception);
begin
  LogAdd(mem_General,'INF: Exception: '+Sender.ClassName+' Mes:'+E.Message);
end;

function TfrmMain.StrToBaudRate(baud_str: string): TBaudRate;
const
  ConstBaud: array[0..17] of integer=(110,
    300, 600, 1200, 2400, 4800, 9600,14400, 19200, 38400,56000, 57600,
    115200,128000,230400,256000, 460800, 921600);
var
   baud : integer;
   n : integer;
begin
  try
    baud := StrToInt( baud_str );
    for n:= Low(ConstBaud) to High(ConstBaud) do
      begin
        if ConstBaud[n]=baud then
          begin
            result := TBaudRate(n);
            break;
          end;
      end;
  except
    result := br__9600;
  end;
end;

function TfrmMain.StrToDataBits(data_bits: string): TDataBits;
const
  ConstBits: array[0..3] of integer=(8, 7 , 6, 5);
var
   bits : integer;
   n : integer;
begin
  try
    bits := StrToInt( data_bits );
    for n:= Low(ConstBits) to High(ConstBits) do
      begin
        if ConstBits[n]=bits then
          begin
            result := TDataBits(n);
            break;
          end;
      end;
  except
    result := db8bits;
  end;
end;

function TfrmMain.StrToParity(parity_str: string): TParity;
const
  ConstParity: array[0..4] of char=('N', 'O', 'E', 'M', 'S');
var
   n : integer;
begin
  try
    for n:= Low(ConstParity) to High(ConstParity) do
      begin
        if ConstParity[n]=parity_str[1] then  // Even,None,Odd first char
          begin
            result := TParity(n);
            break;
          end;
      end;
  except
    result := pNone;
  end;
end;

function TfrmMain.StrToStopBits(stop_bits: string): TStopBits;
begin
  result := sbOne;
  case stop_bits of
    '1'   : result := sbOne;
    '1.5' : result := sbOneAndHalf;
    '2'   : result := sbTwo;
  end;
end;

procedure TfrmMain.EnumComPorts(lst:TStrings);
begin
  //
  lst.CommaText := GetSerialPortNames();
  lst.Insert(0,'');
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  { TODO 1 -oMU -cOptional : Version information must be cross method }
  // versionnum := 'Version: '+Sto_GetFmtFileVersion(Application.ExeName,'%d.%d.%d.%d');
  Application.Title := 'MU Terminal '+ versionnum;
  Application.OnException := @AppException;
  apppath := GetCurrentDir;
  OpenDialog1.InitialDir := apppath;
  SaveDialog1.InitialDir := apppath;
  Caption := Application.Title;
  lstScript := TStringList.Create;
  file_Font.InitialDir := apppath;
  file_Logs.InitialDir := apppath;

  marker := TSynEditMark.Create(mem_Send);
  marker.Visible := true;
  marker.ImageList := ImageList1;
  marker.ImageIndex:= 0;
  mem_Send.Marks.Add(marker);

end;

procedure TfrmMain.FormResize(Sender: TObject);
begin
  pnl_Left_Log.Width := ((Width - pnl_Comm.Width - 10) div 2);
end;

procedure TfrmMain.Button1Click(Sender: TObject);
begin
  EnumComPorts(cmb_CommPorts.Items);
end;


procedure TfrmMain.CiaCom1RxData(Sender: TObject);
var
  s : string;
begin
  //
   try
    s := CiaCom1.ReadData;
    if s <> '' then
    begin
      wait_comm := False;
      if com_some = '' then
      begin
        LogAdd(mem_Log1, 'RCV<: ' + s);
        LogAdd(mem_Log2, 'RCV<: ' + StrToHex(s));
      end
      else
      begin
        LogAddStr(mem_Log1, s);
        LogAddStr(mem_Log2, StrToHex(s));
      end;
      com_some := com_some + s;
    end;
  except
    // LogAdd(mem_General,'Exp : ' );
  end;

end;

procedure TfrmMain.cmb_CommandsExit(Sender: TObject);
begin
  cmb_Commands.Hide;
end;

procedure TfrmMain.cmb_CommandsKeyPress(Sender: TObject; var Key: char);
begin
  if key=#27 then
    begin
      cmb_Commands.Hide;
      Memo1.SetFocus;
    end;
  if key=#13 then
    begin
      Memo1.CaretX := Memo1.CaretX-1;
      Memo1.InsertTextAtCaret(cmb_Commands.Text);
      cmb_Commands.Hide;
      Memo1.SetFocus;
    end;
end;

procedure TfrmMain.cmb_CommandsMouseLeave(Sender: TObject);
begin
  cmb_Commands.Hide;
end;

procedure TfrmMain.cmb_TextCommandsClick(Sender: TObject);
begin
  mem_Send.CaretX := mem_Send.CaretX-1;
  mem_Send.InsertTextAtCaret(cmb_TextCommands.Text);
  cmb_TextCommands.Hide;
  mem_Send.SetFocus;
end;

procedure TfrmMain.cmb_TextCommandsExit(Sender: TObject);
begin
  cmb_TextCommands.Hide;
end;

procedure TfrmMain.cmb_TextCommandsKeyPress(Sender: TObject; var Key: char);
begin
  if key=#27 then
    begin
      cmb_TextCommands.Hide;
      mem_Send.SetFocus;
    end;
  if key=#13 then
    begin
      mem_Send.CaretX := mem_Send.CaretX-1;
      mem_Send.InsertTextAtCaret(cmb_TextCommands.Text);
      cmb_TextCommands.Hide;
      mem_Send.SetFocus;
    end;
end;

procedure TfrmMain.cmb_TextCommandsMouseLeave(Sender: TObject);
begin
  cmb_TextCommands.Hide;
end;



procedure TfrmMain.btn_CommOpenCloseClick(Sender: TObject);
begin
  if cmb_CommPorts.Text = '' then
    exit;

  if CiaCom1.Active then
  begin
    try
      CiaCom1.Close;
    finally
      btn_CommOpenClose.Caption := 'Comm Open';
      LogAdd(mem_General, 'COM: Closed! ');
    end;
  end
  else
  begin
    with CiaCom1 do
    begin

      Device     := cmb_CommPorts.Text;
      BaudRate := StrToBaudRate(cmb_CommBaud.Text);
      DataBits := StrToDataBits(cmb_CommDataBit.Text);


      {if StrToInt(edt_TxBuffSize.Text) <> integer(Buffer.OutputSize) then
        Buffer.OutputSize := StrToInt(edt_TxBuffSize.Text);

      if StrToInt(edt_RxBuffSize.Text) <> integer(Buffer.InputSize) then
        Buffer.InputSize := StrToInt(edt_RxBuffSize.Text);}

        case cmb_CommStopBit.ItemIndex  of
          1: StopBits := sbOne;
          2: StopBits := sbOneAndHalf;
          3: StopBits := sbTwo;
        end;

        case cmb_CommParity.ItemIndex of
          0: Parity := pNone;
          1: Parity := pOdd;
          2: Parity := pEven;
          3: Parity := pMark;
          4: Parity := pSpace;
        end;

        if (frmMain.chkRxDtrEnable.Checked) or
           (frmMain.chkRxRtsEnable.Checked) or
           (frmMain.chkRxDsrSensivity.Checked) then
          FlowControl := fcHardware
        else
          FlowControl := fcNone;

        if frmMain.chkXonXoff.Checked then
        begin
          FlowControl  := fcXonXoff;
        end
        else
        begin
          FlowControl  := fcNone;
        end;

        try
          CiaCom1.Open;
          btn_CommOpenClose.Caption := 'Comm Close';
        except
          exit;
        end;

        if CiaCom1.Active then
        begin
          //btn_CommOpenClose.Caption := 'Comm Close';
          LogAdd(mem_General, 'COM: Opened... ');
        end
        else
          LogAdd(mem_General, 'COM: Did`t open... ');

      end; //with CiaCom1 do

  end;

end;

procedure TfrmMain.btn_CompileClick(Sender: TObject);
begin
  PS_Compile(Memo1.Lines.Text);
end;

procedure TfrmMain.btn_NewClick(Sender: TObject);
begin
  if mem_changed then
  begin
    if Application.MessageBox(PChar('Script changed! Do you want to save?'),
      PChar(Application.Title), MB_YESNO) = idYes then
      btn_SaveClick(nil);
  end;
  Memo1.ClearAll;
  Memo1.SetFocus;
  mem_changed := False;
end;

procedure TfrmMain.btn_OpenClick(Sender: TObject);
begin
  if frmMain.OpenDialog1.Execute then
  begin
    frmMain.OpenDialog1.FileName := frmMain.OpenDialog1.FileName;
    lstScript.LoadFromFile(frmMain.OpenDialog1.FileName);
    Memo1.Lines := lstScript;
    //Memox.Lines.LoadFromFile(frmMain.OpenDialog1.FileName);
    mem_changed := False;
    btn_CompileClick(nil); // compile
  end;
end;

procedure TfrmMain.btn_Open_LogClick(Sender: TObject);
var
  lst : TStringList;
  ilk,son,n : integer;
begin
  if FileExists(file_Logs.FileName) then
    begin
      lst := TStringList.Create;
        lst.LoadFromFile(file_Logs.FileName);
        ilk := lst.IndexOf('[Send Information]');
        son := lst.IndexOf('[End Send Information]');
        mem_Send.Clear;
        for n:=ilk+2 to son-1 do
          mem_Send.Lines.Add(lst.Strings[n]);

        ilk := lst.IndexOf('[Text Log Information]');
        son := lst.IndexOf('[End Text Log Information]');
        mem_Log1.Clear;
        for n:=ilk+2 to son-1 do
          mem_Log1.Lines.Add(lst.Strings[n]);

        ilk := lst.IndexOf('[Hex Log Information]');
        son := lst.IndexOf('[End Hex Log Information]');
        mem_Log2.Clear;
        for n:=ilk+2 to son-1 do
          mem_Log2.Lines.Add(lst.Strings[n]);

        ilk := lst.IndexOf('[General Log Information]');
        son := lst.IndexOf('[End General Log Information]');
        mem_General.Clear;
        for n:=ilk+2 to son-1 do
          mem_General.Lines.Add(lst.Strings[n]);

      lst.Free;
    end;
end;

procedure TfrmMain.btn_RunClick(Sender: TObject);
begin
  btn_CompileClick(nil);
  PageControl1.ActivePageIndex := 0;
  // PSScript1.Exec.Run;
  PSScript1.Execute;
  Memo2.Lines.Add('Executed...');
end;

procedure TfrmMain.btn_SaveClick(Sender: TObject);
var
  fname: string;
begin
  fname := frmMain.SaveDialog1.FileName;
  if fname = '' then
    if frmMain.SaveDialog1.Execute then
      fname := frmMain.SaveDialog1.FileName;

  if fname = '' then
    exit;

  Memo1.Lines.SaveToFile(fname);
  mem_changed := False;
  btn_CompileClick(nil); // compile
  Memo2.Lines.Add('Saved...');
  ListBox1.Items := FindFile('','*.scp');
end;

procedure TfrmMain.btn_Save_LogClick(Sender: TObject);
var
  lst : TStringList;
begin
  SetCurrentDir(apppath);
  lst := TStringList.Create;
    lst.Add('Report generated on '+ FormatDateTime('dd.MM.yyyy hh:nn:ss',now));
    lst.Add('');
    lst.Add('[Send Information]');
    lst.Add('');
    lst.AddStrings(mem_Send.Lines);
    lst.Add('[End Send Information]');
    lst.Add('');
    lst.Add('[Text Log Information]');
    lst.Add('');
    lst.AddStrings(mem_Log1.Lines);
    lst.Add('[End Text Log Information]');
    lst.Add('');
    lst.Add('[Hex Log Information]');
    lst.Add('');
    lst.AddStrings(mem_Log2.Lines);
    lst.Add('[End Hex Log Information]');
    lst.Add('');
    lst.Add('[General Log Information]');
    lst.Add('');
    lst.AddStrings(mem_General.Lines);
    lst.Add('[End General Log Information]');
    lst.SaveToFile(file_Logs.FileName);
  lst.Free;

end;

procedure TfrmMain.btn_Clear_LogClick(Sender: TObject);
begin
  mem_Log1.Lines.Clear;
  mem_Log2.Lines.Clear;
  mem_General.Clear;
end;

procedure TfrmMain.btn_Save_SettingsClick(Sender: TObject);
var
  ayar: TIniFile;
begin
  ayar := TIniFile.Create(apppath + '\' + 'ayar.ini');

  ayar.WriteInteger('COMM', 'cmb_CommPorts.ItemIndex', cmb_CommPorts.ItemIndex);
  ayar.WriteInteger('COMM', 'cmb_CommBaud.ItemIndex', cmb_CommBaud.ItemIndex);
  ayar.WriteInteger('COMM', 'cmb_CommDataBit.ItemIndex', cmb_CommDataBit.ItemIndex);
  ayar.WriteInteger('COMM', 'cmb_CommParity.ItemIndex', cmb_CommParity.ItemIndex);
  ayar.WriteInteger('COMM', 'cmb_CommStopBit.ItemIndex', cmb_CommStopBit.ItemIndex);
  ayar.WriteBool('COMM', 'chkRxDsrSensivity.Checked', chkRxDsrSensivity.Checked);
  ayar.WriteBool('COMM', 'chkRxRtsEnable.Checked', chkRxRtsEnable.Checked);
  ayar.WriteBool('COMM', 'chkRxDtrEnable.Checked', chkRxDtrEnable.Checked);
  ayar.WriteBool('COMM', 'chkXonXoff.Checked', chkXonXoff.Checked);

  ayar.WriteBool('COMM', 'chk_Hex.Checked', chk_Hex.Checked);
  //ayar.WriteBool('COMM','chk_ByScript.Checked',chk_ByScript.Checked);
  ayar.WriteBool('COMM', 'chk_SendSlowly.Checked', chk_SendSlowly.Checked);
  ayar.WriteString('COMM', 'edt_TxBuffSize.Text', edt_TxBuffSize.Text);
  ayar.WriteString('COMM', 'edt_RxBuffSize.Text', edt_RxBuffSize.Text);
  ayar.WriteString('COMM', 'edt_SendSleeper.Text', edt_SendSleeper.Text);
  ayar.WriteString('COMM', 'file_Font.FileName', file_Font.FileName);
  ayar.WriteInteger('COMM', 'FontDialog1.Font.Size', FontDialog1.Font.Size);
  ayar.WriteInteger('COMM', 'FontDialog1.Font.Color', FontDialog1.Font.Color);

  ayar.WriteString('TCP', 'edt_TCP_Address.Text', edt_TCP_Address.Text);
  ayar.WriteString('TCP', 'edt_TCP_Port.Text', edt_TCP_Port.Text);

  ayar.Free;

  if mem_Send.Text <> '' then
    mem_Send.Lines.SaveToFile(apppath + '\' + 'mem_Send.Text');
end;

procedure TfrmMain.btn_SendClick(Sender: TObject);
begin
  if (LTCP_Port.Connected) or (CiaCom1.Active) or (mem_Send.Lines.Count>1)  then
  begin
    if not chk_SendSlowly.Checked then
      if chk_Hex.Checked then
        send_s := HexToStr(mem_Send.Text)
      else
        send_s := mem_Send.Text;

    if not chk_SendSlowly.Checked then
    begin

      if CiaCom1.Active then
        CiaCom1_WriteStr(send_s);

      if LTCP_Port.Connected then
        LTCP_Port_SendMessage(send_s);

    end
    else
    begin
      be_send_slow := True;      // will use in timer
      snd_cnt      := -1;
    end;
  end;
end;

procedure TfrmMain.btn_TcpOpenCloseClick(Sender: TObject);
begin
  if edt_TCP_Address.Text='' then exit;

  if LTCP_Port.Connected then
    begin
      LTCP_Port.Disconnect;
      btn_TcpOpenClose.Caption := 'TCP Open';
      LogAdd(mem_General,'TCP Disconnected : '+LTCP_Port.Host);
      exit;
    end
    else
    if not LTCP_Port.Connected then
      if LTCP_Port.Connect(edt_TCP_Address.Text,StrToInt(edt_TCP_Port.Text)) then
        begin
          if LTCP_Port.Connected then
            btn_TcpOpenClose.Caption := 'TCP Close'
            else
              exit;
        end;

end;

procedure TfrmMain.edt_SendSleeperChange(Sender: TObject);
begin
  try
    tmrGeneral.Interval := StrToInt(edt_SendSleeper.Text);
  except
    tmrGeneral.Interval := 100;
  end;
end;

procedure TfrmMain.file_FontAcceptFileName(Sender: TObject; var Value: String);
var
  fn : string;
begin
  LoadFont(Value);
  fn := ExtractFileName( ExtractFileNameWithoutExt( Value ) );
  FontDialog1.Font.Name := fn;
  if FontDialog1.Execute then
    begin
      LogAdd(mem_General,FontDialog1.Font.Name);
      mem_Log1.Font := FontDialog1.Font;
      mem_Log2.Font := FontDialog1.Font;
    end;
end;

procedure TfrmMain.file_LogsAcceptFileName(Sender: TObject; var Value: String);
begin
  //
end;

procedure TfrmMain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if PSScript1.Running then
    PSScript1.Stop;
  if FileExists( file_Font.FileName ) then
    RemoveFont(file_Font.FileName);
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  PageControl1.ActivePageIndex := 0;
  Label2Click(nil);
  LoadConfig;
  ListBox1.Items := FindFile('','*.scp');
end;

procedure TfrmMain.Label2Click(Sender: TObject);
begin
  try
    EnumComPorts(cmb_CommPorts.Items);
  except
    LogAdd(mem_General,'Exception: Com port list error!');
  end;
end;

procedure TfrmMain.ListBox1DblClick(Sender: TObject);
begin
  frmMain.OpenDialog1.FileName := ListBox1.Items.Strings[ListBox1.ItemIndex];
  lstScript.LoadFromFile(frmMain.OpenDialog1.FileName);
  Memo1.Lines := lstScript;
  //Memox.Lines.LoadFromFile(frmMain.OpenDialog1.FileName);
  mem_changed := False;
  btn_CompileClick(nil); // compile
  PageControl1.ActivePageIndex := 0;
  if scp_compiled then
    PSScript1.Execute;
end;

procedure TfrmMain.LTCP_PortAccept(aSocket: TLSocket);
begin
  LogAdd(mem_General,'TCP Accepted: '+aSocket.LocalAddress);
end;

procedure TfrmMain.LTCP_PortConnect(aSocket: TLSocket);
begin
  LogAdd(mem_General,'TCP Connected: '+LTCP_Port.Host);
end;

procedure TfrmMain.LTCP_PortDisconnect(aSocket: TLSocket);
begin
  LogAdd(mem_General,'TCP Disconnected: '+LTCP_Port.Host);
end;

procedure TfrmMain.LTCP_PortError(const msg: string; aSocket: TLSocket);
begin
  LogAdd(mem_General,'TCP Error: '+msg);
end;

procedure TfrmMain.LTCP_PortReceive(aSocket: TLSocket);
var
  s: string;
  count : integer;
begin
  count :=  aSocket.GetMessage(s);
  if count>0 then
    begin
      wait_tcp := False;
      LTCP_Port.IterReset;
      if tcp_some = '' then
      begin
        LogAdd(mem_Log1, 'TCPRCV<: ' + s);
        LogAdd(mem_Log2, 'TCPRCV<: ' + StrToHex(s));
      end
      else
      begin
        LogAddStr(mem_Log1, s);
        LogAddStr(mem_Log2, StrToHex(s));
      end;
      tcp_some := tcp_some + s;
    end;
end;

procedure TfrmMain.Memo1KeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
    s:string;
begin
  if (ssCtrl in Shift) and (key=VK_SPACE) then
    begin
      with cmb_Commands do
      begin
        Parent := memo1;
        Left := Memo1.CaretXPix;
        Top := Memo1.CaretYPix;
        Show;
        DroppedDown := true;
        ItemIndex := 0;
        SetFocus;
      end;
    end;
end;

procedure TfrmMain.Memo1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  cmb_Commands.Hide;
end;

procedure TfrmMain.MemoxChange(Sender: TObject);
begin
  mem_changed := True;
end;

procedure TfrmMain.mem_SendDblClick(Sender: TObject);
begin
  be_mem_dblclk := true;
end;


procedure TfrmMain.mem_SendGutterClick(Sender: TObject; X, Y, Line: integer;
  mark: TSynEditMark);
begin
  // when double click send selected line
  snd_cnt := line-1;
  be_send_slow := true;
  // LogAdd(mem_General,'Manuel Send: '+inttostr(line)+' '+mem_Send.Lines.Strings[snd_cnt]);
end;

procedure TfrmMain.mem_SendKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
      s:string;
begin
  if (ssCtrl in Shift) and (key=VK_SPACE) then
    begin
      with cmb_TextCommands do
      begin
        Parent := mem_Send;
        Left := mem_Send.CaretXPix;
        Top := mem_Send.CaretYPix;
        Show;
        DroppedDown := true;
        ItemIndex := 0;
        SetFocus;
      end;
    end;

end;

procedure TfrmMain.mem_SendMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbRight then
    begin
      with cmb_TextCommands do
      begin
        Parent := mem_Send;
        Left := mem_Send.CaretXPix;
        Top := mem_Send.CaretYPix;
        Show;
        DroppedDown := true;
        ItemIndex := 0;
        SetFocus;
      end;
    end;
end;


procedure TfrmMain.PSScript1Compile(Sender: TPSScript);
begin

  Sender.AddFunction(@_sleep,               'procedure _sleep(ms:double);');
  Sender.AddFunction(@_now,                 'function _now:double;');
  Sender.AddFunction(@_formatdatetime,      'procedure _formatdatetime(s:string;t:double;var res:string);');
  Sender.AddFunction(@_showmessage,         'procedure _showmessage(s:string);');
  Sender.AddFunction(@_formatfloat,         'procedure _formatfloat(const frmt:string; const number:extended;var res:string);');
  Sender.AddFunction(@_strtodatetime,       'function _strtodatetime(const s:string):Double;');

  Sender.AddFunction(@cia_send_com,         'procedure cia_send_com(s:string);');
  Sender.AddFunction(@cia_recv_com,         'procedure cia_recv_com(var res:string);');
  Sender.AddFunction(@cia_open_com,         'function cia_open_com(const com_str:string):boolean;');
  Sender.AddFunction(@cia_close_com,        'procedure cia_close_com;');
  Sender.AddFunction(@cia_clear_rcv,        'procedure cia_clear_rcv;');

  Sender.AddFunction(@x_ViewBits,           'procedure x_ViewBits(val,siz:smallint;var res:string);');
  Sender.AddFunction(@x_IntToHex,           'procedure x_IntToHex(val:smallint;var res:string);');
  Sender.AddFunction(@x_HexToByte,          'procedure x_HexToByte(Hex:String):Integer;');
  Sender.AddFunction(@x_HexToStr,           'procedure x_HexToStr(hex:string;var res:string);');
  Sender.AddFunction(@x_StrToHex,           'procedure x_StrToHex(data:string;var res:string);');
  Sender.AddFunction(@x_CalcFCS,            'procedure x_CalcFCS(ABuf :string; ABufSize: Cardinal;var res:string);');
  Sender.AddFunction(@x_bcc,                'function x_bcc(const s: string; const index, count: integer): byte;');
  Sender.AddFunction(@x_CRC16,              'procedure x_CRC16(data:string;var res:string);');
  Sender.AddFunction(@x_CRC16_,             'procedure x_CRC16_(data:string;var res:string);');

  Sender.AddFunction(@log_add,              'procedure log_add(const LogWin,s:string);');
  Sender.AddFunction(@GetFormObj,           'function GetFormObj(const formname:string):TComponent;');

  Sender.AddFunction(@tcp_connect,          'function tcp_connect(const tcp_addr: string;const tcp_port:word): boolean;');
  Sender.AddFunction(@tcp_disconnect,       'procedure tcp_disconnect;');
  Sender.AddFunction(@tcp_sendmessage,      'procedure tcp_sendmessage(const s: string);');
  Sender.AddFunction(@tcp_recvmessage,      'procedure tcp_recvmessage(var res: string);');
  Sender.AddFunction(@tcp_clearrcv,         'procedure tcp_clearrcv;');


  Sender.AddRegisteredVariable('Application', 'TApplication');
  Sender.AddRegisteredVariable('Self', 'TForm');

end;

procedure TfrmMain.PSScript1CompImport(Sender: TObject; x: TPSPascalCompiler);
begin
  SIRegister_Std(x);
  SIRegister_Classes(x, True);
  SIRegister_Graphics(x, True);
  SIRegister_Controls(x);
  SIRegister_stdctrls(x);
  SIRegister_Forms(x);
end;

procedure TfrmMain.PSScript1ExecImport(Sender: TObject; se: TPSExec;
  x: TPSRuntimeClassImporter);
begin
  RIRegister_Std(x);
  RIRegister_Classes(x, True);
  RIRegister_Graphics(x, True);
  RIRegister_Controls(x);
  RIRegister_stdctrls(x);
  RIRegister_Forms(x);
end;

procedure TfrmMain.PSScript1Execute(Sender: TPSScript);
begin
  PSScript1.SetVarToInstance('APPLICATION', Application);
  PSScript1.SetVarToInstance('SELF', Self);
  LogAdd(mem_General,'Script Started!');
end;


procedure TfrmMain.SpeedButton1Click(Sender: TObject);
begin
  try
    EnumComPorts(cmb_CommPorts.Items);
  except
    LogAdd(mem_General,'Exception: Com port list error!');
  end;
  cmb_CommPorts.DroppedDown:=true;
end;

procedure TfrmMain.tmrGeneralTimer(Sender: TObject);
var
  n: integer;
  s: string;
  ps_par_start, ps_par_stop: integer;
begin


  // mem_Send.Gutter.MarksPart(0).DebugMarksImageIndex:=snd_cnt;
  // mem_Send.Marks.Line[snd_cnt];

  // Caption := inttostr( PSScript1.Exec.GetCurrentPosition );

  if (snd_cnt=-1) and (be_send_slow) then
    begin
      waiter_tcp := 0;
      waiter := 0;
      wait_comm := false;
      wait_tcp := false;
    end;

  if (waiter > now) or (wait_comm) then
    exit;

  if (waiter_tcp > now) or (wait_tcp) then
    exit;

  if be_send_slow then
    begin
      marker.Line := snd_cnt+2;
    end
    else
    begin
      marker.Line := 0;
    end;


  if (chk_SendSlowly.Checked) and (be_send_slow) then
  begin


    if (not be_mem_dblclk) then
      Inc(snd_cnt);

    if be_mem_dblclk then
      begin
        be_mem_dblclk := false;
        be_send_slow  := false;
        LogAdd(mem_General,'Manuel Send: '+inttostr(snd_cnt)+' '+mem_Send.Lines.Strings[snd_cnt]);
      end;

    if snd_cnt >= mem_Send.Lines.Count then
    begin
      send_s := '';
      be_send_slow := False;
      exit;
    end
    else
    if (CiaCom1.Active) or
       (LTCP_Port.Connected) or
       (mem_Send.Lines.Count>1) then
    begin

      if pos(':TCP_OPEN_CLOSE', mem_Send.Lines.Strings[snd_cnt]) > 0 then
      begin
        // btn_TcpOpenCloseClick(nil);
        if not LTCP_Port.Connected then
           begin
              try
                if LTCP_Port.Connect(LTCP_Port.Host,LTCP_Port.Port) then
                  begin
                    btn_TcpOpenClose.Caption := 'Tcp Close';
                    LogAdd(mem_General, 'TCP: Opened... ');
                  end;
              except
                LogAdd(mem_General, 'TCP: Did`t open... ');
              end;
           end
          else
          begin
            LTCP_Port.Disconnect;
            btn_TcpOpenClose.Caption := 'Tcp Open';
            LogAdd(mem_General, 'TCP: Closed! ');
          end;
        exit;
      end;

      //:TCP_SETUP(www.yahoo.com,80)
      if pos(':TCP_SETUP', mem_Send.Lines.Strings[snd_cnt]) > 0 then
      //vitality
      begin
        try
          ps_par_start := pos('(', mem_Send.Lines.Strings[snd_cnt]);
          ps_par_stop := pos(')', mem_Send.Lines.Strings[snd_cnt]);
          s := _copy(mem_Send.Lines.Strings[snd_cnt], ps_par_start + 1,ps_par_stop - 1);

          if (GetNStr(s, 1, ',') <> '') and (GetNStr(s, 2, ',') <> '') then
          begin
            LTCP_Port.Host :=GetNStr(s, 1, ',');
            edt_TCP_Address.Text:= LTCP_Port.Host;
            LTCP_Port.Port :=StrToInt( GetNStr(s, 2, ',') );
            edt_TCP_Port.Text:= GetNStr(s, 2, ',');
          end;
        except
        end;
        exit;
      end;
      //:WAIT_TCP 3.0
      if pos(':WAIT_TCP', mem_Send.Lines.Strings[snd_cnt]) > 0 then
      begin
        try
          s      := GetNStr(mem_Send.Lines.Strings[snd_cnt], 2, ' ');
          waiter_tcp := now + (((1 / 24) / 60) / 60 * strtofloat(s));
          wait_tcp := True;
          LogAdd(mem_General,'Float: '+FormatDateTime('hh:nn:ss',(waiter_tcp-now)) );
        except
          waiter_tcp := now;
        end;
        exit;
      end;
      //:TCP_SEND_HEX(01 03 02 00 00 02 )
      if pos(':TCP_SEND_HEX', mem_Send.Lines.Strings[snd_cnt]) > 0 then
      begin
        try
          s := GetNStr(mem_Send.Lines.Strings[snd_cnt], 2, '(');
          delete(s,pos(')',s),1);
          send_s := HexToStr(s);
          LTCP_Port_SendMessage(send_s);
        except
        end;
        exit;
      end;
      //:TCP_SEND_TEXT(GET /index.html HTTP/1.0 #013#010)
      if pos(':TCP_SEND_TEXT', mem_Send.Lines.Strings[snd_cnt]) > 0 then
      begin
        try
          s := GetNStr(mem_Send.Lines.Strings[snd_cnt], 2, '(');
          delete(s,pos(')',s),1);
          send_s := StrToText(s);
          LTCP_Port_SendMessage(send_s);
        except
        end;
        exit;
      end;

      // *************************************************************************************************
      if pos(':COMM_OPEN_CLOSE', mem_Send.Lines.Strings[snd_cnt]) > 0 then
      begin
        //btn_CommOpenCloseClick(nil);
        if not CiaCom1.Active then
           begin
              try
                CiaCom1.Open;
                btn_CommOpenClose.Caption := 'Comm Close';
                LogAdd(mem_General, 'COM: Opened... ');
              except
                LogAdd(mem_General, 'COM: Did`t open... ');
              end;
           end
          else
          begin
            try
              CiaCom1.Close;
              marker.Line := snd_cnt+1;

            finally
              btn_CommOpenClose.Caption := 'Comm Open';
              LogAdd(mem_General, 'COM: Closed! ');
            end;
          end;
        exit;
      end;
      //:COMM_SETUP(,9600,7,E,1)
      if pos(':COMM_SETUP', mem_Send.Lines.Strings[snd_cnt]) > 0 then
      begin
        try
          ps_par_start := pos('(', mem_Send.Lines.Strings[snd_cnt]);
          ps_par_stop := pos(')', mem_Send.Lines.Strings[snd_cnt]);
          s := copy(mem_Send.Lines.Strings[snd_cnt], ps_par_start + 1,
            ps_par_stop - 1);

          if GetNStr(s, 1, ',') <> '' then
          begin
            cmb_CommPorts.ItemIndex :=
              cmb_CommPorts.Items.IndexOf(GetNStr(s, 1, ','));
            //btn_CommOpenClose.Click;
            //btn_CommOpenClose.Click;
          end;
          try
            CiaCom1.BaudRate    := StrToBaudRate(GetNStr(s, 2, ','));
            CiaCom1.DataBits    := StrToDataBits(GetNStr(s, 3, ','));
            CiaCom1.Parity := StrToParity(GetNStr(s, 4, ','));
            CiaCom1.StopBits    := StrToStopBits(GetNStr(s, 5, ','));
          except
          end;

          //waiter := now + (((1/24)/60)/60* strtofloat( s ) );
        except
        end;
        exit;
      end;

      if pos(':END', mem_Send.Lines.Strings[snd_cnt]) > 0 then
      begin
        snd_cnt := mem_Send.Lines.Count+1;
        LogAdd(mem_General,'END. ');
        exit;
      end;

      if pos(':GOTO', mem_Send.Lines.Strings[snd_cnt]) > 0 then
      begin
        try
          s      := GetNStr(mem_Send.Lines.Strings[snd_cnt], 2, ' ');
          snd_cnt := strtoint(s)-1;
        except
          snd_cnt := snd_cnt;
        end;
        LogAdd(mem_General,'GOTO:> '+inttostr(snd_cnt));
        exit;
      end;

      if pos(':WAIT', mem_Send.Lines.Strings[snd_cnt]) > 0 then
      begin
        try
          s      := GetNStr(mem_Send.Lines.Strings[snd_cnt], 2, ' ');
          waiter := now + (((1 / 24) / 60) / 60 * strtofloat(s));
        except
          waiter := now;
        end;
        exit;
      end;
      if pos(':WAIT_COMM', mem_Send.Lines.Strings[snd_cnt]) > 0 then
      begin
        try
          wait_comm := True;
          s      := GetNStr(mem_Send.Lines.Strings[snd_cnt], 2, ' ');
          waiter := now + (((1 / 24) / 60) / 60 * strtofloat(s));
        except
          waiter := now;
        end;
        exit;
      end;

      if pos(':SEND_HEX_CRC', mem_Send.Lines.Strings[snd_cnt]) > 0 then
      begin
        try
          s := GetNStr(mem_Send.Lines.Strings[snd_cnt], 2, '(');
          delete(s,pos(')',s),1);
          send_s := HexToStr(s);
          send_s := send_s + CRC16(send_s);
          CiaCom1_WriteStr(send_s);
        except
        end;
        exit;
      end;

      if pos(':SEND_HEX', mem_Send.Lines.Strings[snd_cnt]) > 0 then
      begin
        try
          s := GetNStr(mem_Send.Lines.Strings[snd_cnt], 2, '(');
          delete(s,pos(')',s),1);
          send_s := HexToStr(s);
          CiaCom1_WriteStr(send_s);
        except
        end;
        exit;
      end;

      if pos(':SEND_TEXT', mem_Send.Lines.Strings[snd_cnt]) > 0 then
      begin
        try
          s := GetNStr(mem_Send.Lines.Strings[snd_cnt], 2, '(');
          delete(s,pos(')',s),1);
          send_s := StrToText(s);
          CiaCom1_WriteStr(send_s);
        except
        end;
        exit;
      end;

      if chk_Hex.Checked then
        send_s := HexToStr(mem_Send.Lines.Strings[snd_cnt])
      else
      begin
        send_s := mem_Send.Lines.Strings[snd_cnt];
      end;

      if CiaCom1.Active then
        CiaCom1_WriteStr(send_s);
      if LTCP_Port.Connected then
        LTCP_Port_SendMessage(send_s);
      //LogAdd(mem_Log1,'SND:> '+send_s);
      //LogAdd(mem_Log2,'SND:> '+StrToHex( send_s ) );
    end;
  end;
end;

procedure TfrmMain.LogAdd(LogWindow: TMemo; s: string);
begin
  LogWindow.Lines.Add(formatdatetime('dd.MM hh:nn:ss', now) + ' : ' + s);
end;

procedure TfrmMain.LogAddStr(LogWindow: TMemo; s: string);
var
  ps: integer;
begin
  ps := pos(#10, s);     // for memo component
  if ps>0 then
    Delete(s, ps, 1);
  LogWindow.Text := LogWindow.Text + s;
  SetMemoRowCol(LogWindow,
    LogWindow.Lines.Count - 1,
    length(LogWindow.Lines.Strings[LogWindow.Lines.Count - 1]));
  LogWindow.SetFocus;
end;

procedure TfrmMain.LoadConfig;
var
  ayar: TIniFile;
  fn : string;
begin
  ayar := TIniFile.Create(apppath + '\' + 'ayar.ini');

  cmb_CommPorts.ItemIndex := ayar.ReadInteger('COMM', 'cmb_CommPorts.ItemIndex', cmb_CommPorts.ItemIndex);
  cmb_CommBaud.ItemIndex := ayar.ReadInteger('COMM', 'cmb_CommBaud.ItemIndex', cmb_CommBaud.ItemIndex);
  cmb_CommDataBit.ItemIndex := ayar.ReadInteger('COMM', 'cmb_CommDataBit.ItemIndex', cmb_CommDataBit.ItemIndex);
  cmb_CommParity.ItemIndex := ayar.ReadInteger('COMM', 'cmb_CommParity.ItemIndex', cmb_CommParity.ItemIndex);
  cmb_CommStopBit.ItemIndex := ayar.ReadInteger('COMM', 'cmb_CommStopBit.ItemIndex', cmb_CommStopBit.ItemIndex);
  chkRxDsrSensivity.Checked := ayar.ReadBool('COMM', 'chkRxDsrSensivity.Checked', chkRxDsrSensivity.Checked);
  chkRxRtsEnable.Checked := ayar.ReadBool('COMM', 'chkRxRtsEnable.Checked', chkRxRtsEnable.Checked);
  chkRxDtrEnable.Checked := ayar.ReadBool('COMM', 'chkRxDtrEnable.Checked', chkRxDtrEnable.Checked);
  chkXonXoff.Checked := ayar.ReadBool('COMM', 'chkXonXoff.Checked', chkXonXoff.Checked);

  chk_Hex.Checked     := ayar.ReadBool('COMM', 'chk_Hex.Checked', chk_Hex.Checked);
  //chk_ByScript.Checked := ayar.ReadBool('COMM','chk_ByScript.Checked',chk_ByScript.Checked);
  chk_SendSlowly.Checked := ayar.ReadBool('COMM', 'chk_SendSlowly.Checked', chk_SendSlowly.Checked);
  edt_TxBuffSize.Text := ayar.ReadString('COMM', 'edt_TxBuffSize.Text', edt_TxBuffSize.Text);
  edt_RxBuffSize.Text := ayar.ReadString('COMM', 'edt_RxBuffSize.Text', edt_RxBuffSize.Text);

  edt_SendSleeper.Text := ayar.ReadString('COMM', 'edt_SendSleeper.Text', edt_SendSleeper.Text);
  file_Font.FileName := ayar.ReadString('COMM', 'file_Font.FileName', file_Font.FileName);

  edt_TCP_Address.Text := ayar.ReadString('TCP', 'edt_TCP_Address.Text', edt_TCP_Address.Text);
  edt_TCP_Port.Text := ayar.ReadString('TCP', 'edt_TCP_Port.Text', edt_TCP_Port.Text);

  if FileExists(apppath + '\' + 'mem_Send.Text') then
    mem_Send.Lines.LoadFromFile(apppath + '\' + 'mem_Send.Text');

  if FileExists( file_Font.FileName ) then
    begin
      LoadFont(file_Font.FileName);
      FontDialog1.Font.Size := ayar.ReadInteger('COMM', 'FontDialog1.Font.Size', FontDialog1.Font.Size);
      FontDialog1.Font.Color := ayar.ReadInteger('COMM', 'FontDialog1.Font.Color', FontDialog1.Font.Color);
      fn := ExtractFileName( ExtractFileNameWithoutExt( file_Font.FileName ) );
      FontDialog1.Font.Name := fn;

      mem_Log1.Font := FontDialog1.Font;
      mem_Log2.Font := FontDialog1.Font;
    end;

  ayar.Free;

  edt_SendSleeperChange(nil);
end;

procedure TfrmMain.CiaCom1_WriteStr(s: string);
begin
  if CiaCom1.Active then
  begin
    CiaCom1.WriteData(s);
    com_some := '';
    LogAdd(mem_Log1, 'SND>: ' + s);
    LogAdd(mem_Log2, 'SND>: ' + StrToHex(s));
  end;
end;

procedure TfrmMain.LTCP_Port_SendMessage(s: string);
begin
  if LTCP_Port.Connected then
    begin
      if LTCP_Port.SendMessage(s,LTCP_Port.Iterator)>0 then
        begin
          LogAdd(mem_Log1, 'TCPSND>: ' + s);
          LogAdd(mem_Log2, 'TCPSND>: ' + StrToHex(s));
        end;
    end;
end;


end.
