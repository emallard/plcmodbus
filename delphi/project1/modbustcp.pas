unit ModbusTCP;

{
  ModbusTCP.pas — Client MODBUS TCP minimaliste
  Utilise Synapse (blcksock + synsock), inclus dans Lazarus.
  Compatible Windows et Linux sans aucune modification.

  Fonctions implémentées :
    FC 01 — Read Coils
    FC 02 — Read Discrete Inputs
    FC 03 — Read Holding Registers
    FC 04 — Read Input Registers
    FC 05 — Write Single Coil
    FC 06 — Write Single Register
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  blcksock,   // TTCPBlockSocket — Synapse, livré avec Lazarus
  synsock;    // constantes socket Synapse (cross-platform)

const
  MODBUS_DEFAULT_PORT   = 502;
  MODBUS_FULL_HEADER    = 7;    // 6 octets MBAP + 1 Unit ID
  MODBUS_MAX_PDU        = 253;

  MODBUS_READ_COILS     = $01;
  MODBUS_READ_DISC_IN   = $02;
  MODBUS_READ_HOLD_REGS = $03;
  MODBUS_READ_IN_REGS   = $04;
  MODBUS_WRITE_COIL     = $05;
  MODBUS_WRITE_REG      = $06;

  COIL_ON  = $FF00;
  COIL_OFF = $0000;

type
  TModbusException = class(Exception);

  TModbusRegisters = array of Word;
  TModbusBits      = array of Boolean;

  { TModbusTCPClient }
  TModbusTCPClient = class
  private
    FSock      : TTCPBlockSocket;
    FConnected : Boolean;
    FHost      : string;
    FPort      : Word;
    FUnitID    : Byte;
    FTimeout   : Integer;   // millisecondes
    FTransID   : Word;

    function  NextTransID: Word;
    procedure SendFrame(const PDU: array of Byte; PDULen: Integer);
    function  RecvFrame(out RespPDU: TBytes): Integer;
    function  Execute(const ReqPDU: array of Byte; ReqLen: Integer;
                      out RespPDU: TBytes): Integer;
    procedure PutWord(var Buf: array of Byte; Offset: Integer; Value: Word);
    function  GetWord(const Buf: TBytes; Offset: Integer): Word;
    procedure CheckConnected;
    procedure CheckSockError(const Context: string);

  public
    constructor Create;
    destructor  Destroy; override;

    function  Connect(const AHost: string;
                      APort: Word = MODBUS_DEFAULT_PORT;
                      AUnitID: Byte = 1): Boolean;
    procedure Disconnect;

    function ReadCoils(Address, Count: Word; out Bits: TModbusBits): Boolean;
    function ReadDiscreteInputs(Address, Count: Word; out Bits: TModbusBits): Boolean;
    function ReadHoldingRegisters(Address, Count: Word; out Regs: TModbusRegisters): Boolean;
    function ReadInputRegisters(Address, Count: Word; out Regs: TModbusRegisters): Boolean;
    function WriteCoil(Address: Word; Value: Boolean): Boolean;
    function WriteRegister(Address, Value: Word): Boolean;

    property Connected : Boolean read FConnected;
    property Host      : string  read FHost;
    property Port      : Word    read FPort;
    property UnitID    : Byte    read FUnitID  write FUnitID;
    property Timeout   : Integer read FTimeout write FTimeout;
  end;

implementation

{ ── Helpers ──────────────────────────────────────────────────────────────── }

procedure TModbusTCPClient.PutWord(var Buf: array of Byte;
                                    Offset: Integer; Value: Word);
begin
  Buf[Offset]     := (Value shr 8) and $FF;  // MSB en premier (big-endian)
  Buf[Offset + 1] :=  Value        and $FF;
end;

function TModbusTCPClient.GetWord(const Buf: TBytes; Offset: Integer): Word;
begin
  Result := (Word(Buf[Offset]) shl 8) or Buf[Offset + 1];
end;

function TModbusTCPClient.NextTransID: Word;
begin
  Inc(FTransID);
  if FTransID = 0 then Inc(FTransID);
  Result := FTransID;
end;

procedure TModbusTCPClient.CheckConnected;
begin
  if not FConnected then
    raise TModbusException.Create('Non connecté au serveur MODBUS.');
end;

procedure TModbusTCPClient.CheckSockError(const Context: string);
begin
  if FSock.LastError <> 0 then
    raise TModbusException.CreateFmt('%s — erreur socket %d : %s',
      [Context, FSock.LastError, FSock.LastErrorDesc]);
end;

{ ── Constructeur / Destructeur ───────────────────────────────────────────── }

constructor TModbusTCPClient.Create;
begin
  inherited Create;
  FSock      := TTCPBlockSocket.Create;
  FConnected := False;
  FUnitID    := 1;
  FTimeout   := 3000;
  FTransID   := 0;
end;

destructor TModbusTCPClient.Destroy;
begin
  Disconnect;
  FSock.Free;
  inherited Destroy;
end;

{ ── Connexion ────────────────────────────────────────────────────────────── }

function TModbusTCPClient.Connect(const AHost: string;
                                   APort: Word; AUnitID: Byte): Boolean;
begin
  Result := False;
  if FConnected then Disconnect;

  FHost   := AHost;
  FPort   := APort;
  FUnitID := AUnitID;

  // Synapse gère la résolution DNS et WinSock/Linux de manière transparente
  FSock.Connect(AHost, IntToStr(APort));
  if FSock.LastError <> 0 then
    Exit;

  FSock.SetRecvTimeout(FTimeout);

  FConnected := True;
  Result     := True;
end;

procedure TModbusTCPClient.Disconnect;
begin
  if FConnected then
  begin
    FSock.CloseSocket;
    FConnected := False;
  end;
end;

{ ── Envoi ────────────────────────────────────────────────────────────────── }

procedure TModbusTCPClient.SendFrame(const PDU: array of Byte; PDULen: Integer);
var
  Frame    : TBytes;
  TID      : Word;
  FrameLen : Integer;
begin
  TID      := NextTransID;
  FrameLen := MODBUS_FULL_HEADER + PDULen;
  SetLength(Frame, FrameLen);

  // MBAP Header (7 octets)
  Frame[0] := (TID shr 8) and $FF;          // Transaction ID high
  Frame[1] :=  TID        and $FF;          // Transaction ID low
  Frame[2] := 0;                             // Protocol ID high (0 = MODBUS)
  Frame[3] := 0;                             // Protocol ID low
  Frame[4] := ((PDULen + 1) shr 8) and $FF; // Length high
  Frame[5] :=  (PDULen + 1)        and $FF; // Length low
  Frame[6] := FUnitID;                      // Unit Identifier

  // PDU (function code + données)
  Move(PDU[0], Frame[7], PDULen);

  FSock.SendBuffer(@Frame[0], FrameLen);
  CheckSockError('SendFrame');
end;

{ ── Réception ────────────────────────────────────────────────────────────── }

function TModbusTCPClient.RecvFrame(out RespPDU: TBytes): Integer;
var
  Header : TBytes;
  PDULen : Integer;
begin
  Result := 0;

  // Lire l'en-tête MBAP (7 octets)
  SetLength(Header, MODBUS_FULL_HEADER);
  FSock.RecvBufferEx(@Header[0], MODBUS_FULL_HEADER, FTimeout);
  CheckSockError('RecvFrame header');

  // PDULen = champ Length - 1  (Length inclut l'Unit ID)
  PDULen := ((Integer(Header[4]) shl 8) or Header[5]) - 1;
  if (PDULen <= 0) or (PDULen > MODBUS_MAX_PDU) then
    raise TModbusException.CreateFmt('Longueur PDU invalide : %d', [PDULen]);

  // Lire le PDU
  SetLength(RespPDU, PDULen);
  FSock.RecvBufferEx(@RespPDU[0], PDULen, FTimeout);
  CheckSockError('RecvFrame PDU');

  // Vérifier exception MODBUS (bit 7 du function code = 1)
  if (RespPDU[0] and $80) <> 0 then
    raise TModbusException.CreateFmt(
      'Exception MODBUS — FC: $%02X, Code: $%02X',
      [RespPDU[0] and $7F, RespPDU[1]]);

  Result := PDULen;
end;

{ ── Execute ──────────────────────────────────────────────────────────────── }

function TModbusTCPClient.Execute(const ReqPDU: array of Byte;
                                   ReqLen: Integer;
                                   out RespPDU: TBytes): Integer;
begin
  CheckConnected;
  SendFrame(ReqPDU, ReqLen);
  Result := RecvFrame(RespPDU);
end;

{ ── FC 01 — Read Coils ───────────────────────────────────────────────────── }

function TModbusTCPClient.ReadCoils(Address, Count: Word;
                                     out Bits: TModbusBits): Boolean;
var
  Req  : array[0..4] of Byte;
  Resp : TBytes;
  i    : Integer;
begin
  Result := False;
  Req[0] := MODBUS_READ_COILS;
  PutWord(Req, 1, Address);
  PutWord(Req, 3, Count);
  try
    Execute(Req, 5, Resp);
    SetLength(Bits, Count);
    for i := 0 to Count - 1 do
      Bits[i] := (Resp[2 + (i div 8)] shr (i mod 8)) and 1 = 1;
    Result := True;
  except
    on E: TModbusException do ;
  end;
end;

{ ── FC 02 — Read Discrete Inputs ─────────────────────────────────────────── }

function TModbusTCPClient.ReadDiscreteInputs(Address, Count: Word;
                                              out Bits: TModbusBits): Boolean;
var
  Req  : array[0..4] of Byte;
  Resp : TBytes;
  i    : Integer;
begin
  Result := False;
  Req[0] := MODBUS_READ_DISC_IN;
  PutWord(Req, 1, Address);
  PutWord(Req, 3, Count);
  try
    Execute(Req, 5, Resp);
    SetLength(Bits, Count);
    for i := 0 to Count - 1 do
      Bits[i] := (Resp[2 + (i div 8)] shr (i mod 8)) and 1 = 1;
    Result := True;
  except
    on E: TModbusException do ;
  end;
end;

{ ── FC 03 — Read Holding Registers ──────────────────────────────────────── }

function TModbusTCPClient.ReadHoldingRegisters(Address, Count: Word;
                                                out Regs: TModbusRegisters): Boolean;
var
  Req  : array[0..4] of Byte;
  Resp : TBytes;
  i    : Integer;
begin
  Result := False;
  Req[0] := MODBUS_READ_HOLD_REGS;
  PutWord(Req, 1, Address);
  PutWord(Req, 3, Count);
  try
    Execute(Req, 5, Resp);
    SetLength(Regs, Count);
    for i := 0 to Count - 1 do
      Regs[i] := GetWord(Resp, 2 + i * 2);
    Result := True;
  except
    on E: TModbusException do ;
  end;
end;

{ ── FC 04 — Read Input Registers ─────────────────────────────────────────── }

function TModbusTCPClient.ReadInputRegisters(Address, Count: Word;
                                              out Regs: TModbusRegisters): Boolean;
var
  Req  : array[0..4] of Byte;
  Resp : TBytes;
  i    : Integer;
begin
  Result := False;
  Req[0] := MODBUS_READ_IN_REGS;
  PutWord(Req, 1, Address);
  PutWord(Req, 3, Count);
  try
    Execute(Req, 5, Resp);
    SetLength(Regs, Count);
    for i := 0 to Count - 1 do
      Regs[i] := GetWord(Resp, 2 + i * 2);
    Result := True;
  except
    on E: TModbusException do ;
  end;
end;

{ ── FC 05 — Write Single Coil ────────────────────────────────────────────── }

function TModbusTCPClient.WriteCoil(Address: Word; Value: Boolean): Boolean;
var
  Req  : array[0..4] of Byte;
  Resp : TBytes;
begin
  Result := False;
  Req[0] := MODBUS_WRITE_COIL;
  PutWord(Req, 1, Address);
  if Value then PutWord(Req, 3, COIL_ON)
           else PutWord(Req, 3, COIL_OFF);
  try
    Execute(Req, 5, Resp);
    Result := True;
  except
    on E: TModbusException do ;
  end;
end;

{ ── FC 06 — Write Single Register ───────────────────────────────────────── }

function TModbusTCPClient.WriteRegister(Address, Value: Word): Boolean;
var
  Req  : array[0..4] of Byte;
  Resp : TBytes;
begin
  Result := False;
  Req[0] := MODBUS_WRITE_REG;
  PutWord(Req, 1, Address);
  PutWord(Req, 3, Value);
  try
    Execute(Req, 5, Resp);
    Result := True;
  except
    on E: TModbusException do ;
  end;
end;

end.
