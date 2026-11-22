unit MuWebSocket;

{

Minimal RFC 6455 WebSocket client protocol, independent of any socket API.

The low-level byte transport is injected as IWebSocketSocket, so framing,
handshake and masking can be tested headlessly. MuWebSocketLNet supplies
the real lNet-backed socket for the application.

TWebSocketClientChannel implements the generic IClientChannel role, which
means the script engine does not need to know whether the active client
is TCP or WebSocket.

}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, MuTransport, sha1;

{ RFC 6455 section 4.2.2: SHA-1 of the client key plus the magic GUID,
  encoded as base64. Exported so tests and servers can verify it. }
function WebSocketAccept(const Key: string): string;

type
  EWebSocketError = class(Exception);

  { The smallest byte pipe the protocol needs. Received bytes are queued
    by the adapter and consumed by TWebSocketClientChannel.Buffer. }
  IWebSocketSocket = interface
    ['{1C7D4A93-8B25-4E61-9F30-6A2B5D8C4E17}']
    function Connected: Boolean;
    procedure Connect(const Host, Port: string);
    procedure Disconnect;
    procedure SendBytes(const Data: RawByteString);
    function ReadBytes: RawByteString;
  end;

  TWebSocketClientChannel = class(TInterfacedObject, IClientChannel)
  private
    FSocket: IWebSocketSocket;
    FHost: string;
    FPort: string;
    FPath: string;
    FBuffer: string;
    FPending: RawByteString;
    FHandshakeKey: string;
    FHandshakeDone: Boolean;
    FOutgoingFrames: RawByteString;
    FFragmentOpcode: Byte;
    FFragmentPayload: RawByteString;
    procedure ProcessPending;
    procedure ParseFrames;
    procedure HandleFrame(AFin: Boolean; AOpcode: Byte;
      const Payload: RawByteString);
    function BuildFrame(AOpcode: Byte;
      const Payload: RawByteString): RawByteString;
    procedure SendFrame(AOpcode: Byte; const Payload: RawByteString);
    procedure FlushOutgoing;
    procedure ResetState;
  public
    constructor Create(ASocket: IWebSocketSocket);
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

const
  CRLF = #13#10;
  WebSocketGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

function Base64Encode(const Input: RawByteString): string;
const
  Table = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  I, V: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(Input) do
  begin
    V := Ord(Input[I]) shl 16;
    if I + 1 <= Length(Input) then
      V := V or (Ord(Input[I + 1]) shl 8);
    if I + 2 <= Length(Input) then
      V := V or Ord(Input[I + 2]);

    Result := Result + Table[((V shr 18) and $3F) + 1] +
      Table[((V shr 12) and $3F) + 1];

    if I + 1 <= Length(Input) then
      Result := Result + Table[((V shr 6) and $3F) + 1]
    else
      Result := Result + '=';

    if I + 2 <= Length(Input) then
      Result := Result + Table[(V and $3F) + 1]
    else
      Result := Result + '=';

    Inc(I, 3);
  end;
end;

function WebSocketAccept(const Key: string): string;
var
  Digest: TSHA1Digest;
  Raw: RawByteString;
  I: Integer;
begin
  Digest := SHA1String(Key + WebSocketGuid);
  SetLength(Raw, SizeOf(Digest));
  for I := 0 to High(Digest) do
    Raw[I + 1] := Chr(Digest[I]);
  Result := Base64Encode(Raw);
end;

function RandomKey: RawByteString;
var
  I: Integer;
begin
  SetLength(Result, 16);
  for I := 1 to 16 do
    Result[I] := Chr(Random(256));
end;

procedure ParseEndpoint(const Endpoint: string; out Host, Port, Path: string);
var
  S, HostPort: string;
  P: Integer;
begin
  S := Trim(Endpoint);
  if Copy(S, 1, 6) = 'wss://' then
    raise EWebSocketError.Create('wss desteklenmiyor (TLS yok)');
  if Copy(S, 1, 5) = 'ws://' then
    Delete(S, 1, 5);

  P := Pos('/', S);
  if P > 0 then
  begin
    HostPort := Copy(S, 1, P - 1);
    Path := Copy(S, P, MaxInt);
  end
  else
  begin
    HostPort := S;
    Path := '/';
  end;

  P := LastDelimiter(':', HostPort);
  if P > 0 then
  begin
    Host := Copy(HostPort, 1, P - 1);
    Port := Copy(HostPort, P + 1, MaxInt);
  end
  else
  begin
    Host := HostPort;
    Port := '80';
  end;

  if (Host = '') or (Port = '') then
    raise EWebSocketError.Create('gecersiz WebSocket adresi: ' + Endpoint);
end;

function HeaderValue(const Headers, Name: string): string;
var
  LineStart, LineEnd, Colon: Integer;
  Line: string;
begin
  Result := '';
  LineStart := 1;
  while LineStart <= Length(Headers) do
  begin
    LineEnd := LineStart;
    while (LineEnd <= Length(Headers)) and (Headers[LineEnd] <> #10) do
      Inc(LineEnd);
    Line := Copy(Headers, LineStart, LineEnd - LineStart);
    if (Line <> '') and (Line[Length(Line)] = #13) then
      SetLength(Line, Length(Line) - 1);

    Colon := Pos(':', Line);
    if (Colon > 0) and
       (LowerCase(Trim(Copy(Line, 1, Colon - 1))) = LowerCase(Name)) then
    begin
      Result := Trim(Copy(Line, Colon + 1, MaxInt));
      Exit;
    end;

    if LineEnd > Length(Headers) then
      Break;
    LineStart := LineEnd + 1;
  end;
end;

{ TWebSocketClientChannel }

constructor TWebSocketClientChannel.Create(ASocket: IWebSocketSocket);
begin
  inherited Create;
  FSocket := ASocket;
  FPath := '/';
end;

procedure TWebSocketClientChannel.ResetState;
begin
  FHandshakeDone := False;
  FPending := '';
  FOutgoingFrames := '';
  FFragmentOpcode := 0;
  FFragmentPayload := '';
end;

function TWebSocketClientChannel.Connected: Boolean;
begin
  Result := FHandshakeDone and (FSocket <> nil) and FSocket.Connected;
end;

procedure TWebSocketClientChannel.Configure(const Endpoint: string);
begin
  ParseEndpoint(Endpoint, FHost, FPort, FPath);
end;

procedure TWebSocketClientChannel.Connect;
var
  Key: RawByteString;
  Request: RawByteString;
begin
  if (FSocket = nil) or (FHost = '') then
    Exit;

  ResetState;
  Key := RandomKey;
  FHandshakeKey := Base64Encode(Key);
  FSocket.Connect(FHost, FPort);

  Request := 'GET ' + FPath + ' HTTP/1.1' + CRLF +
    'Host: ' + FHost + ':' + FPort + CRLF +
    'Upgrade: websocket' + CRLF +
    'Connection: Upgrade' + CRLF +
    'Sec-WebSocket-Key: ' + FHandshakeKey + CRLF +
    'Sec-WebSocket-Version: 13' + CRLF + CRLF;
  FSocket.SendBytes(Request);
end;

procedure TWebSocketClientChannel.Disconnect;
begin
  if FHandshakeDone then
    SendFrame($8, '');
  ResetState;
  FHandshakeKey := '';
  if FSocket <> nil then
    FSocket.Disconnect;
end;

procedure TWebSocketClientChannel.Send(const Data: string);
begin
  { Do not drop frames sent before the asynchronous handshake completes.
    SendFrame queues them and FlushOutgoing releases them after 101. }
  SendFrame($1, Data);
end;

function TWebSocketClientChannel.Buffer: string;
begin
  ProcessPending;
  Result := FBuffer;
end;

procedure TWebSocketClientChannel.ClearBuffer;
begin
  FBuffer := '';
end;

procedure TWebSocketClientChannel.Pump;
begin
  ProcessPending;
end;

procedure TWebSocketClientChannel.ProcessPending;
var
  Raw: RawByteString;
  P: Integer;
  Headers, StatusLine, Accept: string;
begin
  if FSocket = nil then
    Exit;

  Raw := FSocket.ReadBytes;
  if Raw <> '' then
    FPending := FPending + Raw;

  if not FHandshakeDone then
  begin
    P := Pos(#13#10#13#10, FPending);
    if P = 0 then
      Exit;
    Headers := Copy(FPending, 1, P - 1);
    if Pos(CRLF, Headers) > 0 then
      StatusLine := Copy(Headers, 1, Pos(CRLF, Headers) - 1)
    else
      StatusLine := Headers;

    if Pos(' 101 ', StatusLine) = 0 then
    begin
      Delete(FPending, 1, P + 3);
      FSocket.Disconnect;
      raise EWebSocketError.Create('WebSocket upgrade reddedildi: ' + StatusLine);
    end;

    Accept := HeaderValue(Headers, 'Sec-WebSocket-Accept');
    if Accept <> WebSocketAccept(FHandshakeKey) then
    begin
      Delete(FPending, 1, P + 3);
      FSocket.Disconnect;
      raise EWebSocketError.Create('WebSocket Sec-WebSocket-Accept dogrulanamadi');
    end;

    Delete(FPending, 1, P + 3);
    FHandshakeDone := True;
    FlushOutgoing;
  end;

  ParseFrames;
end;

procedure TWebSocketClientChannel.ParseFrames;
var
  B0, B1, Opcode, Masked, I: Byte;
  Fin: Boolean;
  Len: QWord;
  Offset, MaskOffset: Integer;
  Mask: array[0..3] of Byte;
  Payload: RawByteString;
begin
  while Length(FPending) >= 2 do
  begin
    B0 := Ord(FPending[1]);
    B1 := Ord(FPending[2]);
    Fin := (B0 and $80) <> 0;
    Opcode := B0 and $0F;
    Masked := B1 and $80;
    Len := B1 and $7F;
    Offset := 3;

    if Len = 126 then
    begin
      if Length(FPending) < Offset + 2 then
        Exit;
      Len := (QWord(Ord(FPending[Offset])) shl 8) or Ord(FPending[Offset + 1]);
      Inc(Offset, 2);
    end
    else if Len = 127 then
    begin
      if Length(FPending) < Offset + 8 then
        Exit;
      Len := 0;
      for I := 0 to 7 do
        Len := (Len shl 8) or Ord(FPending[Offset + I]);
      Inc(Offset, 8);
    end;

    if Masked <> 0 then
    begin
      if Length(FPending) < Offset + 4 then
        Exit;
      MaskOffset := Offset;
      for I := 0 to 3 do
        Mask[I] := Ord(FPending[MaskOffset + I]);
      Inc(Offset, 4);
    end
    else
      FillChar(Mask, SizeOf(Mask), 0);

    if (Len > QWord(MaxInt)) or
       (Length(FPending) < Offset - 1 + Integer(Len)) then
      Exit;

    Payload := '';
    SetLength(Payload, Integer(Len));
    for I := 1 to Integer(Len) do
      Payload[I] := Chr(Ord(FPending[Offset + I - 1]) xor
        Mask[(I - 1) mod 4]);
    Delete(FPending, 1, Offset - 1 + Integer(Len));

    HandleFrame(Fin, Opcode, Payload);
  end;
end;

procedure TWebSocketClientChannel.HandleFrame(AFin: Boolean; AOpcode: Byte;
  const Payload: RawByteString);
begin
  case AOpcode of
    $0:
      begin
        if FFragmentOpcode = 0 then
          raise EWebSocketError.Create(
            'beklenmeyen WebSocket devam (continuation) frame');
        FFragmentPayload := FFragmentPayload + Payload;
        if AFin then
        begin
          FBuffer := FBuffer + FFragmentPayload;
          FFragmentOpcode := 0;
          FFragmentPayload := '';
        end;
      end;
    $1, $2:
      begin
        if FFragmentOpcode <> 0 then
          raise EWebSocketError.Create('onceki WebSocket mesaji tamamlanmadi');
        if AFin then
          FBuffer := FBuffer + Payload
        else
        begin
          FFragmentOpcode := AOpcode;
          FFragmentPayload := Payload;
        end;
      end;
    $8:
      begin
        SendFrame($8, Payload);
        ResetState;
        FHandshakeKey := '';
        if FSocket <> nil then
          FSocket.Disconnect;
      end;
    $9:
      SendFrame($A, Payload);
    $A:
      ; // pong yaniti; veri yok
  else
    raise EWebSocketError.Create('bilinmeyen WebSocket opcode: ' +
      IntToStr(AOpcode));
  end;
end;

function TWebSocketClientChannel.BuildFrame(AOpcode: Byte;
  const Payload: RawByteString): RawByteString;
var
  Len, HeaderLen, MaskPos, I: Integer;
  Mask: array[0..3] of Byte;
  Header: RawByteString;
begin
  Len := Length(Payload);
  if Len < 126 then
  begin
    HeaderLen := 2;
    MaskPos := 3;
  end
  else if Len <= $FFFF then
  begin
    HeaderLen := 4;
    MaskPos := 5;
  end
  else
  begin
    HeaderLen := 10;
    MaskPos := 11;
  end;

  Header := '';
  SetLength(Header, MaskPos + 3);
  Header[1] := Chr($80 or AOpcode);
  if HeaderLen = 2 then
    Header[2] := Chr($80 or Len)
  else if HeaderLen = 4 then
  begin
    Header[2] := Chr($80 or 126);
    Header[3] := Chr((Len shr 8) and $FF);
    Header[4] := Chr(Len and $FF);
  end
  else
  begin
    Header[2] := Chr($80 or 127);
    for I := 0 to 7 do
      Header[3 + I] := Chr((QWord(Len) shr ((7 - I) * 8)) and $FF);
  end;

  for I := 0 to 3 do
  begin
    Mask[I] := Random(256);
    Header[MaskPos + I] := Chr(Mask[I]);
  end;

  Result := '';
  SetLength(Result, MaskPos + 3 + Len);
  Move(Header[1], Result[1], MaskPos + 3);
  for I := 1 to Len do
    Result[MaskPos + 3 + I] := Chr(Ord(Payload[I]) xor Mask[(I - 1) mod 4]);
end;

procedure TWebSocketClientChannel.SendFrame(AOpcode: Byte;
  const Payload: RawByteString);
var
  Frame: RawByteString;
begin
  if FSocket = nil then
    Exit;

  Frame := BuildFrame(AOpcode, Payload);
  if Connected then
    FSocket.SendBytes(Frame)
  else
    FOutgoingFrames := FOutgoingFrames + Frame;
end;

procedure TWebSocketClientChannel.FlushOutgoing;
begin
  if (FOutgoingFrames = '') or (FSocket = nil) or not Connected then
    Exit;
  FSocket.SendBytes(FOutgoingFrames);
  FOutgoingFrames := '';
end;

initialization
  Randomize;

end.
