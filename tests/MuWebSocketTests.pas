unit MuWebSocketTests;

{

Headless tests for the RFC 6455 client protocol.

The socket is a fake: no network, no lNet and no display server are
needed. These tests pin down handshake parsing, frame masking, ping/pong
and receive buffering before the lNet adapter is used in the application.

}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils, fpcunit, testregistry, testutils,
  MuTransport, MuWebSocket;

type
  TWebSocketSocketFake = class(TNoRefCountObject, IWebSocketSocket)
  public
    ConnectedValue: Boolean;
    Host: string;
    Port: string;
    Incoming: RawByteString;
    Sent: RawByteString;
    function Connected: Boolean;
    procedure Connect(const AHost, APort: string);
    procedure Disconnect;
    procedure SendBytes(const Data: RawByteString);
    function ReadBytes: RawByteString;
  end;

  TMuWebSocketTests = class(TTestCase)
  private
    FSocket: TWebSocketSocketFake;
    FChannel: TWebSocketClientChannel;
    procedure ConnectWith(const Endpoint: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestConfigureAndHandshake;
    procedure TestReceiveTextFrame;
    procedure TestSendFrameIsMasked;
    procedure TestPingGetsPong;
    procedure TestExtendedPayloadLength;
    procedure TestRejectsNon101Response;
    procedure TestRejectsBadAccept;
    procedure TestPumpCompletesHandshake;
    procedure TestSendBeforeHandshakeIsQueued;
    procedure TestReassemblesFragmentedText;
  end;

implementation

function ServerFrame(AOpcode: Byte; const Payload: RawByteString;
  AFin: Boolean = True): RawByteString;
var
  Len: Integer;
  FirstByte: Byte;
begin
  if AFin then
    FirstByte := $80 or AOpcode
  else
    FirstByte := AOpcode;
  Len := Length(Payload);
  if Len < 126 then
    Result := Chr(FirstByte) + Chr(Len) + Payload
  else
    Result := Chr(FirstByte) + Chr(126) +
      Chr((Len shr 8) and $FF) + Chr(Len and $FF) + Payload;
end;

function ExtractHandshakeKey(const Request: string): string;
var
  P, E: Integer;
begin
  Result := '';
  P := Pos('Sec-WebSocket-Key:', Request);
  if P = 0 then
    Exit;
  Inc(P, Length('Sec-WebSocket-Key:'));
  while (P <= Length(Request)) and (Request[P] in [' ', #9, #13, #10]) do
    Inc(P);
  E := P;
  while (E <= Length(Request)) and (Request[E] > #32) do
    Inc(E);
  Result := Copy(Request, P, E - P);
end;

function ValidHandshake(const SentRequest: string): RawByteString;
begin
  Result := 'HTTP/1.1 101 Switching Protocols' + #13#10 +
    'Upgrade: websocket' + #13#10 +
    'Connection: Upgrade' + #13#10 +
    'Sec-WebSocket-Accept: ' +
      WebSocketAccept(ExtractHandshakeKey(SentRequest)) + #13#10 + #13#10;
end;

procedure DecodeClientFrame(const Frame: RawByteString; out Opcode: Byte;
  out Payload: RawByteString; out Masked: Boolean);
var
  B1, Len, Offset, I: Integer;
  Mask: array[0..3] of Byte;
begin
  Opcode := Ord(Frame[1]) and $0F;
  B1 := Ord(Frame[2]);
  Masked := (B1 and $80) <> 0;
  Len := B1 and $7F;
  Offset := 3;

  if Len = 126 then
  begin
    Len := (Ord(Frame[3]) shl 8) or Ord(Frame[4]);
    Inc(Offset, 2);
  end
  else if Len = 127 then
  begin
    Len := 0;
    for I := 0 to 7 do
      Len := (Len shl 8) or Ord(Frame[3 + I]);
    Inc(Offset, 8);
  end;

  if Masked then
  begin
    for I := 0 to 3 do
      Mask[I] := Ord(Frame[Offset + I]);
    Inc(Offset, 4);
  end
  else
    FillChar(Mask, SizeOf(Mask), 0);

  SetLength(Payload, Len);
  for I := 1 to Len do
    Payload[I] := Chr(Ord(Frame[Offset + I - 1]) xor Mask[(I - 1) mod 4]);
end;

{ TWebSocketSocketFake }

function TWebSocketSocketFake.Connected: Boolean;
begin
  Result := ConnectedValue;
end;

procedure TWebSocketSocketFake.Connect(const AHost, APort: string);
begin
  Host := AHost;
  Port := APort;
  ConnectedValue := True;
end;

procedure TWebSocketSocketFake.Disconnect;
begin
  ConnectedValue := False;
end;

procedure TWebSocketSocketFake.SendBytes(const Data: RawByteString);
begin
  Sent := Sent + Data;
end;

function TWebSocketSocketFake.ReadBytes: RawByteString;
begin
  Result := Incoming;
  Incoming := '';
end;

{ TMuWebSocketTests }

procedure TMuWebSocketTests.SetUp;
begin
  inherited SetUp;
  FSocket := TWebSocketSocketFake.Create;
  FChannel := TWebSocketClientChannel.Create(FSocket);
end;

procedure TMuWebSocketTests.TearDown;
begin
  FChannel := nil;
  FSocket.Free;
  inherited TearDown;
end;

procedure TMuWebSocketTests.ConnectWith(const Endpoint: string);
begin
  FChannel.Configure(Endpoint);
  FChannel.Connect;
end;

procedure TMuWebSocketTests.TestConfigureAndHandshake;
begin
  ConnectWith('ws://example.com:8080/chat?a=1');

  AssertTrue(FSocket.ConnectedValue);
  AssertEquals('example.com', FSocket.Host);
  AssertEquals('8080', FSocket.Port);
  AssertTrue('GET satiri yok', Pos('GET /chat?a=1 HTTP/1.1', FSocket.Sent) > 0);
  AssertTrue('Host basligi yok', Pos('Host: example.com:8080', FSocket.Sent) > 0);
  AssertTrue('Upgrade basligi yok', Pos('Upgrade: websocket', FSocket.Sent) > 0);
  AssertTrue('Version basligi yok',
    Pos('Sec-WebSocket-Version: 13', FSocket.Sent) > 0);
end;

procedure TMuWebSocketTests.TestReceiveTextFrame;
begin
  ConnectWith('ws://example.com/ws');
  FSocket.Incoming := ValidHandshake(FSocket.Sent) +
    ServerFrame($1, 'merhaba');

  AssertEquals('merhaba', FChannel.Buffer);
  AssertTrue('Handshake tamamlanmadi', FChannel.Connected);
  FChannel.ClearBuffer;
  AssertEquals('', FChannel.Buffer);
end;

procedure TMuWebSocketTests.TestSendFrameIsMasked;
var
  Opcode: Byte;
  Payload: RawByteString;
  Masked: Boolean;
begin
  ConnectWith('ws://example.com/ws');
  FSocket.Incoming := ValidHandshake(FSocket.Sent);
  FChannel.Buffer; // handshake'i isler
  FSocket.Sent := '';

  FChannel.Send('A');
  DecodeClientFrame(FSocket.Sent, Opcode, Payload, Masked);

  AssertEquals($1, Opcode);
  AssertTrue('istemci frame maskelenmeli', Masked);
  AssertEquals('A', Payload);
end;

procedure TMuWebSocketTests.TestPingGetsPong;
var
  Opcode: Byte;
  Payload: RawByteString;
  Masked: Boolean;
begin
  ConnectWith('ws://example.com/ws');
  FSocket.Incoming := ValidHandshake(FSocket.Sent) +
    ServerFrame($9, 'naber');
  FSocket.Sent := ''; // el sıkışma isteğini temizle
  FChannel.Buffer;

  DecodeClientFrame(FSocket.Sent, Opcode, Payload, Masked);
  AssertEquals($A, Opcode);
  AssertTrue(Masked);
  AssertEquals('naber', Payload);
end;

procedure TMuWebSocketTests.TestExtendedPayloadLength;
var
  Payload: RawByteString;
begin
  Payload := StringOfChar('x', 200);
  ConnectWith('ws://example.com/ws');
  FSocket.Incoming := ValidHandshake(FSocket.Sent) + ServerFrame($1, Payload);

  AssertEquals(Payload, FChannel.Buffer);
end;

procedure TMuWebSocketTests.TestRejectsNon101Response;
begin
  ConnectWith('ws://example.com/ws');
  FSocket.Incoming := 'HTTP/1.1 400 Bad Request' + #13#10#13#10;

  try
    FChannel.Buffer;
    Fail('400 yaniti hata vermeli');
  except
    on E: EWebSocketError do
      AssertTrue(Pos('upgrade', LowerCase(E.Message)) > 0);
  end;
  AssertFalse(FSocket.ConnectedValue);
end;

procedure TMuWebSocketTests.TestRejectsBadAccept;
var
  Request: string;
begin
  ConnectWith('ws://example.com/ws');
  Request := FSocket.Sent;
  FSocket.Incoming := 'HTTP/1.1 101 Switching Protocols' + #13#10 +
    'Upgrade: websocket' + #13#10 +
    'Connection: Upgrade' + #13#10 +
    'Sec-WebSocket-Accept: yanlis-deger' + #13#10 + #13#10;

  try
    FChannel.Buffer;
    Fail('yanlis accept hata vermeli');
  except
    on E: EWebSocketError do
      AssertTrue('accept mesaji yok',
        Pos('accept', LowerCase(E.Message)) > 0);
  end;
  AssertFalse(FSocket.ConnectedValue);
  AssertTrue('Bad accept sonrasi baglanti kurulmamis olmali',
    not FChannel.Connected);
  AssertTrue('Handshake istegi gonderilmis olmali', Pos('GET ', Request) > 0);
end;

procedure TMuWebSocketTests.TestPumpCompletesHandshake;
begin
  ConnectWith('ws://example.com/ws');
  FSocket.Incoming := ValidHandshake(FSocket.Sent) +
    ServerFrame($1, 'pump-verisi');

  AssertFalse('Pump oncesi handshake yok', FChannel.Connected);
  FChannel.Pump;
  AssertTrue('Pump handshake tamamladi', FChannel.Connected);
  AssertEquals('pump-verisi', FChannel.Buffer);
end;

procedure TMuWebSocketTests.TestSendBeforeHandshakeIsQueued;
var
  Request: string;
  Opcode: Byte;
  Payload: RawByteString;
  Masked: Boolean;
begin
  ConnectWith('ws://example.com/ws');
  Request := FSocket.Sent;
  FSocket.Sent := '';

  FChannel.Send('erken-veri');
  AssertEquals('Handshake bitmeden frame gonderilmemeli', '', FSocket.Sent);

  FSocket.Incoming := ValidHandshake(Request);
  FChannel.Pump;

  DecodeClientFrame(FSocket.Sent, Opcode, Payload, Masked);
  AssertEquals($1, Opcode);
  AssertTrue(Masked);
  AssertEquals('erken-veri', Payload);
end;

procedure TMuWebSocketTests.TestReassemblesFragmentedText;
begin
  ConnectWith('ws://example.com/ws');
  FSocket.Incoming := ValidHandshake(FSocket.Sent) +
    ServerFrame($1, 'hel', False) +
    ServerFrame($9, 'ping-araya') +
    ServerFrame($0, 'lo ', False) +
    ServerFrame($0, 'dunya', True);

  AssertEquals('hello dunya', FChannel.Buffer);
  FChannel.ClearBuffer;
  AssertEquals('', FChannel.Buffer);
end;

initialization
  RegisterTest(TMuWebSocketTests);

end.
