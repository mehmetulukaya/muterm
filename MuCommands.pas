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
  Classes, Contnrs, SysUtils, StrUtils, MuLibs, MuExpr;

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

  TIfCommand = class(TCommand)
  public
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TElseCommand = class(TCommand)
  public
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TEndIfCommand = class(TCommand)
  public
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TSetCommand = class(TCommand)
  public
    function Execute(Ctx: ICommandContext; Engine: TCommandEngine;
      const Line: string): TCommandResult; override;
  end;

  TLabelCommand = class(TCommand)
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

  TRecvTextCommand = class(TCommand)
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

    function FindCommand(const Line: string): TCommand;
    function DispatchLine(const Line: string): TCommandResult;
    procedure BuildStructure;
    procedure ResetVars;
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

{ Returns the leading ':COMMAND' token of a script line. }
function CommandToken(const Line: string): string;
var
  S: string;
  P: Integer;
begin
  S := Trim(Line);
  if (S = '') or (S[1] <> ':') then
    Exit('');
  P := 2;
  while (P <= Length(S)) and not (S[P] in ['(', ' ', #9]) do
    Inc(P);
  Result := UpperCase(Copy(S, 1, P - 1));
end;

{ Finds the ')' that matches the '(' at OpenPos, ignoring parentheses
  inside quoted strings. }
function FindMatchingParen(const S: string; OpenPos: Integer;
  out ClosePos: Integer): Boolean;
var
  I, Depth: Integer;
  InQuote: Boolean;
begin
  Result := False;
  ClosePos := 0;
  Depth := 0;
  InQuote := False;
  I := OpenPos;
  while I <= Length(S) do
  begin
    if InQuote then
    begin
      if S[I] = '''' then
      begin
        if (I < Length(S)) and (S[I + 1] = '''') then
          Inc(I)
        else
          InQuote := False;
      end;
    end
    else
    begin
      case S[I] of
        '''':
          InQuote := True;
        '(':
          Inc(Depth);
        ')':
          begin
            Dec(Depth);
            if Depth = 0 then
            begin
              ClosePos := I;
              Exit(True);
            end;
          end;
      end;
    end;
    Inc(I);
  end;
end;

function BalancedArgs(const Line: string; out Args: string): Boolean;
var
  P, ClosePos: Integer;
begin
  Result := False;
  Args := '';
  P := Pos('(', Line);
  if P = 0 then
    Exit;
  if not FindMatchingParen(Line, P, ClosePos) then
    Exit;
  Args := Copy(Line, P + 1, ClosePos - P - 1);
  Result := True;
end;

{ Splits an :IF line into its expression and the remainder after ')'.
  Rest is empty for block IF and starts with GOTO for a single-line IF. }
function ParseIfLine(const Line: string; out Expr, Rest: string): Boolean;
var
  S: string;
  P, ClosePos: Integer;
begin
  Result := False;
  Expr := '';
  Rest := '';
  S := Trim(Line);
  if not SameText(Copy(S, 1, 3), ':IF') then
    Exit;
  P := 4;
  while (P <= Length(S)) and (S[P] in [' ', #9]) do
    Inc(P);
  if (P > Length(S)) or (S[P] <> '(') then
    Exit;
  if not FindMatchingParen(S, P, ClosePos) then
    Exit;
  Expr := Trim(Copy(S, P + 1, ClosePos - P - 1));
  Rest := Trim(Copy(S, ClosePos + 1, MaxInt));
  Result := True;
end;

function IsEndIfLine(const Line: string): Boolean;
var
  S, Tok, Rest: string;
begin
  S := Trim(Line);
  Tok := CommandToken(S);
  if (Tok = ':ENDIF') or (Tok = ':END_IF') then
    Exit(True);
  Result := False;
  if Tok = ':END' then
  begin
    Rest := Trim(Copy(S, Length(':END') + 1, MaxInt));
    Result := SameText(Rest, 'IF');
  end;
end;

function IsValidIdentifier(const S: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if S = '' then
    Exit;
  if not (S[1] in ['A'..'Z', 'a'..'z', '_']) then
    Exit;
  for I := 2 to Length(S) do
    if not (S[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Exit;
  Result := True;
end;

{ Treats a trailing ',<number>' as an optional timeout. }
procedure SplitPatternTimeout(const Args: string; out Pattern: string;
  out Timeout: Double);
var
  P: Integer;
  Tail: string;
  N: Double;
begin
  Pattern := Args;
  Timeout := 0;
  P := LastDelimiter(',', Args);
  if P > 0 then
  begin
    Tail := Trim(Copy(Args, P + 1, MaxInt));
    if TryNumber(Tail, N) then
    begin
      Timeout := N;
      Pattern := Copy(Args, 1, P - 1);
    end;
  end;
end;

function WaitForText(Ctx: ICommandContext; Engine: TCommandEngine;
  const Pattern, Buffer: string; Timeout: Double; AsHex: Boolean): TCommandResult;
begin
  Result := crNext;
  if Pos(Pattern, Buffer) > 0 then
  begin
    Engine.SetVar('TIMEOUT', '0');
    if AsHex then
      Ctx.LogGeneral('Wait for hex OK:' + Buffer)
    else
      Ctx.LogGeneral('Wait for text OK:' + Buffer);
  end
  else if (Timeout > 0) and Engine.RepeatExpired(Timeout) then
  begin
    Engine.SetVar('TIMEOUT', '1');
    Ctx.LogGeneral('Wait timeout: ' + Pattern);
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
    begin
      Data := Engine.ExpandVars(ArgsOf(Line));
      Data := HexToStr(Data);
    end
    else
    begin
      Data := StrToText(ArgsOf(Line));
      Data := Engine.ExpandVars(Data);
    end;
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
    Buffer := Ctx.ServerBuffer;
    Result := WaitForText(Ctx, Engine, Pattern, Buffer, Timeout, FAsHex);
  except
    on E: Exception do
    begin
      Ctx.LogGeneral('WAIT: ' + E.Message);
      Result := crStop;
    end;
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
    begin
      Data := Engine.ExpandVars(ArgsOf(Line));
      Data := HexToStr(Data);
    end
    else
    begin
      Data := StrToText(ArgsOf(Line));
      Data := Engine.ExpandVars(Data);
    end;
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
    Buffer := Ctx.TcpBuffer;
    Result := WaitForText(Ctx, Engine, Pattern, Buffer, Timeout, FAsHex);
  except
    on E: Exception do
    begin
      Ctx.LogGeneral('WAIT: ' + E.Message);
      Result := crStop;
    end;
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
    Buffer := Ctx.SerialBuffer;
    Result := WaitForText(Ctx, Engine, Pattern, Buffer, Timeout, FAsHex);
  except
    on E: Exception do
    begin
      Ctx.LogGeneral('WAIT: ' + E.Message);
      Result := crStop;
    end;
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
  if not TryNumber(ArgumentOf(Line), Seconds) then
    Exit;
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
  TargetName: string;
  Target: Integer;
begin
  TargetName := Trim(Copy(Trim(Line), Length(':GOTO') + 1, MaxInt));
  if Engine.ResolveTarget(TargetName, Target) then
  begin
    Engine.JumpTo(Target);
    Ctx.LogGeneral('GOTO:> ' + TargetName);
    Result := crJump;
  end
  else
  begin
    Ctx.LogGeneral('GOTO: hedef bulunamadi: ' + TargetName);
    Result := crStop;
  end;
end;

{ TIfCommand }

function TIfCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
var
  Expr, Rest, TargetName: string;
  Target: Integer;
  Cond: Boolean;
begin
  Result := crNext;
  if not ParseIfLine(Line, Expr, Rest) then
  begin
    Ctx.LogGeneral('IF: sozdizimi hatasi: ' + Line);
    Exit(crStop);
  end;

  try
    Cond := ExprToBool(EvalExpression(Expr, @Engine.ResolveVariable));
  except
    on E: Exception do
    begin
      Ctx.LogGeneral('IF: ' + E.Message);
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
        Ctx.LogGeneral('IF: eslesen END IF yok');
        Result := crStop;
      end;
    end;
  end
  else
  begin
    { Single-line IF: :IF(expr) GOTO label }
    if not StartsText('GOTO', Rest) then
    begin
      Ctx.LogGeneral('IF: GOTO bekleniyordu: ' + Rest);
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
        Ctx.LogGeneral('IF: hedef bulunamadi: ' + TargetName);
        Result := crStop;
      end;
    end;
  end;
end;

{ TElseCommand }

function TElseCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
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
    Ctx.LogGeneral('ELSE: eslesen IF yok');
    Result := crStop;
  end;
end;

{ TEndIfCommand }

function TEndIfCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
begin
  Result := crNext;
end;

{ TSetCommand }

function TSetCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
var
  Args, VarName, Value: string;
  P: Integer;
begin
  Result := crNext;
  if not BalancedArgs(Line, Args) then
  begin
    Ctx.LogGeneral('SET: sozdizimi hatasi');
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
    Ctx.LogGeneral('SET: gecersiz degisken adi: ' + VarName);
    Exit(crStop);
  end;

  Value := StrToText(Value);
  Value := Engine.ExpandVars(Value);
  Engine.SetVar(VarName, Value);
end;

{ TLabelCommand }

function TLabelCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
begin
  Result := crNext;
end;

{ TEndCommand }

function TEndCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
var
  Rest: string;
begin
  Rest := Trim(Copy(Trim(Line), Length(':END') + 1, MaxInt));
  if SameText(Rest, 'IF') then
    Result := crNext
  else
  begin
    Ctx.LogGeneral('END. ');
    Result := crStop;
  end;
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

{ TRecvTextCommand }

constructor TRecvTextCommand.Create(const AName: string; AKind: TBufferKind);
begin
  inherited Create(AName);
  FKind := AKind;
end;

function TRecvTextCommand.Execute(Ctx: ICommandContext;
  Engine: TCommandEngine; const Line: string): TCommandResult;
var
  Args, VarName, TimeoutText, Buffer: string;
  P: Integer;
  Timeout: Double;
begin
  Result := crNext;
  TimeoutText := '';
  if not BalancedArgs(Line, Args) then
  begin
    Ctx.LogGeneral('RECV_TEXT: sozdizimi hatasi');
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
    Ctx.LogGeneral('RECV_TEXT: gecersiz degisken adi: ' + VarName);
    Exit(crStop);
  end;

  case FKind of
    bkSerial: Buffer := Ctx.SerialBuffer;
    bkTcp:    Buffer := Ctx.TcpBuffer;
    bkServer: Buffer := Ctx.ServerBuffer;
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

constructor TCommandEngine.Create(ASource: TStrings; AContext: ICommandContext);
begin
  inherited Create;
  FSource := ASource;
  FContext := AContext;
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
    Result := Cmd.Execute(FContext, Self, Line)
  else
  begin
    FContext.SendDefaultLine(Line);
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
      FContext.LogGeneral('Uyari: tanimsiz degisken: ' + Name);
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
            FContext.LogGeneral('Uyari: tanimsiz degisken: ' + Name);
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
    FRepeatStart := Now;
    Exit(False);
  end;
  Result := (Seconds > 0) and (Now >= FRepeatStart + (Seconds / SecsPerDay));
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
    FContext.LogGeneral('Script: ' + FStructureError);
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
    FContext.LogGeneral('Script: ' + FStructureError);
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

  if not FContext.CanDispatch then
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

procedure RegisterDefaultCommands(Engine: TCommandEngine);
begin
  // Commands are matched by their exact leading token, so registration
  // order does not matter for prefixes such as :WAIT / :WAIT_COMM.

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

  Engine.Register(TRecvTextCommand.Create(':COM_RECV_TEXT', bkSerial));
  Engine.Register(TRecvTextCommand.Create(':TCP_RECV_TEXT', bkTcp));
  Engine.Register(TRecvTextCommand.Create(':SRV_RECV_TEXT', bkServer));

  Engine.Register(TSetCommand.Create(':SET'));
  Engine.Register(TLabelCommand.Create(':LABEL'));
  Engine.Register(TIfCommand.Create(':IF'));
  Engine.Register(TElseCommand.Create(':ELSE'));
  Engine.Register(TEndIfCommand.Create(':ENDIF'));
  Engine.Register(TEndIfCommand.Create(':END_IF'));

  Engine.Register(TGotoCommand.Create(':GOTO'));
  Engine.Register(TEndCommand.Create(':END'));
end;

end.
