unit MuWebSocketIntegrationTests;

{

End-to-end WebSocket client test over a real loopback TCP connection.

The echo server is deliberately tiny and lives inside the test process: it
performs the RFC 6455 handshake, decodes masked client frames and echoes
them back. This exercises the real socket adapter path without lNet, a
display server or an external network service.

}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, BaseUnix, Sockets, fpcunit, testregistry, testutils,
  MuTransport, MuWebSocket;

type
  TLoopbackSocket = class(TNoRefCountObject, IWebSocketSocket)
  private
    FHandle: cint;
  public
    destructor Destroy; override;
    function Connected: Boolean;
    procedure Connect(const Host, Port: string);
    procedure Disconnect;
    procedure SendBytes(const Data: RawByteString);
    function ReadBytes: RawByteString;
  end;

  TEchoServer = class
  private
    FListen: cint;
    FClient: cint;
    FPortText: string;
    FPending: RawByteString;
    FHandshakeDone: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Port: string;
    procedure Step;
  end;

  TMuWebSocketIntegrationTests = class(TTestCase)
  private
    FServer: TEchoServer;
    FSocket: TLoopbackSocket;
    FChannel: TWebSocketClientChannel;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestHandshakeAndEchoOverLoopback;
  end;

implementation

const
  LoopbackAddress = $7F000001; { 127.0.0.1 }
  MaxWaitIterations = 400;
  WaitSliceMs = 5;

function Readable(Handle: cint): Boolean;
var
  Fds: TFDSet;
  Tv: TTimeVal;
begin
  Result := False;
  if Handle < 0 then
    Exit;
  fpFD_ZERO(Fds);
  fpFD_SET(Handle, Fds);
  Tv.tv_sec := 0;
  Tv.tv_usec := 0;
  Result := (fpselect(Handle + 1, @Fds, nil, nil, @Tv) > 0) and
    (fpFD_ISSET(Handle, Fds) <> 0);
end;

function ReadAvailable(Handle: cint): RawByteString;
var
  Buf: array[0..4095] of Byte;
  N: Integer;
begin
  Result := '';
  if not Readable(Handle) then
    Exit;
  N := fprecv(Handle, @Buf[0], SizeOf(Buf), 0);
  if N > 0 then
  begin
    SetLength(Result, N);
    Move(Buf[0], Result[1], N);
  end;
end;

procedure WriteAll(Handle: cint; const Data: RawByteString);
var
  Sent, N: Integer;
begin
  if (Handle < 0) or (Data = '') then
    Exit;
  Sent := 0;
  while Sent < Length(Data) do
  begin
    N := fpsend(Handle, @Data[Sent + 1], Length(Data) - Sent, 0);
    if N <= 0 then
      raise EWebSocketError.Create('loopback yazma hatasi');
    Inc(Sent, N);
  end;
end;

function ExtractKey(const Headers: string): string;
var
  P, E: Integer;
begin
  Result := '';
  P := Pos('Sec-WebSocket-Key:', Headers);
  if P = 0 then
    Exit;
  Inc(P, Length('Sec-WebSocket-Key:'));
  while (P <= Length(Headers)) and (Headers[P] in [' ', #9, #13, #10]) do
    Inc(P);
  E := P;
  while (E <= Length(Headers)) and (Headers[E] > #32) do
    Inc(E);
  Result := Copy(Headers, P, E - P);
end;

function ServerTextFrame(const Payload: RawByteString): RawByteString;
var
  Len: Integer;
begin
  Len := Length(Payload);
  if Len < 126 then
    Result := Chr($81) + Chr(Len) + Payload
  else
    Result := Chr($81) + Chr(126) + Chr((Len shr 8) and $FF) +
      Chr(Len and $FF) + Payload;
end;

function TryClientTextFrame(const Buf: RawByteString;
  out Payload: RawByteString; out Used: Integer): Boolean;
var
  B0, B1, Len, Offset, I: Integer;
  Mask: array[0..3] of Byte;
begin
  Result := False;
  if Length(Buf) < 2 then
    Exit;
  B0 := Ord(Buf[1]);
  B1 := Ord(Buf[2]);
  if ((B0 and $0F) <> $1) or ((B1 and $80) = 0) then
    Exit;

  Len := B1 and $7F;
  Offset := 3;
  if Len = 126 then
  begin
    if Length(Buf) < 5 then
      Exit;
    Len := (Ord(Buf[3]) shl 8) or Ord(Buf[4]);
    Inc(Offset, 2);
  end
  else if Len = 127 then
    Exit; { not needed by this test }

  if Length(Buf) < Offset + 4 + Len - 1 then
    Exit;
  for I := 0 to 3 do
    Mask[I] := Ord(Buf[Offset + I]);
  Inc(Offset, 4);

  SetLength(Payload, Len);
  for I := 1 to Len do
    Payload[I] := Chr(Ord(Buf[Offset + I - 1]) xor Mask[(I - 1) mod 4]);
  Used := Offset + Len - 1;
  Result := True;
end;

{ TLoopbackSocket }

destructor TLoopbackSocket.Destroy;
begin
  Disconnect;
  inherited Destroy;
end;

function TLoopbackSocket.Connected: Boolean;
begin
  Result := FHandle >= 0;
end;

procedure TLoopbackSocket.Connect(const Host, Port: string);
var
  Addr: TInetSockAddr;
begin
  if (Host <> '127.0.0.1') and (Host <> 'localhost') then
    raise EWebSocketError.Create('loopback testi yerel adres kullanir');

  FHandle := fpsocket(AF_INET, SOCK_STREAM, 0);
  if FHandle < 0 then
    raise EWebSocketError.Create('loopback socket acilamadi');

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(Word(StrToInt(Port)));
  Addr.sin_addr.s_addr := htonl(LoopbackAddress);
  if fpconnect(FHandle, @Addr, SizeOf(Addr)) < 0 then
  begin
    CloseSocket(FHandle);
    FHandle := -1;
    raise EWebSocketError.Create('loopback baglantisi basarisiz: ' + Host + ':' + Port);
  end;
end;

procedure TLoopbackSocket.Disconnect;
begin
  if FHandle >= 0 then
    CloseSocket(FHandle);
  FHandle := -1;
end;

procedure TLoopbackSocket.SendBytes(const Data: RawByteString);
begin
  WriteAll(FHandle, Data);
end;

function TLoopbackSocket.ReadBytes: RawByteString;
begin
  Result := ReadAvailable(FHandle);
end;

{ TEchoServer }

constructor TEchoServer.Create;
var
  Addr: TInetSockAddr;
  Len: TSockLen;
begin
  inherited Create;
  FClient := -1;
  FListen := fpsocket(AF_INET, SOCK_STREAM, 0);
  if FListen < 0 then
    raise EWebSocketError.Create('loopback sunucu socket acilamadi');

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := 0;
  Addr.sin_addr.s_addr := htonl(LoopbackAddress);
  if fpbind(FListen, @Addr, SizeOf(Addr)) < 0 then
    raise EWebSocketError.Create('loopback bind basarisiz');
  Len := SizeOf(Addr);
  if fpgetsockname(FListen, @Addr, @Len) < 0 then
    raise EWebSocketError.Create('loopback port okunamadi');
  FPortText := IntToStr(ntohs(Addr.sin_port));
  if fplisten(FListen, 1) < 0 then
    raise EWebSocketError.Create('loopback listen basarisiz');
end;

destructor TEchoServer.Destroy;
begin
  if FClient >= 0 then
    CloseSocket(FClient);
  if FListen >= 0 then
    CloseSocket(FListen);
  inherited Destroy;
end;

function TEchoServer.Port: string;
begin
  Result := FPortText;
end;

procedure TEchoServer.Step;
var
  Addr: TInetSockAddr;
  Len: TSockLen;
  P, Used: Integer;
  Headers, Response, Payload: RawByteString;
begin
  if (FClient < 0) and Readable(FListen) then
  begin
    Len := SizeOf(Addr);
    FClient := fpaccept(FListen, @Addr, @Len);
  end;
  if FClient < 0 then
    Exit;

  FPending := FPending + ReadAvailable(FClient);
  if not FHandshakeDone then
  begin
    P := Pos(#13#10#13#10, FPending);
    if P = 0 then
      Exit;
    Headers := Copy(FPending, 1, P - 1);
    Response := 'HTTP/1.1 101 Switching Protocols' + #13#10 +
      'Upgrade: websocket' + #13#10 +
      'Connection: Upgrade' + #13#10 +
      'Sec-WebSocket-Accept: ' +
        WebSocketAccept(ExtractKey(string(Headers))) + #13#10 + #13#10;
    WriteAll(FClient, Response);
    Delete(FPending, 1, P + 3);
    FHandshakeDone := True;
  end;

  while TryClientTextFrame(FPending, Payload, Used) do
  begin
    Delete(FPending, 1, Used);
    WriteAll(FClient, ServerTextFrame(Payload));
  end;
end;

{ TMuWebSocketIntegrationTests }

procedure TMuWebSocketIntegrationTests.SetUp;
begin
  inherited SetUp;
  FServer := TEchoServer.Create;
  FSocket := TLoopbackSocket.Create;
  FChannel := TWebSocketClientChannel.Create(FSocket);
end;

procedure TMuWebSocketIntegrationTests.TearDown;
begin
  FChannel := nil;
  FSocket.Free;
  FServer.Free;
  inherited TearDown;
end;

procedure TMuWebSocketIntegrationTests.TestHandshakeAndEchoOverLoopback;
var
  I: Integer;
begin
  FChannel.Configure('ws://127.0.0.1:' + FServer.Port + '/echo');
  FChannel.Connect;
  { Deliberately send before the server has answered the handshake. }
  FChannel.Send('erken');

  for I := 1 to MaxWaitIterations do
  begin
    FChannel.Pump;
    FServer.Step;
    if FChannel.Connected and (Pos('erken', FChannel.Buffer) > 0) then
      Break;
    Sleep(WaitSliceMs);
  end;

  AssertTrue('loopback handshake tamamlanmadi', FChannel.Connected);
  AssertTrue('handshake oncesi frame echo edilmedi',
    Pos('erken', FChannel.Buffer) > 0);

  FChannel.ClearBuffer;
  FChannel.Send('ikinci');
  for I := 1 to MaxWaitIterations do
  begin
    FChannel.Pump;
    FServer.Step;
    if Pos('ikinci', FChannel.Buffer) > 0 then
      Break;
    Sleep(WaitSliceMs);
  end;
  AssertTrue('ikinci frame echo edilmedi',
    Pos('ikinci', FChannel.Buffer) > 0);
end;

initialization
  RegisterTest(TMuWebSocketIntegrationTests);

end.
