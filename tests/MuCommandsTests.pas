unit MuCommandsTests;

{

Behaviour tests for the script command engine.

The engine is already decoupled from the UI through ICommandContext, so
these tests run headless with TFakeCommandContext. They document the
current :COMMAND / :SET / :IF / :GOTO semantics before the transport
refactoring starts.

}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpcunit, testregistry, MuCommands, MuTestContext;

type
  TMuCommandsTests = class(TTestCase)
  private
    FSource: TStringList;
    FFake: TFakeCommandContext;
    FEngine: TCommandEngine;
    procedure RunScript(const Lines: array of string;
      MaxTicks: Integer = 200);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSendText;
    procedure TestSendHex;
    procedure TestSendHexCrc;
    procedure TestSetAndExpand;
    procedure TestTcpSetup;
    procedure TestSerialSetup;
    procedure TestUnknownLineGoesToDefault;
    procedure TestIfTrueBranch;
    procedure TestIfFalseBranch;
    procedure TestSingleLineIfGoto;
    procedure TestGotoLabel;
    procedure TestEndStopsScript;
    procedure TestInvalidSetStops;
    procedure TestUnclosedIfStops;
    procedure TestTcpRecvText;
    procedure TestTcpWaitTextSuccess;
    procedure TestTcpWaitHexSuccess;
    procedure TestTcpWaitTimeout;
    procedure TestOpenCloseToggles;
    procedure TestServerCommands;
    procedure TestClearBuffers;
    procedure TestWaitCommands;
  end;

implementation

procedure TMuCommandsTests.SetUp;
begin
  inherited SetUp;
  FSource := TStringList.Create;
  FFake := TFakeCommandContext.Create;
  FEngine := TCommandEngine.Create(FSource, FFake);
  RegisterDefaultCommands(FEngine);
end;

procedure TMuCommandsTests.TearDown;
begin
  FEngine.Free;
  FFake.Free;
  FSource.Free;
  inherited TearDown;
end;

procedure TMuCommandsTests.RunScript(const Lines: array of string;
  MaxTicks: Integer);
var
  I: Integer;
begin
  FSource.Clear;
  for I := Low(Lines) to High(Lines) do
    FSource.Add(Lines[I]);
  FEngine.Start;
  I := 0;
  while FEngine.Running and (I < MaxTicks) do
  begin
    FEngine.Tick;
    Inc(I);
  end;
  AssertFalse('Script bitmedi (sonsuz dongu olabilir)', FEngine.Running);
end;

procedure TMuCommandsTests.TestSendText;
begin
  RunScript([':SEND_TEXT(Hello)']);
  AssertEquals(1, FFake.SerialData.Count);
  AssertEquals('Hello', FFake.SerialData[0]);
end;

procedure TMuCommandsTests.TestSendHex;
begin
  RunScript([':SEND_HEX(01 03)']);
  AssertEquals(1, FFake.SerialData.Count);
  AssertEquals(#$01#$03, FFake.SerialData[0]);
end;

procedure TMuCommandsTests.TestSendHexCrc;
var
  Data: string;
begin
  RunScript([':SEND_HEX_CRC(01 03 00 00 00 0A)']);
  AssertEquals(1, FFake.SerialData.Count);
  Data := FFake.SerialData[0];
  AssertEquals(8, Length(Data));
  AssertEquals(#$01#$03#$00#$00#$00#$0A, Copy(Data, 1, 6));
  AssertEquals(#$C5#$CD, Copy(Data, 7, 2));
end;

procedure TMuCommandsTests.TestSetAndExpand;
begin
  RunScript([':SET(name,World)', ':SEND_TEXT(Hello {name})']);
  AssertEquals(1, FFake.SerialData.Count);
  AssertEquals('Hello World', FFake.SerialData[0]);
end;

procedure TMuCommandsTests.TestTcpSetup;
begin
  RunScript([':TCP_SETUP(example.com,502)']);
  AssertEquals('example.com:502', FFake.TcpConfig);
end;

procedure TMuCommandsTests.TestSerialSetup;
begin
  RunScript([':COMM_SETUP(,9600,8,None,1)']);
  AssertEquals('|9600|8|None|1', FFake.SerialConfig);
end;

procedure TMuCommandsTests.TestUnknownLineGoesToDefault;
begin
  RunScript(['plain text line']);
  AssertEquals(1, FFake.DefaultLines.Count);
  AssertEquals('plain text line', FFake.DefaultLines[0]);
end;

procedure TMuCommandsTests.TestIfTrueBranch;
begin
  RunScript([
    ':SET(flag,1)',
    ':IF(flag=1)',
    ':SEND_TEXT(then)',
    ':ELSE',
    ':SEND_TEXT(else)',
    ':END IF']);
  AssertEquals(1, FFake.SerialData.Count);
  AssertEquals('then', FFake.SerialData[0]);
end;

procedure TMuCommandsTests.TestIfFalseBranch;
begin
  RunScript([
    ':SET(flag,0)',
    ':IF(flag=1)',
    ':SEND_TEXT(then)',
    ':ELSE',
    ':SEND_TEXT(else)',
    ':END IF']);
  AssertEquals(1, FFake.SerialData.Count);
  AssertEquals('else', FFake.SerialData[0]);
end;

procedure TMuCommandsTests.TestSingleLineIfGoto;
begin
  RunScript([
    ':IF(1=1) GOTO yes',
    ':SEND_TEXT(no)',
    ':LABEL yes',
    ':SEND_TEXT(yes)']);
  AssertEquals(1, FFake.SerialData.Count);
  AssertEquals('yes', FFake.SerialData[0]);
end;

procedure TMuCommandsTests.TestGotoLabel;
begin
  RunScript([
    ':GOTO done',
    ':SEND_TEXT(skip)',
    ':LABEL done',
    ':SEND_TEXT(ok)']);
  AssertEquals(1, FFake.SerialData.Count);
  AssertEquals('ok', FFake.SerialData[0]);
end;

procedure TMuCommandsTests.TestEndStopsScript;
begin
  RunScript([':SEND_TEXT(one)', ':END', ':SEND_TEXT(two)']);
  AssertEquals(1, FFake.SerialData.Count);
  AssertEquals('one', FFake.SerialData[0]);
end;

procedure TMuCommandsTests.TestInvalidSetStops;
begin
  RunScript([':SET(1bad,x)', ':SEND_TEXT(after)']);
  AssertEquals(0, FFake.SerialData.Count);
  AssertTrue('Gecersiz degisken icin log yok',
    Pos('gecersiz degisken', FFake.Logs.Text) > 0);
end;

procedure TMuCommandsTests.TestUnclosedIfStops;
begin
  FSource.Clear;
  FSource.Add(':IF(1=1)');
  FSource.Add(':SEND_TEXT(x)');
  FEngine.Start;
  AssertFalse('Kapatilmamis IF calismamali', FEngine.Running);
  AssertTrue('Yapisal hata loglanmali',
    Pos('kapatilmamis', FFake.Logs.Text) > 0);
  AssertEquals(0, FFake.SerialData.Count);
end;

procedure TMuCommandsTests.TestTcpRecvText;
begin
  FFake.TcpBufferValue := 'abc';
  RunScript([':TCP_RECV_TEXT(res)', ':SEND_TEXT({res})']);
  AssertEquals(1, FFake.SerialData.Count);
  AssertEquals('abc', FFake.SerialData[0]);
end;

procedure TMuCommandsTests.TestTcpWaitTextSuccess;
begin
  FFake.TcpBufferValue := 'OK';
  RunScript([':TCP_WAIT_FOR_TEXT(OK,1.0)', ':SEND_TEXT(done)']);
  AssertEquals('0', FEngine.GetVar('TIMEOUT'));
  AssertEquals(1, FFake.SerialData.Count);
  AssertEquals('done', FFake.SerialData[0]);
end;

procedure TMuCommandsTests.TestTcpWaitHexSuccess;
begin
  FFake.TcpBufferValue := #$01#$03#$04;
  RunScript([':TCP_WAIT_FOR_HEX(01 03,1.0)', ':SEND_TEXT(done)']);
  AssertEquals('0', FEngine.GetVar('TIMEOUT'));
  AssertEquals('done', FFake.SerialData[0]);
end;

procedure TMuCommandsTests.TestTcpWaitTimeout;
begin
  FSource.Clear;
  FSource.Add(':TCP_WAIT_FOR_TEXT(NEVER,0.01)');
  FEngine.Start;
  FEngine.Tick;       // starts the timeout window
  Sleep(50);
  FEngine.Tick;       // timeout expires and advances past the line
  AssertEquals('TIMEOUT degeri', '1', FEngine.GetVar('TIMEOUT'));
  FEngine.Tick;       // reaches the end of the source and stops
  AssertFalse('Zaman asimindan sonra betik durmali', FEngine.Running);
end;

procedure TMuCommandsTests.TestOpenCloseToggles;
begin
  RunScript([':TCP_OPEN_CLOSE', ':TCP_OPEN_CLOSE']);
  AssertEquals(1, FFake.ConnectCount);
  AssertEquals(1, FFake.DisconnectCount);

  RunScript([':COMM_OPEN_CLOSE', ':COMM_OPEN_CLOSE']);
  AssertEquals(1, FFake.OpenCount);
  AssertEquals(1, FFake.CloseCount);
end;

procedure TMuCommandsTests.TestServerCommands;
begin
  RunScript([
    ':SRV_SETUP(8080)',
    ':SRV_LISTEN',
    ':SRV_SEND_TEXT(hi)',
    ':SRV_DISCONNECT']);
  AssertEquals('8080', FFake.ServerConfig);
  AssertEquals(1, FFake.ListenCount);
  AssertEquals(1, FFake.ServerDisconnectCount);
  AssertEquals(1, FFake.ServerData.Count);
  AssertEquals('hi', FFake.ServerData[0]);
end;

procedure TMuCommandsTests.TestClearBuffers;
begin
  FFake.SerialBufferValue := 's';
  FFake.TcpBufferValue := 't';
  FFake.ServerBufferValue := 'v';
  RunScript([
    ':COM_CLEAR_RCV_BUF',
    ':TCP_CLEAR_RCV_BUF',
    ':SRV_CLEAR_RCV_BUF']);
  AssertEquals('', FFake.SerialBufferValue);
  AssertEquals('', FFake.TcpBufferValue);
  AssertEquals('', FFake.ServerBufferValue);
end;

procedure TMuCommandsTests.TestWaitCommands;
begin
  RunScript([':WAIT 0.5', ':WAIT_TCP 0.2', ':WAIT_COMM 1.5']);
  AssertEquals(0.5, FFake.WaitSecondsValue, 1E-9);
  AssertEquals(0.2, FFake.WaitTcpValue, 1E-9);
  AssertEquals(1.5, FFake.WaitCommValue, 1E-9);
end;

initialization
  RegisterTest(TMuCommandsTests);

end.
