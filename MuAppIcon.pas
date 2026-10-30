unit MuAppIcon;

{

Window icon helper.

On Linux/GTK2 the LCL converts the project's .ico resource into a GdkPixbuf
and the resulting _NET_WM_ICON property loses the alpha channel: transparent
pixels become opaque black and the colour channels get shifted.  Loading the
icon through GTK directly from a PNG keeps the alpha channel intact, so the
window manager and the task bar render the icon correctly.

The GTK specific code is compiled only for the GTK2 widget set; on Windows
and on the other widgetsets the icon embedded in the executable is used and
this unit does nothing.

}

{$mode objfpc}{$H+}

interface

uses
  Forms;

{ Applies MUTerm.png to the window of AForm when running on GTK2.
  The file is looked up next to the executable, one directory above it and
  in the current directory.  Missing files are ignored. }
procedure ApplyAppIcon(AForm: TCustomForm);

implementation

uses
  SysUtils, LazFileUtils
  {$IFDEF LCLGTK2}, Gtk2{$ENDIF};

const
  AppIconName = 'MUTerm.png';

function FindAppIcon: string;
var
  ExeDir: string;
begin
  ExeDir := ExtractFileDir(ParamStr(0));
  Result := IncludeTrailingPathDelimiter(ExeDir) + AppIconName;
  if FileExists(Result) then
    Exit;

  Result := IncludeTrailingPathDelimiter(ExtractFileDir(ExeDir)) + AppIconName;
  if FileExists(Result) then
    Exit;

  Result := IncludeTrailingPathDelimiter(GetCurrentDir) + AppIconName;
  if not FileExists(Result) then
    Result := '';
end;

procedure ApplyAppIcon(AForm: TCustomForm);
{$IFDEF LCLGTK2}
var
  IconFile: string;
begin
  if (AForm = nil) or not AForm.HandleAllocated then
    Exit;

  IconFile := FindAppIcon;
  if IconFile = '' then
    Exit;

  gtk_window_set_icon_from_file(PGtkWindow(AForm.Handle), PChar(IconFile), nil);
end;
{$ELSE}
begin
end;
{$ENDIF}

end.
