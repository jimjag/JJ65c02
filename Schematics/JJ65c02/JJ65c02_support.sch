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
L Timer:LM555xN U2
U 1 1 5E17C676
P 2500 1700
AR Path="/61660CAC/5E17C676" Ref="U2"  Part="1" 
AR Path="/61610474/5E17C676" Ref="U?"  Part="1" 
F 0 "U2" H 2500 1750 50  0000 C CNN
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
L Device:R R13
U 1 1 5E1F5B26
P 3100 1250
AR Path="/61660CAC/5E1F5B26" Ref="R13"  Part="1" 
AR Path="/61610474/5E1F5B26" Ref="R?"  Part="1" 
F 0 "R13" V 3000 1250 50  0000 C CNN
F 1 "4.7K" V 3100 1250 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" V 3030 1250 50  0001 C CNN
F 3 "~" H 3100 1250 50  0001 C CNN
	1    3100 1250
	1    0    0    -1  
$EndComp
$Comp
L Device:CP C2
U 1 1 5E2337BD
P 3100 2150
AR Path="/61660CAC/5E2337BD" Ref="C2"  Part="1" 
AR Path="/61610474/5E2337BD" Ref="C?"  Part="1" 
F 0 "C2" H 3218 2196 50  0000 L CNN
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
F 2 "Button_Switch_THT:SW_PUSH_6mm" H 1600 2150 50  0001 C CNN
F 3 "~" H 1600 2150 50  0001 C CNN
	1    1600 1950
	0    -1   -1   0   
$EndComp
$Comp
L Device:C C1
U 1 1 5E2ECA64
P 1750 2150
AR Path="/61660CAC/5E2ECA64" Ref="C1"  Part="1" 
AR Path="/61610474/5E2ECA64" Ref="C?"  Part="1" 
F 0 "C1" H 1865 2196 50  0000 L CNN
F 1 "0.1uF" H 1865 2105 50  0000 L CNN
F 2 "Capacitor_THT:C_Disc_D3.4mm_W2.1mm_P2.50mm" H 1788 2000 50  0001 C CNN
F 3 "~" H 1750 2150 50  0001 C CNN
	1    1750 2150
	1    0    0    -1  
$EndComp
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
L Device:R R11
U 1 1 5E3A85D8
P 1750 1250
AR Path="/61660CAC/5E3A85D8" Ref="R11"  Part="1" 
AR Path="/61610474/5E3A85D8" Ref="R?"  Part="1" 
F 0 "R11" V 1650 1250 50  0000 C CNN
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
L Device:R R14
U 1 1 5E552FBE
P 4000 1250
AR Path="/61660CAC/5E552FBE" Ref="R14"  Part="1" 
AR Path="/61610474/5E552FBE" Ref="R?"  Part="1" 
F 0 "R14" V 3900 1250 50  0000 C CNN
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
$Comp
L 74xx:74HC00 U3
U 4 1 5E218D59
P 3600 1500
AR Path="/61660CAC/5E218D59" Ref="U3"  Part="4" 
AR Path="/61610474/5E218D59" Ref="U?"  Part="4" 
F 0 "U3" H 3600 1825 50  0000 C CNN
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
P 8850 2400
AR Path="/6171CEB1" Ref="X?"  Part="1" 
AR Path="/61660CAC/6171CEB1" Ref="X1"  Part="1" 
AR Path="/61610474/6171CEB1" Ref="X?"  Part="1" 
F 0 "X1" H 8950 2650 50  0000 L CNN
F 1 "1Mhz" H 9000 2750 50  0000 L CNN
F 2 "Oscillator:Oscillator_DIP-14" H 9300 2050 50  0001 C CNN
F 3 "http://cdn-reichelt.de/documents/datenblatt/B400/OSZI.pdf" H 8750 2400 50  0001 C CNN
	1    8850 2400
	1    0    0    -1  
$EndComp
Text GLabel 9150 2400 2    43   Output ~ 0
CLK
$Comp
L power:+5V #PWR?
U 1 1 6171CEBE
P 8900 2450
AR Path="/6171CEBE" Ref="#PWR?"  Part="1" 
AR Path="/61660CAC/6171CEBE" Ref="#PWR01"  Part="1" 
AR Path="/61610474/6171CEBE" Ref="#PWR?"  Part="1" 
F 0 "#PWR01" H 8900 2300 50  0001 C CNN
F 1 "+5V" H 8915 2623 50  0000 C CNN
F 2 "" H 8900 2450 50  0001 C CNN
F 3 "" H 8900 2450 50  0001 C CNN
	1    8900 2450
	1    0    0    -1  
$EndComp
NoConn ~ 8550 2400
$Comp
L Oscillator:CXO_DIP14 X?
U 1 1 6171CEC5
P 10200 2400
AR Path="/6171CEC5" Ref="X?"  Part="1" 
AR Path="/61660CAC/6171CEC5" Ref="X2"  Part="1" 
AR Path="/61610474/6171CEC5" Ref="X?"  Part="1" 
F 0 "X2" H 10300 2650 50  0000 L CNN
F 1 "1.8Mhz" H 10350 2750 50  0000 L CNN
F 2 "Oscillator:Oscillator_DIP-14" H 10650 2050 50  0001 C CNN
F 3 "http://cdn-reichelt.de/documents/datenblatt/B400/OSZI.pdf" H 10100 2400 50  0001 C CNN
	1    10200 2400
	1    0    0    -1  
$EndComp
Text GLabel 10500 2400 2    43   Output ~ 0
ACIA-CLK
NoConn ~ 9900 2400
$Comp
L 74xx:74HC00 U3
U 1 1 61753EE9
P 5900 1200
AR Path="/61660CAC/61753EE9" Ref="U3"  Part="1" 
AR Path="/61610474/61753EE9" Ref="U?"  Part="1" 
F 0 "U3" H 5900 1525 50  0000 C CNN
F 1 "74HC00" H 5900 1433 50  0000 C CNN
F 2 "Package_DIP:DIP-14_W7.62mm_Socket" H 5900 1200 50  0001 C CNN
F 3 "http://www.ti.com/lit/gpn/sn74hc00" H 5900 1200 50  0001 C CNN
	1    5900 1200
	1    0    0    -1  
$EndComp
$Comp
L 74xx:74HC00 U3
U 2 1 61753EEF
P 6750 1300
AR Path="/61660CAC/61753EEF" Ref="U3"  Part="2" 
AR Path="/61610474/61753EEF" Ref="U?"  Part="2" 
F 0 "U3" H 6750 1625 50  0000 C CNN
F 1 "74HC00" H 6750 1533 50  0000 C CNN
F 2 "Package_DIP:DIP-14_W7.62mm_Socket" H 6750 1300 50  0001 C CNN
F 3 "http://www.ti.com/lit/gpn/sn74hc00" H 6750 1300 50  0001 C CNN
	2    6750 1300
	1    0    0    -1  
$EndComp
Entry Wire Line
	4950 1200 5050 1300
Entry Wire Line
	4950 1400 5050 1500
Entry Wire Line
	4950 1600 5050 1700
Wire Wire Line
	5050 1300 5450 1300
Wire Wire Line
	5600 1100 5450 1100
Wire Wire Line
	5450 1100 5450 1300
Connection ~ 5450 1300
Wire Wire Line
	5450 1300 5600 1300
Wire Wire Line
	5050 1700 5150 1700
Wire Wire Line
	5150 1700 5150 2100
Wire Wire Line
	5300 1500 5300 1900
Wire Wire Line
	5050 1500 5300 1500
Text GLabel 6350 1400 0    43   Input ~ 0
CLK
Text GLabel 4675 1350 2    35   BiDi ~ 0
a[0..15]
Wire Wire Line
	6450 1400 6350 1400
Text GLabel 7250 1300 2    47   Output ~ 0
RAM~CS
Wire Wire Line
	7050 1300 7150 1300
Entry Wire Line
	4950 1800 5050 1900
Wire Wire Line
	5050 1900 5050 2300
Wire Wire Line
	5050 2300 5600 2300
Wire Wire Line
	5800 2400 5800 1900
Wire Wire Line
	5300 1900 5800 1900
Wire Wire Line
	5700 2100 5700 2500
Wire Wire Line
	5700 2500 5800 2500
Wire Wire Line
	5150 2100 5700 2100
Wire Wire Line
	5600 2300 5600 2600
Wire Wire Line
	5600 2600 5800 2600
Wire Wire Line
	5450 1300 5450 2900
Wire Wire Line
	5450 2900 5800 2900
Text GLabel 8000 2800 2    47   Output ~ 0
ROM~CS
Wire Wire Line
	6800 2400 7050 2400
Text GLabel 7250 2400 2    47   Output ~ 0
IO~CS
$Comp
L 74xx:74HC00 U3
U 3 1 6165C145
P 7550 2800
AR Path="/61660CAC/6165C145" Ref="U3"  Part="3" 
AR Path="/61610474/6165C145" Ref="U?"  Part="1" 
F 0 "U3" H 7550 3125 50  0000 C CNN
F 1 "74HC00" H 7550 3033 50  0000 C CNN
F 2 "Package_DIP:DIP-14_W7.62mm_Socket" H 7550 2800 50  0001 C CNN
F 3 "http://www.ti.com/lit/gpn/sn74hc00" H 7550 2800 50  0001 C CNN
	3    7550 2800
	1    0    0    -1  
$EndComp
Connection ~ 7050 2400
Wire Wire Line
	7050 2400 7250 2400
Wire Wire Line
	7050 2900 7250 2900
NoConn ~ 6800 2500
NoConn ~ 6800 2600
NoConn ~ 6800 2700
NoConn ~ 6800 2800
NoConn ~ 6800 2900
NoConn ~ 6800 3000
NoConn ~ 6800 3100
Text Notes 1450 2650 0    98   ~ 0
Power On Delay Reset
Text Notes 5450 3850 0    98   ~ 0
Memory Map Logic Glue
Text Notes 5200 700  0    98   ~ 0
Support Schematics
Text Label 5350 1300 2    47   ~ 0
a15
Text Label 5600 1900 2    47   ~ 0
a14
Text Label 5600 2100 2    47   ~ 0
a13
Text Label 5600 2300 2    47   ~ 0
a12
Wire Wire Line
	8850 2050 8850 2100
$Comp
L 74xx:74LS138 U5
U 1 1 615D1D41
P 6300 2700
AR Path="/61660CAC/615D1D41" Ref="U5"  Part="1" 
AR Path="/61610474/615D1D41" Ref="U?"  Part="1" 
F 0 "U5" H 6300 3481 50  0000 C CNN
F 1 "74AC138" H 6300 3390 50  0000 C CNN
F 2 "Package_DIP:DIP-16_W7.62mm_Socket" H 6300 2700 50  0001 C CNN
F 3 "http://www.ti.com/lit/gpn/sn74LS138" H 6300 2700 50  0001 C CNN
	1    6300 2700
	1    0    0    -1  
$EndComp
Wire Wire Line
	5800 3000 5800 3100
Wire Wire Line
	6300 3400 5800 3400
Wire Wire Line
	5800 3400 5800 3100
Connection ~ 5800 3100
Wire Wire Line
	6300 3400 6300 3500
Connection ~ 6300 3400
Wire Wire Line
	1750 2400 2500 2400
Wire Wire Line
	2500 2100 2500 2400
Connection ~ 2500 2400
Wire Wire Line
	2500 2400 3100 2400
Wire Wire Line
	6700 2050 6700 2100
Wire Wire Line
	6700 2100 6300 2100
Text GLabel 1250 1000 0    47   Input ~ 0
+5V
Text GLabel 1200 2400 0    47   Input ~ 0
GND
Text GLabel 10200 2750 3    47   Input ~ 0
GND
Text GLabel 6300 3500 3    47   Input ~ 0
GND
Text GLabel 6700 2050 1    47   Input ~ 0
+5V
Text GLabel 8850 2050 1    47   Input ~ 0
+5V
Text GLabel 10200 2000 1    47   Input ~ 0
+5V
Text GLabel 8850 2700 3    47   Input ~ 0
GND
Wire Wire Line
	10200 2000 10200 2100
Wire Wire Line
	10200 2700 10200 2750
$Comp
L JJ65c02-rescue:MAX232B-6502 U?
U 1 1 616302EB
P 4100 3650
AR Path="/616302EB" Ref="U?"  Part="1" 
AR Path="/61660CAC/616302EB" Ref="U4"  Part="1" 
F 0 "U4" V 4850 3350 47  0000 R CNN
F 1 "MAX232B" V 4750 3450 47  0000 R CNN
F 2 "JJ65c02:maxboard" H 4100 3650 47  0001 C CNN
F 3 "" H 4100 3650 47  0001 C CNN
	1    4100 3650
	0    -1   -1   0   
$EndComp
Text GLabel 3900 3250 0    47   Input ~ 0
RxD
Text GLabel 3900 3350 0    47   Input ~ 0
TxD
Text GLabel 3900 3650 0    47   Input ~ 0
+5V
Text GLabel 3900 3750 0    47   Input ~ 0
GND
Wire Wire Line
	3900 3250 4200 3250
Wire Wire Line
	3900 3350 4200 3350
Wire Wire Line
	3900 3650 4200 3650
Wire Wire Line
	3900 3750 4200 3750
NoConn ~ 4200 3450
NoConn ~ 4200 3550
Wire Wire Line
	1250 1000 1750 1000
Connection ~ 1750 1000
Wire Wire Line
	1200 2400 1600 2400
Wire Wire Line
	1600 2150 1600 2400
Connection ~ 1600 2400
Wire Wire Line
	1600 2400 1750 2400
Wire Wire Line
	6200 1200 6450 1200
Wire Wire Line
	8000 2800 7850 2800
Wire Wire Line
	7050 2400 7050 2900
Wire Wire Line
	7150 2700 7250 2700
Wire Wire Line
	7150 2700 7150 1300
Connection ~ 7150 1300
Wire Wire Line
	7150 1300 7250 1300
$Comp
L Device:LED D1
U 1 1 61721221
P 2650 3550
F 0 "D1" V 2689 3432 50  0000 R CNN
F 1 "LED (GREEN)" V 2598 3432 50  0000 R CNN
F 2 "LED_THT:LED_D3.0mm_FlatTop" H 2650 3550 50  0001 C CNN
F 3 "~" H 2650 3550 50  0001 C CNN
	1    2650 3550
	0    -1   -1   0   
$EndComp
$Comp
L Device:R R12
U 1 1 617239C1
P 2650 3250
AR Path="/61660CAC/617239C1" Ref="R12"  Part="1" 
AR Path="/61610474/617239C1" Ref="R?"  Part="1" 
F 0 "R12" V 2550 3250 50  0000 C CNN
F 1 "220" V 2650 3250 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" V 2580 3250 50  0001 C CNN
F 3 "~" H 2650 3250 50  0001 C CNN
	1    2650 3250
	1    0    0    -1  
$EndComp
Text GLabel 2300 3100 0    47   Input ~ 0
+5V
Text GLabel 2300 3800 0    47   Input ~ 0
GND
Wire Wire Line
	2300 3100 2650 3100
Wire Wire Line
	2300 3800 2650 3800
Wire Wire Line
	2650 3800 2650 3700
Entry Wire Line
	1500 5250 1400 5150
Entry Wire Line
	1500 5350 1400 5250
Entry Wire Line
	1500 5450 1400 5350
Entry Wire Line
	1500 5550 1400 5450
Entry Wire Line
	1500 5650 1400 5550
Entry Wire Line
	1500 5750 1400 5650
Entry Wire Line
	1500 5850 1400 5750
Entry Wire Line
	1500 5950 1400 5850
$Comp
L 6502:65C22S VIA?
U 1 1 619CCF88
P 2150 5450
AR Path="/619CCF88" Ref="VIA?"  Part="1" 
AR Path="/61660CAC/619CCF88" Ref="VIA2"  Part="1" 
F 0 "VIA2" H 2150 6615 50  0000 C CNN
F 1 "65C22S" H 2150 6524 50  0000 C CNN
F 2 "Package_DIP:DIP-40_W15.24mm_Socket" H 2150 6500 50  0001 C CNN
F 3 "" H 2250 5450 50  0001 C CNN
	1    2150 5450
	-1   0    0    -1  
$EndComp
Wire Wire Line
	1300 6050 1650 6050
Wire Wire Line
	1650 5150 1500 5150
Wire Wire Line
	1500 5150 1500 5100
Wire Wire Line
	1500 5100 1300 5100
Entry Wire Line
	1500 5050 1400 4950
Entry Wire Line
	1500 4950 1400 4850
Entry Wire Line
	1500 4850 1400 4750
Entry Wire Line
	1500 4750 1400 4650
Wire Wire Line
	1500 5850 1650 5850
Text GLabel 1650 6350 0    47   Input Italic 0
R~W
Text GLabel 1350 6450 0    43   Output ~ 0
V2~IRQ
Text GLabel 1350 6250 0    47   Input Italic 0
IO~CS
Text Label 1500 5250 0    47   ~ 0
d0
Text Label 1500 5350 0    47   ~ 0
d1
Text Label 1500 5450 0    47   ~ 0
d2
Text Label 1500 5550 0    47   ~ 0
d3
Text Label 1500 5650 0    47   ~ 0
d4
Text Label 1500 5750 0    47   ~ 0
d5
Text Label 1500 5850 0    47   ~ 0
d6
Text Label 1500 5950 0    47   ~ 0
d7
Text Label 1500 6150 0    47   ~ 0
a6
Text Label 1525 4750 0    47   ~ 0
a0
Text Label 1525 4850 0    47   ~ 0
a1
Text Label 1525 4950 0    47   ~ 0
a2
Text Label 1525 5050 0    47   ~ 0
a3
Wire Wire Line
	1650 4950 1500 4950
Wire Wire Line
	1500 4850 1650 4850
Wire Wire Line
	1650 4750 1500 4750
Wire Wire Line
	1500 5950 1650 5950
Wire Wire Line
	1500 5750 1650 5750
Wire Wire Line
	1500 5650 1650 5650
Wire Wire Line
	1500 5550 1650 5550
Wire Wire Line
	1500 5450 1650 5450
Wire Wire Line
	1500 5350 1650 5350
Wire Wire Line
	1500 5250 1650 5250
Wire Wire Line
	1500 5050 1650 5050
Text GLabel 1400 5500 0    35   BiDi ~ 0
d[0..7]
Text GLabel 1400 4800 0    35   BiDi ~ 0
a[0..15]
Text GLabel 1300 5100 0    50   Input ~ 0
~RES
Text GLabel 1300 6050 0    43   Input ~ 0
CLK
Entry Wire Line
	1000 6250 1100 6150
Text GLabel 1000 6250 0    35   BiDi ~ 0
a[0..15]
Wire Wire Line
	1100 6150 1650 6150
Wire Wire Line
	1350 6250 1650 6250
Text GLabel 2650 4300 1    47   Input ~ 0
GND
Text GLabel 2550 6650 0    47   Input ~ 0
+5V
Wire Wire Line
	1350 6450 1650 6450
$Comp
L Amplifier_Audio:LM386 U6
U 1 1 61AD8E1A
P 6400 5050
F 0 "U6" H 6650 5500 50  0000 L CNN
F 1 "LM386" H 6550 5400 50  0000 L CNN
F 2 "Package_DIP:DIP-8_W7.62mm_Socket" H 6500 5150 50  0001 C CNN
F 3 "http://www.ti.com/lit/ds/symlink/lm386.pdf" H 6600 5250 50  0001 C CNN
	1    6400 5050
	1    0    0    -1  
$EndComp
$Comp
L Device:R_POT RV?
U 1 1 61AE5299
P 5800 4950
AR Path="/61AE5299" Ref="RV?"  Part="1" 
AR Path="/61660CAC/61AE5299" Ref="RV2"  Part="1" 
F 0 "RV2" H 5732 4996 50  0001 R CNN
F 1 "10k" H 5732 4950 50  0000 R CNN
F 2 "Potentiometer_THT:Potentiometer_Bourns_3339P_Vertical" H 5800 4950 50  0001 C CNN
F 3 "~" H 5800 4950 50  0001 C CNN
	1    5800 4950
	1    0    0    -1  
$EndComp
Text GLabel 5700 4700 0    47   Input ~ 0
GND
Wire Wire Line
	5800 4700 5800 4800
Wire Wire Line
	5950 4950 6100 4950
Text GLabel 6200 4550 0    47   Input ~ 0
+5V
Wire Wire Line
	6200 4550 6300 4550
Wire Wire Line
	6300 4550 6300 4750
$Comp
L Device:Speaker LS1
U 1 1 61B4EE2B
P 8450 5050
F 0 "LS1" H 8620 5046 50  0000 L CNN
F 1 "Speaker" H 8620 4955 50  0000 L CNN
F 2 "JJ65c02:MiniSpeaker" H 8450 4850 50  0001 C CNN
F 3 "~" H 8440 5000 50  0001 C CNN
	1    8450 5050
	1    0    0    -1  
$EndComp
$Comp
L Device:CP C6
U 1 1 61B50526
P 7150 5050
AR Path="/61660CAC/61B50526" Ref="C6"  Part="1" 
AR Path="/61610474/61B50526" Ref="C?"  Part="1" 
F 0 "C6" V 7450 5000 50  0000 L CNN
F 1 "220uF" V 7350 4950 50  0000 L CNN
F 2 "Capacitor_THT:CP_Radial_D6.3mm_P2.50mm" H 7188 4900 50  0001 C CNN
F 3 "~" H 7150 5050 50  0001 C CNN
	1    7150 5050
	0    -1   -1   0   
$EndComp
$Comp
L Device:R R15
U 1 1 61B531C3
P 6850 5300
AR Path="/61660CAC/61B531C3" Ref="R15"  Part="1" 
AR Path="/61610474/61B531C3" Ref="R?"  Part="1" 
F 0 "R15" V 6750 5300 50  0000 C CNN
F 1 "10" V 6850 5300 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" V 6780 5300 50  0001 C CNN
F 3 "~" H 6850 5300 50  0001 C CNN
	1    6850 5300
	1    0    0    -1  
$EndComp
$Comp
L Device:C C5
U 1 1 61B5440E
P 6850 5700
AR Path="/61660CAC/61B5440E" Ref="C5"  Part="1" 
AR Path="/61610474/61B5440E" Ref="C?"  Part="1" 
F 0 "C5" H 6965 5746 50  0000 L CNN
F 1 "47pf" H 6965 5655 50  0000 L CNN
F 2 "Capacitor_THT:C_Disc_D3.4mm_W2.1mm_P2.50mm" H 6888 5550 50  0001 C CNN
F 3 "~" H 6850 5700 50  0001 C CNN
	1    6850 5700
	1    0    0    -1  
$EndComp
Wire Wire Line
	6700 5050 6850 5050
Wire Wire Line
	6850 5150 6850 5050
Connection ~ 6850 5050
Wire Wire Line
	6850 5050 7000 5050
Text GLabel 7300 5900 3    47   Input ~ 0
GND
Wire Wire Line
	6850 5450 6850 5550
Text Notes 6200 6400 0    98   ~ 0
Sound Ckt w/ Low Pass
$Comp
L Device:CP C3
U 1 1 61B81FD0
P 6400 4400
AR Path="/61660CAC/61B81FD0" Ref="C3"  Part="1" 
AR Path="/61610474/61B81FD0" Ref="C?"  Part="1" 
F 0 "C3" H 6100 4250 50  0000 L CNN
F 1 "10uF" H 6050 4350 50  0000 L CNN
F 2 "Capacitor_THT:CP_Radial_D5.0mm_P2.50mm" H 6438 4250 50  0001 C CNN
F 3 "~" H 6400 4400 50  0001 C CNN
	1    6400 4400
	-1   0    0    1   
$EndComp
Text GLabel 6400 4250 1    47   Input ~ 0
GND
Wire Wire Line
	6400 4550 6400 4750
$Comp
L Device:R R16
U 1 1 619F43A1
P 7450 5050
AR Path="/61660CAC/619F43A1" Ref="R16"  Part="1" 
AR Path="/61610474/619F43A1" Ref="R?"  Part="1" 
F 0 "R16" V 7550 5050 50  0000 C CNN
F 1 "330" V 7450 5050 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" V 7380 5050 50  0001 C CNN
F 3 "~" H 7450 5050 50  0001 C CNN
	1    7450 5050
	0    -1   -1   0   
$EndComp
$Comp
L Device:C C7
U 1 1 619FA8A5
P 7650 5450
AR Path="/61660CAC/619FA8A5" Ref="C7"  Part="1" 
AR Path="/61610474/619FA8A5" Ref="C?"  Part="1" 
F 0 "C7" H 7350 5550 50  0000 L CNN
F 1 "47nf" H 7350 5450 50  0000 L CNN
F 2 "Capacitor_THT:C_Disc_D3.4mm_W2.1mm_P2.50mm" H 7688 5300 50  0001 C CNN
F 3 "~" H 7650 5450 50  0001 C CNN
	1    7650 5450
	1    0    0    -1  
$EndComp
Wire Wire Line
	7600 5050 7650 5050
Wire Wire Line
	7650 5300 7650 5050
Connection ~ 7650 5050
Wire Wire Line
	7650 5050 7850 5050
Wire Wire Line
	6850 5850 7300 5850
Wire Wire Line
	7650 5600 7650 5850
Wire Wire Line
	7300 5900 7300 5850
Connection ~ 7300 5850
Wire Wire Line
	7300 5850 7650 5850
Wire Wire Line
	6850 5850 6300 5850
Wire Wire Line
	6100 5850 6100 5150
Connection ~ 6850 5850
Wire Wire Line
	6300 5350 6300 5850
Connection ~ 6300 5850
Wire Wire Line
	6300 5850 6100 5850
Text GLabel 5700 5300 0    47   Input ~ 0
SND_IN
Wire Wire Line
	5800 5100 5800 5300
$Comp
L Device:CP C4
U 1 1 61A13E6D
P 6500 5500
AR Path="/61660CAC/61A13E6D" Ref="C4"  Part="1" 
AR Path="/61610474/61A13E6D" Ref="C?"  Part="1" 
F 0 "C4" V 6350 5450 50  0000 L CNN
F 1 "10uF" V 6250 5400 50  0000 L CNN
F 2 "Capacitor_THT:CP_Radial_D5.0mm_P2.50mm" H 6538 5350 50  0001 C CNN
F 3 "~" H 6500 5500 50  0001 C CNN
	1    6500 5500
	0    -1   -1   0   
$EndComp
Wire Wire Line
	6350 5350 6400 5350
Wire Wire Line
	6350 5350 6350 5500
Wire Wire Line
	6500 5350 6650 5350
Wire Wire Line
	6650 5350 6650 5500
$Comp
L MCU_Module:Arduino_Nano_v2.x A1
U 1 1 61B02721
P 4250 5400
F 0 "A1" H 4250 4311 50  0000 C CNN
F 1 "Arduino_Nano_v2.x" H 4250 4220 50  0000 C CNN
F 2 "Module:Arduino_Nano" H 4250 5400 50  0001 C CIN
F 3 "https://www.arduino.cc/en/uploads/Main/ArduinoNanoManual23.pdf" H 4250 5400 50  0001 C CNN
	1    4250 5400
	1    0    0    -1  
$EndComp
$Comp
L Connector:Mini-DIN-6 J1
U 1 1 61B062BD
P 1350 3500
F 0 "J1" H 1350 3867 50  0000 C CNN
F 1 "Mini-DIN-6" H 1350 3776 50  0000 C CNN
F 2 "JJ65c02:mini_din-6" H 1350 3500 50  0001 C CNN
F 3 "http://service.powerdynamics.com/ec/Catalog17/Section%2011.pdf" H 1350 3500 50  0001 C CNN
	1    1350 3500
	1    0    0    -1  
$EndComp
$Comp
L Connector:Barrel_Jack_Switch_Pin3Ring J2
U 1 1 61B24F10
P 8800 3600
F 0 "J2" H 8857 3917 50  0000 C CNN
F 1 "Barrel_Jack" H 8857 3826 50  0000 C CNN
F 2 "Connector_BarrelJack:CUI_PJ-059AH" H 8850 3560 50  0001 C CNN
F 3 "~" H 8850 3560 50  0001 C CNN
	1    8800 3600
	1    0    0    -1  
$EndComp
$Comp
L Regulator_Linear:LM2936-5.0 U7
U 1 1 61B34034
P 9650 3500
F 0 "U7" H 9650 3742 50  0000 C CNN
F 1 "LM2940T-5.0/LF08" H 9650 3651 50  0000 C CNN
F 2 "Connector:LM2940" H 9650 3725 50  0001 C CIN
F 3 "http://www.ti.com/lit/ds/symlink/lm2936.pdf" H 9650 3450 50  0001 C CNN
	1    9650 3500
	1    0    0    -1  
$EndComp
Wire Wire Line
	9100 3500 9350 3500
Wire Wire Line
	9100 3600 9100 3700
Wire Wire Line
	9100 3700 9100 3800
Wire Wire Line
	9100 3800 9650 3800
Connection ~ 9100 3700
Wire Wire Line
	9950 3500 10150 3500
Wire Wire Line
	9650 3800 10150 3800
Connection ~ 9650 3800
Text GLabel 10150 3500 2    47   Output ~ 0
+5V
Text GLabel 10150 3800 2    47   Output ~ 0
GND
$Comp
L 74xx:74HC00 U3
U 5 1 61D186CE
P 4450 2450
AR Path="/61660CAC/61D186CE" Ref="U3"  Part="5" 
AR Path="/61610474/61D186CE" Ref="U?"  Part="2" 
F 0 "U3" V 4200 2450 50  0000 C CNN
F 1 "74HC00" V 4750 2450 50  0000 C CNN
F 2 "Package_DIP:DIP-14_W7.62mm_Socket" H 4450 2450 50  0001 C CNN
F 3 "http://www.ti.com/lit/gpn/sn74hc00" H 4450 2450 50  0001 C CNN
	5    4450 2450
	0    1    1    0   
$EndComp
Text GLabel 3950 2450 0    47   Input ~ 0
GND
Text GLabel 4950 2450 2    47   Input ~ 0
+5V
Wire Wire Line
	2650 6450 2650 6650
Wire Wire Line
	2650 6650 2550 6650
Text GLabel 4050 4300 0    47   Input ~ 0
+5V
Wire Wire Line
	4150 4400 4150 4300
Wire Wire Line
	4150 4300 4050 4300
Text GLabel 4500 6400 2    47   Input ~ 0
GND
Wire Wire Line
	4500 6400 4350 6400
Wire Wire Line
	4350 6400 4250 6400
Connection ~ 4350 6400
$Comp
L Connector_Generic:Conn_01x14 J4
U 1 1 61C871A3
P 10000 4950
F 0 "J4" H 9950 5650 50  0000 L CNN
F 1 "Arduino Jack1" H 9500 3950 50  0000 L CNN
F 2 "Connector_PinSocket_2.54mm:PinSocket_1x14_P2.54mm_Vertical" H 10000 4950 50  0001 C CNN
F 3 "~" H 10000 4950 50  0001 C CNN
	1    10000 4950
	1    0    0    -1  
$EndComp
$Comp
L Connector_Generic:Conn_01x14 J5
U 1 1 61C8B884
P 10350 4950
F 0 "J5" H 10300 5650 50  0000 L CNN
F 1 "Arduino Jack2" H 9850 3950 50  0000 L CNN
F 2 "Connector_PinSocket_2.54mm:PinSocket_1x14_P2.54mm_Vertical" H 10350 4950 50  0001 C CNN
F 3 "~" H 10350 4950 50  0001 C CNN
	1    10350 4950
	-1   0    0    -1  
$EndComp
Text Label 3600 4800 0    47   ~ 0
nd0
Text Label 3600 4900 0    47   ~ 0
nd1
Text Label 3600 5000 0    47   ~ 0
nd2
Text Label 3600 5100 0    47   ~ 0
nd3
Text Label 3600 5200 0    47   ~ 0
nd4
Text Label 3600 5300 0    47   ~ 0
nd5
Text Label 3600 5400 0    47   ~ 0
nd6
Text Label 3600 5500 0    47   ~ 0
nd7
Text Label 3600 5600 0    47   ~ 0
nd8
Text Label 3600 5700 0    47   ~ 0
nd9
Text Label 3600 5800 0    47   ~ 0
nd10
Text Label 3600 5900 0    47   ~ 0
nd11
Text Label 3600 6000 0    47   ~ 0
nd12
Text Label 3600 6100 0    47   ~ 0
nd13
Text Label 4800 4800 0    47   ~ 0
ndr2
Text Label 4800 4900 0    47   ~ 0
ndr1
Text Label 4800 5200 0    47   ~ 0
ndrf
Text Label 4800 5400 0    47   ~ 0
na0
Text Label 4800 5500 0    47   ~ 0
na1
Text Label 4800 5600 0    47   ~ 0
na2
Text Label 4800 5700 0    47   ~ 0
na3
Text Label 4800 5800 0    47   ~ 0
na4
Text Label 4800 5900 0    47   ~ 0
na5
Text Label 4800 6000 0    47   ~ 0
na6
Text Label 4800 6100 0    47   ~ 0
na7
Wire Wire Line
	3750 4800 3600 4800
Wire Wire Line
	3600 4900 3750 4900
Wire Wire Line
	3750 5000 3600 5000
Wire Wire Line
	3750 5100 3600 5100
Wire Wire Line
	3750 5200 3600 5200
Wire Wire Line
	3750 6100 3600 6100
Wire Wire Line
	3750 6000 3600 6000
Wire Wire Line
	3600 5900 3750 5900
Wire Wire Line
	3600 5800 3750 5800
Wire Wire Line
	3600 5700 3750 5700
Wire Wire Line
	3600 5600 3750 5600
Wire Wire Line
	3750 5500 3600 5500
Wire Wire Line
	3750 5400 3600 5400
Wire Wire Line
	3750 5300 3600 5300
Wire Wire Line
	4750 4800 4950 4800
Wire Wire Line
	4750 4900 4950 4900
Wire Wire Line
	4750 5200 4950 5200
Wire Wire Line
	4750 5400 4950 5400
Wire Wire Line
	4750 5500 4950 5500
Wire Wire Line
	4750 5600 4950 5600
Wire Wire Line
	4750 5700 4950 5700
Wire Wire Line
	4750 5800 4950 5800
Wire Wire Line
	4750 5900 4950 5900
Wire Wire Line
	4750 6000 4950 6000
Wire Wire Line
	4750 6100 4950 6100
Entry Wire Line
	3500 4900 3600 4800
Entry Wire Line
	3500 5000 3600 4900
Entry Wire Line
	3500 5100 3600 5000
Entry Wire Line
	3500 5200 3600 5100
Entry Wire Line
	3500 5300 3600 5200
Entry Wire Line
	3500 5400 3600 5300
Entry Wire Line
	3500 5500 3600 5400
Entry Wire Line
	3500 5600 3600 5500
Entry Wire Line
	3500 5700 3600 5600
Entry Wire Line
	3500 5800 3600 5700
Entry Wire Line
	3500 5900 3600 5800
Entry Wire Line
	3500 6000 3600 5900
Entry Wire Line
	3500 6100 3600 6000
Entry Wire Line
	3500 6200 3600 6100
Entry Wire Line
	4950 4800 5050 4900
Entry Wire Line
	4950 4900 5050 5000
Entry Wire Line
	4950 5200 5050 5300
Entry Wire Line
	4950 5400 5050 5500
Entry Wire Line
	4950 5500 5050 5600
Entry Wire Line
	4950 5600 5050 5700
Entry Wire Line
	4950 5700 5050 5800
Entry Wire Line
	4950 5800 5050 5900
Entry Wire Line
	4950 5900 5050 6000
Entry Wire Line
	4950 6000 5050 6100
Entry Wire Line
	4950 6100 5050 6200
Text GLabel 5050 5450 2    35   BiDi ~ 0
ard
Text GLabel 3500 5550 0    35   BiDi ~ 0
ard
Entry Wire Line
	2850 4750 2950 4650
Entry Wire Line
	2850 4850 2950 4750
Entry Wire Line
	2850 4950 2950 4850
Entry Wire Line
	2850 5050 2950 4950
Entry Wire Line
	2850 5150 2950 5050
Entry Wire Line
	2850 5250 2950 5150
Entry Wire Line
	2850 5250 2950 5150
Entry Wire Line
	2850 5350 2950 5250
Wire Wire Line
	2650 4550 2650 4300
Entry Wire Line
	1500 4550 1400 4450
Wire Bus Line
	1400 4450 1400 4550
Entry Wire Line
	2850 4650 2950 4550
Wire Wire Line
	2650 5350 2850 5350
Wire Wire Line
	2650 5250 2850 5250
Wire Wire Line
	2650 5150 2850 5150
Wire Wire Line
	2650 5050 2850 5050
Wire Wire Line
	2650 4950 2850 4950
Wire Wire Line
	2650 4850 2850 4850
Wire Wire Line
	2650 4650 2850 4650
Wire Wire Line
	1650 4550 1500 4550
Wire Wire Line
	2650 4750 2850 4750
Text GLabel 2950 4900 2    35   BiDi ~ 0
ard
NoConn ~ 4450 4400
NoConn ~ 4350 4400
Text GLabel 1400 4500 0    35   BiDi ~ 0
ard
Text Label 2650 5350 0    47   ~ 0
nd13
Text Label 2650 5250 0    47   ~ 0
nd12
Text Label 2650 5150 0    47   ~ 0
nd11
Text Label 2650 5050 0    47   ~ 0
nd10
Text Label 2650 4950 0    47   ~ 0
nd9
Text Label 2650 4850 0    47   ~ 0
nd8
Text Label 2650 4750 0    47   ~ 0
nd7
Text Label 2650 4650 0    47   ~ 0
nd6
Text GLabel 1650 3500 2    47   Input ~ 0
GND
Text GLabel 1050 3500 0    47   Input ~ 0
+5V
Text Label 1650 3400 0    47   ~ 0
nd2
Wire Wire Line
	1650 3400 1800 3400
Entry Wire Line
	1800 3400 1900 3300
Text GLabel 1900 3400 2    35   BiDi ~ 0
ard
Text Label 1650 3700 0    47   ~ 0
nd4
Wire Wire Line
	1650 3600 1650 3700
Wire Wire Line
	1650 3700 1800 3700
Entry Wire Line
	1800 3700 1900 3600
Wire Bus Line
	1900 3300 1900 3600
NoConn ~ 1050 3600
NoConn ~ 1050 3400
Text Label 1500 4550 0    47   ~ 0
nd5
NoConn ~ 1650 4650
Text Label 10600 5350 0    47   ~ 0
ndr2
Text Label 10600 5250 0    47   ~ 0
ndr1
Text Label 10600 5150 0    47   ~ 0
ndrf
Text Label 10600 5050 0    47   ~ 0
na0
Text Label 10600 4950 0    47   ~ 0
na1
Text Label 10600 4850 0    47   ~ 0
na2
Text Label 10600 4750 0    47   ~ 0
na3
Text Label 10600 4650 0    47   ~ 0
na4
Text Label 10600 4550 0    47   ~ 0
na5
Text Label 10600 4450 0    47   ~ 0
na6
Text Label 10600 4350 0    47   ~ 0
na7
Wire Wire Line
	10550 4350 10750 4350
Wire Wire Line
	10550 4450 10750 4450
Wire Wire Line
	10550 4550 10750 4550
Wire Wire Line
	10550 4650 10750 4650
Wire Wire Line
	10550 4750 10750 4750
Wire Wire Line
	10550 4850 10750 4850
Wire Wire Line
	10550 4950 10750 4950
Wire Wire Line
	10550 5050 10750 5050
Wire Wire Line
	10550 5150 10750 5150
Wire Wire Line
	10550 5250 10750 5250
Wire Wire Line
	10550 5350 10750 5350
Entry Wire Line
	10750 4350 10850 4450
Entry Wire Line
	10750 4450 10850 4550
Entry Wire Line
	10750 4550 10850 4650
Entry Wire Line
	10750 4650 10850 4750
Entry Wire Line
	10750 4750 10850 4850
Entry Wire Line
	10750 4850 10850 4950
Entry Wire Line
	10750 4950 10850 5050
Entry Wire Line
	10750 5050 10850 5150
Entry Wire Line
	10750 5150 10850 5250
Entry Wire Line
	10750 5250 10850 5350
Entry Wire Line
	10750 5350 10850 5450
Text GLabel 10850 4700 2    35   BiDi ~ 0
ard
Text Label 9650 4350 0    47   ~ 0
nd0
Text Label 9650 4450 0    47   ~ 0
nd1
Text Label 9650 4550 0    47   ~ 0
nd2
Text Label 9650 4650 0    47   ~ 0
nd3
Text Label 9650 4750 0    47   ~ 0
nd4
Text Label 9650 4850 0    47   ~ 0
nd5
Text Label 9650 4950 0    47   ~ 0
nd6
Text Label 9650 5050 0    47   ~ 0
nd7
Text Label 9650 5150 0    47   ~ 0
nd8
Text Label 9650 5250 0    47   ~ 0
nd9
Text Label 9650 5350 0    47   ~ 0
nd10
Text Label 9650 5450 0    47   ~ 0
nd11
Text Label 9650 5550 0    47   ~ 0
nd12
Text Label 9650 5650 0    47   ~ 0
nd13
Wire Wire Line
	9800 4350 9650 4350
Wire Wire Line
	9650 4450 9800 4450
Wire Wire Line
	9800 4550 9650 4550
Wire Wire Line
	9800 4650 9650 4650
Wire Wire Line
	9800 4750 9650 4750
Wire Wire Line
	9800 5650 9650 5650
Wire Wire Line
	9800 5550 9650 5550
Wire Wire Line
	9650 5450 9800 5450
Wire Wire Line
	9650 5350 9800 5350
Wire Wire Line
	9650 5250 9800 5250
Wire Wire Line
	9650 5150 9800 5150
Wire Wire Line
	9800 5050 9650 5050
Wire Wire Line
	9800 4950 9650 4950
Wire Wire Line
	9800 4850 9650 4850
Entry Wire Line
	9550 4450 9650 4350
Entry Wire Line
	9550 4550 9650 4450
Entry Wire Line
	9550 4650 9650 4550
Entry Wire Line
	9550 4750 9650 4650
Entry Wire Line
	9550 4850 9650 4750
Entry Wire Line
	9550 4950 9650 4850
Entry Wire Line
	9550 5050 9650 4950
Entry Wire Line
	9550 5150 9650 5050
Entry Wire Line
	9550 5250 9650 5150
Entry Wire Line
	9550 5350 9650 5250
Entry Wire Line
	9550 5450 9650 5350
Entry Wire Line
	9550 5550 9650 5450
Entry Wire Line
	9550 5650 9650 5550
Entry Wire Line
	9550 5750 9650 5650
Text GLabel 9550 5100 0    35   BiDi ~ 0
ard
$Comp
L Connector:AudioJack3 J6
U 1 1 61C5DD65
P 8350 5650
F 0 "J6" H 8170 5725 50  0000 R CNN
F 1 "AudioJack2" H 8170 5634 50  0000 R CNN
F 2 "Connector_Audio:Jack_3.5mm_CUI_SJ1-3533NG_Horizontal" H 8350 5650 50  0001 C CNN
F 3 "~" H 8350 5650 50  0001 C CNN
	1    8350 5650
	-1   0    0    -1  
$EndComp
$Comp
L Switch:SW_SPST SW2
U 1 1 61C861E7
P 8050 5050
F 0 "SW2" H 8050 5285 50  0000 C CNN
F 1 "SW_SPST" H 8050 5194 50  0000 C CNN
F 2 "Button_Switch_THT:SW_DIP_SPSTx01_Slide_6.7x4.1mm_W7.62mm_P2.54mm_LowProfile" H 8050 5050 50  0001 C CNN
F 3 "~" H 8050 5050 50  0001 C CNN
	1    8050 5050
	1    0    0    -1  
$EndComp
Wire Wire Line
	5800 4700 5700 4700
Wire Wire Line
	5800 5300 5700 5300
Connection ~ 7850 5050
Wire Wire Line
	8050 5150 8250 5150
Wire Wire Line
	8050 5850 7650 5850
Connection ~ 7650 5850
Wire Wire Line
	8050 5150 8050 5550
Wire Wire Line
	8150 5550 8050 5550
Connection ~ 8050 5550
Wire Wire Line
	8050 5550 8050 5850
Text GLabel 10700 5700 2    47   Input ~ 0
GND
Text GLabel 10700 5550 2    47   Input ~ 0
+5V
Wire Wire Line
	10700 5550 10650 5550
Wire Wire Line
	10650 5550 10650 5450
Wire Wire Line
	10650 5450 10550 5450
Wire Wire Line
	10700 5700 10600 5700
Wire Wire Line
	10600 5700 10600 5550
Wire Wire Line
	10600 5550 10550 5550
NoConn ~ 10550 5650
$Comp
L Connector_Generic:Conn_01x10 J3
U 1 1 61B31258
P 2850 5850
F 0 "J3" H 2950 5800 50  0000 L CNN
F 1 "VIA2 PortB" H 2750 4950 50  0000 L CNN
F 2 "Connector_PinSocket_2.54mm:PinSocket_1x10_P2.54mm_Vertical" H 2850 5850 50  0001 C CNN
F 3 "~" H 2850 5850 50  0001 C CNN
	1    2850 5850
	1    0    0    -1  
$EndComp
Wire Wire Line
	8150 5650 8150 5750
Wire Wire Line
	8150 5750 7850 5750
Wire Wire Line
	7850 5050 7850 5750
Connection ~ 8150 5750
Wire Bus Line
	1000 6200 1000 6300
Wire Bus Line
	1400 4650 1400 4950
Wire Bus Line
	4950 1200 4950 1950
Wire Bus Line
	1400 5150 1400 5850
Wire Bus Line
	2950 4550 2950 5250
Wire Bus Line
	5050 4900 5050 6200
Wire Bus Line
	10850 4450 10850 5450
Wire Bus Line
	3500 4900 3500 6200
Wire Bus Line
	9550 4450 9550 5750
$EndSCHEMATC
