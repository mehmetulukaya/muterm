unit MuClock;

{

Clock abstraction for the script engine.

Timeout handling used to call SysUtils.Now directly, which forced the
tests to sleep for real. The engine now asks an IClock instead, so a
test can advance time instantly and deterministically.

}

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  IClock = interface
    ['{7B1D4E2A-3C58-4F0B-9A6D-2E8C5F1B4D37}']
    function Now: TDateTime;
  end;

  TSystemClock = class(TInterfacedObject, IClock)
  public
    function Now: TDateTime;
  end;

implementation

function TSystemClock.Now: TDateTime;
begin
  Result := SysUtils.Now;
end;

end.
