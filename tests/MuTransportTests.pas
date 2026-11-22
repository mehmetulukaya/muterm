unit MuTransportTests;

{

Interface segregation tests for command dependencies.

Each test constructs a command with a fake that implements only the
role the command needs. If a command ever reaches for the old fat
ICommandContext again, it cannot be constructed with these fakes, so
the compiler enforces the split.

}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpcunit, testregistry, MuCommands, MuTransport, testutils;

type
  TWaitRoleFake = class(TNoRefCountObject, IWaiter)
  public
    Seconds: Double;
    TcpSeconds: Double;
    CommSeconds: Double;
    procedure WaitSeconds(const ASeconds: Double);
    procedure WaitTcpSeconds(const ASeconds: Double);
    procedure WaitCommSeconds(const ASeconds: Double);
  end;

  TServerRoleFake = class(TNoRefCountObject, IServerChannel)
  public
    DisconnectCount: Integer;
    ListenCount: Integer;
    ClearCount: Integer;
    Sent: TStringList;
    BufferValue: string;
    Config: string;
    constructor Create;
    destructor Destroy; override;
    function ServerConnected: Boolean;
    procedure ServerListen;
    procedure ServerDisconnect;
    procedure SendServer(const Data: string);
    procedure ConfigureServer(const Port: string);
    function ServerBuffer: string;
    procedure ClearServerBuffer;
  end;

  TLogRoleFake = class(TNoRefCountObject, ICommandLog)
  public
    Lines: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure LogGeneral(const Text: string);
  end;

  TSerialRoleFake = class(TNoRefCountObject, ISerialChannel)
  public
    OpenCount: Integer;
    CloseCount: Integer;
    Active: Boolean;
    function SerialActive: Boolean;
    procedure SerialOpen;
    procedure SerialClose;
    procedure SendSerial(const Data: string);
    procedure ConfigureSerial(const Port, Baud, DataBits, Parity,
      StopBits: string);
    function SerialBuffer: string;
    procedure ClearSerialBuffer;
  end;

  THostRoleFake = class(TNoRefCountObject, IScriptHost)
  public
    MarkerLine: Integer;
    procedure SetMarker(const Line: Integer);
    function CanDispatch: Boolean;
    procedure SendDefaultLine(const Line: string);
  end;

  TMuTransportTests = class(TTestCase)
  published
    procedure TestWaitCommandNeedsOnlyWaiter;
    procedure TestEndIfCommandNeedsNoRole;
    procedure TestEndCommandNeedsOnlyLog;
    procedure TestServerDisconnectNeedsOnlyServer;
    procedure TestSerialOpenCloseNeedsSerialAndHost;
    procedure TestClearBufferUsesOnlySelectedChannel;
  end;

implementation

{ TWaitRoleFake }

procedure TWaitRoleFake.WaitSeconds(const ASeconds: Double);
begin
  Seconds := ASeconds;
end;

procedure TWaitRoleFake.WaitTcpSeconds(const ASeconds: Double);
begin
  TcpSeconds := ASeconds;
end;

procedure TWaitRoleFake.WaitCommSeconds(const ASeconds: Double);
begin
  CommSeconds := ASeconds;
end;

{ TServerRoleFake }

constructor TServerRoleFake.Create;
begin
  inherited Create;
  Sent := TStringList.Create;
end;

destructor TServerRoleFake.Destroy;
begin
  Sent.Free;
  inherited Destroy;
end;

function TServerRoleFake.ServerConnected: Boolean;
begin
  Result := False;
end;

procedure TServerRoleFake.ServerListen;
begin
  Inc(ListenCount);
end;

procedure TServerRoleFake.ServerDisconnect;
begin
  Inc(DisconnectCount);
end;

procedure TServerRoleFake.SendServer(const Data: string);
begin
  Sent.Add(Data);
end;

procedure TServerRoleFake.ConfigureServer(const Port: string);
begin
  Config := Port;
end;

function TServerRoleFake.ServerBuffer: string;
begin
  Result := BufferValue;
end;

procedure TServerRoleFake.ClearServerBuffer;
begin
  Inc(ClearCount);
  BufferValue := '';
end;

{ TLogRoleFake }

constructor TLogRoleFake.Create;
begin
  inherited Create;
  Lines := TStringList.Create;
end;

destructor TLogRoleFake.Destroy;
begin
  Lines.Free;
  inherited Destroy;
end;

procedure TLogRoleFake.LogGeneral(const Text: string);
begin
  Lines.Add(Text);
end;

{ TSerialRoleFake }

function TSerialRoleFake.SerialActive: Boolean;
begin
  Result := Active;
end;

procedure TSerialRoleFake.SerialOpen;
begin
  Inc(OpenCount);
  Active := True;
end;

procedure TSerialRoleFake.SerialClose;
begin
  Inc(CloseCount);
  Active := False;
end;

procedure TSerialRoleFake.SendSerial(const Data: string);
begin
end;

procedure TSerialRoleFake.ConfigureSerial(const Port, Baud, DataBits, Parity,
  StopBits: string);
begin
end;

function TSerialRoleFake.SerialBuffer: string;
begin
  Result := '';
end;

procedure TSerialRoleFake.ClearSerialBuffer;
begin
end;

{ THostRoleFake }

procedure THostRoleFake.SetMarker(const Line: Integer);
begin
  MarkerLine := Line;
end;

function THostRoleFake.CanDispatch: Boolean;
begin
  Result := True;
end;

procedure THostRoleFake.SendDefaultLine(const Line: string);
begin
end;

{ TMuTransportTests }

procedure TMuTransportTests.TestWaitCommandNeedsOnlyWaiter;
var
  Fake: TWaitRoleFake;
  Cmd: TWaitCommand;
begin
  Fake := TWaitRoleFake.Create;
  Cmd := TWaitCommand.Create(':WAIT', wkSeconds, Fake);
  try
    AssertEquals(Ord(crNext), Ord(Cmd.Execute(nil, ':WAIT 0.25')));
    AssertEquals(0.25, Fake.Seconds, 1E-9);
    AssertEquals(0.0, Fake.TcpSeconds, 1E-9);
  finally
    Cmd.Free;
    Fake.Free;
  end;
end;

procedure TMuTransportTests.TestEndIfCommandNeedsNoRole;
var
  Cmd: TEndIfCommand;
begin
  Cmd := TEndIfCommand.Create(':ENDIF');
  try
    AssertEquals(Ord(crNext), Ord(Cmd.Execute(nil, ':ENDIF')));
  finally
    Cmd.Free;
  end;
end;

procedure TMuTransportTests.TestEndCommandNeedsOnlyLog;
var
  Log: TLogRoleFake;
  Cmd: TEndCommand;
begin
  Log := TLogRoleFake.Create;
  Cmd := TEndCommand.Create(':END', Log);
  try
    AssertEquals(Ord(crStop), Ord(Cmd.Execute(nil, ':END')));
    AssertEquals(1, Log.Lines.Count);
    AssertEquals('END. ', Log.Lines[0]);
  finally
    Cmd.Free;
    Log.Free;
  end;
end;

procedure TMuTransportTests.TestServerDisconnectNeedsOnlyServer;
var
  Server: TServerRoleFake;
  Cmd: TServerDisconnectCommand;
begin
  Server := TServerRoleFake.Create;
  Cmd := TServerDisconnectCommand.Create(':SRV_DISCONNECT', Server);
  try
    AssertEquals(Ord(crNext), Ord(Cmd.Execute(nil, ':SRV_DISCONNECT')));
    AssertEquals(1, Server.DisconnectCount);
  finally
    Cmd.Free;
    Server.Free;
  end;
end;

procedure TMuTransportTests.TestSerialOpenCloseNeedsSerialAndHost;
var
  Serial: TSerialRoleFake;
  Host: THostRoleFake;
  Cmd: TSerialOpenCloseCommand;
begin
  Serial := TSerialRoleFake.Create;
  Host := THostRoleFake.Create;
  Cmd := TSerialOpenCloseCommand.Create(':COMM_OPEN_CLOSE', Serial, Host);
  try
    { Inactive channel: opens it and does not need the engine marker. }
    AssertEquals(Ord(crNext), Ord(Cmd.Execute(nil, ':COMM_OPEN_CLOSE')));
    AssertEquals(1, Serial.OpenCount);
    AssertEquals(0, Serial.CloseCount);
  finally
    Cmd.Free;
    Host.Free;
    Serial.Free;
  end;
end;

procedure TMuTransportTests.TestClearBufferUsesOnlySelectedChannel;
var
  Server: TServerRoleFake;
  Cmd: TClearBufferCommand;
begin
  Server := TServerRoleFake.Create;
  Server.BufferValue := 'data';
  { Serial and TCP are nil on purpose: the server variant must not touch
    them, even though the constructor accepts all three channels. }
  Cmd := TClearBufferCommand.Create(':SRV_CLEAR_RCV_BUF', bkServer,
    nil, nil, Server);
  try
    AssertEquals(Ord(crNext), Ord(Cmd.Execute(nil, ':SRV_CLEAR_RCV_BUF')));
    AssertEquals(1, Server.ClearCount);
    AssertEquals('', Server.BufferValue);
  finally
    Cmd.Free;
    Server.Free;
  end;
end;

initialization
  RegisterTest(TMuTransportTests);

end.
