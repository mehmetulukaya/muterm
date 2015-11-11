program ftptest;

{$mode objfpc}{$H+}

uses
  Interfaces, // this includes the LCL widgetset
  Forms
  { add your units here }, Main, sitesunit, 
dleparsers, lnetvisual, lnetbase;

begin
  Application.Title:='FTP Test case';
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

