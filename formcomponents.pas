unit FormComponents;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, SynHighlighterAny, SynHighlighterPas, LazSerial,
  uPSComponent, lNetComponents, Dialogs, ExtCtrls, EditBtn, StdCtrls;

type

  { TFormComponents }

  TFormComponents = class(TDataModule)
    CiaCom1: TLazSerial;
    FontDialog1: TFontDialog;
    LTCP_Port: TLTCPComponent;
    OpenDialog1: TOpenDialog;
    PSScript1: TPSScript;
    SaveDialog1: TSaveDialog;
    SynAnySyn1: TSynAnySyn;
    SynPasSyn1: TSynPasSyn;
    tmrGeneral: TTimer;
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  FormComponents: TFormComponents;

implementation

{$R *.lfm}

end.

