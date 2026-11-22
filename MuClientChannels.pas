unit MuClientChannels;

{

Active client channel selection for script commands.

The script keeps using :TCP_* commands, but :TCP_SETUP may now carry a
ws:// endpoint. In that case the router switches the active IClientChannel
from the legacy TCP channel to the WebSocket channel. Plain host,port
endpoints keep the old TCP behaviour.

}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, MuTransport;

type
  TClientChannelRouter = class(TInterfacedObject, IClientChannel)
  private
    FTcp: IClientChannel;
    FWebSocket: IClientChannel;
    FActive: IClientChannel;
    procedure SelectChannel(const Endpoint: string);
  public
    constructor Create(ATcp, AWebSocket: IClientChannel);
    function Connected: Boolean;
    procedure Connect;
    procedure Disconnect;
    procedure Send(const Data: string);
    procedure Configure(const Endpoint: string);
    function Buffer: string;
    procedure ClearBuffer;
    procedure Pump;
  end;

implementation

function IsWebSocketEndpoint(const Endpoint: string): Boolean;
begin
  Result := (LowerCase(Copy(Endpoint, 1, 5)) = 'ws://') or
    (LowerCase(Copy(Endpoint, 1, 6)) = 'wss://');
end;

{ TClientChannelRouter }

constructor TClientChannelRouter.Create(ATcp, AWebSocket: IClientChannel);
begin
  inherited Create;
  FTcp := ATcp;
  FWebSocket := AWebSocket;
  FActive := FTcp;
end;

procedure TClientChannelRouter.SelectChannel(const Endpoint: string);
var
  Wanted: IClientChannel;
begin
  if IsWebSocketEndpoint(Endpoint) then
    Wanted := FWebSocket
  else
    Wanted := FTcp;

  if (Wanted <> nil) and (FActive <> Wanted) then
  begin
    if (FActive <> nil) and FActive.Connected then
      FActive.Disconnect;
    FActive := Wanted;
  end;
end;

function TClientChannelRouter.Connected: Boolean;
begin
  Result := (FActive <> nil) and FActive.Connected;
end;

procedure TClientChannelRouter.Connect;
begin
  if FActive <> nil then
    FActive.Connect;
end;

procedure TClientChannelRouter.Disconnect;
begin
  if FActive <> nil then
    FActive.Disconnect;
end;

procedure TClientChannelRouter.Send(const Data: string);
begin
  if FActive <> nil then
    FActive.Send(Data);
end;

procedure TClientChannelRouter.Configure(const Endpoint: string);
begin
  SelectChannel(Endpoint);
  if FActive <> nil then
    FActive.Configure(Endpoint);
end;

function TClientChannelRouter.Buffer: string;
begin
  Result := '';
  if FActive <> nil then
    Result := FActive.Buffer;
end;

procedure TClientChannelRouter.ClearBuffer;
begin
  if FActive <> nil then
    FActive.ClearBuffer;
end;

procedure TClientChannelRouter.Pump;
begin
  if FActive <> nil then
    FActive.Pump;
end;

end.
