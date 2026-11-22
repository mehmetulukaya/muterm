unit MuCommands;

{

Script command engine for MuTerm.

The old implementation was a ~500 line if-chain inside TfrmMain's timer:
every new ":COMMAND" required editing that function (OCP violation) and
copy/paste blocks kept drifting apart.

Here each command is a small class. The engine owns the instruction
pointer and asks the context (the form) for the actual terminal
operations. Adding a command means adding a class and registering it.

}

{$mode objfpc}{$H+}

interface

uses
  Classes, Contnrs, SysUtils, StrUtils, MuLibs, MuExpr, MuScriptSyntax, MuClock,
  MuTransport;

type

  TCommandResult = (crNext, crRepeat, crStop, crJump);

  { Everything the commands need from the application. Implemented by
    TfrmMain so that command classes stay UI-free. Commands no longer
    depend on this aggregate: the engine adapts it to the focused roles
    in MuTransport and commands receive only the role they use. }
  ICommandContext = interface
    ['{2C6E8B74-91A3-4D0F-8F62-5B1D7E3A9C48}']

    // logging / UI feedback
    procedure LogGeneral(const Text: string);
    procedure SetMarker(const Line: Integer);

    // script execution
    function CanDispatch: Boolean;
    procedure SendDefaultLine(const Line: string);

    // serial port
    function SerialActive: Boolean;
    procedure SerialOpen;
    procedure SerialClose;
    procedure SendSerial(const Data: string);
    procedure ConfigureSerial(const Port, Baud, DataBits, Parity,
      StopBits: string);
    function SerialBuffer: string;
    procedure ClearSerialBuffer;

    // tcp client
    function TcpConnected: Boolean;
    procedure TcpConnect;
    procedure TcpDisconnect;
    procedure SendTcp(const Data: string);
    procedure ConfigureTcp(const Host, Port: string);
    function TcpBuffer: string;
    procedure ClearTcpBuffer;

    // tcp server
    function ServerConnected: Boolean;
    procedure ServerListen;
    procedure ServerDisconnect;
    procedure SendServer(const Data: string);
    procedure ConfigureServer(const Port: string);
    function ServerBuffer: string;
    procedure ClearServerBuffer;

    // timing
    procedure WaitSeconds(const Seconds: Double);
    procedure WaitTcpSeconds(const Seconds: Double);
    procedure WaitCommSeconds(const Seconds: Double);
  end;

  TCommandEngine = class;

  TCommand = class
  private
    FName: string;
  public
    constructor Create(const AName: string);
    property Name: string read FName;
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; virtual; abstract;
  end;

  TServerDisconnectCommand = class(TCommand)
  private
    FServer: IServerChannel;
  public
    constructor Create(const AName: string; AServer: IServerChannel);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TServerSendCommand = class(TCommand)
  private
    FAsHex: Boolean;
    FServer: IServerChannel;
    FLog: ICommandLog;
  public
    constructor Create(const AName: string; AAsHex: Boolean;
      AServer: IServerChannel; ALog: ICommandLog);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TServerWaitCommand = class(TCommand)
  private
    FAsHex: Boolean;
    FServer: IServerChannel;
    FLog: ICommandLog;
  public
    constructor Create(const AName: string; AAsHex: Boolean;
      AServer: IServerChannel; ALog: ICommandLog);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TServerListenCommand = class(TCommand)
  private
    FServer: IServerChannel;
  public
    constructor Create(const AName: string; AServer: IServerChannel);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TServerSetupCommand = class(TCommand)
  private
    FServer: IServerChannel;
  public
    constructor Create(const AName: string; AServer: IServerChannel);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TTcpOpenCloseCommand = class(TCommand)
  private
    FTcp: IClientChannel;
  public
    constructor Create(const AName: string; ATcp: IClientChannel);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TTcpSetupCommand = class(TCommand)
  private
    FTcp: IClientChannel;
  public
    constructor Create(const AName: string; ATcp: IClientChannel);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TTcpSendCommand = class(TCommand)
  private
    FAsHex: Boolean;
    FTcp: IClientChannel;
  public
    constructor Create(const AName: string; AAsHex: Boolean; ATcp: IClientChannel);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TTcpWaitCommand = class(TCommand)
  private
    FAsHex: Boolean;
    FTcp: IClientChannel;
    FLog: ICommandLog;
  public
    constructor Create(const AName: string; AAsHex: Boolean;
      ATcp: IClientChannel; ALog: ICommandLog);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TSerialOpenCloseCommand = class(TCommand)
  private
    FSerial: ISerialChannel;
    FHost: IScriptHost;
  public
    constructor Create(const AName: string; ASerial: ISerialChannel;
      AHost: IScriptHost);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TSerialSetupCommand = class(TCommand)
  private
    FSerial: ISerialChannel;
  public
    constructor Create(const AName: string; ASerial: ISerialChannel);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TSendKind = (skHex, skText, skHexCrc);

  TSerialSendCommand = class(TCommand)
  private
    FKind: TSendKind;
    FSerial: ISerialChannel;
  public
    constructor Create(const AName: string; AKind: TSendKind;
      ASerial: ISerialChannel);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TSerialWaitCommand = class(TCommand)
  private
    FAsHex: Boolean;
    FSerial: ISerialChannel;
    FLog: ICommandLog;
  public
    constructor Create(const AName: string; AAsHex: Boolean;
      ASerial: ISerialChannel; ALog: ICommandLog);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TWaitKind = (wkSeconds, wkTcp, wkComm);

  TWaitCommand = class(TCommand)
  private
    FKind: TWaitKind;
    FWaiter: IWaiter;
  public
    constructor Create(const AName: string; AKind: TWaitKind;
      AWaiter: IWaiter);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TGotoCommand = class(TCommand)
  private
    FLog: ICommandLog;
  public
    constructor Create(const AName: string; ALog: ICommandLog);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TEndCommand = class(TCommand)
  private
    FLog: ICommandLog;
  public
    constructor Create(const AName: string; ALog: ICommandLog);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TIfCommand = class(TCommand)
  private
    FLog: ICommandLog;
  public
    constructor Create(const AName: string; ALog: ICommandLog);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TElseCommand = class(TCommand)
  private
    FLog: ICommandLog;
  public
    constructor Create(const AName: string; ALog: ICommandLog);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TEndIfCommand = class(TCommand)
  public
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TSetCommand = class(TCommand)
  private
    FLog: ICommandLog;
  public
    constructor Create(const AName: string; ALog: ICommandLog);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TLabelCommand = class(TCommand)
  public
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TBufferKind = (bkSerial, bkTcp, bkServer);

  TClearBufferCommand = class(TCommand)
  private
    FKind: TBufferKind;
    FSerial: ISerialChannel;
    FTcp: IClientChannel;
    FServer: IServerChannel;
  public
    constructor Create(const AName: string; AKind: TBufferKind;
      ASerial: ISerialChannel; ATcp: IClientChannel; AServer: IServerChannel);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TRecvTextCommand = class(TCommand)
  private
    FKind: TBufferKind;
    FSerial: ISerialChannel;
    FTcp: IClientChannel;
    FServer: IServerChannel;
    FLog: ICommandLog;
  public
    constructor Create(const AName: string; AKind: TBufferKind;
      ASerial: ISerialChannel; ATcp: IClientChannel; AServer: IServerChannel;
      ALog: ICommandLog);
    function Execute(Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TCommandEngine = class
  private
    FSource: TStrings;
    FCommands: TObjectList;
    FPointer: Integer;
    FLastLine: Integer;
    FRunning: Boolean;

    FVars: TStringList;
    FWarnedVars: TStringList;
    FLabels: TStringList;
    FIfFalseTarget: array of Integer;
    FIfEndTarget: array of Integer;
    FIfElseLine: array of Integer;
    FElseEndTarget: array of Integer;
    FRepeatLine: Integer;
    FRepeatStart: TDateTime;
    FStructureError: string;
    FClock: IClock;

    FLog: ICommandLog;
    FHost: IScriptHost;
    FSerial: ISerialChannel;
    FTcp: IClientChannel;
    FServer: IServerChannel;
    FWaiter: IWaiter;

    function FindCommand(const Line: string): TCommand;
    function DispatchLine(const Line: string): TCommandResult;
    procedure BuildStructure;
    procedure ResetVars;
    procedure InitRoles(ASource: TStrings; ALog: ICommandLog;
      AHost: IScriptHost; ASerial: ISerialChannel; AClient: IClientChannel;
      AServer: IServerChannel; AWaiter: IWaiter; AClock: IClock);
  public
    constructor Create(ASource: TStrings; AContext: ICommandContext;
      AClock: IClock = nil);
    { Preferred constructor for new transports: no form context needed. }
    constructor CreateRoles(ASource: TStrings; ALog: ICommandLog;
      AHost: IScriptHost; ASerial: ISerialChannel; AClient: IClientChannel;
      AServer: IServerChannel; AWaiter: IWaiter; AClock: IClock = nil);
    destructor Destroy; override;

    procedure Register(Command: TCommand);
    procedure RegisterDefaults;
    procedure Start;
    procedure StartAt(Index: Integer);
    procedure Stop;
    procedure JumpTo(Index: Integer);
    procedure Tick;

    function HasLine(Index: Integer): Boolean;
    function LineAt(Index: Integer): string;
    function LineCount: Integer;

    function TryGetVar(const Name: string; out Value: string): Boolean;
    function GetVar(const Name: string): string;
    procedure SetVar(const Name, Value: string);
    function ResolveVariable(const Name: string; out Value: string): Boolean;
    function ExpandVars(const Text: string): string;
    function ResolveTarget(const Target: string; out Index: Integer): Boolean;
    function RepeatExpired(const Seconds: Double): Boolean;
    function IfFalseTarget(Line: Integer): Integer;
    function ElseEndTarget(Line: Integer): Integer;

    property Running: Boolean read FRunning;
    property CurrentLine: Integer read FPointer;
    property LastLine: Integer read FLastLine;
  end;

procedure RegisterDefaultCommands(Engine: TCommandEngine);

{ Builds the legacy TCP client channel from the form context. New code
  should inject a client channel explicitly instead. }
function CreateContextClientChannel(AContext: ICommandContext): IClientChannel;

{ Creates an engine that keeps the form context for logging/UI/serial,
  but uses the supplied client channel for :TCP_* commands. }
function CreateCommandEngineWithClient(ASource: TStrings;
  AContext: ICommandContext; AClient: IClientChannel;
  AClock: IClock = nil): TCommandEngine;

implementation

{ Adapts the application context to the narrow role interfaces.

  FPC 3.2 does not support multiple interface inheritance, so the roles
  cannot be composed into ICommandContext. This adapter is the seam: the
  form keeps implementing the existing aggregate context, while commands
  only ever see the role they asked for. Once the form is split into
  transport objects, this class can disappear without touching the
  commands. }
type
  TContextRoles = class(TInterfacedObject, ICommandLog, IScriptHost,
    ISerialChannel, ITcpChannel, IServerChannel, IWaiter)
  private
    FContext: ICommandContext;
  public
    constructor Create(AContext: ICommandContext);

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

constructor TContextRoles.Create(AContext: ICommandContext);
begin
  inherited Create;
  FContext := AContext;
end;

procedure TContextRoles.LogGeneral(const Text: string);
begin
  FContext.LogGeneral(Text);
end;

procedure TContextRoles.SetMarker(const Line: Integer);
begin
  FContext.SetMarker(Line);
end;

function TContextRoles.CanDispatch: Boolean;
begin
  Result := FContext.CanDispatch;
end;

procedure TContextRoles.SendDefaultLine(const Line: string);
begin
  FContext.SendDefaultLine(Line);
end;

function TContextRoles.SerialActive: Boolean;
begin
  Result := FContext.SerialActive;
end;

procedure TContextRoles.SerialOpen;
begin
  FContext.SerialOpen;
end;

procedure TContextRoles.SerialClose;
begin
  FContext.SerialClose;
end;

procedure TContextRoles.SendSerial(const Data: string);
begin
  FContext.SendSerial(Data);
end;

procedure TContextRoles.ConfigureSerial(const Port, Baud, DataBits, Parity,
  StopBits: string);
begin
  FContext.ConfigureSerial(Port, Baud, DataBits, Parity, StopBits);
end;

function TContextRoles.SerialBuffer: string;
begin
  Result := FContext.SerialBuffer;
end;

procedure TContextRoles.ClearSerialBuffer;
begin
  FContext.ClearSerialBuffer;
end;

function TContextRoles.TcpConnected: Boolean;
begin
  Result := FContext.TcpConnected;
end;

procedure TContextRoles.TcpConnect;
begin
  FContext.TcpConnect;
end;

procedure TContextRoles.TcpDisconnect;
begin
  FContext.TcpDisconnect;
end;

procedure TContextRoles.SendTcp(const Data: string);
begin
  FContext.SendTcp(Data);
end;

procedure TContextRoles.ConfigureTcp(const Host, Port: string);
begin
  FContext.ConfigureTcp(Host, Port);
end;

function TContextRoles.TcpBuffer: string;
begin
  Result := FContext.TcpBuffer;
end;

procedure TContextRoles.ClearTcpBuffer;
begin
  FContext.ClearTcpBuffer;
end;

function TContextRoles.ServerConnected: Boolean;
begin
  Result := FContext.ServerConnected;
end;

procedure TContextRoles.ServerListen;
begin
  FContext.ServerListen;
end;

procedure TContextRoles.ServerDisconnect;
begin
  FContext.ServerDisconnect;
end;

procedure TContextRoles.SendServer(const Data: string);
begin
  FContext.SendServer(Data);
end;

procedure TContextRoles.ConfigureServer(const Port: string);
begin
  FContext.ConfigureServer(Port);
end;

function TContextRoles.ServerBuffer: string;
begin
  Result := FContext.ServerBuffer;
end;

procedure TContextRoles.ClearServerBuffer;
begin
  FContext.ClearServerBuffer;
end;

procedure TContextRoles.WaitSeconds(const Seconds: Double);
begin
  FContext.WaitSeconds(Seconds);
end;

procedure TContextRoles.WaitTcpSeconds(const Seconds: Double);
begin
  FContext.WaitTcpSeconds(Seconds);
end;

procedure TContextRoles.WaitCommSeconds(const Seconds: Double);
begin
  FContext.WaitCommSeconds(Seconds);
end;

{ helpers }

function WaitForText(Engine: TCommandEngine; ALog: ICommandLog;
  const Pattern, Buffer: string; Timeout: Double; AsHex: Boolean): TCommandResult;
begin
  Result := crNext;
  if Pos(Pattern, Buffer) > 0 then
  begin
    Engine.SetVar('TIMEOUT', '0');
    if AsHex then
      ALog.LogGeneral('Wait for hex OK:' + Buffer)
    else
      ALog.LogGeneral('Wait for text OK:' + Buffer);
  end
  else if (Timeout > 0) and Engine.RepeatExpired(Timeout) then
  begin
    Engine.SetVar('TIMEOUT', '1');
    ALog.LogGeneral('Wait timeout: ' + Pattern);
  end
  else
    Result := crRepeat;
end;

{ TCommand }

constructor TCommand.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

{ TServerDisconnectCommand }

constructor TServerDisconnectCommand.Create(const AName: string;
  AServer: IServerChannel);
begin
  inherited Create(AName);
  FServer := AServer;
end;

function TServerDisconnectCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
begin
  FServer.ServerDisconnect;
  Result := crNext;
end;

{ TServerSendCommand }

constructor TServerSendCommand.Create(const AName: string; AAsHex: Boolean;
  AServer: IServerChannel; ALog: ICommandLog);
begin
  inherited Create(AName);
  FAsHex := AAsHex;
  FServer := AServer;
  FLog := ALog;
end;

function TServerSendCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
var
  Data: string;
begin
  Result := crNext;
  try
    if FAsHex then
    begin
      Data := Engine.ExpandVars(ArgsOf(Line));
      Data := HexToStr(Data);
    end
    else
    begin
      Data := StrToText(ArgsOf(Line));
      Data := Engine.ExpandVars(Data);
    end;
    FServer.SendServer(Data);
    if FAsHex then
      FLog.LogGeneral('HexSnd:' + Data)
    else
      FLog.LogGeneral('Snd:' + Data);
  except
  end;
end;

{ TServerWaitCommand }

constructor TServerWaitCommand.Create(const AName: string; AAsHex: Boolean;
  AServer: IServerChannel; ALog: ICommandLog);
begin
  inherited Create(AName);
  FAsHex := AAsHex;
  FServer := AServer;
  FLog := ALog;
end;

function TServerWaitCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
var
  Args, Pattern, Buffer: string;
  Timeout: Double;
begin
  Result := crNext;
  try
    Args := ArgsOf(Line);
    SplitPatternTimeout(Args, Pattern, Timeout);
    Pattern := Engine.ExpandVars(Pattern);
    if FAsHex then
      Pattern := HexToStr(Pattern);
    Buffer := FServer.ServerBuffer;
    Result := WaitForText(Engine, FLog, Pattern, Buffer, Timeout, FAsHex);
  except
    on E: Exception do
    begin
      FLog.LogGeneral('WAIT: ' + E.Message);
      Result := crStop;
    end;
  end;
end;

{ TServerListenCommand }

constructor TServerListenCommand.Create(const AName: string;
  AServer: IServerChannel);
begin
  inherited Create(AName);
  FServer := AServer;
end;

function TServerListenCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
begin
  FServer.ServerListen;
  Result := crNext;
end;

{ TServerSetupCommand }

constructor TServerSetupCommand.Create(const AName: string;
  AServer: IServerChannel);
begin
  inherited Create(AName);
  FServer := AServer;
end;

function TServerSetupCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
begin
  Result := crNext;
  try
    FServer.ConfigureServer(ArgsOf(Line));
  except
  end;
end;

{ TTcpOpenCloseCommand }

constructor TTcpOpenCloseCommand.Create(const AName: string;
  ATcp: IClientChannel);
begin
  inherited Create(AName);
  FTcp := ATcp;
end;

function TTcpOpenCloseCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
begin
  if FTcp.Connected then
    FTcp.Disconnect
  else
    FTcp.Connect;
  Result := crNext;
end;

{ TTcpSetupCommand }

constructor TTcpSetupCommand.Create(const AName: string; ATcp: IClientChannel);
begin
  inherited Create(AName);
  FTcp := ATcp;
end;

function TTcpSetupCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
begin
  Result := crNext;
  try
    FTcp.Configure(ArgsOf(Line));
  except
  end;
end;

{ TTcpSendCommand }

constructor TTcpSendCommand.Create(const AName: string; AAsHex: Boolean;
  ATcp: IClientChannel);
begin
  inherited Create(AName);
  FAsHex := AAsHex;
  FTcp := ATcp;
end;

function TTcpSendCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
var
  Data: string;
begin
  Result := crNext;
  try
    if FAsHex then
    begin
      Data := Engine.ExpandVars(ArgsOf(Line));
      Data := HexToStr(Data);
    end
    else
    begin
      Data := StrToText(ArgsOf(Line));
      Data := Engine.ExpandVars(Data);
    end;
    FTcp.Send(Data);
  except
  end;
end;

{ TTcpWaitCommand }

constructor TTcpWaitCommand.Create(const AName: string; AAsHex: Boolean;
  ATcp: IClientChannel; ALog: ICommandLog);
begin
  inherited Create(AName);
  FAsHex := AAsHex;
  FTcp := ATcp;
  FLog := ALog;
end;

function TTcpWaitCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
var
  Args, Pattern, Buffer: string;
  Timeout: Double;
begin
  Result := crNext;
  try
    Args := ArgsOf(Line);
    SplitPatternTimeout(Args, Pattern, Timeout);
    Pattern := Engine.ExpandVars(Pattern);
    if FAsHex then
      Pattern := HexToStr(Pattern);
    Buffer := FTcp.Buffer;
    Result := WaitForText(Engine, FLog, Pattern, Buffer, Timeout, FAsHex);
  except
    on E: Exception do
    begin
      FLog.LogGeneral('WAIT: ' + E.Message);
      Result := crStop;
    end;
  end;
end;

{ TSerialOpenCloseCommand }

constructor TSerialOpenCloseCommand.Create(const AName: string;
  ASerial: ISerialChannel; AHost: IScriptHost);
begin
  inherited Create(AName);
  FSerial := ASerial;
  FHost := AHost;
end;

function TSerialOpenCloseCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
begin
  if FSerial.SerialActive then
  begin
    FSerial.SerialClose;
    FHost.SetMarker(Engine.CurrentLine + 1);
  end
  else
    FSerial.SerialOpen;
  Result := crNext;
end;

{ TSerialSetupCommand }

constructor TSerialSetupCommand.Create(const AName: string;
  ASerial: ISerialChannel);
begin
  inherited Create(AName);
  FSerial := ASerial;
end;

function TSerialSetupCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
var
  Args: string;
begin
  Result := crNext;
  try
    Args := ArgsOf(Line);
    FSerial.ConfigureSerial(
      GetNStr(Args, 1, ','),
      GetNStr(Args, 2, ','),
      GetNStr(Args, 3, ','),
      GetNStr(Args, 4, ','),
      GetNStr(Args, 5, ','));
  except
  end;
end;

{ TSerialSendCommand }

constructor TSerialSendCommand.Create(const AName: string; AKind: TSendKind;
  ASerial: ISerialChannel);
begin
  inherited Create(AName);
  FKind := AKind;
  FSerial := ASerial;
end;

function TSerialSendCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
var
  Data: string;
begin
  Result := crNext;
  try
    Data := ArgsOf(Line);
    case FKind of
      skHex:
        begin
          Data := Engine.ExpandVars(Data);
          Data := HexToStr(Data);
        end;
      skText:
        begin
          Data := StrToText(Data);
          Data := Engine.ExpandVars(Data);
        end;
      skHexCrc:
        begin
          Data := Engine.ExpandVars(Data);
          Data := HexToStr(Data);
          Data := Data + CRC16(Data);
        end;
    end;
    FSerial.SendSerial(Data);
  except
  end;
end;

{ TSerialWaitCommand }

constructor TSerialWaitCommand.Create(const AName: string; AAsHex: Boolean;
  ASerial: ISerialChannel; ALog: ICommandLog);
begin
  inherited Create(AName);
  FAsHex := AAsHex;
  FSerial := ASerial;
  FLog := ALog;
end;

function TSerialWaitCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
var
  Args, Pattern, Buffer: string;
  Timeout: Double;
begin
  Result := crNext;
  try
    Args := ArgsOf(Line);
    SplitPatternTimeout(Args, Pattern, Timeout);
    Pattern := Engine.ExpandVars(Pattern);
    if FAsHex then
      Pattern := HexToStr(Pattern);
    Buffer := FSerial.SerialBuffer;
    Result := WaitForText(Engine, FLog, Pattern, Buffer, Timeout, FAsHex);
  except
    on E: Exception do
    begin
      FLog.LogGeneral('WAIT: ' + E.Message);
      Result := crStop;
    end;
  end;
end;

{ TWaitCommand }

constructor TWaitCommand.Create(const AName: string; AKind: TWaitKind;
  AWaiter: IWaiter);
begin
  inherited Create(AName);
  FKind := AKind;
  FWaiter := AWaiter;
end;

function TWaitCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
var
  Seconds: Double;
begin
  Result := crNext;
  if not TryNumber(ArgumentOf(Line), Seconds) then
    Exit;
  case FKind of
    wkSeconds: FWaiter.WaitSeconds(Seconds);
    wkTcp:     FWaiter.WaitTcpSeconds(Seconds);
    wkComm:    FWaiter.WaitCommSeconds(Seconds);
  end;
end;

{ TGotoCommand }

constructor TGotoCommand.Create(const AName: string; ALog: ICommandLog);
begin
  inherited Create(AName);
  FLog := ALog;
end;

function TGotoCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
var
  TargetName: string;
  Target: Integer;
begin
  TargetName := Trim(Copy(Trim(Line), Length(':GOTO') + 1, MaxInt));
  if Engine.ResolveTarget(TargetName, Target) then
  begin
    Engine.JumpTo(Target);
    FLog.LogGeneral('GOTO:> ' + TargetName);
    Result := crJump;
  end
  else
  begin
    FLog.LogGeneral('GOTO: hedef bulunamadi: ' + TargetName);
    Result := crStop;
  end;
end;

{ TIfCommand }

constructor TIfCommand.Create(const AName: string; ALog: ICommandLog);
begin
  inherited Create(AName);
  FLog := ALog;
end;

function TIfCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
var
  Expr, Rest, TargetName: string;
  Target: Integer;
  Cond: Boolean;
begin
  Result := crNext;
  if not ParseIfLine(Line, Expr, Rest) then
  begin
    FLog.LogGeneral('IF: sozdizimi hatasi: ' + Line);
    Exit(crStop);
  end;

  try
    Cond := ExprToBool(EvalExpression(Expr, @Engine.ResolveVariable));
  except
    on E: Exception do
    begin
      FLog.LogGeneral('IF: ' + E.Message);
      Exit(crStop);
    end;
  end;

  if Rest = '' then
  begin
    { Block IF: skip to ELSE+1 or END IF+1 when the condition is false. }
    if not Cond then
    begin
      Target := Engine.IfFalseTarget(Engine.CurrentLine);
      if Target >= 0 then
      begin
        Engine.JumpTo(Target);
        Result := crJump;
      end
      else
      begin
        FLog.LogGeneral('IF: eslesen END IF yok');
        Result := crStop;
      end;
    end;
  end
  else
  begin
    { Single-line IF: :IF(expr) GOTO label }
    if not StartsText('GOTO', Rest) then
    begin
      FLog.LogGeneral('IF: GOTO bekleniyordu: ' + Rest);
      Exit(crStop);
    end;
    if Cond then
    begin
      TargetName := Trim(Copy(Rest, Length('GOTO') + 1, MaxInt));
      if Engine.ResolveTarget(TargetName, Target) then
      begin
        Engine.JumpTo(Target);
        Result := crJump;
      end
      else
      begin
        FLog.LogGeneral('IF: hedef bulunamadi: ' + TargetName);
        Result := crStop;
      end;
    end;
  end;
end;

{ TElseCommand }

constructor TElseCommand.Create(const AName: string; ALog: ICommandLog);
begin
  inherited Create(AName);
  FLog := ALog;
end;

function TElseCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
var
  Target: Integer;
begin
  { Reaching ELSE means the true branch has finished. }
  Target := Engine.ElseEndTarget(Engine.CurrentLine);
  if Target >= 0 then
  begin
    Engine.JumpTo(Target + 1);
    Result := crJump;
  end
  else
  begin
    FLog.LogGeneral('ELSE: eslesen IF yok');
    Result := crStop;
  end;
end;

{ TEndIfCommand }

function TEndIfCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
begin
  Result := crNext;
end;

{ TSetCommand }

constructor TSetCommand.Create(const AName: string; ALog: ICommandLog);
begin
  inherited Create(AName);
  FLog := ALog;
end;

function TSetCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
var
  Args, VarName, Value: string;
  P: Integer;
begin
  Result := crNext;
  if not BalancedArgs(Line, Args) then
  begin
    FLog.LogGeneral('SET: sozdizimi hatasi');
    Exit(crStop);
  end;

  P := Pos(',', Args);
  if P = 0 then
  begin
    VarName := Trim(Args);
    Value := '';
  end
  else
  begin
    VarName := Trim(Copy(Args, 1, P - 1));
    Value := Copy(Args, P + 1, MaxInt);
  end;

  if not IsValidIdentifier(VarName) then
  begin
    FLog.LogGeneral('SET: gecersiz degisken adi: ' + VarName);
    Exit(crStop);
  end;

  Value := StrToText(Value);
  Value := Engine.ExpandVars(Value);
  Engine.SetVar(VarName, Value);
end;

{ TLabelCommand }

function TLabelCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
begin
  Result := crNext;
end;

{ TEndCommand }

constructor TEndCommand.Create(const AName: string; ALog: ICommandLog);
begin
  inherited Create(AName);
  FLog := ALog;
end;

function TEndCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
var
  Rest: string;
begin
  Rest := Trim(Copy(Trim(Line), Length(':END') + 1, MaxInt));
  if SameText(Rest, 'IF') then
    Result := crNext
  else
  begin
    FLog.LogGeneral('END. ');
    Result := crStop;
  end;
end;

{ TClearBufferCommand }

constructor TClearBufferCommand.Create(const AName: string; AKind: TBufferKind;
  ASerial: ISerialChannel; ATcp: IClientChannel; AServer: IServerChannel);
begin
  inherited Create(AName);
  FKind := AKind;
  FSerial := ASerial;
  FTcp := ATcp;
  FServer := AServer;
end;

function TClearBufferCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
begin
  case FKind of
    bkSerial: FSerial.ClearSerialBuffer;
    bkTcp:    FTcp.ClearBuffer;
    bkServer: FServer.ClearServerBuffer;
  end;
  Result := crNext;
end;

{ TRecvTextCommand }

constructor TRecvTextCommand.Create(const AName: string; AKind: TBufferKind;
  ASerial: ISerialChannel; ATcp: IClientChannel; AServer: IServerChannel;
  ALog: ICommandLog);
begin
  inherited Create(AName);
  FKind := AKind;
  FSerial := ASerial;
  FTcp := ATcp;
  FServer := AServer;
  FLog := ALog;
end;

function TRecvTextCommand.Execute(Engine: TCommandEngine;
  const Line: string): TCommandResult;
var
  Args, VarName, TimeoutText, Buffer: string;
  P: Integer;
  Timeout: Double;
begin
  Result := crNext;
  TimeoutText := '';
  if not BalancedArgs(Line, Args) then
  begin
    FLog.LogGeneral('RECV_TEXT: sozdizimi hatasi');
    Exit(crStop);
  end;

  P := Pos(',', Args);
  if P = 0 then
  begin
    VarName := Trim(Args);
    Timeout := 0;
  end
  else
  begin
    VarName := Trim(Copy(Args, 1, P - 1));
    TimeoutText := Trim(Copy(Args, P + 1, MaxInt));
    if not TryNumber(TimeoutText, Timeout) then
      Timeout := 0;
  end;

  if not IsValidIdentifier(VarName) then
  begin
    FLog.LogGeneral('RECV_TEXT: gecersiz degisken adi: ' + VarName);
    Exit(crStop);
  end;

  case FKind of
    bkSerial: Buffer := FSerial.SerialBuffer;
    bkTcp:    Buffer := FTcp.Buffer;
    bkServer: Buffer := FServer.ServerBuffer;
  else
    Buffer := '';
  end;

  if (Timeout > 0) and (Buffer = '') then
  begin
    if Engine.RepeatExpired(Timeout) then
    begin
      Engine.SetVar('TIMEOUT', '1');
      Engine.SetVar(VarName, Buffer);
    end
    else
      Result := crRepeat;
  end
  else
  begin
    Engine.SetVar('TIMEOUT', '0');
    Engine.SetVar(VarName, Buffer);
  end;
end;

{ TCommandEngine }

procedure TCommandEngine.InitRoles(ASource: TStrings; ALog: ICommandLog;
  AHost: IScriptHost; ASerial: ISerialChannel; AClient: IClientChannel;
  AServer: IServerChannel; AWaiter: IWaiter; AClock: IClock);
begin
  FSource := ASource;
  FLog := ALog;
  FHost := AHost;
  FSerial := ASerial;
  FTcp := AClient;
  FServer := AServer;
  FWaiter := AWaiter;

  if AClock <> nil then
    FClock := AClock
  else
    FClock := TSystemClock.Create;
  FCommands := TObjectList.Create(True);
  FPointer := 0;
  FLastLine := -1;
  FRunning := False;
  FRepeatLine := -1;
  FStructureError := '';

  FVars := TStringList.Create;
  FVars.CaseSensitive := False;
  FWarnedVars := TStringList.Create;
  FWarnedVars.CaseSensitive := False;
  FLabels := TStringList.Create;
  FLabels.CaseSensitive := False;
end;

constructor TCommandEngine.Create(ASource: TStrings; AContext: ICommandContext;
  AClock: IClock);
var
  Roles: TContextRoles;
  LegacyTcp: ITcpChannel;
begin
  inherited Create;
  Roles := TContextRoles.Create(AContext);
  LegacyTcp := Roles;
  InitRoles(ASource, Roles, Roles, Roles,
    TTcpClientChannel.Create(LegacyTcp), Roles, Roles, AClock);
end;

constructor TCommandEngine.CreateRoles(ASource: TStrings; ALog: ICommandLog;
  AHost: IScriptHost; ASerial: ISerialChannel; AClient: IClientChannel;
  AServer: IServerChannel; AWaiter: IWaiter; AClock: IClock);
begin
  inherited Create;
  InitRoles(ASource, ALog, AHost, ASerial, AClient, AServer, AWaiter, AClock);
end;

destructor TCommandEngine.Destroy;
begin
  FVars.Free;
  FWarnedVars.Free;
  FLabels.Free;
  FCommands.Free;
  inherited Destroy;
end;

procedure TCommandEngine.Register(Command: TCommand);
begin
  if Assigned(Command) then
    FCommands.Add(Command);
end;

function TCommandEngine.FindCommand(const Line: string): TCommand;
var
  Token: string;
  I: Integer;
begin
  Token := CommandToken(Line);
  if Token = '' then
    Exit(nil);
  for I := 0 to FCommands.Count - 1 do
  begin
    Result := TCommand(FCommands[I]);
    if SameText(Result.Name, Token) then
      Exit;
  end;
  Result := nil;
end;

function TCommandEngine.DispatchLine(const Line: string): TCommandResult;
var
  Cmd: TCommand;
begin
  Cmd := FindCommand(Line);
  if Assigned(Cmd) then
    Result := Cmd.Execute(Self, Line)
  else
  begin
    FHost.SendDefaultLine(Line);
    Result := crNext;
  end;
end;

procedure TCommandEngine.ResetVars;
begin
  FVars.Clear;
  FWarnedVars.Clear;
end;

procedure TCommandEngine.BuildStructure;
var
  I, J, N, StackTop: Integer;
  Stack: array of Integer;
  Line, Token, Expr, Rest, Name: string;

  procedure Fail(const Msg: string);
  begin
    if FStructureError = '' then
      FStructureError := Msg;
  end;

begin
  FLabels.Clear;
  N := FSource.Count;
  SetLength(FIfFalseTarget, N);
  SetLength(FIfEndTarget, N);
  SetLength(FIfElseLine, N);
  SetLength(FElseEndTarget, N);
  for I := 0 to N - 1 do
  begin
    FIfFalseTarget[I] := -1;
    FIfEndTarget[I] := -1;
    FIfElseLine[I] := -1;
    FElseEndTarget[I] := -1;
  end;

  SetLength(Stack, 0);
  StackTop := 0;
  FStructureError := '';

  for I := 0 to N - 1 do
  begin
    Line := Trim(FSource[I]);
    Token := CommandToken(Line);

    if Token = ':LABEL' then
    begin
      Name := Trim(Copy(Line, Length(':LABEL') + 1, MaxInt));
      if not IsValidIdentifier(Name) then
        Fail('Gecersiz etiket adi: ' + Name + ' (satir ' + IntToStr(I + 1) + ')')
      else if FLabels.IndexOfName(Name) >= 0 then
        Fail('Ayni etiket iki kez tanimli: ' + Name + ' (satir ' + IntToStr(I + 1) + ')')
      else
        FLabels.Add(Name + '=' + IntToStr(I));
    end
    else if Token = ':IF' then
    begin
      if not ParseIfLine(Line, Expr, Rest) then
        Fail('IF sozdizimi: ' + Line + ' (satir ' + IntToStr(I + 1) + ')')
      else if Rest = '' then
      begin
        SetLength(Stack, StackTop + 1);
        Stack[StackTop] := I;
        Inc(StackTop);
      end;
    end
    else if Token = ':ELSE' then
    begin
      if StackTop = 0 then
        Fail('ELSE icin eslesen IF yok (satir ' + IntToStr(I + 1) + ')')
      else
      begin
        J := Stack[StackTop - 1];
        if FIfElseLine[J] >= 0 then
          Fail('IF icinde birden fazla ELSE (satir ' + IntToStr(I + 1) + ')')
        else
          FIfElseLine[J] := I;
      end;
    end
    else if IsEndIfLine(Line) then
    begin
      if StackTop = 0 then
        Fail('END IF icin eslesen IF yok (satir ' + IntToStr(I + 1) + ')')
      else
      begin
        Dec(StackTop);
        J := Stack[StackTop];
        FIfEndTarget[J] := I;
        if FIfElseLine[J] >= 0 then
        begin
          FElseEndTarget[FIfElseLine[J]] := I;
          FIfFalseTarget[J] := FIfElseLine[J] + 1;
        end
        else
          FIfFalseTarget[J] := I + 1;
      end;
    end;
  end;

  if StackTop > 0 then
    Fail('IF blogu kapatilmamis (satir ' + IntToStr(Stack[StackTop - 1] + 1) + ')');
end;

function TCommandEngine.TryGetVar(const Name: string; out Value: string): Boolean;
var
  P: Integer;
begin
  P := FVars.IndexOfName(Name);
  Result := P >= 0;
  if Result then
    Value := FVars.ValueFromIndex[P]
  else
    Value := '';
end;

function TCommandEngine.GetVar(const Name: string): string;
begin
  if not TryGetVar(Name, Result) then
    Result := '';
end;

procedure TCommandEngine.SetVar(const Name, Value: string);
var
  P: Integer;
begin
  P := FVars.IndexOfName(Name);
  if P >= 0 then
    FVars[P] := Name + '=' + Value
  else
    FVars.Add(Name + '=' + Value);
end;

function TCommandEngine.ResolveVariable(const Name: string; out Value: string): Boolean;
begin
  Result := TryGetVar(Name, Value);
  if not Result then
  begin
    Value := '';
    if (Name <> '') and (FWarnedVars.IndexOf(Name) < 0) then
    begin
      FWarnedVars.Add(Name);
      FLog.LogGeneral('Uyari: tanimsiz degisken: ' + Name);
    end;
  end;
end;

function TCommandEngine.ExpandVars(const Text: string): string;
var
  I, P: Integer;
  Name, Value: string;
begin
  Result := '';
  I := 1;
  while I <= Length(Text) do
  begin
    if Text[I] = '{' then
    begin
      if (I < Length(Text)) and (Text[I + 1] = '{') then
      begin
        Result := Result + '{';
        Inc(I, 2);
      end
      else
      begin
        P := PosEx('}', Text, I + 1);
        if P = 0 then
        begin
          Result := Result + Text[I];
          Inc(I);
        end
        else
        begin
          Name := Trim(Copy(Text, I + 1, P - I - 1));
          if TryGetVar(Name, Value) then
            Result := Result + Value
          else if (Name <> '') and (FWarnedVars.IndexOf(Name) < 0) then
          begin
            FWarnedVars.Add(Name);
            FLog.LogGeneral('Uyari: tanimsiz degisken: ' + Name);
          end;
          I := P + 1;
        end;
      end;
    end
    else
    begin
      Result := Result + Text[I];
      Inc(I);
    end;
  end;
end;

function TCommandEngine.ResolveTarget(const Target: string; out Index: Integer): Boolean;
var
  Number, P: Integer;
begin
  Result := False;
  Index := -1;
  if TryStrToInt(Target, Number) then
  begin
    if (Number >= 0) and (Number < FSource.Count) then
    begin
      Index := Number;
      Result := True;
    end;
    Exit;
  end;
  P := FLabels.IndexOfName(Target);
  if P >= 0 then
  begin
    Index := StrToInt(FLabels.ValueFromIndex[P]);
    Result := True;
  end;
end;

function TCommandEngine.RepeatExpired(const Seconds: Double): Boolean;
begin
  if FRepeatLine <> FPointer then
  begin
    FRepeatLine := FPointer;
    FRepeatStart := FClock.Now;
    Exit(False);
  end;
  Result := (Seconds > 0) and (FClock.Now >= FRepeatStart + (Seconds / SecsPerDay));
end;

function TCommandEngine.IfFalseTarget(Line: Integer): Integer;
begin
  if (Line >= 0) and (Line < Length(FIfFalseTarget)) then
    Result := FIfFalseTarget[Line]
  else
    Result := -1;
end;

function TCommandEngine.ElseEndTarget(Line: Integer): Integer;
begin
  if (Line >= 0) and (Line < Length(FElseEndTarget)) then
    Result := FElseEndTarget[Line]
  else
    Result := -1;
end;

procedure TCommandEngine.Start;
begin
  FPointer := 0;
  FLastLine := -1;
  FRepeatLine := -1;
  ResetVars;
  BuildStructure;
  if FStructureError <> '' then
  begin
    FLog.LogGeneral('Script: ' + FStructureError);
    FRunning := False;
    Exit;
  end;
  FRunning := True;
end;

procedure TCommandEngine.StartAt(Index: Integer);
begin
  FPointer := Index;
  FLastLine := Index;
  FRepeatLine := -1;
  ResetVars;
  BuildStructure;
  if FStructureError <> '' then
  begin
    FLog.LogGeneral('Script: ' + FStructureError);
    FRunning := False;
    Exit;
  end;
  FRunning := HasLine(Index);
end;

procedure TCommandEngine.Stop;
begin
  FRunning := False;
  FRepeatLine := -1;
end;

procedure TCommandEngine.JumpTo(Index: Integer);
begin
  FPointer := Index;
  FRepeatLine := -1;
end;

procedure TCommandEngine.Tick;
var
  Line: string;
begin
  if not FRunning then
    Exit;

  if not HasLine(FPointer) then
  begin
    Stop;
    Exit;
  end;

  if not FHost.CanDispatch then
  begin
    Inc(FPointer);
    FRepeatLine := -1;
    if not HasLine(FPointer) then
      Stop;
    Exit;
  end;

  Line := FSource[FPointer];
  FLastLine := FPointer;

  case DispatchLine(Line) of
    crNext:
      begin
        Inc(FPointer);
        FRepeatLine := -1;
      end;
    crRepeat: ;  // wait for the expected data
    crJump:
      FRepeatLine := -1;  // handler already moved the pointer
    crStop:
      Stop;
  end;
end;

function TCommandEngine.HasLine(Index: Integer): Boolean;
begin
  Result := (Index >= 0) and (Index < FSource.Count);
end;

function TCommandEngine.LineAt(Index: Integer): string;
begin
  if HasLine(Index) then
    Result := FSource[Index]
  else
    Result := '';
end;

function TCommandEngine.LineCount: Integer;
begin
  Result := FSource.Count;
end;

{ registration }

procedure TCommandEngine.RegisterDefaults;
begin
  // Commands are matched by their exact leading token, so registration
  // order does not matter for prefixes such as :WAIT / :WAIT_COMM.
  Register(TServerDisconnectCommand.Create(':SRV_DISCONNECT', FServer));
  Register(TServerSendCommand.Create(':SRV_SEND_HEX', True, FServer, FLog));
  Register(TServerSendCommand.Create(':SRV_SEND_TEXT', False, FServer, FLog));
  Register(TServerWaitCommand.Create(':SRV_WAIT_FOR_HEX', True, FServer, FLog));
  Register(TServerWaitCommand.Create(':SRV_WAIT_FOR_TEXT', False, FServer, FLog));
  Register(TServerListenCommand.Create(':SRV_LISTEN', FServer));
  Register(TServerSetupCommand.Create(':SRV_SETUP', FServer));
  Register(TClearBufferCommand.Create(':SRV_CLEAR_RCV_BUF', bkServer,
    FSerial, FTcp, FServer));

  Register(TTcpOpenCloseCommand.Create(':TCP_OPEN_CLOSE', FTcp));
  Register(TTcpSetupCommand.Create(':TCP_SETUP', FTcp));
  Register(TTcpSendCommand.Create(':TCP_SEND_HEX', True, FTcp));
  Register(TTcpSendCommand.Create(':TCP_SEND_TEXT', False, FTcp));
  Register(TTcpWaitCommand.Create(':TCP_WAIT_FOR_HEX', True, FTcp, FLog));
  Register(TTcpWaitCommand.Create(':TCP_WAIT_FOR_TEXT', False, FTcp, FLog));
  Register(TClearBufferCommand.Create(':TCP_CLEAR_RCV_BUF', bkTcp,
    FSerial, FTcp, FServer));

  Register(TSerialOpenCloseCommand.Create(':COMM_OPEN_CLOSE', FSerial, FHost));
  Register(TSerialSetupCommand.Create(':COMM_SETUP', FSerial));
  Register(TSerialWaitCommand.Create(':COM_WAIT_FOR_HEX', True, FSerial, FLog));
  Register(TSerialWaitCommand.Create(':COM_WAIT_FOR_TEXT', False, FSerial, FLog));
  Register(TClearBufferCommand.Create(':COM_CLEAR_RCV_BUF', bkSerial,
    FSerial, FTcp, FServer));

  Register(TWaitCommand.Create(':WAIT_COMM', wkComm, FWaiter));
  Register(TWaitCommand.Create(':WAIT_TCP', wkTcp, FWaiter));
  Register(TWaitCommand.Create(':WAIT', wkSeconds, FWaiter));

  Register(TSerialSendCommand.Create(':SEND_HEX_CRC', skHexCrc, FSerial));
  Register(TSerialSendCommand.Create(':SEND_HEX', skHex, FSerial));
  Register(TSerialSendCommand.Create(':SEND_TEXT', skText, FSerial));

  Register(TRecvTextCommand.Create(':COM_RECV_TEXT', bkSerial,
    FSerial, FTcp, FServer, FLog));
  Register(TRecvTextCommand.Create(':TCP_RECV_TEXT', bkTcp,
    FSerial, FTcp, FServer, FLog));
  Register(TRecvTextCommand.Create(':SRV_RECV_TEXT', bkServer,
    FSerial, FTcp, FServer, FLog));

  Register(TSetCommand.Create(':SET', FLog));
  Register(TLabelCommand.Create(':LABEL'));
  Register(TIfCommand.Create(':IF', FLog));
  Register(TElseCommand.Create(':ELSE', FLog));
  Register(TEndIfCommand.Create(':ENDIF'));
  Register(TEndIfCommand.Create(':END_IF'));

  Register(TGotoCommand.Create(':GOTO', FLog));
  Register(TEndCommand.Create(':END', FLog));
end;

procedure RegisterDefaultCommands(Engine: TCommandEngine);
begin
  Engine.RegisterDefaults;
end;

function CreateContextClientChannel(AContext: ICommandContext): IClientChannel;
var
  Roles: TContextRoles;
  LegacyTcp: ITcpChannel;
begin
  Roles := TContextRoles.Create(AContext);
  LegacyTcp := Roles;
  Result := TTcpClientChannel.Create(LegacyTcp);
end;

function CreateCommandEngineWithClient(ASource: TStrings;
  AContext: ICommandContext; AClient: IClientChannel;
  AClock: IClock): TCommandEngine;
var
  Roles: TContextRoles;
begin
  Roles := TContextRoles.Create(AContext);
  Result := TCommandEngine.CreateRoles(ASource, Roles, Roles, Roles,
    AClient, Roles, Roles, AClock);
end;

end.
