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
L JJ65c02-rescue:NE555-Timer-6502 U1
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
P 8700 3300
AR Path="/6171CEB1" Ref="X?"  Part="1" 
AR Path="/61660CAC/6171CEB1" Ref="X1"  Part="1" 
AR Path="/61610474/6171CEB1" Ref="X?"  Part="1" 
F 0 "X1" H 8800 3550 50  0000 L CNN
F 1 "1Mhz" H 8850 3650 50  0000 L CNN
F 2 "Oscillator:Oscillator_DIP-14" H 9150 2950 50  0001 C CNN
F 3 "http://cdn-reichelt.de/documents/datenblatt/B400/OSZI.pdf" H 8600 3300 50  0001 C CNN
	1    8700 3300
	1    0    0    -1  
$EndComp
Text GLabel 9000 3300 2    43   Output ~ 0
CLK
$Comp
L power:+5V #PWR?
U 1 1 6171CEBE
P 8750 3350
AR Path="/6171CEBE" Ref="#PWR?"  Part="1" 
AR Path="/61660CAC/6171CEBE" Ref="#PWR020"  Part="1" 
AR Path="/61610474/6171CEBE" Ref="#PWR?"  Part="1" 
F 0 "#PWR020" H 8750 3200 50  0001 C CNN
F 1 "+5V" H 8765 3523 50  0000 C CNN
F 2 "" H 8750 3350 50  0001 C CNN
F 3 "" H 8750 3350 50  0001 C CNN
	1    8750 3350
	1    0    0    -1  
$EndComp
NoConn ~ 8400 3300
$Comp
L Oscillator:CXO_DIP14 X?
U 1 1 6171CEC5
P 10050 3300
AR Path="/6171CEC5" Ref="X?"  Part="1" 
AR Path="/61660CAC/6171CEC5" Ref="X2"  Part="1" 
AR Path="/61610474/6171CEC5" Ref="X?"  Part="1" 
F 0 "X2" H 10150 3550 50  0000 L CNN
F 1 "1.8Mhz" H 10200 3650 50  0000 L CNN
F 2 "Oscillator:Oscillator_DIP-14" H 10500 2950 50  0001 C CNN
F 3 "http://cdn-reichelt.de/documents/datenblatt/B400/OSZI.pdf" H 9950 3300 50  0001 C CNN
	1    10050 3300
	1    0    0    -1  
$EndComp
Text GLabel 10350 3300 2    43   Output ~ 0
ACIA-CLK
NoConn ~ 9750 3300
$Comp
L 74xx:74HC00 U2
U 1 1 61753EE9
P 5900 1200
AR Path="/61660CAC/61753EE9" Ref="U2"  Part="1" 
AR Path="/61610474/61753EE9" Ref="U?"  Part="1" 
F 0 "U2" H 5900 1525 50  0000 C CNN
F 1 "74HC00" H 5900 1433 50  0000 C CNN
F 2 "Package_DIP:DIP-14_W7.62mm_Socket" H 5900 1200 50  0001 C CNN
F 3 "http://www.ti.com/lit/gpn/sn74hc00" H 5900 1200 50  0001 C CNN
	1    5900 1200
	1    0    0    -1  
$EndComp
$Comp
L 74xx:74HC00 U2
U 2 1 61753EEF
P 6750 1300
AR Path="/61660CAC/61753EEF" Ref="U2"  Part="2" 
AR Path="/61610474/61753EEF" Ref="U?"  Part="2" 
F 0 "U2" H 6750 1625 50  0000 C CNN
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
L 74xx:74HC00 U2
U 3 1 6165C145
P 7550 2800
AR Path="/61660CAC/6165C145" Ref="U2"  Part="3" 
AR Path="/61610474/6165C145" Ref="U?"  Part="1" 
F 0 "U2" H 7550 3125 50  0000 C CNN
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
Text Notes 5550 3950 0    98   ~ 0
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
	8700 2950 8700 3000
$Comp
L 74xx:74LS138 U3
U 1 1 615D1D41
P 6300 2700
AR Path="/61660CAC/615D1D41" Ref="U3"  Part="1" 
AR Path="/61610474/615D1D41" Ref="U?"  Part="1" 
F 0 "U3" H 6300 3481 50  0000 C CNN
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
Text GLabel 10050 3650 3    47   Input ~ 0
GND
Text GLabel 6300 3500 3    47   Input ~ 0
GND
Text GLabel 6700 2050 1    47   Input ~ 0
+5V
Text GLabel 8700 2950 1    47   Input ~ 0
+5V
Text GLabel 10050 2900 1    47   Input ~ 0
+5V
Text GLabel 8700 3600 3    47   Input ~ 0
GND
Wire Wire Line
	10050 2900 10050 3000
Wire Wire Line
	10050 3600 10050 3650
$Comp
L 74xx:74LS08 U4
U 1 1 615F5956
P 9700 1500
F 0 "U4" H 9700 1825 50  0000 C CNN
F 1 "74HC08" H 9700 1734 50  0000 C CNN
F 2 "Package_DIP:DIP-14_W7.62mm_Socket" H 9700 1500 50  0001 C CNN
F 3 "http://www.ti.com/lit/gpn/sn74LS08" H 9700 1500 50  0001 C CNN
	1    9700 1500
	1    0    0    -1  
$EndComp
Text GLabel 10000 1500 2    47   Output ~ 0
~IRQ
Text GLabel 9200 1400 0    47   Input ~ 0
V~IRQ
Text GLabel 9200 1600 0    47   Input ~ 0
A~IRQ
Wire Wire Line
	9400 1600 9300 1600
Wire Wire Line
	9400 1400 9200 1400
$Comp
L Device:R R2
U 1 1 615FE1AE
P 9300 1850
AR Path="/61660CAC/615FE1AE" Ref="R2"  Part="1" 
AR Path="/61610474/615FE1AE" Ref="R?"  Part="1" 
F 0 "R2" V 9200 1850 50  0000 C CNN
F 1 "4.7K" V 9300 1850 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" V 9230 1850 50  0001 C CNN
F 3 "~" H 9300 1850 50  0001 C CNN
	1    9300 1850
	1    0    0    -1  
$EndComp
Wire Wire Line
	9300 1700 9300 1600
Connection ~ 9300 1600
Wire Wire Line
	9300 1600 9200 1600
Text GLabel 9300 2100 3    47   Input ~ 0
+5V
Wire Wire Line
	9300 2000 9300 2100
Text Notes 8850 2500 0    98   ~ 0
~IRQ~ Logic Glue
$Comp
L JJ65c02-rescue:MAX232B-6502 U5
U 1 1 616302EB
P 3800 3750
AR Path="/616302EB" Ref="U5"  Part="1" 
AR Path="/61660CAC/616302EB" Ref="U5"  Part="1" 
F 0 "U5" V 4550 3450 47  0000 R CNN
F 1 "MAX232B" V 4450 3550 47  0000 R CNN
F 2 "TerminalBlock_TE-Connectivity:TerminalBlock_TE_282834-6_1x06_P2.54mm_Horizontal" H 3800 3750 47  0001 C CNN
F 3 "" H 3800 3750 47  0001 C CNN
	1    3800 3750
	0    -1   -1   0   
$EndComp
Text GLabel 3600 3350 0    47   Input ~ 0
RxD
Text GLabel 3600 3450 0    47   Input ~ 0
TxD
Text GLabel 3600 3750 0    47   Input ~ 0
+5V
Text GLabel 3600 3850 0    47   Input ~ 0
GND
Wire Wire Line
	3600 3350 3900 3350
Wire Wire Line
	3600 3450 3900 3450
Wire Wire Line
	3600 3750 3900 3750
Wire Wire Line
	3600 3850 3900 3850
NoConn ~ 3900 3550
NoConn ~ 3900 3650
$Comp
L power:+5VD #PWR0101
U 1 1 6160B5F2
P 1350 3400
F 0 "#PWR0101" H 1350 3250 50  0001 C CNN
F 1 "+5VD" H 1365 3573 50  0000 C CNN
F 2 "" H 1350 3400 50  0001 C CNN
F 3 "" H 1350 3400 50  0001 C CNN
	1    1350 3400
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0102
U 1 1 6160BF33
P 1350 3700
F 0 "#PWR0102" H 1350 3450 50  0001 C CNN
F 1 "GND" H 1355 3527 50  0000 C CNN
F 2 "" H 1350 3700 50  0001 C CNN
F 3 "" H 1350 3700 50  0001 C CNN
	1    1350 3700
	1    0    0    -1  
$EndComp
Text GLabel 950  3450 0    47   Input ~ 0
+5V
Text GLabel 950  3650 0    47   Input ~ 0
GND
Wire Wire Line
	950  3450 1350 3450
Wire Wire Line
	1350 3450 1350 3400
Wire Wire Line
	950  3650 1350 3650
Wire Wire Line
	1350 3650 1350 3700
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
P 2450 3650
F 0 "D1" V 2489 3532 50  0000 R CNN
F 1 "LED (GREEN)" V 2398 3532 50  0000 R CNN
F 2 "" H 2450 3650 50  0001 C CNN
F 3 "~" H 2450 3650 50  0001 C CNN
	1    2450 3650
	0    -1   -1   0   
$EndComp
$Comp
L Device:R R13
U 1 1 617239C1
P 2450 3350
AR Path="/61660CAC/617239C1" Ref="R13"  Part="1" 
AR Path="/61610474/617239C1" Ref="R?"  Part="1" 
F 0 "R13" V 2350 3350 50  0000 C CNN
F 1 "220" V 2450 3350 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" V 2380 3350 50  0001 C CNN
F 3 "~" H 2450 3350 50  0001 C CNN
	1    2450 3350
	1    0    0    -1  
$EndComp
Text GLabel 2100 3200 0    47   Input ~ 0
+5V
Text GLabel 2100 3900 0    47   Input ~ 0
GND
Wire Wire Line
	2100 3200 2450 3200
Wire Wire Line
	2100 3900 2450 3900
Wire Wire Line
	2450 3900 2450 3800
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
Entry Wire Line
	1500 6050 1400 5950
Entry Wire Line
	1500 6150 1400 6050
$Comp
L 6502:65C22S VIA?
U 1 1 619CCF88
P 2150 5650
AR Path="/619CCF88" Ref="VIA?"  Part="1" 
AR Path="/61660CAC/619CCF88" Ref="VIA2"  Part="1" 
F 0 "VIA2" H 2150 6815 50  0000 C CNN
F 1 "65C22S" H 2150 6724 50  0000 C CNN
F 2 "Package_DIP:DIP-40_W15.24mm_Socket" H 2150 6700 50  0001 C CNN
F 3 "" H 2250 5650 50  0001 C CNN
	1    2150 5650
	-1   0    0    -1  
$EndComp
Wire Wire Line
	1300 6250 1650 6250
Wire Wire Line
	2650 6650 2900 6650
Wire Wire Line
	1650 5350 1500 5350
Wire Wire Line
	1500 5350 1500 5300
Wire Wire Line
	1500 5300 1300 5300
Text GLabel 1150 5700 2    35   BiDi ~ 0
d[0..7]
Wire Bus Line
	1400 5000 1250 5000
Entry Wire Line
	1500 5250 1400 5150
Entry Wire Line
	1500 5150 1400 5050
Entry Wire Line
	1500 5050 1400 4950
Entry Wire Line
	1500 4950 1400 4850
NoConn ~ 1650 4850
NoConn ~ 1650 4750
Wire Wire Line
	1500 6050 1650 6050
Text GLabel 1650 6550 0    47   Input Italic 0
R~W
Text GLabel 1350 6650 0    43   Input ~ 0
V~IRQ
Text GLabel 1350 6450 0    47   Input Italic 0
IO~CS
Text Label 1500 5450 0    47   ~ 0
d0
Text Label 1500 5550 0    47   ~ 0
d1
Text Label 1500 5650 0    47   ~ 0
d2
Text Label 1500 5750 0    47   ~ 0
d3
Text Label 1500 5850 0    47   ~ 0
d4
Text Label 1500 5950 0    47   ~ 0
d5
Text Label 1500 6050 0    47   ~ 0
d6
Text Label 1500 6150 0    47   ~ 0
d7
Text Label 1500 6350 0    47   ~ 0
a6
Text Label 1525 4950 0    47   ~ 0
a0
Text Label 1525 5050 0    47   ~ 0
a1
Text Label 1525 5150 0    47   ~ 0
a2
Text Label 1525 5250 0    47   ~ 0
a3
Wire Wire Line
	1650 5150 1500 5150
Wire Wire Line
	1500 5050 1650 5050
Wire Wire Line
	1650 4950 1500 4950
Wire Wire Line
	1500 6150 1650 6150
Wire Wire Line
	1500 5950 1650 5950
Wire Wire Line
	1500 5850 1650 5850
Wire Wire Line
	1500 5750 1650 5750
Wire Wire Line
	1500 5650 1650 5650
Wire Wire Line
	1500 5550 1650 5550
Wire Wire Line
	1500 5450 1650 5450
Wire Wire Line
	1500 5250 1650 5250
Text GLabel 1150 5700 2    35   BiDi ~ 0
d[0..7]
Text GLabel 975  5000 2    35   BiDi ~ 0
a[0..15]
Text GLabel 1300 5300 0    50   Input ~ 0
~RES
Text GLabel 1300 6250 0    43   Input ~ 0
CLK
Entry Wire Line
	1000 6450 1100 6350
Text GLabel 700  6450 2    35   BiDi ~ 0
a[0..15]
Wire Wire Line
	1100 6350 1650 6350
Wire Wire Line
	1350 6450 1650 6450
Text GLabel 2900 6650 2    47   Input ~ 0
GND
Text GLabel 2900 4750 2    47   Input ~ 0
+5V
Wire Wire Line
	2650 4750 2900 4750
Wire Wire Line
	1350 6650 1650 6650
Connection ~ 1400 5000
$Comp
L Amplifier_Audio:LM386 U6
U 1 1 61AD8E1A
P 5050 5150
F 0 "U6" H 5300 5600 50  0000 L CNN
F 1 "LM386" H 5200 5500 50  0000 L CNN
F 2 "" H 5150 5250 50  0001 C CNN
F 3 "http://www.ti.com/lit/ds/symlink/lm386.pdf" H 5250 5350 50  0001 C CNN
	1    5050 5150
	1    0    0    -1  
$EndComp
$Comp
L Device:R_POT RV?
U 1 1 61AE5299
P 4450 5050
AR Path="/61AE5299" Ref="RV?"  Part="1" 
AR Path="/61660CAC/61AE5299" Ref="RV2"  Part="1" 
F 0 "RV2" H 4382 5096 50  0001 R CNN
F 1 "10k" H 4382 5050 50  0000 R CNN
F 2 "Potentiometer_THT:Potentiometer_Bourns_3339P_Vertical" H 4450 5050 50  0001 C CNN
F 3 "~" H 4450 5050 50  0001 C CNN
	1    4450 5050
	1    0    0    -1  
$EndComp
Text GLabel 4200 4800 0    47   Input ~ 0
GND
Wire Wire Line
	4200 4800 4450 4800
Wire Wire Line
	4450 4800 4450 4900
Wire Wire Line
	4600 5050 4750 5050
Text GLabel 4850 4650 0    47   Input ~ 0
+5V
Wire Wire Line
	4850 4650 4950 4650
Wire Wire Line
	4950 4650 4950 4850
$Comp
L Device:Speaker LS1
U 1 1 61B4EE2B
P 6700 5150
F 0 "LS1" H 6870 5146 50  0000 L CNN
F 1 "Speaker" H 6870 5055 50  0000 L CNN
F 2 "" H 6700 4950 50  0001 C CNN
F 3 "~" H 6690 5100 50  0001 C CNN
	1    6700 5150
	1    0    0    -1  
$EndComp
$Comp
L Device:CP C4
U 1 1 61B50526
P 5800 5150
AR Path="/61660CAC/61B50526" Ref="C4"  Part="1" 
AR Path="/61610474/61B50526" Ref="C?"  Part="1" 
F 0 "C4" V 6100 5100 50  0000 L CNN
F 1 "220uF" V 6000 5050 50  0000 L CNN
F 2 "Capacitor_THT:C_Disc_D3.4mm_W2.1mm_P2.50mm" H 5838 5000 50  0001 C CNN
F 3 "~" H 5800 5150 50  0001 C CNN
	1    5800 5150
	0    -1   -1   0   
$EndComp
$Comp
L Device:R R15
U 1 1 61B531C3
P 5500 5400
AR Path="/61660CAC/61B531C3" Ref="R15"  Part="1" 
AR Path="/61610474/61B531C3" Ref="R?"  Part="1" 
F 0 "R15" V 5400 5400 50  0000 C CNN
F 1 "10" V 5500 5400 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" V 5430 5400 50  0001 C CNN
F 3 "~" H 5500 5400 50  0001 C CNN
	1    5500 5400
	1    0    0    -1  
$EndComp
$Comp
L Device:C C5
U 1 1 61B5440E
P 5500 5800
AR Path="/61660CAC/61B5440E" Ref="C5"  Part="1" 
AR Path="/61610474/61B5440E" Ref="C?"  Part="1" 
F 0 "C5" H 5615 5846 50  0000 L CNN
F 1 "47pf" H 5615 5755 50  0000 L CNN
F 2 "Capacitor_THT:C_Disc_D3.4mm_W2.1mm_P2.50mm" H 5538 5650 50  0001 C CNN
F 3 "~" H 5500 5800 50  0001 C CNN
	1    5500 5800
	1    0    0    -1  
$EndComp
Wire Wire Line
	5350 5150 5500 5150
Wire Wire Line
	5500 5250 5500 5150
Connection ~ 5500 5150
Wire Wire Line
	5500 5150 5650 5150
Text GLabel 5950 6000 3    47   Input ~ 0
GND
Wire Wire Line
	5500 5550 5500 5650
Text Notes 4850 6500 0    98   ~ 0
Sound Ckt w/ Low Pass
$Comp
L Device:CP C7
U 1 1 61B81FD0
P 5050 4500
AR Path="/61660CAC/61B81FD0" Ref="C7"  Part="1" 
AR Path="/61610474/61B81FD0" Ref="C?"  Part="1" 
F 0 "C7" H 4750 4350 50  0000 L CNN
F 1 "10uF" H 4700 4450 50  0000 L CNN
F 2 "Capacitor_THT:C_Disc_D3.4mm_W2.1mm_P2.50mm" H 5088 4350 50  0001 C CNN
F 3 "~" H 5050 4500 50  0001 C CNN
	1    5050 4500
	-1   0    0    1   
$EndComp
Text GLabel 5050 4350 1    47   Input ~ 0
GND
Wire Wire Line
	5050 4650 5050 4850
$Comp
L Device:R R16
U 1 1 619F43A1
P 6100 5150
AR Path="/61660CAC/619F43A1" Ref="R16"  Part="1" 
AR Path="/61610474/619F43A1" Ref="R?"  Part="1" 
F 0 "R16" V 6200 5150 50  0000 C CNN
F 1 "330" V 6100 5150 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" V 6030 5150 50  0001 C CNN
F 3 "~" H 6100 5150 50  0001 C CNN
	1    6100 5150
	0    -1   -1   0   
$EndComp
$Comp
L Device:C C1
U 1 1 619FA8A5
P 6300 5550
AR Path="/61660CAC/619FA8A5" Ref="C1"  Part="1" 
AR Path="/61610474/619FA8A5" Ref="C?"  Part="1" 
F 0 "C1" H 6000 5650 50  0000 L CNN
F 1 "47nf" H 6000 5550 50  0000 L CNN
F 2 "Capacitor_THT:C_Disc_D3.4mm_W2.1mm_P2.50mm" H 6338 5400 50  0001 C CNN
F 3 "~" H 6300 5550 50  0001 C CNN
	1    6300 5550
	1    0    0    -1  
$EndComp
Wire Wire Line
	6250 5150 6300 5150
Wire Wire Line
	6300 5400 6300 5150
Connection ~ 6300 5150
Wire Wire Line
	6300 5150 6500 5150
Wire Wire Line
	5500 5950 5950 5950
Wire Wire Line
	6500 5250 6500 5950
Wire Wire Line
	6300 5700 6300 5950
Connection ~ 6300 5950
Wire Wire Line
	6300 5950 6500 5950
Wire Wire Line
	5950 6000 5950 5950
Connection ~ 5950 5950
Wire Wire Line
	5950 5950 6300 5950
Wire Wire Line
	5500 5950 4950 5950
Wire Wire Line
	4750 5950 4750 5250
Connection ~ 5500 5950
Wire Wire Line
	4950 5450 4950 5950
Connection ~ 4950 5950
Wire Wire Line
	4950 5950 4750 5950
Text GLabel 4200 5400 0    47   Input ~ 0
SND_IN
Wire Wire Line
	4450 5200 4450 5400
Wire Wire Line
	4450 5400 4200 5400
$Comp
L Device:CP C6
U 1 1 61A13E6D
P 5150 5600
AR Path="/61660CAC/61A13E6D" Ref="C6"  Part="1" 
AR Path="/61610474/61A13E6D" Ref="C?"  Part="1" 
F 0 "C6" V 5000 5550 50  0000 L CNN
F 1 "10uF" V 4900 5500 50  0000 L CNN
F 2 "Capacitor_THT:C_Disc_D3.4mm_W2.1mm_P2.50mm" H 5188 5450 50  0001 C CNN
F 3 "~" H 5150 5600 50  0001 C CNN
	1    5150 5600
	0    -1   -1   0   
$EndComp
Wire Wire Line
	5000 5450 5050 5450
Wire Wire Line
	5000 5450 5000 5600
Wire Wire Line
	5150 5450 5300 5450
Wire Wire Line
	5300 5450 5300 5600
$Comp
L Device:LED D2
U 1 1 61AAFD1D
P 4450 6100
F 0 "D2" V 4489 5982 50  0000 R CNN
F 1 "LED (RED)" V 4398 5982 50  0000 R CNN
F 2 "" H 4450 6100 50  0001 C CNN
F 3 "~" H 4450 6100 50  0001 C CNN
	1    4450 6100
	0    -1   -1   0   
$EndComp
$Comp
L Device:R R14
U 1 1 61AAFD23
P 4450 5800
AR Path="/61660CAC/61AAFD23" Ref="R14"  Part="1" 
AR Path="/61610474/61AAFD23" Ref="R?"  Part="1" 
F 0 "R14" V 4350 5800 50  0000 C CNN
F 1 "1K" V 4450 5800 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" V 4380 5800 50  0001 C CNN
F 3 "~" H 4450 5800 50  0001 C CNN
	1    4450 5800
	1    0    0    -1  
$EndComp
Text GLabel 4200 5650 0    47   Input ~ 0
SND_IN
Text GLabel 4200 6350 0    47   Input ~ 0
GND
Wire Wire Line
	4450 6350 4450 6250
Wire Wire Line
	4200 5650 4450 5650
Wire Wire Line
	4450 6350 4200 6350
$Comp
L MCU_Module:Arduino_Nano_v2.x A?
U 1 1 61B02721
P 7950 5150
F 0 "A?" H 7950 4061 50  0000 C CNN
F 1 "Arduino_Nano_v2.x" H 7950 3970 50  0000 C CNN
F 2 "Module:Arduino_Nano" H 7950 5150 50  0001 C CIN
F 3 "https://www.arduino.cc/en/uploads/Main/ArduinoNanoManual23.pdf" H 7950 5150 50  0001 C CNN
	1    7950 5150
	1    0    0    -1  
$EndComp
$Comp
L Connector:Mini-DIN-6 J?
U 1 1 61B062BD
P 9800 5200
F 0 "J?" H 9800 5567 50  0000 C CNN
F 1 "Mini-DIN-6" H 9800 5476 50  0000 C CNN
F 2 "" H 9800 5200 50  0001 C CNN
F 3 "http://service.powerdynamics.com/ec/Catalog17/Section%2011.pdf" H 9800 5200 50  0001 C CNN
	1    9800 5200
	1    0    0    -1  
$EndComp
Wire Bus Line
	1000 6400 1000 6500
Wire Bus Line
	1400 4850 1400 5000
Wire Bus Line
	1400 5000 1400 5150
Wire Bus Line
	4950 1200 4950 1950
Wire Bus Line
	1400 5350 1400 6050
$EndSCHEMATC
