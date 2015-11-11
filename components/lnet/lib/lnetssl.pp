unit lNetSSL;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, cTypes, OpenSSL,
  lNet, lEvents;
  
type
  TLSSLMethod = (msSSLv2or3, msSSLv2, msSSLv3, msTLSv1);
  TLSSLStatus = (slNone, slConnect, slActiveteTLS, slShutdown);

  TLPasswordCB = function(buf: pChar; num, rwflag: cInt; userdata: Pointer): cInt; cdecl;

  { TLSSLSocket }

  TLSSLSocket = class(TLSocket)
   protected
    FSSL: PSSL;
    FSSLContext: PSSL_CTX;
    FSSLStatus: TLSSLStatus;
{    FSSLSendBuffer: array[0..65535] of Byte;
    FSSLSendSize: Integer;}
    function GetConnected: Boolean; override;

    function DoSend(const aData; const aSize: Integer): Integer; override;
    function DoGet(out aData; const aSize: Integer): Integer; override;
    
    function HandleResult(const aResult, aOp: Integer): Integer; override;

    function SetActiveSSL(const AValue: Boolean): Boolean;

    procedure SetupSSLSocket;
    procedure ActivateTLSEvent;
    procedure ConnectEvent;
    procedure ConnectSSL;
    procedure ShutdownSSL;

    procedure LogError(const msg: string; const ernum: Integer); override;
   public
    destructor Destroy; override;
    
    function SetState(const aState: TLSocketState; const TurnOn: Boolean = True): Boolean; override;

    procedure Disconnect; override;
   public
    property SSLStatus: TLSSLStatus read FSSLStatus;
  end;

  { TLSSLSession }

  TLSSLSession = class(TLSession)
   protected
    FOnSSLConnect: TLSocketEvent;
    FSSLActive: Boolean;
    FSSLContext: PSSL_CTX;
    FPassword: string;
    FCAFile: string;
    FKeyFile: string;
    FMethod: TLSSLMethod;
    FPasswordCallback: TLPasswordCB;
    
    procedure CallOnSSLConnect(aSocket: TLSocket);
    
    procedure SetSSLActive(const AValue: Boolean);
    procedure SetCAFile(AValue: string);
    procedure SetKeyFile(AValue: string);
    procedure SetPassword(const AValue: string);
    procedure SetMethod(const AValue: TLSSLMethod);
    procedure SetPasswordCallback(const AValue: TLPasswordCB);
    
    procedure CreateSSLContext; virtual;
   public
    constructor Create(aOwner: TComponent); override;
    
    procedure RegisterWithComponent(aConnection: TLConnection); override;
    
    procedure InitHandle(aHandle: TLHandle); override;
    
    procedure ConnectEvent(aHandle: TLHandle); override;
    procedure ReceiveEvent(aHandle: TLHandle); override;
    procedure AcceptEvent(aHandle: TLHandle); override;
    function HandleSSLConnection(aSocket: TLSSLSocket): Boolean;
   public
    property Password: string read FPassword write SetPassword;
    property CAFile: string read FCAFile write SetCAFile;
    property KeyFile: string read FKeyFile write SetKeyFile;
    property Method: TLSSLMethod read FMethod write SetMethod;
    property PasswordCallback: TLPasswordCB read FPasswordCallback write SetPasswordCallback;
    property SSLContext: PSSL_CTX read FSSLContext;
    property SSLActive: Boolean read FSSLActive write SetSSLActive;
    property OnSSLConnect: TLSocketEvent read FOnSSLConnect write FOnSSLConnect;
  end;
  
  function IsSSLBlockError(const anError: Longint): Boolean; inline;
  
implementation

uses
  {Math,} lCommon;

function PasswordCB(buf: pChar; num, rwflag: cInt; userdata: Pointer): cInt; cdecl;
var
  S: TLSSLSession;
begin
  S := TLSSLSession(userdata);
  
  if num < Length(S.Password) + 1 then
    Exit(0);

  Move(S.Password[1], buf[0], Length(S.Password));
  Result := Length(S.Password);
end;

function IsSSLBlockError(const anError: Longint): Boolean; inline;
begin
  Result := (anError = SSL_ERROR_WANT_READ) or (anError = SSL_ERROR_WANT_WRITE);
end;

{ TLSSLSocket }

function TLSSLSocket.SetActiveSSL(const AValue: Boolean): Boolean;
begin
  Result := False;
  
  if (ssSSLActive in FSocketState) = AValue then Exit(True);
  case aValue of
    True  : FSocketState := FSocketState + [ssSSLActive];
    False : FSocketState := FSocketState - [ssSSLActive];
  end;
  
  if aValue and FConnected then
    ActivateTLSEvent;

  if not aValue then begin
    if Connected then
      ShutdownSSL
    else if FSSLStatus in [slConnect, slActiveteTLS] then
      raise Exception.Create('Switching SSL mode on socket during SSL handshake is not supported');
  end;
  
  Result := True;
end;

procedure TLSSLSocket.SetupSSLSocket;
begin
  if Assigned(FSSL) then
    SslFree(FSSL);

  FSSL := SSLNew(FSSLContext);
  if not Assigned(FSSL) then begin
    Bail('SSLNew error', -1);
    Exit;
  end;

  if SslSetFd(FSSL, FHandle) = 0 then begin
    FSSL := nil;
    Bail('SSL setFD error', -1);
    Exit;
  end;
end;

procedure TLSSLSocket.ActivateTLSEvent;
begin
  SetupSSLSocket;
  FSSLStatus := slActiveteTLS;
  ConnectSSL;
end;

function TLSSLSocket.GetConnected: Boolean;
begin
  if ssSSLActive in FSocketState then
    Result := Assigned(FSSL) and (FSSLStatus = slNone)
  else
    Result := inherited;
end;

function TLSSLSocket.DoSend(const aData; const aSize: Integer): Integer;
begin
  if ssSSLActive in FSocketState then begin
{    if FSSLSendSize = 0 then begin
      FSSLSendSize := Min(aSize, Length(FSSLSendBuffer));
      Move(aData, FSSLSendBuffer[0], FSSLSendSize);
    end;
      
    Result := SSLWrite(FSSL, @FSSLSendBuffer[0], FSSLSendSize);
    if Result > 0 then
      FSSLSendSize := 0;}

    Result := SSLWrite(FSSL, @aData, aSize);
  end else
    Result := inherited DoSend(aData, aSize);
end;

function TLSSLSocket.DoGet(out aData; const aSize: Integer): Integer;
begin
  if ssSSLActive in FSocketState then
    Result := SSLRead(FSSL, @aData, aSize)
  else
    Result := inherited DoGet(aData, aSize);
end;

function TLSSLSocket.HandleResult(const aResult, aOp: Integer): Integer;
const
  GSStr: array[0..1] of string = ('SSLWrite', 'SSLRead');
var
  LastError: cInt;
begin
  if not (ssSSLActive in FSocketState) then
    Exit(inherited HandleResult(aResult, aOp));
    
  Result := aResult;
  if Result <= 0 then begin
    LastError := SslGetError(FSSL, Result);
    if IsSSLBlockError(LastError) then case aOp of
      0: begin
           FSocketState := FSocketState - [ssCanSend];
           IgnoreWrite := False;
         end;
      1: begin
           FSocketState := FSocketState - [ssCanReceive];
           IgnoreRead := False;
         end;
    end else
      Bail(GSStr[aOp] + ' error', LastError);
    Result := 0;
  end;
end;

procedure TLSSLSocket.ConnectEvent;
begin
  SetupSSLSocket;
  FSSLStatus := slConnect;
  ConnectSSL;
end;

procedure TLSSLSocket.LogError(const msg: string; const ernum: Integer);
var
  s: string;
begin
  if not (ssSSLActive in FSocketState) then
    inherited LogError(msg, ernum)
  else if Assigned(FOnError) then begin
    if ernum > 0 then begin
      SetLength(s, 1024);
      ErrErrorString(ernum, s, Length(s));
      FOnError(Self, msg + ': ' + s);
    end else
      FOnError(Self, msg);
  end;
end;

destructor TLSSLSocket.Destroy;
begin
  inherited Destroy;
  SslFree(FSSL);
end;

function TLSSLSocket.SetState(const aState: TLSocketState; const TurnOn: Boolean
  ): Boolean;
begin
  case aState of
    ssSSLActive: Result := SetActiveSSL(TurnOn);
  else
    Result := inherited SetState(aState, TurnOn);
  end;
end;

procedure TLSSLSocket.ConnectSSL;
var
  c: cInt;
begin
  c := SSLConnect(FSSL);
  if c <= 0 then begin
    case SslGetError(FSSL, c) of
      SSL_ERROR_WANT_READ  : begin // make sure we're watching for reads and flag status
                               FSocketState := FSocketState - [ssCanReceive];
                               IgnoreRead := False;
                             end;
      SSL_ERROR_WANT_WRITE : begin // make sure we're watching for writes and flag status
                               FSocketState := FSocketState - [ssCanSend];
                               IgnoreWrite := False;
                             end;
    else
      begin
        Bail('SSL connect error', -1);
        Exit;
      end;
    end;
  end else begin
    FSSLStatus := slNone;
    TLSSLSession(FSession).CallOnSSLConnect(Self);
  end;
end;

procedure TLSSLSocket.ShutdownSSL;
var
  n, c: Integer;
begin
  c := 0;
  if Assigned(FSSL) then begin
    FSSLStatus := slNone; // for now
    n := SSLShutdown(FSSL); // don't care for now, unless it fails badly
    if n <= 0 then begin
      n := SslGetError(FSSL, n);
      case n of
        SSL_ERROR_WANT_READ,
        SSL_ERROR_WANT_WRITE,
        SSL_ERROR_SYSCALL     : begin end; // ignore
      else
        Bail('SSL shutdown error', n);
      end;
    end;
  end;
end;

procedure TLSSLSocket.Disconnect;
begin
  if ssSSLActive in FSocketState then begin
    FSSLStatus := slShutdown;
    SetActiveSSL(False);
  end;
  
  inherited Disconnect;
end;

{ TLSSLSession }

procedure TLSSLSession.SetSSLActive(const AValue: Boolean);
begin
  if aValue = FSSLActive then Exit;
  FSSLActive := aValue;
  if aValue then
    CreateSSLContext;
end;

procedure TLSSLSession.CallOnSSLConnect(aSocket: TLSocket);
begin
  if Assigned(FOnSSLConnect) then
    FOnSSLConnect(aSocket);
end;

procedure TLSSLSession.SetCAFile(AValue: string);
begin
  DoDirSeparators(aValue);
  if aValue = FCAFile then Exit;
  FCAFile := aValue;
  CreateSSLContext;
end;

procedure TLSSLSession.SetKeyFile(AValue: string);
begin
  DoDirSeparators(aValue);
  if aValue = FKeyFile then Exit;
  FKeyFile := aValue;
  CreateSSLContext;
end;

procedure TLSSLSession.SetPassword(const AValue: string);
begin
  if aValue = FPassword then Exit;
  FPassword := aValue;
  CreateSSLContext;
end;

procedure TLSSLSession.SetMethod(const AValue: TLSSLMethod);
begin
  if aValue = FMethod then Exit;
  FMethod := aValue;
  CreateSSLContext;
end;

procedure TLSSLSession.SetPasswordCallback(const AValue: TLPasswordCB);
begin
  if aValue = FPasswordCallback then Exit;
  FPasswordCallback := aValue;
  CreateSSLContext;
end;

procedure TLSSLSession.CreateSSLContext;
var
  aMethod: PSSL_METHOD;
begin
  if Assigned(FSSLContext) then
    SSLCTXFree(FSSLContext);
    
  if not FSSLActive then
    Exit;

  case FMethod of
    msSSLv2or3 : aMethod := SslMethodV23;
    msSSLv2    : aMethod := SslMethodV2;
    msSSLv3    : aMethod := SslMethodV3;
    msTLSv1    : aMethod := SslMethodTLSV1;
  end;

  FSSLContext := SSLCTXNew(aMethod);
  if not Assigned(FSSLContext) then
    raise Exception.Create('Error creating SSL CTX: SSLCTXNew');
    
  if SSLCTXSetMode(FSSLContext, SSL_MODE_ENABLE_PARTIAL_WRITE) and SSL_MODE_ENABLE_PARTIAL_WRITE <> SSL_MODE_ENABLE_PARTIAL_WRITE then
    raise Exception.Create('Error setting partial write mode on CTX');
  if SSLCTXSetMode(FSSLContext, SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER) and SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER <> SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER then
    raise Exception.Create('Error setting accept moving buffer mode on CTX');

  if Length(FKeyFile) > 0 then begin
    if SslCtxUseCertificateChainFile(FSSLContext, FKeyFile) = 0 then
      raise Exception.Create('Error creating SSL CTX: SslCtxUseCertificateChainFile');

    SslCtxSetDefaultPasswdCb(FSSLContext, FPasswordCallback);
    SslCtxSetDefaultPasswdCbUserdata(FSSLContext, Self);
  
    if SSLCTXUsePrivateKeyFile(FSSLContext, FKeyfile, SSL_FILETYPE_PEM) = 0 then
      raise Exception.Create('Error creating SSL CTX: SSLCTXUsePrivateKeyFile');
  end;

  if Length(FCAFile) > 0 then
    if SSLCTXLoadVerifyLocations(FSSLContext, FCAFile, pChar(nil)) = 0 then
      raise Exception.Create('Error creating SSL CTX: SSLCTXLoadVerifyLocations');
end;

constructor TLSSLSession.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  FPasswordCallback := @PasswordCB;
  FSSLActive := True;
  CreateSSLContext;
end;

procedure TLSSLSession.RegisterWithComponent(aConnection: TLConnection);
begin
  inherited RegisterWithComponent(aConnection);
  
  if not aConnection.SocketClass.InheritsFrom(TLSSLSocket) then
    aConnection.SocketClass := TLSSLSocket;
end;

procedure TLSSLSession.InitHandle(aHandle: TLHandle);
begin
  inherited;
  
  TLSSLSocket(aHandle).FSSLContext := FSSLContext;
  TLSSLSocket(aHandle).SetState(ssSSLActive, FSSLActive);
end;

procedure TLSSLSession.ConnectEvent(aHandle: TLHandle);
begin
  if not (ssSSLActive in TLSSLSocket(aHandle).SocketState) then
    inherited ConnectEvent(aHandle)
  else if HandleSSLConnection(TLSSLSocket(aHandle)) then
    CallConnectEvent(aHandle);
end;

procedure TLSSLSession.ReceiveEvent(aHandle: TLHandle);
begin
  if not (ssSSLActive in TLSSLSocket(aHandle).SocketState) then
    inherited ReceiveEvent(aHandle)
  else case TLSSLSocket(aHandle).SSLStatus of
    slConnect:
      if HandleSSLConnection(TLSSLSocket(aHandle)) then
      case ssServerSocket in TLSSLSocket(aHandle).SocketState of
        True  : CallAcceptEvent(aHandle);
        False : CallConnectEvent(aHandle);
      end;
    slActiveteTLS:
      HandleSSLConnection(TLSSLSocket(aHandle));
  else
    CallReceiveEvent(aHandle);
  end;
end;

procedure TLSSLSession.AcceptEvent(aHandle: TLHandle);
begin
  if not (ssSSLActive in TLSSLSocket(aHandle).SocketState) then
    inherited AcceptEvent(aHandle)
  else if HandleSSLConnection(TLSSLSocket(aHandle)) then
    CallAcceptEvent(aHandle);
end;

function TLSSLSession.HandleSSLConnection(aSocket: TLSSLSocket): Boolean;
begin
  Result := False;
  
  if not Assigned(FSSLContext) then
    raise Exception.Create('Context not created during SSL connect/accept');

  case aSocket.FSSLStatus of
    slNone        : aSocket.ConnectEvent;
    slActiveteTLS,
    slConnect     : aSocket.ConnectSSL;
    slShutdown    : raise Exception.Create('Got ConnectEvent or AcceptEvent on socket with ssShutdown status');
  end;
  
  Result := aSocket.SSLStatus = slNone;
end;

initialization
  SslLibraryInit;
  SslLoadErrorStrings;

finalization
  DestroySSLInterface;

end.

