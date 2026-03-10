unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ModbusTCP;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Memo1: TMemo;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Memo1Change(Sender: TObject);
  private
    FModbus      : TModbusTCPClient;
    procedure Log(const Msg: string; IsError: Boolean = False);

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin

end;

procedure TForm1.Memo1Change(Sender: TObject);
begin

end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  //if not FModbus.Connected then begin Log('Non connecté.', True); Exit; end;
  Log('Connecté', True);
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  connected: Boolean;
begin
  try
     FModbus := TModbusTCPClient.Create;
     connected := FModbus.Connect('127.0.0.1', 502, 1);
     Log('connected ' + connected.ToString(), False);
  except
    on E:Exception do
       Log('Erreur ' + E.Message, True);
  end;
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  if not FModbus.Connected then begin Log('Non connecté.', True); Exit; end;
  // FC 05 — Coil 0 = TRUE
  if FModbus.WriteCoil(0, True) then
    Log('Commande MARCHE envoyée (Coil 0 → TRUE)')
  else
    Log('Échec commande MARCHE.', True);
end;

procedure TForm1.Button4Click(Sender: TObject);
var
  Val: Integer;
begin
  if not FModbus.Connected then begin Log('Non connecté.', True); Exit; end;
  Val := 10;
  if FModbus.WriteRegister(0, Val) then
    Log(Format('Consigne envoyée : %d %%', [Val]))
  else
    Log('Échec de l''écriture de la consigne.', True);
end;

procedure TForm1.Button5Click(Sender: TObject);
var
  Regs: TModbusRegisters;
begin
  if not FModbus.Connected then begin Log('Non connecté.', True); Exit; end;

  if FModbus.ReadHoldingRegisters(0, 1, Regs) then
    Log(Format('Consigne reçue : %d', [Regs[0]]))
  else
    Log('Échec de la lecture de la consigne.', True);
end;

procedure TForm1.Log(const Msg: string; IsError: Boolean = False);
var
  Prefix: string;
begin
  Prefix := FormatDateTime('[hh:nn:ss]', Now);
  if IsError then
  begin
     Prefix := Prefix + '!';
  end;
  Memo1.Lines.Add(Prefix + ' ' + Msg);
end;

end.

