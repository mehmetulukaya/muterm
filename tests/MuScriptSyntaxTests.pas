unit MuScriptSyntaxTests;

{

Characterisation tests for the pure script-line parser.

These helpers were extracted from MuCommands so they can be tested
without an engine or a command context. The cases below pin down the
quirks the command engine already relies on (quoted parentheses,
':END IF' variants, optimistic timeout parsing, ...).

}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpcunit, testregistry, MuScriptSyntax;

type
  TMuScriptSyntaxTests = class(TTestCase)
  published
    procedure TestArgsOf;
    procedure TestArgsOfMissingParen;
    procedure TestArgumentOf;
    procedure TestCommandToken;
    procedure TestFindMatchingParen;
    procedure TestBalancedArgs;
    procedure TestBalancedArgsQuotedParen;
    procedure TestParseIfLineBlock;
    procedure TestParseIfLineSingleLine;
    procedure TestParseIfLineInvalid;
    procedure TestIsEndIfLine;
    procedure TestIsValidIdentifier;
    procedure TestSplitPatternTimeout;
  end;

implementation

procedure TMuScriptSyntaxTests.TestArgsOf;
begin
  AssertEquals('Hello', ArgsOf(':SEND_TEXT(Hello)'));
  AssertEquals('COM1,9600', ArgsOf(':COMM_SETUP(COM1,9600)'));
  AssertEquals('', ArgsOf(':IF()'));
end;

procedure TMuScriptSyntaxTests.TestArgsOfMissingParen;
begin
  { ArgsOf is the optimistic variant: no '(' or no ')' means no args. }
  AssertEquals('', ArgsOf(':END'));
  AssertEquals('', ArgsOf(':SEND_TEXT(Hello'));
end;

procedure TMuScriptSyntaxTests.TestArgumentOf;
begin
  AssertEquals('0.5', ArgumentOf(':WAIT 0.5'));
  { Only the second field is used, so anything after it is ignored. }
  AssertEquals('0.5', ArgumentOf(':WAIT 0.5 extra'));
  { GetNStr returns the last field when the index is beyond the end; the
    caller guards with TryNumber, so a missing argument is harmless. }
  AssertEquals(':WAIT', ArgumentOf(':WAIT'));
end;

procedure TMuScriptSyntaxTests.TestCommandToken;
begin
  AssertEquals(':SEND_TEXT', CommandToken(':SEND_TEXT(Hello)'));
  AssertEquals(':SEND_TEXT', CommandToken('  :send_text (Hello)'));
  AssertEquals(':END', CommandToken(':END IF'));
  AssertEquals('', CommandToken('plain text'));
  AssertEquals('', CommandToken(''));
end;

procedure TMuScriptSyntaxTests.TestFindMatchingParen;
var
  ClosePos: Integer;
begin
  AssertTrue(FindMatchingParen('(a(b)c)', 1, ClosePos));
  AssertEquals(7, ClosePos);

  AssertTrue(FindMatchingParen('(''a)b'')', 1, ClosePos));
  AssertEquals(7, ClosePos);

  AssertFalse(FindMatchingParen('(a(b)', 1, ClosePos));
  { An escaped quote ('') inside a string must not end the quote. }
  AssertTrue(FindMatchingParen('(''it''''s'')', 1, ClosePos));
  AssertEquals(9, ClosePos);
end;

procedure TMuScriptSyntaxTests.TestBalancedArgs;
var
  Args: string;
begin
  AssertTrue(BalancedArgs(':SET(a,b(c))', Args));
  AssertEquals('a,b(c)', Args);

  AssertFalse(BalancedArgs(':SET(a,b', Args));
  AssertEquals('', Args);

  AssertFalse(BalancedArgs(':SET', Args));
end;

procedure TMuScriptSyntaxTests.TestBalancedArgsQuotedParen;
var
  Args: string;
begin
  AssertTrue(BalancedArgs(':SEND_TEXT(''a)b'')', Args));
  AssertEquals('''a)b''', Args);
end;

procedure TMuScriptSyntaxTests.TestParseIfLineBlock;
var
  Expr, Rest: string;
begin
  AssertTrue(ParseIfLine(':IF(a=1)', Expr, Rest));
  AssertEquals('a=1', Expr);
  AssertEquals('', Rest);

  AssertTrue(ParseIfLine(':if ( a = 1 )', Expr, Rest));
  AssertEquals('a = 1', Expr);
  AssertEquals('', Rest);
end;

procedure TMuScriptSyntaxTests.TestParseIfLineSingleLine;
var
  Expr, Rest: string;
begin
  AssertTrue(ParseIfLine(':IF(a=1) GOTO done', Expr, Rest));
  AssertEquals('a=1', Expr);
  AssertEquals('GOTO done', Rest);

  AssertTrue(ParseIfLine(':IF(POS(''x'',s)>0) GOTO ok', Expr, Rest));
  AssertEquals('POS(''x'',s)>0', Expr);
  AssertEquals('GOTO ok', Rest);
end;

procedure TMuScriptSyntaxTests.TestParseIfLineInvalid;
var
  Expr, Rest: string;
begin
  AssertFalse(ParseIfLine(':ELSE', Expr, Rest));
  AssertFalse(ParseIfLine(':IF a=1', Expr, Rest));
  AssertFalse(ParseIfLine(':IF(a=1', Expr, Rest));
  AssertFalse(ParseIfLine(':IF', Expr, Rest));
end;

procedure TMuScriptSyntaxTests.TestIsEndIfLine;
begin
  AssertTrue(IsEndIfLine(':ENDIF'));
  AssertTrue(IsEndIfLine(':END_IF'));
  AssertTrue(IsEndIfLine(':END IF'));
  AssertTrue(IsEndIfLine('  :end   if  '));
  AssertFalse(IsEndIfLine(':END'));
  AssertFalse(IsEndIfLine(':ENDX'));
  AssertFalse(IsEndIfLine(':SEND_TEXT(END IF)'));
end;

procedure TMuScriptSyntaxTests.TestIsValidIdentifier;
begin
  AssertTrue(IsValidIdentifier('flag'));
  AssertTrue(IsValidIdentifier('_tmp1'));
  AssertTrue(IsValidIdentifier('A_B_2'));
  AssertFalse(IsValidIdentifier(''));
  AssertFalse(IsValidIdentifier('1flag'));
  AssertFalse(IsValidIdentifier('a-b'));
  AssertFalse(IsValidIdentifier('a b'));
end;

procedure TMuScriptSyntaxTests.TestSplitPatternTimeout;
var
  Pattern: string;
  Timeout: Double;
begin
  SplitPatternTimeout('OK,1.5', Pattern, Timeout);
  AssertEquals('OK', Pattern);
  AssertEquals(1.5, Timeout, 1E-9);

  SplitPatternTimeout('OK', Pattern, Timeout);
  AssertEquals('OK', Pattern);
  AssertEquals(0.0, Timeout, 1E-9);

  { Only a numeric tail is a timeout; the comma stays part of the pattern. }
  SplitPatternTimeout('A,B', Pattern, Timeout);
  AssertEquals('A,B', Pattern);
  AssertEquals(0.0, Timeout, 1E-9);

  SplitPatternTimeout('A, 2 ', Pattern, Timeout);
  AssertEquals('A', Pattern);
  AssertEquals(2.0, Timeout, 1E-9);
end;

initialization
  RegisterTest(TMuScriptSyntaxTests);

end.
