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

  { Generic client: this is what a WebSocket transport would implement. }
  TClientRoleFake = class(TNoRefCountObject, IClientChannel)
  public
    ConnectedValue: Boolean;
    ConnectCount: Integer;
    DisconnectCount: Integer;
    ClearCount: Integer;
    Sent: TStringList;
    BufferValue: string;
    EndpointValue: string;
    constructor Create;
    destructor Destroy; override;
    function Connected: Boolean;
    procedure Connect;
    procedure Disconnect;
    procedure Send(const Data: string);
    procedure Configure(const Endpoint: string);
    function Buffer: string;
    procedure ClearBuffer;
  end;

  { Legacy TCP role, used to prove the adapter translates TCP details. }
  TLegacyTcpRoleFake = class(TNoRefCountObject, ITcpChannel)
  public
    ConnectedValue: Boolean;
    ConnectCount: Integer;
    DisconnectCount: Integer;
    ClearCount: Integer;
    Sent: TStringList;
    BufferValue: string;
    Host: string;
    Port: string;
    constructor Create;
    destructor Destroy; override;
    function TcpConnected: Boolean;
    procedure TcpConnect;
    procedure TcpDisconnect;
    procedure SendTcp(const Data: string);
    procedure ConfigureTcp(const AHost, APort: string);
    function TcpBuffer: string;
    procedure ClearTcpBuffer;
  end;

  TMuTransportTests = class(TTestCase)
  published
    procedure TestWaitCommandNeedsOnlyWaiter;
    procedure TestEndIfCommandNeedsNoRole;
    procedure TestEndCommandNeedsOnlyLog;
    procedure TestServerDisconnectNeedsOnlyServer;
    procedure TestSerialOpenCloseNeedsSerialAndHost;
    procedure TestClearBufferUsesOnlySelectedChannel;
    procedure TestTcpClientChannelAdapter;
    procedure TestEngineRunsWithoutContext;
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

{ TClientRoleFake }

constructor TClientRoleFake.Create;
begin
  inherited Create;
  Sent := TStringList.Create;
end;

destructor TClientRoleFake.Destroy;
begin
  Sent.Free;
  inherited Destroy;
end;

function TClientRoleFake.Connected: Boolean;
begin
  Result := ConnectedValue;
end;

procedure TClientRoleFake.Connect;
begin
  Inc(ConnectCount);
  ConnectedValue := True;
end;

procedure TClientRoleFake.Disconnect;
begin
  Inc(DisconnectCount);
  ConnectedValue := False;
end;

procedure TClientRoleFake.Send(const Data: string);
begin
  Sent.Add(Data);
end;

procedure TClientRoleFake.Configure(const Endpoint: string);
begin
  EndpointValue := Endpoint;
end;

function TClientRoleFake.Buffer: string;
begin
  Result := BufferValue;
end;

procedure TClientRoleFake.ClearBuffer;
begin
  Inc(ClearCount);
  BufferValue := '';
end;

{ TLegacyTcpRoleFake }

constructor TLegacyTcpRoleFake.Create;
begin
  inherited Create;
  Sent := TStringList.Create;
end;

destructor TLegacyTcpRoleFake.Destroy;
begin
  Sent.Free;
  inherited Destroy;
end;

function TLegacyTcpRoleFake.TcpConnected: Boolean;
begin
  Result := ConnectedValue;
end;

procedure TLegacyTcpRoleFake.TcpConnect;
begin
  Inc(ConnectCount);
  ConnectedValue := True;
end;

procedure TLegacyTcpRoleFake.TcpDisconnect;
begin
  Inc(DisconnectCount);
  ConnectedValue := False;
end;

procedure TLegacyTcpRoleFake.SendTcp(const Data: string);
begin
  Sent.Add(Data);
end;

procedure TLegacyTcpRoleFake.ConfigureTcp(const AHost, APort: string);
begin
  Host := AHost;
  Port := APort;
end;

function TLegacyTcpRoleFake.TcpBuffer: string;
begin
  Result := BufferValue;
end;

procedure TLegacyTcpRoleFake.ClearTcpBuffer;
begin
  Inc(ClearCount);
  BufferValue := '';
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

procedure TMuTransportTests.TestTcpClientChannelAdapter;
var
  Legacy: TLegacyTcpRoleFake;
  Channel: IClientChannel;
begin
  Legacy := TLegacyTcpRoleFake.Create;
  Channel := TTcpClientChannel.Create(Legacy);
  try
    AssertFalse(Channel.Connected);
    Channel.Configure('example.com,502');
    AssertEquals('example.com', Legacy.Host);
    AssertEquals('502', Legacy.Port);

    Channel.Connect;
    Channel.Send('hello');
    Channel.Buffer;
    Channel.ClearBuffer;

    AssertTrue(Channel.Connected);
    AssertEquals(1, Legacy.ConnectCount);
    AssertEquals(0, Legacy.DisconnectCount);
    AssertEquals(1, Legacy.Sent.Count);
    AssertEquals('hello', Legacy.Sent[0]);
    AssertEquals(1, Legacy.ClearCount);

    Channel.Disconnect;
    AssertFalse(Channel.Connected);
    AssertEquals(1, Legacy.DisconnectCount);
  finally
    Channel := nil;
    Legacy.Free;
  end;
end;

procedure TMuTransportTests.TestEngineRunsWithoutContext;
var
  Source: TStringList;
  Log: TLogRoleFake;
  Host: THostRoleFake;
  Serial: TSerialRoleFake;
  Client: TClientRoleFake;
  Server: TServerRoleFake;
  Waiter: TWaitRoleFake;
  Engine: TCommandEngine;
  I: Integer;
begin
  Source := TStringList.Create;
  Log := TLogRoleFake.Create;
  Host := THostRoleFake.Create;
  Serial := TSerialRoleFake.Create;
  Client := TClientRoleFake.Create;
  Server := TServerRoleFake.Create;
  Waiter := TWaitRoleFake.Create;
  try
    Engine := TCommandEngine.CreateRoles(Source, Log, Host, Serial, Client,
      Server, Waiter, nil);
    try
      Engine.RegisterDefaults;
      Source.Add(':TCP_SETUP(example.com,502)');
      Source.Add(':TCP_SEND_TEXT(hello)');
      Source.Add(':TCP_RECV_TEXT');
      Source.Add(':END');

      Engine.Start;
      I := 0;
      while Engine.Running and (I < 100) do
      begin
        Engine.Tick;
        Inc(I);
      end;

      AssertFalse('Script should finish', Engine.Running);
      { The generic channel receives the raw endpoint text; only the
        TCP adapter knows how to split host and port. }
      AssertEquals('example.com,502', Client.EndpointValue);
      AssertEquals(1, Client.Sent.Count);
      AssertEquals('hello', Client.Sent[0]);
    finally
      Engine.Free;
    end;
  finally
    Waiter.Free;
    Server.Free;
    Client.Free;
    Serial.Free;
    Host.Free;
    Log.Free;
    Source.Free;
  end;
end;

initialization
  RegisterTest(TMuTransportTests);

end.
