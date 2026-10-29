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
  Classes, Contnrs, SysUtils, StrUtils, MuLibs;

type

  TCommandResult = (crNext, crRepeat, crStop, crJump);

  { Everything the commands need from the application. Implemented by
    TfrmMain so that command classes stay UI-free. }
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
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; virtual; abstract;
  end;

  TServerDisconnectCommand = class(TCommand)
  public
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TServerSendCommand = class(TCommand)
  private
    FAsHex: Boolean;
  public
    constructor Create(const AName: string; AAsHex: Boolean);
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TServerWaitCommand = class(TCommand)
  private
    FAsHex: Boolean;
  public
    constructor Create(const AName: string; AAsHex: Boolean);
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TServerListenCommand = class(TCommand)
  public
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TServerSetupCommand = class(TCommand)
  public
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TTcpOpenCloseCommand = class(TCommand)
  public
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TTcpSetupCommand = class(TCommand)
  public
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TTcpSendCommand = class(TCommand)
  private
    FAsHex: Boolean;
  public
    constructor Create(const AName: string; AAsHex: Boolean);
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TTcpWaitCommand = class(TCommand)
  private
    FAsHex: Boolean;
  public
    constructor Create(const AName: string; AAsHex: Boolean);
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TSerialOpenCloseCommand = class(TCommand)
  public
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TSerialSetupCommand = class(TCommand)
  public
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TSendKind = (skHex, skText, skHexCrc);

  TSerialSendCommand = class(TCommand)
  private
    FKind: TSendKind;
  public
    constructor Create(const AName: string; AKind: TSendKind);
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TSerialWaitCommand = class(TCommand)
  private
    FAsHex: Boolean;
  public
    constructor Create(const AName: string; AAsHex: Boolean);
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TWaitKind = (wkSeconds, wkTcp, wkComm);

  TWaitCommand = class(TCommand)
  private
    FKind: TWaitKind;
  public
    constructor Create(const AName: string; AKind: TWaitKind);
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TGotoCommand = class(TCommand)
  public
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TEndCommand = class(TCommand)
  public
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TBufferKind = (bkSerial, bkTcp, bkServer);

  TClearBufferCommand = class(TCommand)
  private
    FKind: TBufferKind;
  public
    constructor Create(const AName: string; AKind: TBufferKind);
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TCommandEngine = class
  private
    FSource: TStrings;
    FContext: ICommandContext;
    FCommands: TObjectList;
    FPointer: Integer;
    FLastLine: Integer;
    FRunning: Boolean;
    function FindCommand(const Line: string): TCommand;
    function DispatchLine(const Line: string): TCommandResult;
  public
    constructor Create(ASource: TStrings; AContext: ICommandContext);
    destructor Destroy; override;

    procedure Register(Command: TCommand);
    procedure Start;
    procedure StartAt(Index: Integer);
    procedure Stop;
    procedure JumpTo(Index: Integer);
    procedure Tick;

    function HasLine(Index: Integer): Boolean;
    function LineAt(Index: Integer): string;
    function LineCount: Integer;

    property Running: Boolean read FRunning;
    property CurrentLine: Integer read FPointer;
    property LastLine: Integer read FLastLine;
  end;

procedure RegisterDefaultCommands(Engine: TCommandEngine);

implementation

{ helpers }

function ArgsOf(const Line: string): string;
var
  p1, p2: Integer;
begin
  Result := '';
  p1 := Pos('(', Line);
  if p1 = 0 then
    Exit;
  p2 := PosEx(')', Line, p1 + 1);
  if p2 = 0 then
    Exit;
  Result := Copy(Line, p1 + 1, p2 - p1 - 1);
end;

function ArgumentOf(const Line: string): string;
begin
  Result := GetNStr(Line, 2, ' ');
end;

{ TCommand }

constructor TCommand.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

{ TServerDisconnectCommand }

function TServerDisconnectCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
begin
  Ctx.ServerDisconnect;
  Result := crNext;
end;

{ TServerSendCommand }

constructor TServerSendCommand.Create(const AName: string; AAsHex: Boolean);
begin
  inherited Create(AName);
  FAsHex := AAsHex;
end;

function TServerSendCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
var
  Data: string;
begin
  Result := crNext;
  try
    if FAsHex then
      Data := HexToStr(ArgsOf(Line))
    else
      Data := StrToText(ArgsOf(Line));
    Ctx.SendServer(Data);
    if FAsHex then
      Ctx.LogGeneral('HexSnd:' + Data)
    else
      Ctx.LogGeneral('Snd:' + Data);
  except
  end;
end;

{ TServerWaitCommand }

constructor TServerWaitCommand.Create(const AName: string; AAsHex: Boolean);
begin
  inherited Create(AName);
  FAsHex := AAsHex;
end;

function TServerWaitCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
var
  Pattern, Buffer: string;
begin
  Result := crNext;
  try
    Pattern := ArgsOf(Line);
    if FAsHex then
      Pattern := HexToStr(Pattern);
    Buffer := Ctx.ServerBuffer;
    if Pos(Pattern, Buffer) > 0 then
    begin
      if FAsHex then
        Ctx.LogGeneral('Wait for hex OK:' + Buffer)
      else
        Ctx.LogGeneral('Wait for text OK:' + Buffer);
    end
    else
      Result := crRepeat;
  except
  end;
end;

{ TServerListenCommand }

function TServerListenCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
begin
  Ctx.ServerListen;
  Result := crNext;
end;

{ TServerSetupCommand }

function TServerSetupCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
begin
  Result := crNext;
  try
    Ctx.ConfigureServer(ArgsOf(Line));
  except
  end;
end;

{ TTcpOpenCloseCommand }

function TTcpOpenCloseCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
begin
  if Ctx.TcpConnected then
    Ctx.TcpDisconnect
  else
    Ctx.TcpConnect;
  Result := crNext;
end;

{ TTcpSetupCommand }

function TTcpSetupCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
var
  Host, Port: string;
begin
  Result := crNext;
  try
    Host := GetNStr(ArgsOf(Line), 1, ',');
    Port := GetNStr(ArgsOf(Line), 2, ',');
    if (Host <> '') and (Port <> '') then
      Ctx.ConfigureTcp(Host, Port);
  except
  end;
end;

{ TTcpSendCommand }

constructor TTcpSendCommand.Create(const AName: string; AAsHex: Boolean);
begin
  inherited Create(AName);
  FAsHex := AAsHex;
end;

function TTcpSendCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
var
  Data: string;
begin
  Result := crNext;
  try
    if FAsHex then
      Data := HexToStr(ArgsOf(Line))
    else
      Data := StrToText(ArgsOf(Line));
    Ctx.SendTcp(Data);
  except
  end;
end;

{ TTcpWaitCommand }

constructor TTcpWaitCommand.Create(const AName: string; AAsHex: Boolean);
begin
  inherited Create(AName);
  FAsHex := AAsHex;
end;

function TTcpWaitCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
var
  Pattern, Buffer: string;
begin
  Result := crNext;
  try
    Pattern := ArgsOf(Line);
    if FAsHex then
      Pattern := HexToStr(Pattern);
    Buffer := Ctx.TcpBuffer;
    if Pos(Pattern, Buffer) > 0 then
    begin
      if FAsHex then
        Ctx.LogGeneral('Wait for hex OK:' + Buffer)
      else
        Ctx.LogGeneral('Wait for text OK:' + Buffer);
    end
    else
      Result := crRepeat;
  except
  end;
end;

{ TSerialOpenCloseCommand }

function TSerialOpenCloseCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
begin
  if Ctx.SerialActive then
  begin
    Ctx.SerialClose;
    Ctx.SetMarker(Engine.CurrentLine + 1);
  end
  else
    Ctx.SerialOpen;
  Result := crNext;
end;

{ TSerialSetupCommand }

function TSerialSetupCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
var
  Args: string;
begin
  Result := crNext;
  try
    Args := ArgsOf(Line);
    Ctx.ConfigureSerial(
      GetNStr(Args, 1, ','),
      GetNStr(Args, 2, ','),
      GetNStr(Args, 3, ','),
      GetNStr(Args, 4, ','),
      GetNStr(Args, 5, ','));
  except
  end;
end;

{ TSerialSendCommand }

constructor TSerialSendCommand.Create(const AName: string; AKind: TSendKind);
begin
  inherited Create(AName);
  FKind := AKind;
end;

function TSerialSendCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
var
  Data: string;
begin
  Result := crNext;
  try
    Data := ArgsOf(Line);
    case FKind of
      skHex:    Data := HexToStr(Data);
      skText:   Data := StrToText(Data);
      skHexCrc:
        begin
          Data := HexToStr(Data);
          Data := Data + CRC16(Data);
        end;
    end;
    Ctx.SendSerial(Data);
  except
  end;
end;

{ TSerialWaitCommand }

constructor TSerialWaitCommand.Create(const AName: string; AAsHex: Boolean);
begin
  inherited Create(AName);
  FAsHex := AAsHex;
end;

function TSerialWaitCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
var
  Pattern, Buffer: string;
begin
  Result := crNext;
  try
    Pattern := ArgsOf(Line);
    if FAsHex then
      Pattern := HexToStr(Pattern);
    Buffer := Ctx.SerialBuffer;
    if Pos(Pattern, Buffer) > 0 then
    begin
      if FAsHex then
        Ctx.LogGeneral('Wait for hex OK:' + Buffer)
      else
        Ctx.LogGeneral('Wait for text OK:' + Buffer);
    end
    else
      Result := crRepeat;
  except
  end;
end;

{ TWaitCommand }

constructor TWaitCommand.Create(const AName: string; AKind: TWaitKind);
begin
  inherited Create(AName);
  FKind := AKind;
end;

function TWaitCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
var
  Seconds: Double;
begin
  Result := crNext;
  try
    Seconds := StrToFloat(ArgumentOf(Line));
  except
    Exit;
  end;
  case FKind of
    wkSeconds: Ctx.WaitSeconds(Seconds);
    wkTcp:     Ctx.WaitTcpSeconds(Seconds);
    wkComm:    Ctx.WaitCommSeconds(Seconds);
  end;
end;

{ TGotoCommand }

function TGotoCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
var
  Target: Integer;
begin
  Result := crNext;
  try
    Target := StrToInt(ArgumentOf(Line));
  except
    Exit;
  end;
  Engine.JumpTo(Target);
  Ctx.LogGeneral('GOTO:> ' + IntToStr(Target));
  Result := crJump;
end;

{ TEndCommand }

function TEndCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
begin
  Ctx.LogGeneral('END. ');
  Result := crStop;
end;

{ TClearBufferCommand }

constructor TClearBufferCommand.Create(const AName: string; AKind: TBufferKind);
begin
  inherited Create(AName);
  FKind := AKind;
end;

function TClearBufferCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
begin
  case FKind of
    bkSerial: Ctx.ClearSerialBuffer;
    bkTcp:    Ctx.ClearTcpBuffer;
    bkServer: Ctx.ClearServerBuffer;
  end;
  Result := crNext;
end;

{ TCommandEngine }

constructor TCommandEngine.Create(ASource: TStrings; AContext: ICommandContext);
begin
  inherited Create;
  FSource := ASource;
  FContext := AContext;
  FCommands := TObjectList.Create(True);
  FPointer := 0;
  FLastLine := -1;
  FRunning := False;
end;

destructor TCommandEngine.Destroy;
begin
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
  i: Integer;
begin
  for i := 0 to FCommands.Count - 1 do
  begin
    Result := TCommand(FCommands[i]);
    if Pos(Result.Name, Line) > 0 then
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
    Result := Cmd.Execute(FContext, Self, Line)
  else
  begin
    FContext.SendDefaultLine(Line);
    Result := crNext;
  end;
end;

procedure TCommandEngine.Start;
begin
  FPointer := 0;
  FLastLine := -1;
  FRunning := True;
end;

procedure TCommandEngine.StartAt(Index: Integer);
begin
  FPointer := Index;
  FLastLine := Index;
  FRunning := True;
end;

procedure TCommandEngine.Stop;
begin
  FRunning := False;
end;

procedure TCommandEngine.JumpTo(Index: Integer);
begin
  FPointer := Index;
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

  if not FContext.CanDispatch then
  begin
    Inc(FPointer);
    if not HasLine(FPointer) then
      Stop;
    Exit;
  end;

  Line := FSource[FPointer];
  FLastLine := FPointer;

  case DispatchLine(Line) of
    crNext:   Inc(FPointer);
    crRepeat: ;  // wait for the expected data
    crJump:   ;  // handler already moved the pointer
    crStop:   Stop;
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

procedure RegisterDefaultCommands(Engine: TCommandEngine);
begin
  // More specific names must be registered before their prefixes
  // (:WAIT_COMM before :WAIT, :SEND_HEX_CRC before :SEND_HEX, ...).

  Engine.Register(TServerDisconnectCommand.Create(':SRV_DISCONNECT'));
  Engine.Register(TServerSendCommand.Create(':SRV_SEND_HEX', True));
  Engine.Register(TServerSendCommand.Create(':SRV_SEND_TEXT', False));
  Engine.Register(TServerWaitCommand.Create(':SRV_WAIT_FOR_HEX', True));
  Engine.Register(TServerWaitCommand.Create(':SRV_WAIT_FOR_TEXT', False));
  Engine.Register(TServerListenCommand.Create(':SRV_LISTEN'));
  Engine.Register(TServerSetupCommand.Create(':SRV_SETUP'));
  Engine.Register(TClearBufferCommand.Create(':SRV_CLEAR_RCV_BUF', bkServer));

  Engine.Register(TTcpOpenCloseCommand.Create(':TCP_OPEN_CLOSE'));
  Engine.Register(TTcpSetupCommand.Create(':TCP_SETUP'));
  Engine.Register(TTcpSendCommand.Create(':TCP_SEND_HEX', True));
  Engine.Register(TTcpSendCommand.Create(':TCP_SEND_TEXT', False));
  Engine.Register(TTcpWaitCommand.Create(':TCP_WAIT_FOR_HEX', True));
  Engine.Register(TTcpWaitCommand.Create(':TCP_WAIT_FOR_TEXT', False));
  Engine.Register(TClearBufferCommand.Create(':TCP_CLEAR_RCV_BUF', bkTcp));

  Engine.Register(TSerialOpenCloseCommand.Create(':COMM_OPEN_CLOSE'));
  Engine.Register(TSerialSetupCommand.Create(':COMM_SETUP'));
  Engine.Register(TSerialWaitCommand.Create(':COM_WAIT_FOR_HEX', True));
  Engine.Register(TSerialWaitCommand.Create(':COM_WAIT_FOR_TEXT', False));
  Engine.Register(TClearBufferCommand.Create(':COM_CLEAR_RCV_BUF', bkSerial));

  Engine.Register(TWaitCommand.Create(':WAIT_COMM', wkComm));
  Engine.Register(TWaitCommand.Create(':WAIT_TCP', wkTcp));
  Engine.Register(TWaitCommand.Create(':WAIT', wkSeconds));

  Engine.Register(TSerialSendCommand.Create(':SEND_HEX_CRC', skHexCrc));
  Engine.Register(TSerialSendCommand.Create(':SEND_HEX', skHex));
  Engine.Register(TSerialSendCommand.Create(':SEND_TEXT', skText));

  Engine.Register(TGotoCommand.Create(':GOTO'));
  Engine.Register(TEndCommand.Create(':END'));
end;

end.
