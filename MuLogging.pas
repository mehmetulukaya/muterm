unit MuLogging;

{

Log abstraction for MuTerm.

TfrmMain no longer talks to TMemo objects directly; it only talks to a
TLogManager, which forwards each message to a registered ILogSink.
This makes it possible to add file/console sinks later without touching
the terminal logic.

}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StdCtrls;

type

  ILogSink = interface
    ['{6D3A9C41-2B7E-4F58-9A10-7C5E2F8B4D91}']
    procedure WriteLine(const Line: string);
    procedure WriteRaw(const Text: string);
  end;

  { Appends log lines to a TMemo. Keeps the visual behaviour of the old
    TfrmMain.LogAdd / LogAddStr methods. }
  TMemoLogSink = class(TInterfacedObject, ILogSink)
  private
    FMemo: TMemo;
  public
    constructor Create(AMemo: TMemo);
    procedure WriteLine(const Line: string);
    procedure WriteRaw(const Text: string);
  end;

  { Named collection of sinks. Sink names are the component names used by
    the scripting API (mem_Log1, mem_Log2, mem_General). }
  TLogManager = class
  private
    FNames: TStringList;
    FSinks: TInterfaceList;
    function IndexOf(const Name: string): Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure RegisterSink(const Name: string; Sink: ILogSink);
    function Add(const Name, Text: string): Boolean;     // timestamped line
    function AddRaw(const Name, Text: string): Boolean;  // append without newline
  end;

implementation

{ TMemoLogSink }

constructor TMemoLogSink.Create(AMemo: TMemo);
begin
  inherited Create;
  FMemo := AMemo;
end;

procedure TMemoLogSink.WriteLine(const Line: string);
begin
  FMemo.Lines.Add(Line);
end;

procedure TMemoLogSink.WriteRaw(const Text: string);
var
  s: string;
  ps: Integer;
begin
  s := Text;
  ps := Pos(#10, s);     // for memo component
  if ps > 0 then
    Delete(s, ps, 1);
  if s = '' then
    Exit;
  FMemo.Text := FMemo.Text + s;
  {$IFDEF WINDOWS}
  FMemo.SelStart := Length(FMemo.Text);
  FMemo.SelLength := 0;
  {$ENDIF}
end;

{ TLogManager }

constructor TLogManager.Create;
begin
  inherited Create;
  FNames := TStringList.Create;
  FNames.CaseSensitive := False;
  FSinks := TInterfaceList.Create;
end;

destructor TLogManager.Destroy;
begin
  FSinks.Free;
  FNames.Free;
  inherited Destroy;
end;

function TLogManager.IndexOf(const Name: string): Integer;
begin
  Result := FNames.IndexOf(Name);
end;

procedure TLogManager.RegisterSink(const Name: string; Sink: ILogSink);
var
  i: Integer;
begin
  i := IndexOf(Name);
  if i >= 0 then
  begin
    FNames[i] := Name;
    FSinks[i] := Sink;
  end
  else
  begin
    FNames.Add(Name);
    FSinks.Add(Sink);
  end;
end;

function TLogManager.Add(const Name, Text: string): Boolean;
var
  i: Integer;
begin
  i := IndexOf(Name);
  Result := i >= 0;
  if Result then
    (FSinks[i] as ILogSink).WriteLine(
      FormatDateTime('dd.MM hh:nn:ss', Now) + ' : ' + Text);
end;

function TLogManager.AddRaw(const Name, Text: string): Boolean;
var
  i: Integer;
begin
  i := IndexOf(Name);
  Result := i >= 0;
  if Result then
    (FSinks[i] as ILogSink).WriteRaw(Text);
end;

end.
