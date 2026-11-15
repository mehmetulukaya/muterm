unit MuTestContext;

{

Test double for MuCommands.ICommandContext.

The command engine is UI-free, so tests can run it headless with this fake.
It records every operation instead of touching hardware, which makes the
tests deterministic and safe on CI machines without serial ports.

}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, MuCommands, testutils;

type
  { Non-reference-counted: the test owns the instance and frees it in TearDown. }
  TFakeCommandContext = class(TNoRefCountObject, ICommandContext)
  public
    Logs: TStringList;
    SerialData: TStringList;
    TcpData: TStringList;
    ServerData: TStringList;
    DefaultLines: TStringList;

    SerialBufferValue: string;
    TcpBufferValue: string;
    ServerBufferValue: string;

    SerialActiveValue: Boolean;
    TcpConnectedValue: Boolean;
    ServerConnectedValue: Boolean;

    SerialConfig: string;
    TcpConfig: string;
    ServerConfig: string;

    MarkerLine: Integer;
    CanDispatchValue: Boolean;

    WaitSecondsValue: Double;
    WaitTcpValue: Double;
    WaitCommValue: Double;

    OpenCount: Integer;
    CloseCount: Integer;
    ConnectCount: Integer;
    DisconnectCount: Integer;
    ListenCount: Integer;
    ServerDisconnectCount: Integer;

    constructor Create;
    destructor Destroy; override;

    { ICommandContext }
    procedure LogGeneral(const Text: string);
    procedure SetMarker(const Line: Integer);
    function CanDispatch: Boolean;
    procedure SendDefaultLine(const Line: string);

    function SerialActive: Boolean;
    procedure SerialOpen;
    procedure SerialClose;
    procedure SendSerial(const Data: string);
    procedure ConfigureSerial(const Port, Baud, DataBits, Parity,
      StopBits: string);
    function SerialBuffer: string;
    procedure ClearSerialBuffer;

    function TcpConnected: Boolean;
    procedure TcpConnect;
    procedure TcpDisconnect;
    procedure SendTcp(const Data: string);
    procedure ConfigureTcp(const Host, Port: string);
    function TcpBuffer: string;
    procedure ClearTcpBuffer;

    function ServerConnected: Boolean;
    procedure ServerListen;
    procedure ServerDisconnect;
    procedure SendServer(const Data: string);
    procedure ConfigureServer(const Port: string);
    function ServerBuffer: string;
    procedure ClearServerBuffer;

    procedure WaitSeconds(const Seconds: Double);
    procedure WaitTcpSeconds(const Seconds: Double);
    procedure WaitCommSeconds(const Seconds: Double);
  end;

implementation

constructor TFakeCommandContext.Create;
begin
  inherited Create;
  Logs := TStringList.Create;
  SerialData := TStringList.Create;
  TcpData := TStringList.Create;
  ServerData := TStringList.Create;
  DefaultLines := TStringList.Create;
  MarkerLine := -1;
  CanDispatchValue := True;
end;

destructor TFakeCommandContext.Destroy;
begin
  Logs.Free;
  SerialData.Free;
  TcpData.Free;
  ServerData.Free;
  DefaultLines.Free;
  inherited Destroy;
end;

procedure TFakeCommandContext.LogGeneral(const Text: string);
begin
  Logs.Add(Text);
end;

procedure TFakeCommandContext.SetMarker(const Line: Integer);
begin
  MarkerLine := Line;
end;

function TFakeCommandContext.CanDispatch: Boolean;
begin
  Result := CanDispatchValue;
end;

procedure TFakeCommandContext.SendDefaultLine(const Line: string);
begin
  DefaultLines.Add(Line);
end;

function TFakeCommandContext.SerialActive: Boolean;
begin
  Result := SerialActiveValue;
end;

procedure TFakeCommandContext.SerialOpen;
begin
  Inc(OpenCount);
  SerialActiveValue := True;
end;

procedure TFakeCommandContext.SerialClose;
begin
  Inc(CloseCount);
  SerialActiveValue := False;
end;

procedure TFakeCommandContext.SendSerial(const Data: string);
begin
  SerialData.Add(Data);
end;

procedure TFakeCommandContext.ConfigureSerial(const Port, Baud, DataBits,
  Parity, StopBits: string);
begin
  SerialConfig := Port + '|' + Baud + '|' + DataBits + '|' + Parity + '|' +
    StopBits;
end;

function TFakeCommandContext.SerialBuffer: string;
begin
  Result := SerialBufferValue;
end;

procedure TFakeCommandContext.ClearSerialBuffer;
begin
  SerialBufferValue := '';
end;

function TFakeCommandContext.TcpConnected: Boolean;
begin
  Result := TcpConnectedValue;
end;

procedure TFakeCommandContext.TcpConnect;
begin
  Inc(ConnectCount);
  TcpConnectedValue := True;
end;

procedure TFakeCommandContext.TcpDisconnect;
begin
  Inc(DisconnectCount);
  TcpConnectedValue := False;
end;

procedure TFakeCommandContext.SendTcp(const Data: string);
begin
  TcpData.Add(Data);
end;

procedure TFakeCommandContext.ConfigureTcp(const Host, Port: string);
begin
  TcpConfig := Host + ':' + Port;
end;

function TFakeCommandContext.TcpBuffer: string;
begin
  Result := TcpBufferValue;
end;

procedure TFakeCommandContext.ClearTcpBuffer;
begin
  TcpBufferValue := '';
end;

function TFakeCommandContext.ServerConnected: Boolean;
begin
  Result := ServerConnectedValue;
end;

procedure TFakeCommandContext.ServerListen;
begin
  Inc(ListenCount);
  ServerConnectedValue := True;
end;

procedure TFakeCommandContext.ServerDisconnect;
begin
  Inc(ServerDisconnectCount);
  ServerConnectedValue := False;
end;

procedure TFakeCommandContext.SendServer(const Data: string);
begin
  ServerData.Add(Data);
end;

procedure TFakeCommandContext.ConfigureServer(const Port: string);
begin
  ServerConfig := Port;
end;

function TFakeCommandContext.ServerBuffer: string;
begin
  Result := ServerBufferValue;
end;

procedure TFakeCommandContext.ClearServerBuffer;
begin
  ServerBufferValue := '';
end;

procedure TFakeCommandContext.WaitSeconds(const Seconds: Double);
begin
  WaitSecondsValue := Seconds;
end;

procedure TFakeCommandContext.WaitTcpSeconds(const Seconds: Double);
begin
  WaitTcpValue := Seconds;
end;

procedure TFakeCommandContext.WaitCommSeconds(const Seconds: Double);
begin
  WaitCommValue := Seconds;
end;

end.
