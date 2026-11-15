unit MuLibsTests;

{

Characterisation tests for MuLibs.

These tests describe the behaviour the rest of MuTerm already relies on.
They are intentionally written before the refactoring so that the helpers
can be split into smaller units without changing wire-format behaviour.

}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpcunit, testregistry, MuLibs;

type
  TMuLibsTests = class(TTestCase)
  published
    procedure TestGetNStrFields;
    procedure TestGetNStrEmptyField;
    procedure TestGetNStrMissingField;
    procedure TestStrToHex;
    procedure TestHexToStr;
    procedure TestHexToStrWithoutTrailingSpace;
    procedure TestHexToStrInvalidRaises;
    procedure TestHexToByte;
    procedure TestStrToTextDecimal;
    procedure TestStrToTextHex;
    procedure TestStrToTextControlCharacters;
    procedure TestChecksum;
    procedure TestModbusCrc16;
    procedure TestModbusCrc16Swapped;
    procedure TestCalcFcs;
    procedure TestSetAndGetBit;
    procedure TestViewBits;
    procedure TestCopyHelper;
  end;

implementation

procedure TMuLibsTests.TestGetNStrFields;
begin
  AssertEquals('COM1', GetNStr('COM1,19200,8,N,1', 1, ','));
  AssertEquals('19200', GetNStr('COM1,19200,8,N,1', 2, ','));
  AssertEquals('8', GetNStr('COM1,19200,8,N,1', 3, ','));
  AssertEquals('N', GetNStr('COM1,19200,8,N,1', 4, ','));
  AssertEquals('1', GetNStr('COM1,19200,8,N,1', 5, ','));
end;

procedure TMuLibsTests.TestGetNStrEmptyField;
begin
  AssertEquals('', GetNStr('a,,c', 2, ','));
  AssertEquals('c', GetNStr('a,,c', 3, ','));
  AssertEquals('', GetNStr('', 1, ','));
end;

procedure TMuLibsTests.TestGetNStrMissingField;
begin
  { Characterisation: the current helper returns the last field when the
    requested index is beyond the available fields. Do not "fix" this
    silently; callers depend on the existing parsing behaviour. }
  AssertEquals('b', GetNStr('a,b', 5, ','));
end;

procedure TMuLibsTests.TestStrToHex;
begin
  AssertEquals('41 42 ', StrToHex('AB'));
  AssertEquals('00 0A ', StrToHex(#0#10));
  AssertEquals('', StrToHex(''));
end;

procedure TMuLibsTests.TestHexToStr;
begin
  AssertEquals('AB', HexToStr('41 42 '));
  AssertEquals(#1#3#0#10, HexToStr('01 03 00 0A '));
  AssertEquals('', HexToStr(''));
end;

procedure TMuLibsTests.TestHexToStrWithoutTrailingSpace;
begin
  { :SEND_HEX(01 03) passes the argument without a trailing space; the old
    implementation silently dropped the last byte. }
  AssertEquals(#1#3, HexToStr('01 03'));
  AssertEquals(#1#3#0#10, HexToStr('01 03 00 0A'));
  AssertEquals(#1#3, HexToStr('01  03'));
  AssertEquals(#1#3, HexToStr('0103'));
end;

procedure TMuLibsTests.TestHexToStrInvalidRaises;
var
  Raised: Boolean;
begin
  Raised := False;
  try
    HexToStr('01 0');
  except
    on E: EConvertError do
      Raised := True;
  end;
  AssertTrue('Eksik hex bayti hata vermeli', Raised);
end;

procedure TMuLibsTests.TestHexToByte;
begin
  AssertEquals(255, HexToByte('FF'));
  AssertEquals(255, HexToByte('ff'));
  AssertEquals(10, HexToByte('0A'));
  AssertEquals(0, HexToByte('00'));
end;

procedure TMuLibsTests.TestStrToTextDecimal;
begin
  AssertEquals('AB', StrToText('A#066'));
end;

procedure TMuLibsTests.TestStrToTextHex;
begin
  AssertEquals('AB', StrToText('$41$42'));
end;

procedure TMuLibsTests.TestStrToTextControlCharacters;
begin
  AssertEquals(#13#10, StrToText('#013#010'));
  AssertEquals(#13#10, StrToText('$0D$0A'));
end;

procedure TMuLibsTests.TestChecksum;
begin
  { 0x31 + 0x32 + 0x33 + 0x34 = 0xCA }
  AssertEquals($CA, CHKSUM('1234'));
  AssertEquals(0, CHKSUM(''));
end;

procedure TMuLibsTests.TestModbusCrc16;
var
  Data, Crc: string;
begin
  Data := #$01#$03#$00#$00#$00#$0A;
  Crc := CRC16(Data);
  AssertEquals(2, Length(Crc));
  { Modbus RTU sends the low byte first: 0xC5 0xCD }
  AssertEquals(#$C5#$CD, Crc);
end;

procedure TMuLibsTests.TestModbusCrc16Swapped;
var
  Data, Crc: string;
begin
  Data := #$01#$03#$00#$00#$00#$0A;
  Crc := CRC16_(Data);
  AssertEquals(2, Length(Crc));
  { CRC16_ is the big-endian variant used by some protocols. }
  AssertEquals(#$CD#$C5, Crc);
end;

procedure TMuLibsTests.TestCalcFcs;
begin
  { Reference values from the PPP FCS-16 algorithm. }
  AssertEquals(0, CalcFCS('', 0));
  AssertEquals($F5A3, CalcFCS('A', 1));
  AssertEquals($6E90, CalcFCS('123456789', 9));
end;

procedure TMuLibsTests.TestSetAndGetBit;
begin
  AssertEquals(8, SetBit(0, 3, True));
  AssertEquals(0, SetBit(8, 3, False));
  AssertTrue(GetBit(8, 3));
  AssertFalse(GetBit(0, 3));
end;

procedure TMuLibsTests.TestViewBits;
begin
  { 5 = 0101, displayed from bit 3 down to bit 0. }
  AssertEquals('0 1 0 1 ', ViewBits(5, 3));
end;

procedure TMuLibsTests.TestCopyHelper;
begin
  AssertEquals('bcd', _copy('abcdef', 2, 4));
  AssertEquals('a', _copy('a', 1, 1));
end;

initialization
  RegisterTest(TMuLibsTests);

end.
