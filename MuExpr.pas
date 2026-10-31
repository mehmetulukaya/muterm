unit MuExpr;

{

Small expression evaluator for the MuTerm script command engine.

Supported syntax:

  'text'  #013  #$0D          string / character literals
  name                         variable (resolved by the caller)
  POS(haystack, needle)        1-based position, 0 when not found
  POSP(needle, haystack)       Pascal argument order
  CONTAINS(haystack, needle)   boolean
  LEN(s) TRIM(s) UPPER(s) LOWER(s)
  =  <>  <  >  <=  >=
  not  and  or  ( )

Results are strings. Boolean results are '1' / '0'; use ExprToBool.

}

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  { Returns True and sets Value when Name is a known variable. }
  TVariableResolver = function(const Name: string; out Value: string): Boolean of object;

  TExprError = class(Exception);

function EvalExpression(const Expr: string; Resolver: TVariableResolver): string;
function ExprToBool(const Value: string): Boolean;
function TryNumber(const S: string; out N: Double): Boolean;

implementation

type
  TTokenKind = (tkEOF, tkString, tkNumber, tkIdent, tkLParen, tkRParen,
    tkComma, tkEqual, tkNotEqual, tkLess, tkLessEq, tkGreater, tkGreaterEq,
    tkAnd, tkOr, tkNot);

  TToken = record
    Kind: TTokenKind;
    Text: string;
  end;

  TExprParser = class
  private
    FSource: string;
    FTokens: array of TToken;
    FPos: Integer;
    FResolver: TVariableResolver;
    procedure Tokenize;
    procedure AddToken(Kind: TTokenKind; const Text: string);
    function Current: TToken;
    procedure Next;
    procedure Expect(Kind: TTokenKind; const What: string);
    function ReadCharCode(var Index: Integer): string;
    function ParseOr: string;
    function ParseAnd: string;
    function ParseNot: string;
    function ParseComparison: string;
    function ParsePrimary: string;
    function CallFunction(const Name: string; const Args: array of string): string;
    function ResolveName(const Name: string): string;
  public
    constructor Create(const ASource: string; AResolver: TVariableResolver);
    function Parse: string;
  end;

function BoolText(B: Boolean): string;
begin
  if B then
    Result := '1'
  else
    Result := '0';
end;

function DecodeText(const S: string): string;
var
  I, Start, Code: Integer;
  Digits: string;
  Hex: Boolean;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if S[I] <> '#' then
    begin
      Result := Result + S[I];
      Inc(I);
      Continue;
    end;

    if (I < Length(S)) and (S[I + 1] = '#') then
    begin
      Result := Result + '#';
      Inc(I, 2);
      Continue;
    end;

    Inc(I); // skip '#'
    Hex := False;
    if (I <= Length(S)) and (S[I] = '$') then
    begin
      Hex := True;
      Inc(I);
    end;
    Start := I;
    if Hex then
    begin
      while (I <= Length(S)) and (S[I] in ['0'..'9', 'A'..'F', 'a'..'f']) do
        Inc(I);
    end
    else
    begin
      while (I <= Length(S)) and (S[I] in ['0'..'9']) do
        Inc(I);
    end;
    Digits := Copy(S, Start, I - Start);
    if Digits = '' then
    begin
      Result := Result + '#';
      Continue;
    end;
    if Hex then
      Code := StrToInt('$' + Digits)
    else
      Code := StrToInt(Digits);
    Result := Result + Chr(Byte(Code and $FF));
  end;
end;

{ TExprParser }

constructor TExprParser.Create(const ASource: string; AResolver: TVariableResolver);
begin
  inherited Create;
  FSource := ASource;
  FResolver := AResolver;
  FPos := 0;
  Tokenize;
end;

procedure TExprParser.AddToken(Kind: TTokenKind; const Text: string);
begin
  SetLength(FTokens, Length(FTokens) + 1);
  FTokens[High(FTokens)].Kind := Kind;
  FTokens[High(FTokens)].Text := Text;
end;

function TExprParser.Current: TToken;
begin
  Result := FTokens[FPos];
end;

procedure TExprParser.Next;
begin
  if FPos < High(FTokens) then
    Inc(FPos);
end;

procedure TExprParser.Expect(Kind: TTokenKind; const What: string);
begin
  if Current.Kind <> Kind then
    raise TExprError.CreateFmt('%s bekleniyordu, bulunan: %s', [What, Current.Text]);
  Next;
end;

function TExprParser.ReadCharCode(var Index: Integer): string;
var
  Start, Code: Integer;
  Digits: string;
  Hex: Boolean;
begin
  Inc(Index); // skip '#'
  Hex := False;
  if (Index <= Length(FSource)) and (FSource[Index] = '$') then
  begin
    Hex := True;
    Inc(Index);
  end;
  Start := Index;
  if Hex then
  begin
    while (Index <= Length(FSource)) and (FSource[Index] in ['0'..'9', 'A'..'F', 'a'..'f']) do
      Inc(Index);
  end
  else
  begin
    while (Index <= Length(FSource)) and (FSource[Index] in ['0'..'9']) do
      Inc(Index);
  end;
  Digits := Copy(FSource, Start, Index - Start);
  if Digits = '' then
    raise TExprError.Create('Karakter kodu eksik');
  if Hex then
    Code := StrToInt('$' + Digits)
  else
    Code := StrToInt(Digits);
  Result := Chr(Byte(Code and $FF));
end;

procedure TExprParser.Tokenize;
var
  I, N: Integer;
  C: Char;
  S: string;
begin
  SetLength(FTokens, 0);
  I := 1;
  N := Length(FSource);
  while I <= N do
  begin
    C := FSource[I];
    if C in [' ', #9, #10, #13] then
      Inc(I)
    else if C = '(' then
    begin
      AddToken(tkLParen, '(');
      Inc(I);
    end
    else if C = ')' then
    begin
      AddToken(tkRParen, ')');
      Inc(I);
    end
    else if C = ',' then
    begin
      AddToken(tkComma, ',');
      Inc(I);
    end
    else if C = '=' then
    begin
      AddToken(tkEqual, '=');
      Inc(I);
    end
    else if C = '<' then
    begin
      if (I < N) and (FSource[I + 1] = '>') then
      begin
        AddToken(tkNotEqual, '<>');
        Inc(I, 2);
      end
      else if (I < N) and (FSource[I + 1] = '=') then
      begin
        AddToken(tkLessEq, '<=');
        Inc(I, 2);
      end
      else
      begin
        AddToken(tkLess, '<');
        Inc(I);
      end;
    end
    else if C = '>' then
    begin
      if (I < N) and (FSource[I + 1] = '=') then
      begin
        AddToken(tkGreaterEq, '>=');
        Inc(I, 2);
      end
      else
      begin
        AddToken(tkGreater, '>');
        Inc(I);
      end;
    end
    else if C = '''' then
    begin
      S := '';
      Inc(I);
      while I <= N do
      begin
        if FSource[I] = '''' then
        begin
          if (I < N) and (FSource[I + 1] = '''') then
          begin
            S := S + '''';
            Inc(I, 2);
          end
          else
          begin
            Inc(I);
            Break;
          end;
        end
        else
        begin
          S := S + FSource[I];
          Inc(I);
        end;
      end;
      AddToken(tkString, DecodeText(S));
    end
    else if C = '#' then
      AddToken(tkString, ReadCharCode(I))
    else if C in ['0'..'9'] then
    begin
      S := '';
      while (I <= N) and (FSource[I] in ['0'..'9', '.']) do
      begin
        S := S + FSource[I];
        Inc(I);
      end;
      AddToken(tkNumber, S);
    end
    else if C in ['A'..'Z', 'a'..'z', '_'] then
    begin
      S := '';
      while (I <= N) and (FSource[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
      begin
        S := S + FSource[I];
        Inc(I);
      end;
      if SameText(S, 'and') then
        AddToken(tkAnd, S)
      else if SameText(S, 'or') then
        AddToken(tkOr, S)
      else if SameText(S, 'not') then
        AddToken(tkNot, S)
      else
        AddToken(tkIdent, S);
    end
    else
      raise TExprError.CreateFmt('Beklenmeyen karakter: %s', [C]);
  end;
  AddToken(tkEOF, '');
end;

function TExprParser.Parse: string;
begin
  Result := ParseOr;
  if Current.Kind <> tkEOF then
    raise TExprError.CreateFmt('Fazla ifade: %s', [Current.Text]);
end;

function TExprParser.ParseOr: string;
var
  R: string;
begin
  Result := ParseAnd;
  while Current.Kind = tkOr do
  begin
    Next;
    R := ParseAnd;
    Result := BoolText(ExprToBool(Result) or ExprToBool(R));
  end;
end;

function TExprParser.ParseAnd: string;
var
  R: string;
begin
  Result := ParseNot;
  while Current.Kind = tkAnd do
  begin
    Next;
    R := ParseNot;
    Result := BoolText(ExprToBool(Result) and ExprToBool(R));
  end;
end;

function TExprParser.ParseNot: string;
begin
  if Current.Kind = tkNot then
  begin
    Next;
    Result := BoolText(not ExprToBool(ParseNot()));
  end
  else
    Result := ParseComparison;
end;

function TExprParser.ParseComparison: string;
var
  L, R: string;
  Op: TTokenKind;
  LN, RN: Double;
  LNum, RNum: Boolean;
  Cmp: Integer;
begin
  L := ParsePrimary;
  if Current.Kind in [tkEqual, tkNotEqual, tkLess, tkLessEq, tkGreater, tkGreaterEq] then
  begin
    Op := Current.Kind;
    Next;
    R := ParsePrimary;
    LNum := TryNumber(L, LN);
    RNum := TryNumber(R, RN);
    if LNum and RNum then
    begin
      if LN < RN then
        Cmp := -1
      else if LN > RN then
        Cmp := 1
      else
        Cmp := 0;
    end
    else
      Cmp := CompareStr(L, R);

    case Op of
      tkEqual:     Result := BoolText(Cmp = 0);
      tkNotEqual:  Result := BoolText(Cmp <> 0);
      tkLess:      Result := BoolText(Cmp < 0);
      tkLessEq:    Result := BoolText(Cmp <= 0);
      tkGreater:   Result := BoolText(Cmp > 0);
      tkGreaterEq: Result := BoolText(Cmp >= 0);
    else
      Result := L;
    end;
  end
  else
    Result := L;
end;

function TExprParser.ParsePrimary: string;
var
  Name: string;
  Args: array of string;
  ArgCount: Integer;
begin
  case Current.Kind of
    tkNumber:
      begin
        Result := Current.Text;
        Next;
      end;
    tkString:
      begin
        Result := '';
        while Current.Kind = tkString do
        begin
          Result := Result + Current.Text;
          Next;
        end;
      end;
    tkLParen:
      begin
        Next;
        Result := ParseOr;
        Expect(tkRParen, ')');
      end;
    tkIdent:
      begin
        Name := Current.Text;
        Next;
        if Current.Kind = tkLParen then
        begin
          Next;
          ArgCount := 0;
          SetLength(Args, 0);
          if Current.Kind <> tkRParen then
          begin
            repeat
              SetLength(Args, ArgCount + 1);
              Args[ArgCount] := ParseOr;
              Inc(ArgCount);
              if Current.Kind = tkComma then
                Next
              else
                Break;
            until False;
          end;
          Expect(tkRParen, ')');
          Result := CallFunction(Name, Args);
        end
        else
          Result := ResolveName(Name);
      end;
  else
    raise TExprError.CreateFmt('Ifade bekleniyordu: %s', [Current.Text]);
  end;
end;

function TExprParser.CallFunction(const Name: string; const Args: array of string): string;
begin
  if SameText(Name, 'POS') then
  begin
    if Length(Args) <> 2 then
      raise TExprError.Create('POS iki arguman ister');
    Result := IntToStr(Pos(Args[1], Args[0]));
  end
  else if SameText(Name, 'POSP') then
  begin
    if Length(Args) <> 2 then
      raise TExprError.Create('POSP iki arguman ister');
    Result := IntToStr(Pos(Args[0], Args[1]));
  end
  else if SameText(Name, 'CONTAINS') then
  begin
    if Length(Args) <> 2 then
      raise TExprError.Create('CONTAINS iki arguman ister');
    Result := BoolText(Pos(Args[1], Args[0]) > 0);
  end
  else if SameText(Name, 'LEN') then
  begin
    if Length(Args) <> 1 then
      raise TExprError.Create('LEN bir arguman ister');
    Result := IntToStr(Length(Args[0]));
  end
  else if SameText(Name, 'TRIM') then
  begin
    if Length(Args) <> 1 then
      raise TExprError.Create('TRIM bir arguman ister');
    Result := Trim(Args[0]);
  end
  else if SameText(Name, 'UPPER') then
  begin
    if Length(Args) <> 1 then
      raise TExprError.Create('UPPER bir arguman ister');
    Result := UpperCase(Args[0]);
  end
  else if SameText(Name, 'LOWER') then
  begin
    if Length(Args) <> 1 then
      raise TExprError.Create('LOWER bir arguman ister');
    Result := LowerCase(Args[0]);
  end
  else
    raise TExprError.CreateFmt('Bilinmeyen fonksiyon: %s', [Name]);
end;

function TExprParser.ResolveName(const Name: string): string;
begin
  if Assigned(FResolver) and FResolver(Name, Result) then
    Exit;
  Result := '';
end;

function ExprToBool(const Value: string): Boolean;
var
  V: string;
  N: Double;
begin
  V := Trim(Value);
  if V = '' then
  begin
    Result := False;
    Exit;
  end;
  if TryNumber(V, N) then
  begin
    Result := N <> 0;
    Exit;
  end;
  Result := not (SameText(V, 'false') or SameText(V, 'no') or SameText(V, 'off'));
end;

function TryNumber(const S: string; out N: Double): Boolean;
var
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  FS.ThousandSeparator := #0;
  Result := TryStrToFloat(Trim(S), N, FS);
end;

function EvalExpression(const Expr: string; Resolver: TVariableResolver): string;
var
  Parser: TExprParser;
begin
  Parser := TExprParser.Create(Expr, Resolver);
  try
    Result := Parser.Parse;
  finally
    Parser.Free;
  end;
end;

end.
