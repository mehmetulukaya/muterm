unit MuScriptSyntax;

{

Pure helpers for parsing MuTerm script lines.

The command engine used to keep these functions next to the command
classes. They have no dependency on the engine, the context or the UI,
so they live in their own unit: the parser can now be tested in
isolation and MuCommands only has to deal with command behaviour.

Nothing here evaluates expressions or executes commands; this is just
string handling for the ':COMMAND(...)' line syntax.

}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, StrUtils, MuLibs, MuExpr;

{ Returns the text between the first '(' and the matching ')'.
  The result is empty when the line has no complete argument list. }
function ArgsOf(const Line: string): string;

{ Returns the second space-separated token, used by ':WAIT 0.5'. }
function ArgumentOf(const Line: string): string;

{ Returns the leading ':COMMAND' token of a script line, upper-cased,
  or an empty string when the line is not a command. }
function CommandToken(const Line: string): string;

{ Finds the ')' that matches the '(' at OpenPos, ignoring parentheses
  inside quoted strings. }
function FindMatchingParen(const S: string; OpenPos: Integer;
  out ClosePos: Integer): Boolean;

{ Like ArgsOf, but requires a balanced argument list. }
function BalancedArgs(const Line: string; out Args: string): Boolean;

{ Splits an :IF line into its expression and the remainder after ')'.
  Rest is empty for block IF and starts with GOTO for a single-line IF. }
function ParseIfLine(const Line: string; out Expr, Rest: string): Boolean;

{ True for ':ENDIF', ':END_IF' and ':END IF'. }
function IsEndIfLine(const Line: string): Boolean;

{ Script identifiers start with a letter or '_' and continue with
  letters, digits or '_'. Variable and label names share this rule. }
function IsValidIdentifier(const S: string): Boolean;

{ Treats a trailing ',<number>' as an optional timeout. }
procedure SplitPatternTimeout(const Args: string; out Pattern: string;
  out Timeout: Double);

implementation

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

end.
