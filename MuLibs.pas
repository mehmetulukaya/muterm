{

MuLibs is a library includes some useful function for Lazarus/fpc and Delphi.

It can be portable Windows or Linux. ( I tried on debian based Mint 32 Bit)

All rights reserved on me please don't use in commercial softwares.
Let's do it your self !

11.11.2015 Mehmet Ulukaya ( mehmetulukaya@gmail.com )

}
unit MuLibs;

{$mode delphi}{$H+}

interface

uses
  SysUtils,
  Variants,
  Classes,
  {$IFDEF LINUX}
    resource, elfreader, versiontypes,versionresource,
  {$ELSE}
    windows,
  {$ENDIF}
  Strutils;



function GetNStr(Str: string; Count: integer; sep: char): string;

function SetBit(CurrentValue: integer; Bit: byte; Position: boolean): integer;
function GetBit(CurrentValue: integer; Bit: byte): boolean;
function ViewBits(val, siz: smallint): string;

function CHKSUM(Data: string): byte;
function CRC16(Data: string): string;
function CRC16_(Data: string): string;

function HexToByte(Hex: string): integer;
function HexToStr(hex: string): string;
function StrToHex(Data: string): string;
function StrToText(Data: string): string;
function CalcFCS(Abuf: string; ABufSize: cardinal): word;
{$IFDEF WINDOWS}
function Sto_GetFmtFileVersion(const FileName: string = '';
  const Fmt: string = '%d.%d.%d.%d'): string;
{$ENDIF}
function _copy(s:string;strt,stp:integer):string;

{$IFDEF LINUX}
  Function GetProgramVersion (Out Version : String) : Boolean;
{$ENDIF}

implementation

const
  fcstab: array[byte] of word = (
    $0000, $1189, $2312, $329b, $4624, $57ad, $6536, $74bf,
    $8c48, $9dc1, $af5a, $bed3, $ca6c, $dbe5, $e97e, $f8f7,
    $1081, $0108, $3393, $221a, $56a5, $472c, $75b7, $643e,
    $9cc9, $8d40, $bfdb, $ae52, $daed, $cb64, $f9ff, $e876,
    $2102, $308b, $0210, $1399, $6726, $76af, $4434, $55bd,
    $ad4a, $bcc3, $8e58, $9fd1, $eb6e, $fae7, $c87c, $d9f5,
    $3183, $200a, $1291, $0318, $77a7, $662e, $54b5, $453c,
    $bdcb, $ac42, $9ed9, $8f50, $fbef, $ea66, $d8fd, $c974,
    $4204, $538d, $6116, $709f, $0420, $15a9, $2732, $36bb,
    $ce4c, $dfc5, $ed5e, $fcd7, $8868, $99e1, $ab7a, $baf3,
    $5285, $430c, $7197, $601e, $14a1, $0528, $37b3, $263a,
    $decd, $cf44, $fddf, $ec56, $98e9, $8960, $bbfb, $aa72,
    $6306, $728f, $4014, $519d, $2522, $34ab, $0630, $17b9,
    $ef4e, $fec7, $cc5c, $ddd5, $a96a, $b8e3, $8a78, $9bf1,
    $7387, $620e, $5095, $411c, $35a3, $242a, $16b1, $0738,
    $ffcf, $ee46, $dcdd, $cd54, $b9eb, $a862, $9af9, $8b70,
    $8408, $9581, $a71a, $b693, $c22c, $d3a5, $e13e, $f0b7,
    $0840, $19c9, $2b52, $3adb, $4e64, $5fed, $6d76, $7cff,
    $9489, $8500, $b79b, $a612, $d2ad, $c324, $f1bf, $e036,
    $18c1, $0948, $3bd3, $2a5a, $5ee5, $4f6c, $7df7, $6c7e,
    $a50a, $b483, $8618, $9791, $e32e, $f2a7, $c03c, $d1b5,
    $2942, $38cb, $0a50, $1bd9, $6f66, $7eef, $4c74, $5dfd,
    $b58b, $a402, $9699, $8710, $f3af, $e226, $d0bd, $c134,
    $39c3, $284a, $1ad1, $0b58, $7fe7, $6e6e, $5cf5, $4d7c,
    $c60c, $d785, $e51e, $f497, $8028, $91a1, $a33a, $b2b3,
    $4a44, $5bcd, $6956, $78df, $0c60, $1de9, $2f72, $3efb,
    $d68d, $c704, $f59f, $e416, $90a9, $8120, $b3bb, $a232,
    $5ac5, $4b4c, $79d7, $685e, $1ce1, $0d68, $3ff3, $2e7a,
    $e70e, $f687, $c41c, $d595, $a12a, $b0a3, $8238, $93b1,
    $6b46, $7acf, $4854, $59dd, $2d62, $3ceb, $0e70, $1ff9,
    $f78f, $e606, $d49d, $c514, $b1ab, $a022, $92b9, $8330,
    $7bc7, $6a4e, $58d5, $495c, $3de3, $2c6a, $1ef1, $0f78
    );


// copy komutan farkli olarak baslangic ve bitisi belirlenebilir copy
function _copy(s:string;strt,stp:integer):string;
var n : integer;
    rs : string;
begin

  for n:= strt to stp do
    rs := rs + s[n];

  result :=rs;
end;



{$IFDEF WINDOWS}
function Sto_GetFmtFileVersion(const FileName: string = '';
  const Fmt: string = '%d.%d.%d.%d'): string;
var
  sFileName: string;
  iBufferSize: DWORD;
  iDummy: DWORD;
  pBuffer: Pointer;
  pFileInfo: Pointer;
  iVer: array[1..4] of word;
begin
  // set default value
    Result    := '';
    // get filename of exe/dll if no filename is specified
    sFileName := FileName;
    if (sFileName = '') then
    begin
      // prepare buffer for path and terminating #0
      SetLength(sFileName, MAX_PATH + 1);
      SetLength(sFileName,
        GetModuleFileName(hInstance, PChar(sFileName), MAX_PATH + 1));
    end;
    // get size of version info (0 if no version info exists)
    iBufferSize := GetFileVersionInfoSize(PChar(sFileName), iDummy);
    if (iBufferSize > 0) then
    begin
      GetMem(pBuffer, iBufferSize);
      try
        // get fixed file info (language independent)
        GetFileVersionInfo(PChar(sFileName), 0, iBufferSize, pBuffer);
        VerQueryValue(pBuffer, '\', pFileInfo, iDummy);
        // read version blocks
        iVer[1] := HiWord(PVSFixedFileInfo(pFileInfo)^.dwFileVersionMS);
        iVer[2] := LoWord(PVSFixedFileInfo(pFileInfo)^.dwFileVersionMS);
        iVer[3] := HiWord(PVSFixedFileInfo(pFileInfo)^.dwFileVersionLS);
        iVer[4] := LoWord(PVSFixedFileInfo(pFileInfo)^.dwFileVersionLS);
      finally
        FreeMem(pBuffer);
      end;
      // format result string
      Result := Format(Fmt, [iVer[1], iVer[2], iVer[3], iVer[4]]);
    end;
end;
{$ENDIF}

function CalcFCS(ABuf: string; ABufSize: cardinal): word;
var
  CurFCS, res: word;
  //P: ^Byte;
  P: byte;
begin
  CurFCS := $ffff;
  //P := @ABuf;
  //inttohex(($FEF0 xor $ffff),4)
  P      := 1;
  while ABufSize <> 0 do
  begin
    //CurFCS := (CurFCS shr 8) xor fcstab[(CurFCS xor P^) and $ff];
    CurFCS := (CurFCS shr 8) xor fcstab[(CurFCS xor byte(ABuf[P])) and $ff];
    Dec(ABufSize);
    Inc(P);
  end;
  ABuf   := '';
  Res    := (CurFCS xor $ffff);
  Result := swap(res);
end;



// IEC Chksum
function CHKSUM(Data: string): byte;
var
  checksum, n: integer;
begin
  checksum := 0;
  for n := 1 to length(Data) do
  begin
    checksum := (checksum + Ord(Data[n])) and ($00FF);
  end;
  Result := checksum;
end;


// GETNSTR
function GetNStr(Str: string; Count: integer; sep: char): string;
var
  i, buldum: integer;
  res: string;
begin
  str := str + sep;
  res := '';
  for i := 1 to Count do
  begin
    buldum := pos(sep, str);
    if buldum > 0 then
    begin
      res := copy(str, 1, buldum - 1);
      Delete(Str, 1, Buldum);
    end;
  end;
  Result := res;
end;

// GETNSTR
function GetNStrS(Str: string; Count: integer; sep: string): string;
var
  i, buldum: integer;
  res: string;
begin
  str := str + sep;
  res := '';
  for i := 1 to Count do
  begin
    buldum := pos(sep, str);
    if buldum > 0 then
    begin
      res := copy(str, 1, buldum - 1);
      Delete(Str, 1, Buldum);
    end;
  end;
  Result := res;
end;


// SETBIT
function SetBit(CurrentValue: integer; Bit: byte; Position: boolean): integer;
begin
  if Position then
    Result := CurrentValue or (1 shl Bit)
  else
    Result := CurrentValue and (not (1 shl Bit));
end;


// GETBIT
function GetBit(CurrentValue: integer; Bit: byte): boolean;
begin
  Result := CurrentValue and (1 shl Bit) > 0;
end;


//VIEWBITS
function ViewBits(val, siz: smallint): string;
var
  n: integer;
  s: string;
begin
  for n := siz downto 0 do
  begin
    if GetBit(val, n) then
      s := s + '1 '
    else
      s := s + '0 ';
  end;
  Result := s;
end;


// HEXTOBYTE
function HexToByte(Hex: string): integer;
var
  n, n2, sayi: integer;
begin
  n  := 0;
  n2 := 0;
  case Hex[1] of
    'A', 'a': n := 10;
    'B', 'b': n := 11;
    'C', 'c': n := 12;
    'D', 'd': n := 13;
    'E', 'e': n := 14;
    'F', 'f': n := 15;
  end;
  if Hex[1] in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'] then
    n := StrToInt(Hex[1]);

  case Hex[2] of
    'A', 'a': n2 := 10;
    'B', 'b': n2 := 11;
    'C', 'c': n2 := 12;
    'D', 'd': n2 := 13;
    'E', 'e': n2 := 14;
    'F', 'f': n2 := 15;
  end;
  if Hex[2] in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'] then
    n2   := StrToInt(Hex[2]);
  sayi   := n * 16 + n2;
  Result := sayi;
end;


//HEXTOSTR
function HexToStr(hex: string): string;
var
  n, d: integer;
  res:  string;
begin
  res := '';
  d   := (length(hex) div 3);
  for n := 1 to d do
  begin
    res := res + Chr(HexToByte(UpperCase(GetNStr(hex, n, ' '))));
  end;
  Result := res;
end;


//STRTOHEX
function StrToHex(Data: string): string;
var
  n: integer;
  s: string;
begin
  s := '';
  for n := 1 to length(Data) do
  begin
    s := s + IntToHex(Ord(Data[n]), 2) + ' ';
  end;
  Result := s;
end;

function StrToText(Data: string): string;
var
  res, val, x_char: string;
  p: integer;
begin
  // '#02000000532100000012050$'
  // '#DENEME'$0A#010

  res := Data;
  p   := 0;
  repeat
    p := PosEx('#', res,p+1);
    if p > 0 then
      try
        val    := copy(res, p + 1, 3);
        x_char := chr(StrToInt(val));
        Delete(res, p, 4);
        Insert(x_char, res, p);
      except
      end;
  until p = 0;

  repeat
    p := PosEx('$', res,p+1);
    if p > 0 then
      try
        val    := copy(res, p + 1, 2);
        x_char := chr(HexToByte(val));
        Delete(res, p, 3);
        Insert(x_char, res, p);
      except
      end;
  until p = 0;

  Result := res;
end;

// CRC16
function CRC16(Data: string): string;
var
  i, j, iSum, f: smallint;
begin
  iSum := $FFFF;
  for i := 1 to Length(Data) do
  begin
    iSum := iSum xor Ord(Data[i]);
    for j := 1 to 8 do
    begin
      f    := iSum and $0001;
      iSum := iSum shr 1;
      if f = 1 then
        iSum := iSum xor $A001;
    end;
  end;
  Result := char(Lo(iSum)) + char(Hi(iSum));
end;


//CRC16_
function CRC16_(Data: string): string;
var
  i, j, iSum, f: smallint;
begin
  iSum := $FFFF;
  for i := 1 to Length(Data) do
  begin
    iSum := iSum xor Ord(Data[i]);
    for j := 1 to 8 do
    begin
      f    := iSum and $0001;
      iSum := iSum shr 1;
      if f = 1 then
        iSum := iSum xor $A001;
    end;
  end;
  Result := char(Hi(iSum)) + char(Lo(iSum));
end;


{$IFDEF LINUX}
Function GetProgramVersion (Out Version : String) : Boolean;

Var
   RS : TResources;
   E : TElfResourceReader;
   VR : TVersionResource;
   I : Integer;

begin
   Version:='';
   RS:=TResources.Create;
   try
     E:=TElfResourceReader.Create;
     try
       Rs.LoadFromFile(ParamStr(0),E);
     finally
       E.Free;
     end;
     VR:=Nil;
     I:=0;
     While (VR=Nil) and (I<RS.Count) do
       begin
       if RS.Items[i] is TVersionResource then
          VR:=TVersionResource(RS.Items[i]);
       Inc(I);
       end;
     Result:=(VR<>Nil);
     if Result then
       For I:=0 to 3 do
         begin
         If (Version<>'') then
           Version:=Version+'.';
         Version:=Version+IntToStr(VR.FixedInfo.FileVersion[I]);
         end;
   Finally
     RS.FRee;
   end;
end;
{$ENDIF}

end.
