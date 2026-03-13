unit MonThread;

interface

uses
  Classes, ComCtrls;

type
  TCalcFunc = function(): Word of object;

  TSinusThread = class(TThread)
  private
    FProgressBar : TProgressBar;   // référence à la barre
    FMethod      : TCalcFunc;
    FAngle       : Double;         // angle courant (radians)
    FCurrentVal  : Integer;        // valeur calculée (0..100)
    procedure UpdateProgressBar;   // exécutée dans le thread UI
  protected
    procedure Execute; override;
  public
    constructor Create(AProgressBar: TProgressBar; AMethod: TCalcFunc);
  end;

implementation

{ Constructeur }
constructor TSinusThread.Create(AProgressBar: TProgressBar; AMethod: TCalcFunc);
begin
  inherited Create(False);     // False = démarrage immédiat
  FreeOnTerminate := True;    // libération automatique
  FProgressBar    := AProgressBar;
  FAngle          := 0;
  FMethod         := AMethod;
end;

{ Boucle principale du thread }
procedure TSinusThread.Execute;
begin
  while not Terminated do
  begin
    // Sin() ∈ [-1, 1]  →  ramener à [0, 100]
    FCurrentVal := FMethod(); //Round((1 + Sin(FAngle)) * 50);

    // Mise à jour thread-safe via Synchronize
    Synchronize(@UpdateProgressBar);

    FAngle := FAngle + 0.1;    // incrément angulaire
    Sleep(50);                  // pause 500 ms
  end;
end;

{ Exécutée dans le thread principal (VCL-safe) }
procedure TSinusThread.UpdateProgressBar;
begin
  FProgressBar.Position := FCurrentVal;
end;

end.
