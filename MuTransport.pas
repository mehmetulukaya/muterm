unit MuTransport;

{

Role interfaces for script command side effects.

ICommandContext used to be one 31-method interface, so every command
depended on serial ports, TCP, the server, logging and timing even when
it only needed one of them. The roles below split that contract:

  ICommandLog      - write a line to the general log
  IScriptHost      - UI feedback and script dispatch state
  ISerialChannel   - serial port operations
  IClientChannel   - active client transport (TCP today, WebSocket later)
  ITcpChannel      - legacy TCP-only role, used to adapt existing code
  IServerChannel   - TCP server operations
  IWaiter          - blocking waits

Commands only see IClientChannel. The script command names stay :TCP_*
for compatibility, but the channel behind them can be swapped without
touching the command engine. TTcpClientChannel adapts the legacy TCP
role to that generic contract; a WebSocket channel will implement
IClientChannel directly.

}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, MuLibs;

type
  ICommandLog = interface
    ['{3E9A6C21-4B7D-4E15-8F0A-6C2D5B8E1A73}']
    procedure LogGeneral(const Text: string);
  end;

  { The script host decides whether the next line may run and shows the
    execution marker. SendDefaultLine is the fallback for plain text
    lines that are not commands. }
  IScriptHost = interface
    ['{A4C8E2D7-5F16-4B93-9C0E-7D1A8B3F5E26}']
    procedure SetMarker(const Line: Integer);
    function CanDispatch: Boolean;
    procedure SendDefaultLine(const Line: string);
  end;

  ISerialChannel = interface
    ['{C7B3F1A9-6D28-4E84-8A57-2F9C0E6B1D45}']
    function SerialActive: Boolean;
    procedure SerialOpen;
    procedure SerialClose;
    procedure SendSerial(const Data: string);
    procedure ConfigureSerial(const Port, Baud, DataBits, Parity,
      StopBits: string);
    function SerialBuffer: string;
    procedure ClearSerialBuffer;
  end;

  { Transport-neutral client connection. Configure receives the raw
    argument text after the script command, so each transport decides
    how to interpret it (TCP expects "host,port", a WebSocket could
    expect a URL). }
  IClientChannel = interface
    ['{C2F8B1D4-6A39-4E7B-9D0F-2A5C8E3B1F76}']
    function Connected: Boolean;
    procedure Connect;
    procedure Disconnect;
    procedure Send(const Data: string);
    procedure Configure(const Endpoint: string);
    function Buffer: string;
    procedure ClearBuffer;
    { Gives asynchronous transports a chance to advance their state even
      when no script command is reading Buffer in this tick. Legacy TCP
      keeps its own polling in the form, so this is a no-op there. }
    procedure Pump;
  end;

  { Kept for the form context and older adapters. New transports should
    implement IClientChannel instead. }
  ITcpChannel = interface
    ['{D1E5A8C3-7F42-4B69-9D18-3A6C2E4F7B90}']
    function TcpConnected: Boolean;
    procedure TcpConnect;
    procedure TcpDisconnect;
    procedure SendTcp(const Data: string);
    procedure ConfigureTcp(const Host, Port: string);
    function TcpBuffer: string;
    procedure ClearTcpBuffer;
  end;

  { Adapts the legacy TCP role to the transport-neutral client role.
    This is the only place that knows the :TCP_SETUP argument format. }
  TTcpClientChannel = class(TInterfacedObject, IClientChannel)
  private
    FTcp: ITcpChannel;
  public
    constructor Create(ATcp: ITcpChannel);
    function Connected: Boolean;
    procedure Connect;
    procedure Disconnect;
    procedure Send(const Data: string);
    procedure Configure(const Endpoint: string);
    function Buffer: string;
    procedure ClearBuffer;
    procedure Pump;
  end;

  IServerChannel = interface
    ['{E8F2C4B6-8A53-4D71-B29E-5C0A7D3F6E14}']
    function ServerConnected: Boolean;
    procedure ServerListen;
    procedure ServerDisconnect;
    procedure SendServer(const Data: string);
    procedure ConfigureServer(const Port: string);
    function ServerBuffer: string;
    procedure ClearServerBuffer;
  end;

  { Blocking waits are a separate role: they are the part of the engine
    that talks to the clock and should be replaceable in tests. }
  IWaiter = interface
    ['{F5A9D7E1-9B64-4C28-8E31-6D4B0A2C5F87}']
    procedure WaitSeconds(const Seconds: Double);
    procedure WaitTcpSeconds(const Seconds: Double);
    procedure WaitCommSeconds(const Seconds: Double);
  end;

implementation

{ TTcpClientChannel }

constructor TTcpClientChannel.Create(ATcp: ITcpChannel);
begin
  inherited Create;
  FTcp := ATcp;
end;

function TTcpClientChannel.Connected: Boolean;
begin
  Result := FTcp.TcpConnected;
end;

procedure TTcpClientChannel.Connect;
begin
  FTcp.TcpConnect;
end;

procedure TTcpClientChannel.Disconnect;
begin
  FTcp.TcpDisconnect;
end;

procedure TTcpClientChannel.Send(const Data: string);
begin
  FTcp.SendTcp(Data);
end;

procedure TTcpClientChannel.Configure(const Endpoint: string);
var
  Host, Port: string;
begin
  Host := GetNStr(Endpoint, 1, ',');
  Port := GetNStr(Endpoint, 2, ',');
  if (Host <> '') and (Port <> '') then
    FTcp.ConfigureTcp(Host, Port);
end;

function TTcpClientChannel.Buffer: string;
begin
  Result := FTcp.TcpBuffer;
end;

procedure TTcpClientChannel.ClearBuffer;
begin
  FTcp.ClearTcpBuffer;
end;

procedure TTcpClientChannel.Pump;
begin
  { The legacy TCP component is polled by the form timer. }
end;

end.
