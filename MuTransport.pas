unit MuTransport;

{

Role interfaces for script command side effects.

ICommandContext used to be one 31-method interface, so every command
depended on serial ports, TCP, the server, logging and timing even when
it only needed one of them. The roles below split that contract:

  ICommandLog      - write a line to the general log
  IScriptHost      - UI feedback and script dispatch state
  ISerialChannel   - serial port operations
  ITcpChannel      - TCP client operations
  IServerChannel   - TCP server operations
  IWaiter          - blocking waits

MuCommands composes them into ICommandContext, and each command class
only stores the roles it actually calls. A new transport (for example
WebSocket) therefore has to implement only its own channel contract
instead of the whole application context.

}

{$mode objfpc}{$H+}

interface

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

end.
