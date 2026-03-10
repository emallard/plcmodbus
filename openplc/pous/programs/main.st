PROGRAM main
VAR
	Input : bool AT %QX0.0;
	Output : bool AT %QX0.1;
	EtatPompe : bool;
	Consigne : int AT %QW0;
END_VAR

(* Variables internes *)
Output    := Input;
EtatPompe := Input;

END_PROGRAM