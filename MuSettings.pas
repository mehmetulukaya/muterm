unit MuSettings;

{

Settings persistence for MuTerm.

The old TfrmMain.SaveComponentValue / LoadComponentValue methods used a
chain of "if (cmp is TEdit) ... else if (cmp is TCheckBox) ..." blocks.
Adding a new control type meant editing that chain (OCP violation).

Here every control type has its own handler. New types are supported by
creating a handler and registering it, without modifying existing code.

}

{$mode objfpc}{$H+}

interface

uses
  Classes, Contnrs, SysUtils, IniFiles, StdCtrls, EditBtn, Dialogs;

type

  TComponentArray = array of TComponent;

  { One handler per persisted control type. }
  TComponentValueHandler = class
  public
    function CanHandle(Cmp: TComponent): Boolean; virtual; abstract;
    procedure SaveValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string); virtual; abstract;
    procedure LoadValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string); virtual; abstract;
  end;

  TFileNameEditValueHandler = class(TComponentValueHandler)
  public
    function CanHandle(Cmp: TComponent): Boolean; override;
    procedure SaveValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string); override;
    procedure LoadValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string); override;
  end;

  TEditValueHandler = class(TComponentValueHandler)
  public
    function CanHandle(Cmp: TComponent): Boolean; override;
    procedure SaveValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string); override;
    procedure LoadValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string); override;
  end;

  TCheckBoxValueHandler = class(TComponentValueHandler)
  public
    function CanHandle(Cmp: TComponent): Boolean; override;
    procedure SaveValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string); override;
    procedure LoadValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string); override;
  end;

  TRadioButtonValueHandler = class(TComponentValueHandler)
  public
    function CanHandle(Cmp: TComponent): Boolean; override;
    procedure SaveValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string); override;
    procedure LoadValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string); override;
  end;

  TListBoxValueHandler = class(TComponentValueHandler)
  public
    function CanHandle(Cmp: TComponent): Boolean; override;
    procedure SaveValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string); override;
    procedure LoadValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string); override;
  end;

  TComboBoxValueHandler = class(TComponentValueHandler)
  public
    function CanHandle(Cmp: TComponent): Boolean; override;
    procedure SaveValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string); override;
    procedure LoadValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string); override;
  end;

  TFontDialogValueHandler = class(TComponentValueHandler)
  public
    function CanHandle(Cmp: TComponent): Boolean; override;
    procedure SaveValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string); override;
    procedure LoadValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string); override;
  end;

  { Finds the handler for a component. Register new handlers to extend. }
  TComponentValueSerializer = class
  private
    FHandlers: TObjectList;
    function FindHandler(Cmp: TComponent): TComponentValueHandler;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Register(Handler: TComponentValueHandler);
    function SaveValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string): Boolean;
    function LoadValue(Cmp: TComponent; Ini: TCustomIniFile;
      const Section: string): Boolean;
  end;

  { Owns the ini file location and the serializer. }
  TAppSettings = class
  private
    FFileName: string;
    FSection: string;
    FSerializer: TComponentValueSerializer;
  public
    constructor Create(const AFileName: string; const ASection: string = 'COMM');
    destructor Destroy; override;

    property FileName: string read FFileName;
    property Section: string read FSection;
    property Serializer: TComponentValueSerializer read FSerializer;

    procedure SaveComponents(const Components: array of TComponent);
    procedure LoadComponents(const Components: array of TComponent);
  end;

implementation

{ TFileNameEditValueHandler }

function TFileNameEditValueHandler.CanHandle(Cmp: TComponent): Boolean;
begin
  Result := Cmp is TFileNameEdit;
end;

procedure TFileNameEditValueHandler.SaveValue(Cmp: TComponent;
  Ini: TCustomIniFile; const Section: string);
begin
  Ini.WriteString(Section, Cmp.Name, TFileNameEdit(Cmp).FileName);
end;

procedure TFileNameEditValueHandler.LoadValue(Cmp: TComponent;
  Ini: TCustomIniFile; const Section: string);
begin
  TFileNameEdit(Cmp).FileName :=
    Ini.ReadString(Section, Cmp.Name, TFileNameEdit(Cmp).FileName);
end;

{ TEditValueHandler }

function TEditValueHandler.CanHandle(Cmp: TComponent): Boolean;
begin
  Result := Cmp is TEdit;
end;

procedure TEditValueHandler.SaveValue(Cmp: TComponent;
  Ini: TCustomIniFile; const Section: string);
begin
  Ini.WriteString(Section, Cmp.Name, TEdit(Cmp).Text);
end;

procedure TEditValueHandler.LoadValue(Cmp: TComponent;
  Ini: TCustomIniFile; const Section: string);
begin
  TEdit(Cmp).Text := Ini.ReadString(Section, Cmp.Name, TEdit(Cmp).Text);
end;

{ TCheckBoxValueHandler }

function TCheckBoxValueHandler.CanHandle(Cmp: TComponent): Boolean;
begin
  Result := Cmp is TCheckBox;
end;

procedure TCheckBoxValueHandler.SaveValue(Cmp: TComponent;
  Ini: TCustomIniFile; const Section: string);
begin
  Ini.WriteBool(Section, Cmp.Name, TCheckBox(Cmp).Checked);
end;

procedure TCheckBoxValueHandler.LoadValue(Cmp: TComponent;
  Ini: TCustomIniFile; const Section: string);
begin
  TCheckBox(Cmp).Checked :=
    Ini.ReadBool(Section, Cmp.Name, TCheckBox(Cmp).Checked);
end;

{ TRadioButtonValueHandler }

function TRadioButtonValueHandler.CanHandle(Cmp: TComponent): Boolean;
begin
  Result := Cmp is TRadioButton;
end;

procedure TRadioButtonValueHandler.SaveValue(Cmp: TComponent;
  Ini: TCustomIniFile; const Section: string);
begin
  Ini.WriteBool(Section, Cmp.Name, TRadioButton(Cmp).Checked);
end;

procedure TRadioButtonValueHandler.LoadValue(Cmp: TComponent;
  Ini: TCustomIniFile; const Section: string);
begin
  TRadioButton(Cmp).Checked :=
    Ini.ReadBool(Section, Cmp.Name, TRadioButton(Cmp).Checked);
end;

{ TListBoxValueHandler }

function TListBoxValueHandler.CanHandle(Cmp: TComponent): Boolean;
begin
  Result := Cmp is TListBox;
end;

procedure TListBoxValueHandler.SaveValue(Cmp: TComponent;
  Ini: TCustomIniFile; const Section: string);
begin
  Ini.WriteInteger(Section, Cmp.Name, TListBox(Cmp).ItemIndex);
end;

procedure TListBoxValueHandler.LoadValue(Cmp: TComponent;
  Ini: TCustomIniFile; const Section: string);
begin
  TListBox(Cmp).ItemIndex :=
    Ini.ReadInteger(Section, Cmp.Name, TListBox(Cmp).ItemIndex);
end;

{ TComboBoxValueHandler }

function TComboBoxValueHandler.CanHandle(Cmp: TComponent): Boolean;
begin
  Result := Cmp is TComboBox;
end;

procedure TComboBoxValueHandler.SaveValue(Cmp: TComponent;
  Ini: TCustomIniFile; const Section: string);
begin
  Ini.WriteInteger(Section, Cmp.Name, TComboBox(Cmp).ItemIndex);
end;

procedure TComboBoxValueHandler.LoadValue(Cmp: TComponent;
  Ini: TCustomIniFile; const Section: string);
begin
  TComboBox(Cmp).ItemIndex :=
    Ini.ReadInteger(Section, Cmp.Name, TComboBox(Cmp).ItemIndex);
end;

{ TFontDialogValueHandler }

function TFontDialogValueHandler.CanHandle(Cmp: TComponent): Boolean;
begin
  Result := Cmp is TFontDialog;
end;

procedure TFontDialogValueHandler.SaveValue(Cmp: TComponent;
  Ini: TCustomIniFile; const Section: string);
begin
  Ini.WriteInteger(Section, Cmp.Name + '.Font.Color', TFontDialog(Cmp).Font.Color);
  Ini.WriteInteger(Section, Cmp.Name + '.Font.Size', TFontDialog(Cmp).Font.Size);
end;

procedure TFontDialogValueHandler.LoadValue(Cmp: TComponent;
  Ini: TCustomIniFile; const Section: string);
begin
  TFontDialog(Cmp).Font.Color := Ini.ReadInteger(Section,
    Cmp.Name + '.Font.Color', TFontDialog(Cmp).Font.Color);
  TFontDialog(Cmp).Font.Size := Ini.ReadInteger(Section,
    Cmp.Name + '.Font.Size', TFontDialog(Cmp).Font.Size);
end;

{ TComponentValueSerializer }

constructor TComponentValueSerializer.Create;
begin
  inherited Create;
  FHandlers := TObjectList.Create(True);
  Register(TFileNameEditValueHandler.Create);
  Register(TEditValueHandler.Create);
  Register(TCheckBoxValueHandler.Create);
  Register(TRadioButtonValueHandler.Create);
  Register(TListBoxValueHandler.Create);
  Register(TComboBoxValueHandler.Create);
  Register(TFontDialogValueHandler.Create);
end;

destructor TComponentValueSerializer.Destroy;
begin
  FHandlers.Free;
  inherited Destroy;
end;

procedure TComponentValueSerializer.Register(Handler: TComponentValueHandler);
begin
  if Assigned(Handler) then
    FHandlers.Add(Handler);
end;

function TComponentValueSerializer.FindHandler(
  Cmp: TComponent): TComponentValueHandler;
var
  i: Integer;
begin
  Result := nil;
  if not Assigned(Cmp) then
    Exit;
  for i := 0 to FHandlers.Count - 1 do
  begin
    if TComponentValueHandler(FHandlers[i]).CanHandle(Cmp) then
    begin
      Result := TComponentValueHandler(FHandlers[i]);
      Exit;
    end;
  end;
end;

function TComponentValueSerializer.SaveValue(Cmp: TComponent;
  Ini: TCustomIniFile; const Section: string): Boolean;
var
  Handler: TComponentValueHandler;
begin
  Handler := FindHandler(Cmp);
  Result := Assigned(Handler);
  if Result then
    Handler.SaveValue(Cmp, Ini, Section);
end;

function TComponentValueSerializer.LoadValue(Cmp: TComponent;
  Ini: TCustomIniFile; const Section: string): Boolean;
var
  Handler: TComponentValueHandler;
begin
  Handler := FindHandler(Cmp);
  Result := Assigned(Handler);
  if Result then
    Handler.LoadValue(Cmp, Ini, Section);
end;

{ TAppSettings }

constructor TAppSettings.Create(const AFileName: string;
  const ASection: string);
begin
  inherited Create;
  FFileName := AFileName;
  FSection := ASection;
  FSerializer := TComponentValueSerializer.Create;
end;

destructor TAppSettings.Destroy;
begin
  FSerializer.Free;
  inherited Destroy;
end;

procedure TAppSettings.SaveComponents(const Components: array of TComponent);
var
  Ini: TIniFile;
  i: Integer;
begin
  Ini := TIniFile.Create(FFileName);
  try
    for i := Low(Components) to High(Components) do
      FSerializer.SaveValue(Components[i], Ini, FSection);
  finally
    Ini.Free;
  end;
end;

procedure TAppSettings.LoadComponents(const Components: array of TComponent);
var
  Ini: TIniFile;
  i: Integer;
begin
  Ini := TIniFile.Create(FFileName);
  try
    for i := Low(Components) to High(Components) do
      FSerializer.LoadValue(Components[i], Ini, FSection);
  finally
    Ini.Free;
  end;
end;

end.
