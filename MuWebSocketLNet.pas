unit MuWebSocketLNet;

{

lNet-backed byte transport for MuWebSocket.

This is the only unit that knows about lNet. The protocol and the script
engine only see IWebSocketSocket / IClientChannel, so swapping the socket
library later does not touch either of them.

}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, lNet, lNetComponents, MuWebSocket;

type
  TLNetWebSocketSocket = class(TInterfacedObject, IWebSocketSocket)
  private
    FClient: TLTCPComponent;
    FIncoming: RawByteString;
    FOutgoing: RawByteString;
    procedure SocketConnect(aSocket: TLSocket);
    procedure SocketDisconnect(aSocket: TLSocket);
    procedure SocketReceive(aSocket: TLSocket);
    procedure SocketError(const Msg: string; aSocket: TLSocket);
  public
    constructor Create;
    destructor Destroy; override;
    function Connected: Boolean;
    procedure Connect(const Host, Port: string);
    procedure Disconnect;
    procedure SendBytes(const Data: RawByteString);
    function ReadBytes: RawByteString;
  end;

implementation

{ TLNetWebSocketSocket }

constructor TLNetWebSocketSocket.Create;
begin
  inherited Create;
  FClient := TLTCPComponent.Create(nil);
  FClient.OnConnect := @SocketConnect;
  FClient.OnDisconnect := @SocketDisconnect;
  FClient.OnReceive := @SocketReceive;
  FClient.OnError := @SocketError;
end;

destructor TLNetWebSocketSocket.Destroy;
begin
  FClient.Free;
  inherited Destroy;
end;

function TLNetWebSocketSocket.Connected: Boolean;
begin
  Result := (FClient <> nil) and FClient.Connected;
end;

procedure TLNetWebSocketSocket.Connect(const Host, Port: string);
var
  PortNumber: Integer;
begin
  if not TryStrToInt(Port, PortNumber) then
    raise EWebSocketError.Create('gecersiz WebSocket portu: ' + Port);
  if (PortNumber < 1) or (PortNumber > 65535) then
    raise EWebSocketError.Create('WebSocket port aralik disinda: ' + Port);
  if not FClient.Connect(Host, Word(PortNumber)) then
    raise EWebSocketError.Create('WebSocket baglanamadi: ' + Host + ':' + Port);
end;

procedure TLNetWebSocketSocket.Disconnect;
begin
  FIncoming := '';
  FOutgoing := '';
  if FClient <> nil then
    FClient.Disconnect;
end;

procedure TLNetWebSocketSocket.SendBytes(const Data: RawByteString);
begin
  if Data = '' then
    Exit;
  { lNet connects asynchronously. Queue the HTTP upgrade until OnConnect
    fires, otherwise the first frame would be silently dropped. }
  if Connected then
    FClient.SendMessage(Data, FClient.Iterator)
  else
    FOutgoing := FOutgoing + Data;
end;

function TLNetWebSocketSocket.ReadBytes: RawByteString;
begin
  if FClient <> nil then
    FClient.CallAction;
  Result := FIncoming;
  FIncoming := '';
end;

procedure TLNetWebSocketSocket.SocketConnect(aSocket: TLSocket);
begin
  if (FOutgoing <> '') and Connected then
  begin
    FClient.SendMessage(FOutgoing, FClient.Iterator);
    FOutgoing := '';
  end;
end;

procedure TLNetWebSocketSocket.SocketDisconnect(aSocket: TLSocket);
begin
  FIncoming := '';
  FOutgoing := '';
end;

procedure TLNetWebSocketSocket.SocketReceive(aSocket: TLSocket);
var
  S: string;
begin
  if aSocket.GetMessage(S) > 0 then
    FIncoming := FIncoming + S;
end;

procedure TLNetWebSocketSocket.SocketError(const Msg: string;
  aSocket: TLSocket);
begin
  // Errors are surfaced by the protocol layer through Connected = False.
end;

end.
