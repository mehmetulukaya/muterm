program MuTests;

{

Headless FPCUnit runner for the LCL-free MuTerm units.

Run from the repository root:

  ./tests/run-tests.sh

The runner is built with plain FPC, not Lazarus, so it stays fast and
works on build agents without a display server.

}

{$mode objfpc}{$H+}

uses
  consoletestrunner,
  MuLibsTests,
  MuExprTests,
  MuScriptSyntaxTests,
  MuCommandsTests,
  MuTransportTests,
  MuWebSocketTests
  {$IFDEF UNIX}
  , MuWebSocketIntegrationTests
  {$ENDIF}
  ;

var
  App: TTestRunner;
begin
  DefaultRunAllTests := True;
  DefaultFormat := fPlain;

  App := TTestRunner.Create(nil);
  try
    App.Initialize;
    App.Title := 'MuTerm unit tests';
    App.Run;
  finally
    App.Free;
  end;
end.
