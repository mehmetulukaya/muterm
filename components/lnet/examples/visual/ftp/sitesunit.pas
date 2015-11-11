unit sitesunit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, IniFiles, Menus;

type

  TSiteInfo = record
    Site: string;
    txtHost: string;
    Port: string;
    path: string;
    user: string;
    pass: string;
    Anonymous: Boolean;
  end;
  
  { TfrmSites }

  TfrmSites = class(TForm)
    btnAddSite: TBitBtn;
    btnSave: TBitBtn;
    btnClose: TBitBtn;
    btnConnect: TBitBtn;
    Label1: TLabel;
    MenuItemSiteDelete: TMenuItem;
    PopupMenuSites: TPopupMenu;
    txtPort: TLabeledEdit;
    txtSite: TLabeledEdit;
    txtPass: TLabeledEdit;
    txtUser: TLabeledEdit;
    txtPath: TLabeledEdit;
    txtHost: TLabeledEdit;
    lbSites: TListBox;
    procedure lbSitesClick(Sender: TObject);
    procedure MenuItemSiteDeleteClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure btnConnectClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure btnAddSiteClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure txtSiteChange(Sender: TObject);
  private
    { private declarations }
    FSites: array of TSiteInfo;
    FNewSite: Boolean;
    function OkToClose: boolean;
    function  SaveChanges: boolean;
    procedure DeleteSite(const i: Integer);
    procedure LoadSites;
    procedure SaveSites;
    procedure UpdateCurrentSite;
    function  CheckInfo: integer;
    procedure Modified(ok: boolean);
    procedure SaveLastSite;
  protected
    procedure ChildHandlesCreated; override;
  public
    { public declarations }
    class procedure LoadLastSite;
  end;

var
  frmSites: TfrmSites;
  Site: TSiteInfo;
  
  function  GetSitePath:string;

implementation

// simple xor encrypt
function EncryptString(const s:string): string;
var
  i: Integer;
begin
  result := '';
  for i:=1 to Length(s) do
    result := result + chr(ord(s[i]) xor 21);
end;
function DecryptString(const s:string): string;
begin
  result := EncryptString(s);
end;

class procedure TfrmSites.LoadLastSite;
var
  Ini: TIniFile;
  i: Integer;
  s: string;
begin
  s := extractFilePath(Application.ExeName)+'sites.ini';
  Ini := TIniFile.Create(s);
  try
    I := Ini.ReadInteger('global','lastsite', -1);
    s := 'site'+IntToStr(i);
    Site.Site := Ini.ReadString(s, 'site', '<see sites manager>');
    Site.txtHost := Ini.ReadString(s, 'host', '');
    Site.Port := Ini.ReadString(s, 'port', '');
    Site.path := Ini.ReadString(s, 'path', '');
    Site.user := Ini.ReadString(s, 'user', '');
    Site.pass := DecryptString(Ini.ReadString(s, 'pass', ''));
  finally
    Ini.Free;
  end;
end;

function GetSitePath: string;
begin
  if Site.path='' then
    result := '/'
  else
    Result := Site.Path;
end;

{ TfrmSites }

procedure TfrmSites.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  CanClose := OkToClose;
end;

procedure TfrmSites.btnSaveClick(Sender: TObject);
begin
  if SaveChanges then begin
    Modified(False);
    SaveLastSite;
    LoadSites;
  end;
end;

procedure TfrmSites.btnConnectClick(Sender: TObject);
begin
  if CheckInfo<>0 then
    exit;
  SaveLastSite;
  ModalResult := mrYes;
end;

procedure TfrmSites.btnCloseClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TfrmSites.MenuItemSiteDeleteClick(Sender: TObject);
var
  i: Integer;
begin
  i := lbSites.ItemIndex;
  
  if (i >= 0) and (i < Length(FSites)) then begin
    lbSites.Items.Delete(i);
    txtSite.Text := '';
    txtPass.Text := '';
    txtHost.Text := '';
    txtPort.Text := '';
    txtUser.Text := '';
    Modified(False);
    DeleteSite(i);
  end;
end;

procedure TfrmSites.lbSitesClick(Sender: TObject);
begin
  UpdateCurrentSite;
  Modified(False);
end;

procedure TfrmSites.btnAddSiteClick(Sender: TObject);
var
  i: Integer;
begin
  // it's a new site
  FnewSite := True;
  Modified(True);
  
  // select new item in listbox
  i := lbSites.Items.addObject('<new site>', TObject(ptrint(-1)));
  lbSites.ItemIndex := i;
  
  // defaults for new site
  txtSite.text := '';
  txtHost.Text := '';
  txtPort.Text := '21';
  txtPath.Text := '/';
  txtUser.Text := 'anonymous';
  txtPass.Text := '';
end;

procedure TfrmSites.FormShow(Sender: TObject);
begin
  LoadSites;
  lbSitesClick(Sender);
  // locate current site;
  //lbSites.ItemIndex := lbSites.Items.IndexOf(Site.Site);
  //UpdateCurrentSite;
  //Modified(False);
end;

procedure TfrmSites.txtSiteChange(Sender: TObject);
begin
  // something has changed, but btnAddSite is not enabled
  // this means user is editing current site
  if not btnAddSite.Enabled then
    FNewSite := False;
  Modified(True);
end;

function TfrmSites.OkToClose: boolean;
var
  res: TModalResult;
begin
  result := True;
  if btnSave.Enabled then begin
    res := QuestionDlg('Warning!', 'There are unsaved changes'^M'What do you want to do?'^M,
      mtWarning, [mrOk, 'Save Changes', mrIgnore, 'Ignore changes', mrCancel, 'Don''t close'], 0);
    if res = mrOk then
      result := SaveChanges else
    if res=mrCancel then
      result := False;
  end;
end;

function TfrmSites.SaveChanges: boolean;
var
  i: Integer;
begin
  // check consistency
  result := CheckInfo = 0;
  if not result then
    exit;
    
  // Update listbox
  if lbSites.items.Count = 0 then
    i := -1
  else begin
    if lbSites.Enabled then
      i := lbSites.ItemIndex
    else
      i := lbSites.Items.Count - 1;
  end;
    
  if i = -1 then begin
    i := Length(FSites);
    SetLength(FSites, i + 1);
    lbSites.Items.Add(txtSite.Text);
  end else begin
    if i >= Length(FSites) then
      SetLength(FSites, i + 1);
    lbSites.Items[i] := txtSite.Text;
    lbSites.Items.Objects[i] := nil;
  end;
  
  // store site values
  FSites[i].Site := txtSite.Text;
  FSites[i].txtHost := txtHost.Text;
  FSites[i].Port := txtPort.Text;
  FSites[i].path := txtPath.Text;
  FSites[i].User := txtUser.Text;
  FSites[i].Pass := txtPass.Text;
  SaveSites;
end;

procedure TfrmSites.DeleteSite(const i: Integer);
var
  j: Integer;
begin
  for j := i to High(FSites) - 1 do
    FSites[j] := FSites[j + 1];
    
  SetLength(FSites, Length(FSites) - 1);
  SaveSites;
end;

procedure TfrmSites.LoadSites;
var
  Ini: TIniFile;
  i,n: Integer;
  s  : string;
begin
  s := extractFilePath(Application.ExeName) + 'sites.ini';
  Ini := TIniFile.Create(s);
  try
    n:= Ini.ReadInteger('global', 'sitecount', 0);
    SetLength(FSites, n);
    lbSites.Clear;
    for i := 1 to n do
    with FSites[i - 1] do begin
      s := 'site'+IntToStr(i);
      Site := Ini.ReadString(s, 'site', s);
      txtHost := Ini.ReadString(s, 'host', '');
      Port := Ini.ReadString(s, 'port', '');
      Path := Ini.ReadString(s, 'path', '');
      User := Ini.ReadString(s, 'user', '');
      Pass := DecryptString(Ini.ReadString(s, 'pass', ''));
      lbSites.Items.add(Site);
    end;
  finally
    ini.free;
  end;
end;

procedure TfrmSites.SaveSites;
var
  Ini: TIniFile;
  i  : Integer;
  s  : string;
begin
  s := extractFilePath(Application.ExeName) + 'sites.ini';
  Ini := TIniFile.Create(s);
  try
    ini.WriteInteger('global', 'sitecount', Length(Fsites));
    for i := 0 to High(FSites) do begin
      s :='site' + IntToStr(i + 1);
      ini.WriteString(s, 'site', FSites[i].Site);
      ini.WriteString(s, 'host', FSites[i].txtHost);
      ini.WriteString(s, 'port', FSites[i].Port);
      ini.WriteString(s, 'path', FSites[i].Path);
      ini.WriteString(s, 'user', FSites[i].User);
      ini.WriteString(s, 'pass', EncryptString(FSites[i].Pass));
    end;
  finally
    ini.free;
  end;
end;

procedure TfrmSites.UpdateCurrentSite;
var
  i: Integer;
begin
  if lbSites.Items.Count>0 then begin
    if lbSites.ItemIndex<0 then
      i := 0
    else
      i := lbSites.ItemIndex;
  end else
    i:=-1;
    
  lbSites.ItemIndex := i;
  if i>=0 then begin
    txtSite.Text := FSites[i].Site;
    txtHost.Text := FSites[i].txtHost;
    txtPort.Text := FSites[i].Port;
    txtPath.Text := FSites[i].Path;
    txtUser.Text := FSites[i].User;
    txtPass.Text := FSites[i].Pass;
  end;
end;

function TfrmSites.CheckInfo: integer;
var
  tmp: Integer;
begin
  result := 0;
  with lbSites.Items do
  if txtSite.text = '' then
    result := 1
  else
  if FNewSite and (Count>0) and
     (Objects[lbSites.ItemIndex] = nil) and (IndexOf(txtSite.text) >= 0)
  then
    result := 2
  else
  if txtHost.Text = '' then
    result := 3
  else
  if txtPort.Text = '' then
    result := 4
  else
  if txtUser.Text = '' then
    result := 5;
  tmp := StrToIntDef(txtPort.Text, -1);
  if tmp < 0 then
    Result := 6
  else
  if (tmp < 1) or (tmp > 65535) then
    result := 7;

  case result of
    1: ShowMessage('Site dosn''t have a name');
    2: ShowMessage('Site it''s duplicated');
    3: ShowMessage('Host is blank');
    4: ShowMessage('Port is blank, try 21');
    5: ShowMessage('user is blank');
    6: ShowMessage('port value is invalid');
    7: ShowMessage('Port value is out of range');
  end;
end;

procedure TfrmSites.Modified(ok: boolean);
begin
  btnAddSite.Enabled := not ok;
  btnSave.Enabled := ok;
  btnConnect.Enabled := not ok;
  lbSites.Enabled := not ok;
end;

procedure TfrmSites.SaveLastSite;
var
  Ini: TIniFile;
  s: string;
begin
  Site.Site := txtSite.Text;
  Site.txtHost := txtHost.Text;
  Site.Port := txtPort.Text;
  Site.Path := txtPath.text;
  Site.User := txtUser.Text;
  Site.Pass := txtPass.Text;

  s := extractFilePath(Application.ExeName) + 'sites.ini';
  Ini := TIniFile.Create(s);
  try
    Ini.WriteInteger('global', 'lastsite', lbSites.ItemIndex + 1);
  finally
    Ini.Free;
  end;
end;

procedure TfrmSites.ChildHandlesCreated;
begin
  inherited ChildHandlesCreated;
  Modified(False);
end;

initialization

  {$I sitesunit.lrs}
  
end.

