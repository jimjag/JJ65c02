EESchema Schematic File Version 4
EELAYER 30 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 2 2
Title "JJ65c02 Hobby Breadboard Computer"
Date ""
Rev ""
Comp ""
Comment1 ""
Comment2 ""
Comment3 "Author: Jim Jagielski"
Comment4 "Support Circuits"
$EndDescr
$Comp
L 6502:NE555-Timer U1
U 1 1 5E17C676
P 2500 1700
AR Path="/61660CAC/5E17C676" Ref="U1"  Part="1" 
AR Path="/61610474/5E17C676" Ref="U?"  Part="1" 
F 0 "U1" H 2500 1750 50  0000 C CNN
F 1 "NE555" H 2500 1650 50  0000 C CNN
F 2 "Package_DIP:DIP-8_W7.62mm_Socket" H 2500 1700 50  0001 C CNN
F 3 "http://www.ti.com/lit/ds/symlink/ne555.pdf" H 2500 1700 50  0001 C CNN
	1    2500 1700
	1    0    0    -1  
$EndComp
Wire Wire Line
	2000 1900 1900 1900
Wire Wire Line
	3000 1700 3100 1700
Wire Wire Line
	3100 1700 3100 1900
Wire Wire Line
	3100 1900 3000 1900
$Comp
L Device:R R8
U 1 1 5E1F5B26
P 3100 1250
AR Path="/61660CAC/5E1F5B26" Ref="R8"  Part="1" 
AR Path="/61610474/5E1F5B26" Ref="R?"  Part="1" 
F 0 "R8" V 3000 1250 50  0000 C CNN
F 1 "4.7K" V 3100 1250 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" V 3030 1250 50  0001 C CNN
F 3 "~" H 3100 1250 50  0001 C CNN
	1    3100 1250
	1    0    0    -1  
$EndComp
$Comp
L Device:CP C3
U 1 1 5E2337BD
P 3100 2150
AR Path="/61660CAC/5E2337BD" Ref="C3"  Part="1" 
AR Path="/61610474/5E2337BD" Ref="C?"  Part="1" 
F 0 "C3" H 3218 2196 50  0000 L CNN
F 1 "10uF" H 3218 2105 50  0000 L CNN
F 2 "Capacitor_THT:CP_Radial_D5.0mm_P2.50mm" H 3138 2000 50  0001 C CNN
F 3 "~" H 3100 2150 50  0001 C CNN
	1    3100 2150
	1    0    0    -1  
$EndComp
Wire Wire Line
	3100 2000 3100 1900
Connection ~ 3100 1900
Wire Wire Line
	3100 2300 3100 2400
NoConn ~ 2000 1700
$Comp
L Switch:SW_Push SW1
U 1 1 5E2CBD4E
P 1600 1950
AR Path="/61660CAC/5E2CBD4E" Ref="SW1"  Part="1" 
AR Path="/61610474/5E2CBD4E" Ref="SW?"  Part="1" 
F 0 "SW1" V 1650 2250 50  0000 R CNN
F 1 "RESET" V 1550 2300 50  0000 R CNN
F 2 "Button_Switch_THT:SW_PUSH_6mm_H4.3mm" H 1600 2150 50  0001 C CNN
F 3 "~" H 1600 2150 50  0001 C CNN
	1    1600 1950
	0    -1   -1   0   
$EndComp
$Comp
L Device:C C2
U 1 1 5E2ECA64
P 1750 2150
AR Path="/61660CAC/5E2ECA64" Ref="C2"  Part="1" 
AR Path="/61610474/5E2ECA64" Ref="C?"  Part="1" 
F 0 "C2" H 1865 2196 50  0000 L CNN
F 1 "0.1uF" H 1865 2105 50  0000 L CNN
F 2 "Capacitor_THT:C_Disc_D3.4mm_W2.1mm_P2.50mm" H 1788 2000 50  0001 C CNN
F 3 "~" H 1750 2150 50  0001 C CNN
	1    1750 2150
	1    0    0    -1  
$EndComp
Wire Wire Line
	1600 2150 1600 2400
Wire Wire Line
	1600 2400 1750 2400
Wire Wire Line
	1750 2300 1750 2400
Connection ~ 1750 2400
Wire Wire Line
	1750 2000 1750 1500
Wire Wire Line
	1750 1500 2000 1500
Wire Wire Line
	1600 1750 1600 1500
Wire Wire Line
	1600 1500 1750 1500
Connection ~ 1750 1500
$Comp
L Device:R R7
U 1 1 5E3A85D8
P 1750 1250
AR Path="/61660CAC/5E3A85D8" Ref="R7"  Part="1" 
AR Path="/61610474/5E3A85D8" Ref="R?"  Part="1" 
F 0 "R7" V 1650 1250 50  0000 C CNN
F 1 "1M" V 1750 1250 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" V 1680 1250 50  0001 C CNN
F 3 "~" H 1750 1250 50  0001 C CNN
	1    1750 1250
	1    0    0    -1  
$EndComp
Wire Wire Line
	1750 1500 1750 1400
Wire Wire Line
	1750 1100 1750 1000
Wire Wire Line
	1750 1000 1900 1000
Wire Wire Line
	3000 1500 3200 1500
Text GLabel 4100 1500 2    50   Output ~ 0
~RES
Wire Wire Line
	3900 1500 4000 1500
$Comp
L Device:R R9
U 1 1 5E552FBE
P 4000 1250
AR Path="/61660CAC/5E552FBE" Ref="R9"  Part="1" 
AR Path="/61610474/5E552FBE" Ref="R?"  Part="1" 
F 0 "R9" V 3900 1250 50  0000 C CNN
F 1 "10K" V 4000 1250 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" V 3930 1250 50  0001 C CNN
F 3 "~" H 4000 1250 50  0001 C CNN
	1    4000 1250
	1    0    0    -1  
$EndComp
Wire Wire Line
	1900 1000 1900 1900
Wire Wire Line
	3100 1700 3100 1400
Connection ~ 3100 1700
Wire Wire Line
	3100 1100 3100 1000
Wire Wire Line
	3100 1000 2500 1000
Wire Wire Line
	1900 1000 2500 1000
Connection ~ 1900 1000
Connection ~ 2500 1000
Wire Wire Line
	4000 1100 4000 1000
Wire Wire Line
	4000 1000 3100 1000
Connection ~ 3100 1000
Wire Wire Line
	4000 1400 4000 1500
Connection ~ 4000 1500
Wire Wire Line
	4000 1500 4100 1500
Wire Wire Line
	2500 1300 2500 1000
Connection ~ 1600 2400
Wire Wire Line
	1100 1000 1200 1000
Connection ~ 1750 1000
Wire Wire Line
	1050 2400 1200 2400
$Comp
L Device:C C1
U 1 1 5E7C431C
P 1200 1700
AR Path="/61660CAC/5E7C431C" Ref="C1"  Part="1" 
AR Path="/61610474/5E7C431C" Ref="C?"  Part="1" 
F 0 "C1" H 1315 1746 50  0000 L CNN
F 1 "0.1uF" H 1315 1655 50  0000 L CNN
F 2 "Capacitor_THT:C_Disc_D3.4mm_W2.1mm_P2.50mm" H 1238 1550 50  0001 C CNN
F 3 "~" H 1200 1700 50  0001 C CNN
	1    1200 1700
	1    0    0    -1  
$EndComp
Wire Wire Line
	1200 1850 1200 2400
Connection ~ 1200 2400
Wire Wire Line
	1200 2400 1600 2400
Wire Wire Line
	1200 1550 1200 1000
Connection ~ 1200 1000
Wire Wire Line
	1200 1000 1750 1000
$Comp
L 74xx:74HC00 U2
U 4 1 5E218D59
P 3600 1500
AR Path="/61660CAC/5E218D59" Ref="U2"  Part="4" 
AR Path="/61610474/5E218D59" Ref="U?"  Part="4" 
F 0 "U2" H 3600 1825 50  0000 C CNN
F 1 "74HC00" H 3600 1734 50  0000 C CNN
F 2 "Package_DIP:DIP-14_W7.62mm_Socket" H 3600 1500 50  0001 C CNN
F 3 "http://www.ti.com/lit/gpn/sn74hc00" H 3600 1500 50  0001 C CNN
	4    3600 1500
	1    0    0    -1  
$EndComp
Wire Wire Line
	3300 1400 3200 1400
Wire Wire Line
	3200 1400 3200 1500
Wire Wire Line
	3200 1600 3300 1600
Connection ~ 3200 1500
Wire Wire Line
	3200 1500 3200 1600
$Comp
L Oscillator:CXO_DIP14 X?
U 1 1 6171CEB1
P 9450 1150
AR Path="/6171CEB1" Ref="X?"  Part="1" 
AR Path="/61660CAC/6171CEB1" Ref="X1"  Part="1" 
AR Path="/61610474/6171CEB1" Ref="X?"  Part="1" 
F 0 "X1" H 9550 1400 50  0000 L CNN
F 1 "1Mhz" H 9600 1500 50  0000 L CNN
F 2 "Oscillator:Oscillator_DIP-14" H 9900 800 50  0001 C CNN
F 3 "http://cdn-reichelt.de/documents/datenblatt/B400/OSZI.pdf" H 9350 1150 50  0001 C CNN
	1    9450 1150
	1    0    0    -1  
$EndComp
Text GLabel 9750 1150 2    43   Output ~ 0
CLK
$Comp
L power:+5V #PWR?
U 1 1 6171CEBE
P 9500 1200
AR Path="/6171CEBE" Ref="#PWR?"  Part="1" 
AR Path="/61660CAC/6171CEBE" Ref="#PWR020"  Part="1" 
AR Path="/61610474/6171CEBE" Ref="#PWR?"  Part="1" 
F 0 "#PWR020" H 9500 1050 50  0001 C CNN
F 1 "+5V" H 9515 1373 50  0000 C CNN
F 2 "" H 9500 1200 50  0001 C CNN
F 3 "" H 9500 1200 50  0001 C CNN
	1    9500 1200
	1    0    0    -1  
$EndComp
NoConn ~ 9150 1150
$Comp
L Oscillator:CXO_DIP14 X?
U 1 1 6171CEC5
P 9450 2500
AR Path="/6171CEC5" Ref="X?"  Part="1" 
AR Path="/61660CAC/6171CEC5" Ref="X2"  Part="1" 
AR Path="/61610474/6171CEC5" Ref="X?"  Part="1" 
F 0 "X2" H 9550 2750 50  0000 L CNN
F 1 "1.8Mhz" H 9600 2850 50  0000 L CNN
F 2 "Oscillator:Oscillator_DIP-14" H 9900 2150 50  0001 C CNN
F 3 "http://cdn-reichelt.de/documents/datenblatt/B400/OSZI.pdf" H 9350 2500 50  0001 C CNN
	1    9450 2500
	1    0    0    -1  
$EndComp
Text GLabel 9750 2500 2    43   Output ~ 0
ACIA-CLK
NoConn ~ 9150 2500
$Comp
L 74xx:74HC00 U2
U 1 1 61753EE9
P 5950 2400
AR Path="/61660CAC/61753EE9" Ref="U2"  Part="1" 
AR Path="/61610474/61753EE9" Ref="U?"  Part="1" 
F 0 "U2" H 5950 2725 50  0000 C CNN
F 1 "74HC00" H 5950 2633 50  0000 C CNN
F 2 "Package_DIP:DIP-14_W7.62mm_Socket" H 5950 2400 50  0001 C CNN
F 3 "http://www.ti.com/lit/gpn/sn74hc00" H 5950 2400 50  0001 C CNN
	1    5950 2400
	1    0    0    -1  
$EndComp
$Comp
L 74xx:74HC00 U2
U 2 1 61753EEF
P 6800 2500
AR Path="/61660CAC/61753EEF" Ref="U2"  Part="2" 
AR Path="/61610474/61753EEF" Ref="U?"  Part="2" 
F 0 "U2" H 6800 2825 50  0000 C CNN
F 1 "74HC00" H 6800 2733 50  0000 C CNN
F 2 "Package_DIP:DIP-14_W7.62mm_Socket" H 6800 2500 50  0001 C CNN
F 3 "http://www.ti.com/lit/gpn/sn74hc00" H 6800 2500 50  0001 C CNN
	2    6800 2500
	1    0    0    -1  
$EndComp
Entry Wire Line
	5000 2400 5100 2500
Entry Wire Line
	5000 2600 5100 2700
Entry Wire Line
	5000 2800 5100 2900
Wire Wire Line
	5100 2500 5500 2500
Wire Wire Line
	5650 2300 5500 2300
Wire Wire Line
	5500 2300 5500 2500
Connection ~ 5500 2500
Wire Wire Line
	5500 2500 5650 2500
Wire Wire Line
	6250 2400 6350 2400
Wire Wire Line
	5100 2900 5200 2900
Wire Wire Line
	5200 2900 5200 3300
Wire Wire Line
	5350 2700 5350 3100
Wire Wire Line
	5100 2700 5350 2700
Text GLabel 6400 2600 0    43   Input ~ 0
CLK
Wire Wire Line
	6350 2400 6350 2100
Connection ~ 6350 2400
Wire Wire Line
	6350 2400 6500 2400
Text GLabel 4725 2550 2    35   BiDi ~ 0
a[0..15]
Wire Wire Line
	6500 2600 6400 2600
Text GLabel 7300 2500 2    47   Output ~ 0
RAM~CS
Wire Wire Line
	7100 2500 7300 2500
Text GLabel 7300 2100 2    47   Output ~ 0
ROM~CE
Wire Wire Line
	6350 2100 7300 2100
Wire Wire Line
	7300 2100 7300 2150
Entry Wire Line
	5000 3000 5100 3100
Wire Wire Line
	5100 3100 5100 3500
Wire Wire Line
	5100 3500 5650 3500
Wire Wire Line
	5850 3600 5850 3100
Wire Wire Line
	5350 3100 5850 3100
Wire Wire Line
	5750 3300 5750 3700
Wire Wire Line
	5750 3700 5850 3700
Wire Wire Line
	5200 3300 5750 3300
Wire Wire Line
	5650 3500 5650 3800
Wire Wire Line
	5650 3800 5850 3800
Wire Wire Line
	5500 2500 5500 4100
Wire Wire Line
	5500 4100 5850 4100
Text GLabel 8050 4000 2    47   Output ~ 0
ROM~OE
Wire Wire Line
	6850 3600 7100 3600
Text GLabel 7300 3600 2    47   Output ~ 0
IO~CS
$Comp
L 74xx:74HC00 U2
U 3 1 6165C145
P 7600 4000
AR Path="/61660CAC/6165C145" Ref="U2"  Part="3" 
AR Path="/61610474/6165C145" Ref="U?"  Part="1" 
F 0 "U2" H 7600 4325 50  0000 C CNN
F 1 "74HC00" H 7600 4233 50  0000 C CNN
F 2 "Package_DIP:DIP-14_W7.62mm_Socket" H 7600 4000 50  0001 C CNN
F 3 "http://www.ti.com/lit/gpn/sn74hc00" H 7600 4000 50  0001 C CNN
	3    7600 4000
	1    0    0    -1  
$EndComp
Wire Wire Line
	7100 3600 7100 3900
Wire Wire Line
	7100 3900 7300 3900
Connection ~ 7100 3600
Wire Wire Line
	7100 3600 7300 3600
Wire Wire Line
	7100 3900 7100 4100
Wire Wire Line
	7100 4100 7300 4100
Connection ~ 7100 3900
Wire Wire Line
	7900 4000 8050 4000
NoConn ~ 6850 3700
NoConn ~ 6850 3800
NoConn ~ 6850 3900
NoConn ~ 6850 4000
NoConn ~ 6850 4100
NoConn ~ 6850 4200
NoConn ~ 6850 4300
Text Notes 1450 2650 0    98   ~ 0
Power On Delay Reset
Text Notes 5600 5150 0    98   ~ 0
Memory Map Logic Glue
Text Notes 1050 7000 0    118  ~ 0
Memory Map:\n$0000 - $7fff      RAM: 32k\n  $0000 - $00ff      RAM: Zero Page\n  $0100 - $01ff      RAM: Stack pointer (sp) / Page 1\n  $0200 - $02ff      RAM: miniOS system memory\n$8000 - $8fff      IO: 4K\n  $8010 - $801f     ACIA\n  $8020 - $802f     VIA\n$9000 - $ffff      ROM: 28K
Text Notes 5200 700  0    98   ~ 0
Support Schematics
Text Label 5400 2500 2    47   ~ 0
a15
Text Label 5650 3100 2    47   ~ 0
a14
Text Label 5650 3300 2    47   ~ 0
a13
Text Label 5650 3500 2    47   ~ 0
a12
Wire Wire Line
	9450 800  9450 850 
$Comp
L 74xx:74LS138 U3
U 1 1 615D1D41
P 6350 3900
AR Path="/61660CAC/615D1D41" Ref="U3"  Part="1" 
AR Path="/61610474/615D1D41" Ref="U?"  Part="1" 
F 0 "U3" H 6350 4681 50  0000 C CNN
F 1 "74HC138" H 6350 4590 50  0000 C CNN
F 2 "Package_DIP:DIP-16_W7.62mm_Socket" H 6350 3900 50  0001 C CNN
F 3 "http://www.ti.com/lit/gpn/sn74LS138" H 6350 3900 50  0001 C CNN
	1    6350 3900
	1    0    0    -1  
$EndComp
Wire Wire Line
	5850 4200 5850 4300
Wire Wire Line
	6350 4600 5850 4600
Wire Wire Line
	5850 4600 5850 4300
Connection ~ 5850 4300
Wire Wire Line
	6350 4600 6350 4700
Connection ~ 6350 4600
Wire Wire Line
	1750 2400 2500 2400
Wire Wire Line
	2500 2100 2500 2400
Connection ~ 2500 2400
Wire Wire Line
	2500 2400 3100 2400
Wire Wire Line
	6750 3250 6750 3300
Wire Wire Line
	6750 3300 6350 3300
Text GLabel 1100 1000 0    47   Input ~ 0
+5V
Text GLabel 1050 2400 0    47   Input ~ 0
GND
Text GLabel 9450 2850 3    47   Input ~ 0
GND
Text GLabel 6350 4700 3    47   Input ~ 0
GND
Text GLabel 6750 3250 1    47   Input ~ 0
+5V
Text GLabel 9450 800  1    47   Input ~ 0
+5V
Text GLabel 9450 2100 1    47   Input ~ 0
+5V
Text GLabel 9450 1450 3    47   Input ~ 0
GND
Wire Wire Line
	9450 2100 9450 2200
Wire Wire Line
	9450 2800 9450 2850
$Comp
L 74xx:74LS08 U4
U 1 1 615F5956
P 2200 3550
F 0 "U4" H 2200 3875 50  0000 C CNN
F 1 "74HC08" H 2200 3784 50  0000 C CNN
F 2 "Package_DIP:DIP-14_W7.62mm_Socket" H 2200 3550 50  0001 C CNN
F 3 "http://www.ti.com/lit/gpn/sn74LS08" H 2200 3550 50  0001 C CNN
	1    2200 3550
	1    0    0    -1  
$EndComp
Text GLabel 2500 3550 2    47   Output ~ 0
~IRQ
Text GLabel 1700 3450 0    47   Input ~ 0
V~IRQ
Text GLabel 1700 3650 0    47   Input ~ 0
A~IRQ
Wire Wire Line
	1900 3650 1800 3650
Wire Wire Line
	1900 3450 1700 3450
$Comp
L Device:R R2
U 1 1 615FE1AE
P 1800 3900
AR Path="/61660CAC/615FE1AE" Ref="R2"  Part="1" 
AR Path="/61610474/615FE1AE" Ref="R?"  Part="1" 
F 0 "R2" V 1700 3900 50  0000 C CNN
F 1 "4.7K" V 1800 3900 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" V 1730 3900 50  0001 C CNN
F 3 "~" H 1800 3900 50  0001 C CNN
	1    1800 3900
	1    0    0    -1  
$EndComp
Wire Wire Line
	1800 3750 1800 3650
Connection ~ 1800 3650
Wire Wire Line
	1800 3650 1700 3650
Text GLabel 1800 4150 3    47   Input ~ 0
+5V
Wire Wire Line
	1800 4050 1800 4150
Text Notes 1350 4550 0    98   ~ 0
~IRQ~ Logic Glue
$Comp
L 6502:MAX232B U5
U 1 1 616302EB
P 9350 4350
F 0 "U5" V 10100 4050 47  0000 R CNN
F 1 "MAX232B" V 10000 4150 47  0000 R CNN
F 2 "TerminalBlock_TE-Connectivity:TerminalBlock_TE_282834-6_1x06_P2.54mm_Horizontal" H 9350 4350 47  0001 C CNN
F 3 "" H 9350 4350 47  0001 C CNN
	1    9350 4350
	0    -1   -1   0   
$EndComp
Text GLabel 9150 3950 0    47   Input ~ 0
RxD
Text GLabel 9150 4050 0    47   Input ~ 0
TxD
Text GLabel 9150 4350 0    47   Input ~ 0
+5V
Text GLabel 9150 4450 0    47   Input ~ 0
GND
Wire Wire Line
	9150 3950 9450 3950
Wire Wire Line
	9150 4050 9450 4050
Wire Wire Line
	9150 4350 9450 4350
Wire Wire Line
	9150 4450 9450 4450
NoConn ~ 9450 4150
NoConn ~ 9450 4250
$Comp
L power:+5VD #PWR?
U 1 1 6160B5F2
P 4300 4200
F 0 "#PWR?" H 4300 4050 50  0001 C CNN
F 1 "+5VD" H 4315 4373 50  0000 C CNN
F 2 "" H 4300 4200 50  0001 C CNN
F 3 "" H 4300 4200 50  0001 C CNN
	1    4300 4200
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR?
U 1 1 6160BF33
P 4300 4500
F 0 "#PWR?" H 4300 4250 50  0001 C CNN
F 1 "GND" H 4305 4327 50  0000 C CNN
F 2 "" H 4300 4500 50  0001 C CNN
F 3 "" H 4300 4500 50  0001 C CNN
	1    4300 4500
	1    0    0    -1  
$EndComp
Text GLabel 3900 4250 0    47   Input ~ 0
+5V
Text GLabel 3900 4450 0    47   Input ~ 0
GND
Wire Wire Line
	3900 4250 4300 4250
Wire Wire Line
	4300 4250 4300 4200
Wire Wire Line
	3900 4450 4300 4450
Wire Wire Line
	4300 4450 4300 4500
Wire Bus Line
	5000 2400 5000 3150
$EndSCHEMATC
