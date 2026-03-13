PROGRAM main
VAR
	Input : bool AT %QX0.0;
	Output : bool AT %QX0.1;
	WaterLevel : int AT %QW0;
	TimerRemplissage : TON;
END_VAR

TimerRemplissage(In := (WaterLevel < 100), PT := T#100MS);

// Fill Water
IF TimerRemplissage.Q THEN
    WaterLevel := WaterLevel + 1;
    (*
    timer(IN := FALSE);
    timer(IN := running AND (counter < 100));
    *)
END_IF;

// Pump
IF Input THEN
    WaterLevel := WaterLevel - 2;
END_IF;

IF WaterLevel > 100 THEN
    WaterLevel := 100;
END_IF;

IF WaterLevel < 0 THEN
    WaterLevel := 0;
END_IF;

END_PROGRAM