unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs,
  StdCtrls, Buttons, lNetComponents, lNet, ExtCtrls, Menus;

type

  { TForm1 }

  TForm1 = class(TForm)
    ButtonDiconnect: TButton;
    ButtonConnect: TButton;
    ButtonListen: TButton;
    LTCP: TLTCPComponent;
    LUDP: TLUDPComponent;
    EditPort: TEdit;
    EditIP: TEdit;
    LabelPort: TLabel;
    LabelHostName: TLabel;
    GBConnection: TRadioGroup;
    MainMenu1: TMainMenu;
    MenuItemExit: TMenuItem;
    MenuItemAbout: TMenuItem;
    MenuItemHelp: TMenuItem;
    MenuItemFile: TMenuItem;
    RBTCP: TRadioButton;
    RBUDP: TRadioButton;
    ButtonSend: TButton;
    EditSend: TEdit;
    MemoText: TMemo;
    procedure LTCPComponentConnect(aSocket: TLSocket);
    procedure ListenButtonClick(Sender: TObject);
    procedure ConnectButtonClick(Sender: TObject);
    procedure DiconnectButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure LTCPComponentError(const msg: string; aSocket: TLSocket);
    procedure LTCPComponentAccept(aSocket: TLSocket);
    procedure LTCPComponentReceive(aSocket: TLSocket);
    procedure LTcpComponentDisconnect(aSocket: TLSocket);
    procedure MenuItemAboutClick(Sender: TObject);
    procedure MenuItemExitClick(Sender: TObject);
    procedure RBTCPChange(Sender: TObject);
    procedure RBUDPChange(Sender: TObject);
    procedure SendButtonClick(Sender: TObject);
    procedure SendEditKeyPress(Sender: TObject; var Key: char);
  private
    FNet: TLConnection;
    FIsServer: Boolean;
  public
    { public declarations }
  end; 

var
  Form1: TForm1; 

implementation

{ TForm1 }

procedure TForm1.ConnectButtonClick(Sender: TObject);
begin
  if FNet.Connect(EditIP.Text, StrToInt(EditPort.Text)) then
    FIsServer := False;
end;

procedure TForm1.ListenButtonClick(Sender: TObject);
begin
  if FNet.Listen(StrToInt(EditPort.Text)) then begin
    MemoText.Append('Accepting connections');
    FIsServer := True;
  end;
end;

procedure TForm1.LTCPComponentConnect(aSocket: TLSocket);
begin
  MemoText.Append('Connected to remote host');
end;

procedure TForm1.LTCPComponentError(const msg: string; aSocket: TLSocket);
begin
  MemoText.Append(msg);
  MemoText.SelStart := Length(MemoText.Lines.Text);
end;

procedure TForm1.LTCPComponentAccept(aSocket: TLSocket);
begin
  MemoText.Append('Connection accepted');
  MemoText.SelStart := Length(MemoText.Lines.Text);
end;

procedure TForm1.LTCPComponentReceive(aSocket: TLSocket);
var
  s: string;
begin
  if aSocket.GetMessage(s) > 0 then begin
    MemoText.Append(s);
    MemoText.SelStart := Length(MemoText.Lines.Text);
    FNet.IterReset;
    if FIsServer then repeat
      FNet.SendMessage(s, FNet.Iterator);
    until not FNet.IterNext;
  end;
end;

procedure TForm1.LTcpComponentDisconnect(aSocket: TLSocket);
begin
  MemoText.Append('Connection lost');
  MemoText.SelStart := Length(MemoText.Lines.Text);
end;

procedure TForm1.MenuItemAboutClick(Sender: TObject);
begin
  MessageDlg('TCP/UDP example copyright(c) 2005-2008 by Ales Katona. All rights deserved ;)',
             mtInformation, [mbOK], 0);
end;

procedure TForm1.MenuItemExitClick(Sender: TObject);
begin
  Close;
end;

procedure TForm1.SendButtonClick(Sender: TObject);
var
  AllOK: Boolean;
  n: Integer;
begin
  if Length(EditSend.Text) > 0 then begin
    AllOk := True;
    if Assigned(FNet.Iterator) then repeat
      n := FNet.SendMessage(EditSend.Text, FNet.Iterator);
      if n < Length(EditSend.Text) then begin
        MemoText.Append('Error on send [' + IntToStr(n) + ']');
        AllOK := False;
      end;
    until not FNet.IterNext;
    if FIsServer and AllOK then
      MemoText.Append(EditSend.Text);
    EditSend.Text := '';
  end;
end;

procedure TForm1.DiconnectButtonClick(Sender: TObject);
begin
  FNet.Disconnect;
  MemoText.Append('Disconnected');
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  FNet := LTCP;
  FIsServer := False;
end;

procedure TForm1.RBTCPChange(Sender: TObject);
begin
  FNet.Disconnect;
  FNet := LTCP;
end;

procedure TForm1.RBUDPChange(Sender: TObject);
begin
  FNet.Disconnect;
  FNet := LUDP;
end;

procedure TForm1.SendEditKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
    SendButtonClick(Sender);
end;

initialization
  {$I main.lrs}

end.

