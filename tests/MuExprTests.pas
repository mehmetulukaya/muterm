unit MuExprTests;

{

Characterisation tests for the expression evaluator used by :IF and :SET.

}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, MuExpr;

type
  TVariableTable = class
  private
    FValues: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const Name, Value: string);
    function Resolve(const Name: string; out Value: string): Boolean;
  end;

  TMuExprTests = class(TTestCase)
  private
    FVars: TVariableTable;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestNumberAndStringLiterals;
    procedure TestCharacterLiterals;
    procedure TestComparisons;
    procedure TestLogicalOperators;
    procedure TestFunctions;
    procedure TestVariables;
    procedure TestTryNumber;
    procedure TestExprToBool;
    procedure TestUnexpectedCharacterRaises;
    procedure TestUnknownFunctionRaises;
    procedure TestTrailingExpressionRaises;
  end;

implementation

{ TVariableTable }

constructor TVariableTable.Create;
begin
  inherited Create;
  FValues := TStringList.Create;
  FValues.CaseSensitive := False;
end;

destructor TVariableTable.Destroy;
begin
  FValues.Free;
  inherited Destroy;
end;

procedure TVariableTable.Add(const Name, Value: string);
begin
  FValues.Values[Name] := Value;
end;

function TVariableTable.Resolve(const Name: string; out Value: string): Boolean;
var
  I: Integer;
begin
  I := FValues.IndexOfName(Name);
  Result := I >= 0;
  if Result then
    Value := FValues.ValueFromIndex[I]
  else
    Value := '';
end;

{ TMuExprTests }

procedure TMuExprTests.SetUp;
begin
  inherited SetUp;
  FVars := TVariableTable.Create;
end;

procedure TMuExprTests.TearDown;
begin
  FVars.Free;
  inherited TearDown;
end;

procedure TMuExprTests.TestNumberAndStringLiterals;
begin
  AssertEquals('42', EvalExpression('42', nil));
  AssertEquals('1.5', EvalExpression('1.5', nil));
  AssertEquals('hello', EvalExpression(QuotedStr('hello'), nil));
end;

procedure TMuExprTests.TestCharacterLiterals;
begin
  AssertEquals('A', EvalExpression('#65', nil));
  AssertEquals('A', EvalExpression('#$41', nil));
  { Adjacent string tokens are concatenated by the parser. }
  AssertEquals('AB', EvalExpression(QuotedStr('A') + '#66', nil));
end;

procedure TMuExprTests.TestComparisons;
begin
  AssertEquals('1', EvalExpression('1=1', nil));
  AssertEquals('0', EvalExpression('1<>1', nil));
  AssertEquals('1', EvalExpression('2<10', nil));
  AssertEquals('0', EvalExpression('2>10', nil));
  AssertEquals('1', EvalExpression('2<=2', nil));
  AssertEquals('1', EvalExpression('2>=2', nil));
  AssertEquals('1', EvalExpression(QuotedStr('b') + '>' + QuotedStr('a'), nil));
end;

procedure TMuExprTests.TestLogicalOperators;
begin
  AssertEquals('1', EvalExpression('1=1 and 2=2', nil));
  AssertEquals('0', EvalExpression('1=2 and 2=2', nil));
  AssertEquals('1', EvalExpression('1=2 or 2=2', nil));
  AssertEquals('0', EvalExpression('1=2 or 2=3', nil));
  AssertEquals('1', EvalExpression('not 0', nil));
  AssertEquals('0', EvalExpression('not 1', nil));
end;

procedure TMuExprTests.TestFunctions;
begin
  AssertEquals('2', EvalExpression('POS(' + QuotedStr('abc') + ',' +
    QuotedStr('b') + ')', nil));
  AssertEquals('2', EvalExpression('POSP(' + QuotedStr('b') + ',' +
    QuotedStr('abc') + ')', nil));
  AssertEquals('1', EvalExpression('CONTAINS(' + QuotedStr('abc') + ',' +
    QuotedStr('bc') + ')', nil));
  AssertEquals('0', EvalExpression('CONTAINS(' + QuotedStr('abc') + ',' +
    QuotedStr('zz') + ')', nil));
  AssertEquals('3', EvalExpression('LEN(' + QuotedStr('abc') + ')', nil));
  AssertEquals('x', EvalExpression('TRIM(' + QuotedStr('  x  ') + ')', nil));
  AssertEquals('AB', EvalExpression('UPPER(' + QuotedStr('aB') + ')', nil));
  AssertEquals('ab', EvalExpression('LOWER(' + QuotedStr('aB') + ')', nil));
end;

procedure TMuExprTests.TestVariables;
begin
  FVars.Add('name', 'World');
  AssertEquals('World', EvalExpression('name', @FVars.Resolve));
  AssertEquals('1', EvalExpression('name=' + QuotedStr('World'),
    @FVars.Resolve));
  AssertEquals('', EvalExpression('unknown', @FVars.Resolve));
end;

procedure TMuExprTests.TestTryNumber;
var
  N: Double;
begin
  AssertTrue(TryNumber('1.5', N));
  AssertEquals(1.5, N, 1E-9);
  AssertTrue(TryNumber(' 42 ', N));
  AssertEquals(42.0, N, 1E-9);
  AssertFalse(TryNumber('abc', N));
  AssertFalse(TryNumber('1,5', N));
end;

procedure TMuExprTests.TestExprToBool;
begin
  AssertFalse(ExprToBool('0'));
  AssertTrue(ExprToBool('1'));
  AssertFalse(ExprToBool(''));
  AssertFalse(ExprToBool('false'));
  AssertFalse(ExprToBool('no'));
  AssertFalse(ExprToBool('off'));
  AssertTrue(ExprToBool('yes'));
  AssertTrue(ExprToBool('text'));
end;

procedure TMuExprTests.TestUnexpectedCharacterRaises;
var
  Raised: Boolean;
begin
  Raised := False;
  try
    EvalExpression('1 + 2', nil);
  except
    on E: TExprError do
      Raised := True;
  end;
  AssertTrue('TExprError bekleniyordu', Raised);
end;

procedure TMuExprTests.TestUnknownFunctionRaises;
var
  Raised: Boolean;
begin
  Raised := False;
  try
    EvalExpression('NO_SUCH_FUNCTION(1)', nil);
  except
    on E: TExprError do
      Raised := True;
  end;
  AssertTrue('TExprError bekleniyordu', Raised);
end;

procedure TMuExprTests.TestTrailingExpressionRaises;
var
  Raised: Boolean;
begin
  Raised := False;
  try
    EvalExpression('1 2', nil);
  except
    on E: TExprError do
      Raised := True;
  end;
  AssertTrue('TExprError bekleniyordu', Raised);
end;

initialization
  RegisterTest(TMuExprTests);

end.
