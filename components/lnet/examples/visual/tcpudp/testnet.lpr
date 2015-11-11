program testnet;

{$mode objfpc}{$H+}

uses
  Interfaces, // this includes the LCL widgetset
  Forms
  { add your units here }, main, lnetvisual, lnetbase;

begin
  Application.Title:='TCP/UDP Test case';
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

