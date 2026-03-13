# plcmodbus
First Try using OpenPLC, ModBus TCP and Lazarus


# Install 
- OpenPLC
- OpenPLCRuntime for modbus
- Lazarus
- Open PAckage Manager : laz-synapse

# Screenshots
![Description](Capture1.png)
![Description](Capture2.png)

# Notes:

## 2. Rappel MODBUS — ce que vous devez savoir

### 2.1 Les quatre zones mémoire

| Zone                   | FC lecture | FC écriture  | Description                                |
|------------------------|------------|---------------|--------------------------------------------|
| Coils (0x)             | FC 01      | FC 05 / 15    | BOOL — lecture + écriture par le maître    |
| Discrete Inputs (1x)   | FC 02      | —             | BOOL — lecture seule (entrées terrain)     |
| Input Registers (3x)   | FC 04      | —             | WORD 16 bits — lecture seule (mesures)     |
| Holding Registers (4x) | FC 03      | FC 06 / 16    | WORD 16 bits — lecture + écriture          |

### 2.2 Correspondance adresses OpenPLC ↔ MODBUS

| Variable OpenPLC | Zone MODBUS → Accès                               |
|-----------------|---------------------------------------------------|
| %QX0.0          | Coil 0 (0x0001) → écriture par le maître          |
| %IX0.0          | Discrete Input 0 (1x0001) → lecture seule         |
| %IW0            | Input Register 0 (3x0001) → lecture seule (capteur)|
| %QW0            | Holding Register 0 (4x0001) → lecture + écriture  |
