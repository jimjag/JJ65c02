EESchema Schematic File Version 4
EELAYER 30 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 1 2
Title "JJ65c02 Hobby Breadboard Computer"
Date ""
Rev ""
Comp ""
Comment1 ""
Comment2 ""
Comment3 "Inspiration: Ben Eater (et.al) 6502 project"
Comment4 "Author: Jim Jagielski"
$EndDescr
$Comp
L 6502:28C256 ROM1
U 1 1 61333CF7
P 7900 2600
F 0 "ROM1" H 7900 3515 50  0000 C CNN
F 1 "28C256" H 7900 3424 50  0000 C CNN
F 2 "Package_DIP:DIP-28_W15.24mm_Socket" H 7850 3400 50  0001 C CNN
F 3 "" H 7900 2600 50  0001 C CNN
	1    7900 2600
	1    0    0    -1  
$EndComp
Text GLabel 2900 2100 2    43   Input ~ 0
CLK
Wire Wire Line
	2900 2100 2800 2100
NoConn ~ 1800 1800
NoConn ~ 1800 2000
NoConn ~ 1800 2200
NoConn ~ 1800 2400
NoConn ~ 2800 1900
NoConn ~ 2800 2000
Entry Wire Line
	2950 2600 3050 2500
Entry Wire Line
	2950 2700 3050 2600
Entry Wire Line
	2950 2800 3050 2700
Entry Wire Line
	2950 2900 3050 2800
Entry Wire Line
	2950 3000 3050 2900
Wire Wire Line
	2800 3300 2950 3300
Wire Wire Line
	2800 3400 2950 3400
Wire Wire Line
	2800 3500 2950 3500
Wire Wire Line
	2800 3600 2950 3600
Wire Wire Line
	2800 2500 2950 2500
Wire Wire Line
	2800 2600 2950 2600
Wire Wire Line
	2800 2700 2950 2700
Wire Wire Line
	2800 2800 2950 2800
Wire Wire Line
	2800 2900 2950 2900
Wire Wire Line
	2800 3000 2950 3000
Wire Wire Line
	2800 3100 2950 3100
Wire Wire Line
	2800 3200 2950 3200
Entry Wire Line
	2950 2500 3050 2400
Entry Wire Line
	2950 3100 3050 3000
Entry Wire Line
	2950 3200 3050 3100
Wire Wire Line
	1800 2700 1650 2700
Wire Wire Line
	1800 2800 1650 2800
Wire Wire Line
	1800 2900 1650 2900
Wire Wire Line
	1800 3000 1650 3000
Wire Wire Line
	1800 3100 1650 3100
Wire Wire Line
	1800 3200 1650 3200
Wire Wire Line
	1800 3300 1650 3300
Wire Wire Line
	1800 3400 1650 3400
Wire Wire Line
	1800 3500 1650 3500
Wire Wire Line
	1800 3600 1650 3600
Wire Wire Line
	1800 3700 1650 3700
Wire Wire Line
	1800 2600 1650 2600
Entry Wire Line
	1550 2700 1650 2600
Entry Wire Line
	1550 2800 1650 2700
Entry Wire Line
	1550 3800 1650 3700
Entry Wire Line
	1550 3700 1650 3600
Entry Wire Line
	1550 3600 1650 3500
Entry Wire Line
	1550 3500 1650 3400
Entry Wire Line
	1550 3400 1650 3300
Entry Wire Line
	1550 3300 1650 3200
Entry Wire Line
	1550 3200 1650 3100
Entry Wire Line
	1550 3100 1650 3000
Entry Wire Line
	1550 3000 1650 2900
Entry Wire Line
	1550 2900 1650 2800
Entry Wire Line
	2950 3300 3050 3400
Entry Wire Line
	2950 3400 3050 3500
Entry Wire Line
	2950 3500 3050 3600
Entry Wire Line
	2950 3600 3050 3700
Wire Bus Line
	3050 4100 1550 4100
Wire Wire Line
	6800 2750 6400 2750
Wire Wire Line
	6400 2550 6800 2550
Connection ~ 6800 2550
Wire Wire Line
	6800 2550 6800 2750
Wire Wire Line
	2800 1800 2900 1800
Wire Wire Line
	2900 1800 2900 950 
Wire Wire Line
	3350 950  2900 950 
$Comp
L Device:R_POT RV1
U 1 1 615573C8
P 7050 5650
F 0 "RV1" H 6982 5696 50  0001 R CNN
F 1 "10k" H 6982 5650 50  0000 R CNN
F 2 "Potentiometer_THT:Potentiometer_Bourns_3339P_Vertical" H 7050 5650 50  0001 C CNN
F 3 "~" H 7050 5650 50  0001 C CNN
	1    7050 5650
	1    0    0    -1  
$EndComp
NoConn ~ 7050 5400
Wire Wire Line
	7050 5500 7050 5400
Entry Wire Line
	5150 1950 5250 2050
Entry Wire Line
	5150 2050 5250 2150
Entry Wire Line
	5150 2150 5250 2250
Entry Wire Line
	5150 2250 5250 2350
Entry Wire Line
	5150 2350 5250 2450
Entry Wire Line
	5150 2450 5250 2550
Entry Wire Line
	5150 2550 5250 2650
Entry Wire Line
	5150 2650 5250 2750
Entry Wire Line
	5150 2750 5250 2850
Entry Wire Line
	5150 1850 5250 1950
Wire Wire Line
	5400 1950 5250 1950
Wire Wire Line
	5400 2050 5250 2050
Wire Wire Line
	5400 2150 5250 2150
Wire Wire Line
	5400 2250 5250 2250
Wire Wire Line
	5400 2350 5250 2350
Wire Wire Line
	5400 2450 5250 2450
Wire Wire Line
	5400 2550 5250 2550
Wire Wire Line
	5400 2650 5250 2650
Wire Wire Line
	5400 2750 5250 2750
Wire Wire Line
	5400 2850 5250 2850
Text GLabel 3050 2800 2    35   BiDi ~ 0
d[0..7]
Text GLabel 4950 1800 2    35   BiDi ~ 0
a[0..15]
Text GLabel 1275 3900 2    35   BiDi ~ 0
a[0..15]
Entry Wire Line
	7150 1950 7250 2050
Entry Wire Line
	7150 2050 7250 2150
Entry Wire Line
	7150 2150 7250 2250
Entry Wire Line
	7150 2250 7250 2350
Entry Wire Line
	7150 2350 7250 2450
Entry Wire Line
	7150 2450 7250 2550
Entry Wire Line
	7150 2550 7250 2650
Entry Wire Line
	7150 2650 7250 2750
Entry Wire Line
	7150 2750 7250 2850
Entry Wire Line
	7150 1850 7250 1950
Wire Wire Line
	7400 1950 7250 1950
Wire Wire Line
	7400 2050 7250 2050
Wire Wire Line
	7400 2150 7250 2150
Wire Wire Line
	7400 2250 7250 2250
Wire Wire Line
	7400 2350 7250 2350
Wire Wire Line
	7400 2450 7250 2450
Wire Wire Line
	7400 2550 7250 2550
Wire Wire Line
	7400 2650 7250 2650
Wire Wire Line
	7400 2750 7250 2750
Wire Wire Line
	7400 2850 7250 2850
Text GLabel 6950 1800 2    35   BiDi ~ 0
a[0..15]
$Comp
L 6502:62256 RAM1
U 1 1 613314B4
P 5900 2600
F 0 "RAM1" H 5900 3515 50  0000 C CNN
F 1 "62256" H 5900 3424 50  0000 C CNN
F 2 "Package_DIP:DIP-28_W15.24mm_Socket" H 5850 3400 50  0001 C CNN
F 3 "" H 5900 2600 50  0001 C CNN
	1    5900 2600
	1    0    0    -1  
$EndComp
Entry Wire Line
	7050 2650 7150 2550
Wire Wire Line
	6400 2650 7050 2650
Wire Wire Line
	6400 2450 7050 2450
Wire Wire Line
	6400 2350 7050 2350
Wire Wire Line
	6400 2250 7050 2250
Wire Wire Line
	6400 2150 7050 2150
Entry Wire Line
	7050 2150 7150 2050
Entry Wire Line
	7050 2250 7150 2150
Entry Wire Line
	7050 2350 7150 2250
Entry Wire Line
	7050 2450 7150 2350
Text GLabel 8975 2225 2    35   BiDi ~ 0
a[0..15]
Entry Wire Line
	8850 2650 8950 2550
Entry Wire Line
	8850 2150 8950 2050
Entry Wire Line
	8850 2250 8950 2150
Entry Wire Line
	8850 2350 8950 2250
Entry Wire Line
	8850 2450 8950 2350
Wire Wire Line
	8850 2150 8400 2150
Wire Wire Line
	8400 2250 8850 2250
Wire Wire Line
	8850 2350 8400 2350
Wire Wire Line
	8400 2450 8850 2450
Wire Wire Line
	8850 2650 8400 2650
Entry Wire Line
	3550 5300 3450 5200
Entry Wire Line
	3550 5400 3450 5300
Entry Wire Line
	3550 5500 3450 5400
Entry Wire Line
	3550 5600 3450 5500
Entry Wire Line
	3550 5700 3450 5600
Entry Wire Line
	3550 5800 3450 5700
Entry Wire Line
	3550 5900 3450 5800
Entry Wire Line
	3550 6000 3450 5900
Text GLabel 3350 6100 0    43   Input ~ 0
CLK
$Comp
L 6502:65C22S VIA1
U 1 1 6132BE2E
P 4200 5500
F 0 "VIA1" H 4200 6665 50  0000 C CNN
F 1 "65C22S" H 4200 6574 50  0000 C CNN
F 2 "Package_DIP:DIP-40_W15.24mm_Socket" H 4200 6550 50  0001 C CNN
F 3 "" H 4300 5500 50  0001 C CNN
	1    4200 5500
	-1   0    0    -1  
$EndComp
Wire Wire Line
	3350 6100 3700 6100
Wire Wire Line
	4850 6750 3500 6750
Wire Wire Line
	3500 6750 3500 6300
Wire Wire Line
	3500 6300 3700 6300
Wire Wire Line
	4700 6500 4950 6500
Wire Wire Line
	3700 5200 3550 5200
Wire Wire Line
	3550 5200 3550 5150
Wire Wire Line
	3550 5150 3350 5150
NoConn ~ 4700 6300
Entry Wire Line
	3200 6400 3300 6300
Wire Wire Line
	3700 6200 3400 6200
Wire Wire Line
	3400 6200 3400 6300
Wire Wire Line
	3400 6300 3300 6300
Text GLabel 3200 5550 2    35   BiDi ~ 0
d[0..7]
Text GLabel 2900 6400 2    35   BiDi ~ 0
a[0..15]
Wire Bus Line
	3450 4850 3300 4850
Text GLabel 3025 4850 2    35   BiDi ~ 0
a[0..15]
Entry Wire Line
	3550 5100 3450 5000
Entry Wire Line
	3550 5000 3450 4900
Entry Wire Line
	3550 4900 3450 4800
Entry Wire Line
	3550 4800 3450 4700
NoConn ~ 3700 4700
NoConn ~ 3700 4600
Wire Wire Line
	3350 950  3350 4300
Wire Wire Line
	4850 6750 4850 4200
Wire Wire Line
	3550 5900 3700 5900
$Comp
L 6502:65C02S CPU1
U 1 1 61323888
P 2300 2700
F 0 "CPU1" H 2300 3865 50  0000 C CNN
F 1 "65C02S" H 2300 3774 50  0000 C CNN
F 2 "Package_DIP:DIP-40_W15.24mm_Socket" H 2300 3750 50  0001 C CNN
F 3 "" H 2150 3650 50  0001 C CNN
	1    2300 2700
	1    0    0    -1  
$EndComp
Wire Wire Line
	2900 3900 2900 3700
Wire Wire Line
	2900 3700 2800 3700
Connection ~ 5400 3900
Wire Wire Line
	4700 4600 5400 4600
Wire Wire Line
	5400 4600 5400 3900
Wire Wire Line
	4700 5400 5600 5400
Wire Wire Line
	4700 5300 5500 5300
Wire Wire Line
	4700 5200 5400 5200
Wire Wire Line
	5400 2950 5250 2950
Wire Wire Line
	5400 3050 5250 3050
Wire Wire Line
	5400 3150 5250 3150
Entry Wire Line
	5250 2950 5150 3050
Entry Wire Line
	5250 3050 5150 3150
Entry Wire Line
	5250 3150 5150 3250
Text GLabel 4900 3150 2    35   BiDi ~ 0
d[0..7]
Wire Wire Line
	6400 2850 6800 2850
Wire Wire Line
	6400 2950 6800 2950
Wire Wire Line
	6400 3050 6800 3050
Wire Wire Line
	6400 3150 6800 3150
Wire Wire Line
	6400 3250 6800 3250
Wire Wire Line
	7400 3250 7200 3250
Entry Wire Line
	6800 2850 6900 2750
Entry Wire Line
	6800 2950 6900 2850
Entry Wire Line
	6800 3050 6900 2950
Entry Wire Line
	6800 3150 6900 3050
Entry Wire Line
	6800 3250 6900 3150
Text GLabel 6800 3300 2    35   BiDi ~ 0
d[0..7]
Wire Wire Line
	7400 2950 7000 2950
Entry Wire Line
	7000 2950 6900 2850
Wire Wire Line
	7400 3050 7000 3050
Wire Wire Line
	7400 3150 7000 3150
Entry Wire Line
	7000 3050 6900 2950
Entry Wire Line
	7000 3150 6900 3050
Wire Wire Line
	8400 2850 8550 2850
Wire Wire Line
	8400 2950 8550 2950
Wire Wire Line
	8400 3050 8550 3050
Wire Wire Line
	8400 3150 8550 3150
Wire Wire Line
	8400 3250 8550 3250
Entry Wire Line
	8550 2850 8650 2950
Entry Wire Line
	8550 2950 8650 3050
Entry Wire Line
	8550 3050 8650 3150
Entry Wire Line
	8550 3150 8650 3250
Entry Wire Line
	8550 3250 8650 3350
Text GLabel 8700 3150 2    35   BiDi ~ 0
d[0..7]
Wire Wire Line
	6400 1950 6450 1950
Wire Wire Line
	8500 2750 8400 2750
Wire Wire Line
	6450 1950 6450 1900
Wire Wire Line
	8400 1950 8800 1950
Wire Wire Line
	9350 1800 9350 1500
Text GLabel 3450 2400 2    47   Output Italic 0
R~W
Text GLabel 6400 2050 2    47   Input Italic 0
R~W
Text GLabel 3700 6400 0    47   Input Italic 0
R~W
Wire Wire Line
	850  1900 1000 1900
Wire Wire Line
	850  900  850  1900
$Comp
L Device:R R1
U 1 1 61ABC413
P 1150 1900
F 0 "R1" V 1050 1900 50  0000 C CNN
F 1 "4.7K" V 1150 1900 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" H 1150 1900 50  0001 C CNN
F 3 "~" H 1150 1900 50  0001 C CNN
	1    1150 1900
	0    1    1    0   
$EndComp
Wire Wire Line
	4950 4250 4950 4800
Wire Wire Line
	4950 4800 4700 4800
Wire Wire Line
	4700 5100 5100 5100
Wire Wire Line
	5100 5100 5100 4400
NoConn ~ 4700 4700
Wire Wire Line
	3500 2200 3500 2050
$Comp
L Switch:SW_Push UB1
U 1 1 6136A5EF
P 8400 4900
F 0 "UB1" V 8300 5050 50  0000 C CNN
F 1 "SW_Push" H 8400 5050 50  0001 C CNN
F 2 "Button_Switch_THT:SW_PUSH_6mm_H4.3mm" H 8400 5100 50  0001 C CNN
F 3 "~" H 8400 5100 50  0001 C CNN
	1    8400 4900
	0    1    1    0   
$EndComp
$Comp
L Switch:SW_Push RB1
U 1 1 61379F3D
P 8700 4900
F 0 "RB1" V 8600 5050 50  0000 C CNN
F 1 "SW_Push" H 8700 5050 50  0001 C CNN
F 2 "Button_Switch_THT:SW_PUSH_6mm_H4.3mm" H 8700 5100 50  0001 C CNN
F 3 "~" H 8700 5100 50  0001 C CNN
	1    8700 4900
	0    1    1    0   
$EndComp
$Comp
L Switch:SW_Push DB1
U 1 1 6138977F
P 9000 4900
F 0 "DB1" V 8900 5050 50  0000 C CNN
F 1 "SW_Push" H 9000 5050 50  0001 C CNN
F 2 "Button_Switch_THT:SW_PUSH_6mm_H4.3mm" H 9000 5100 50  0001 C CNN
F 3 "~" H 9000 5100 50  0001 C CNN
	1    9000 4900
	0    1    1    0   
$EndComp
$Comp
L Device:R R6
U 1 1 613C0CBF
P 9000 5600
F 0 "R6" H 8900 5450 50  0000 C CNN
F 1 "1K" V 9000 5600 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" H 9000 5600 50  0001 C CNN
F 3 "~" H 9000 5600 50  0001 C CNN
	1    9000 5600
	-1   0    0    1   
$EndComp
$Comp
L Device:R R5
U 1 1 613C09A0
P 8700 5600
F 0 "R5" H 8600 5450 50  0000 C CNN
F 1 "1K" V 8700 5600 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" H 8700 5600 50  0001 C CNN
F 3 "~" H 8700 5600 50  0001 C CNN
	1    8700 5600
	-1   0    0    1   
$EndComp
$Comp
L Device:R R4
U 1 1 613C0477
P 8400 5600
F 0 "R4" H 8300 5450 50  0000 C CNN
F 1 "1K" V 8400 5600 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" H 8400 5600 50  0001 C CNN
F 3 "~" H 8400 5600 50  0001 C CNN
	1    8400 5600
	-1   0    0    1   
$EndComp
$Comp
L Device:R R3
U 1 1 613AF256
P 8100 5600
F 0 "R3" H 8000 5450 50  0000 C CNN
F 1 "1K" V 8100 5600 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" H 8100 5600 50  0001 C CNN
F 3 "~" H 8100 5600 50  0001 C CNN
	1    8100 5600
	-1   0    0    1   
$EndComp
Wire Wire Line
	9000 4700 8700 4700
Connection ~ 8400 4700
Wire Wire Line
	8400 4700 8100 4700
Connection ~ 8700 4700
Wire Wire Line
	8700 4700 8550 4700
Wire Wire Line
	8550 4600 8550 4700
Connection ~ 8550 4700
Wire Wire Line
	8550 4700 8400 4700
Wire Wire Line
	4700 4900 5000 4900
Wire Wire Line
	4700 5000 5050 5000
Wire Wire Line
	5000 4900 5000 4300
Wire Wire Line
	5050 5000 5050 4350
Wire Wire Line
	4700 5500 5250 5500
Entry Wire Line
	5250 5500 5350 5600
Wire Wire Line
	4700 5600 5250 5600
Entry Wire Line
	5250 5600 5350 5700
Wire Wire Line
	4700 5700 5250 5700
Entry Wire Line
	5250 5700 5350 5800
Wire Wire Line
	4700 5800 5250 5800
Entry Wire Line
	5250 5800 5350 5900
Wire Wire Line
	4700 5900 5250 5900
Entry Wire Line
	5250 5900 5350 6000
Wire Wire Line
	4700 6000 5250 6000
Entry Wire Line
	5250 6000 5350 6100
Wire Wire Line
	4700 6100 5250 6100
Entry Wire Line
	5250 6100 5350 6200
Wire Wire Line
	4700 6200 5250 6200
Entry Wire Line
	5250 6200 5350 6300
Wire Wire Line
	5900 5500 5450 5500
Entry Wire Line
	5450 5500 5350 5600
Wire Wire Line
	5900 5600 5450 5600
Entry Wire Line
	5450 5600 5350 5700
Wire Wire Line
	5900 5700 5450 5700
Entry Wire Line
	5450 5700 5350 5800
Wire Wire Line
	5900 5800 5450 5800
Entry Wire Line
	5450 5800 5350 5900
Wire Wire Line
	5900 5900 5450 5900
Entry Wire Line
	5450 5900 5350 6000
Wire Wire Line
	5900 6000 5450 6000
Entry Wire Line
	5450 6000 5350 6100
Wire Wire Line
	5900 6100 5450 6100
Entry Wire Line
	5450 6100 5350 6200
Wire Wire Line
	5900 6200 5450 6200
Entry Wire Line
	5450 6200 5350 6300
Text GLabel 5250 6350 2    35   BiDi ~ 0
pb[0..7]
Connection ~ 8550 5850
Wire Wire Line
	7200 3900 7200 4000
Wire Wire Line
	5400 3900 7200 3900
Wire Wire Line
	8550 5850 8550 5950
$Comp
L Switch:SW_Push LB1
U 1 1 613599F4
P 8100 4900
F 0 "LB1" V 8000 5050 50  0000 C CNN
F 1 "SW_Push" H 8100 5050 50  0001 C CNN
F 2 "Button_Switch_THT:SW_PUSH_6mm_H4.3mm" H 8100 5100 50  0001 C CNN
F 3 "~" H 8100 5100 50  0001 C CNN
	1    8100 4900
	0    1    1    0   
$EndComp
$Comp
L 6502:65C51N ACIA1
U 1 1 614BD6C2
P 1900 5600
F 0 "ACIA1" H 1900 6515 50  0000 C CNN
F 1 "65C51N" H 1900 6424 50  0000 C CNN
F 2 "Package_DIP:DIP-28_W15.24mm_Socket" H 1850 6400 50  0001 C CNN
F 3 "" H 1900 5600 50  0001 C CNN
	1    1900 5600
	1    0    0    -1  
$EndComp
Entry Wire Line
	2750 5350 2650 5250
Entry Wire Line
	2750 5450 2650 5350
Entry Wire Line
	2750 5550 2650 5450
Entry Wire Line
	2750 5650 2650 5550
Entry Wire Line
	2750 5750 2650 5650
Entry Wire Line
	2750 5850 2650 5750
Entry Wire Line
	2750 5950 2650 5850
Entry Wire Line
	2750 6050 2650 5950
Text GLabel 2750 5650 2    35   BiDi ~ 0
d[0..7]
Wire Wire Line
	2650 5250 2400 5250
Wire Wire Line
	2650 5950 2400 5950
Wire Wire Line
	2650 5750 2400 5750
Wire Wire Line
	2650 5650 2400 5650
Wire Wire Line
	2650 5550 2400 5550
Wire Wire Line
	2650 5350 2400 5350
Wire Wire Line
	2650 5450 2400 5450
Wire Wire Line
	2650 5850 2400 5850
Wire Wire Line
	4850 4200 1200 4200
Wire Wire Line
	1200 4200 1200 5150
Wire Wire Line
	1200 5150 1400 5150
Entry Wire Line
	1100 6250 1200 6150
Text GLabel 800  6250 2    35   BiDi ~ 0
a[0..15]
Entry Wire Line
	1100 6350 1200 6250
Wire Wire Line
	1400 6150 1200 6150
Wire Wire Line
	1400 6250 1200 6250
Entry Wire Line
	850  5150 950  5050
Text GLabel 550  5150 2    35   BiDi ~ 0
a[0..15]
Wire Wire Line
	950  5050 1400 5050
Wire Wire Line
	1400 4950 1400 4500
Wire Wire Line
	1400 4500 950  4500
Wire Wire Line
	950  4500 950  4600
Wire Wire Line
	3350 4300 1300 4300
Wire Wire Line
	1300 4300 1300 5250
Wire Wire Line
	1300 5250 1400 5250
Connection ~ 3350 4300
Wire Wire Line
	3350 4300 3350 5150
Text GLabel 2500 5050 2    43   Input ~ 0
CLK
Text GLabel 1350 5450 0    43   Input ~ 0
ACIA-CLK
Wire Wire Line
	1400 5450 1350 5450
Wire Wire Line
	2400 5050 2500 5050
Text GLabel 2450 4950 2    47   Input Italic 0
R~W
Wire Wire Line
	2400 4950 2450 4950
Text GLabel 2750 5150 2    43   Output ~ 0
A~IRQ
Wire Wire Line
	2400 5150 2750 5150
Text GLabel 3400 6500 0    43   Output ~ 0
V~IRQ
Wire Wire Line
	3700 6500 3400 6500
Text GLabel 1400 2100 0    43   Input ~ 0
~IRQ
Connection ~ 850  1900
NoConn ~ 1400 5350
Wire Wire Line
	2400 6050 2500 6050
Wire Wire Line
	2500 6150 2400 6150
Wire Wire Line
	2500 6050 2500 6150
Connection ~ 2500 6150
Wire Wire Line
	2500 6150 2500 6500
NoConn ~ 1400 5550
NoConn ~ 1400 5950
NoConn ~ 1400 5650
Wire Wire Line
	1400 5750 900  5750
$Sheet
S 10050 4800 1000 1600
U 61660CAC
F0 "JJ65c02_support" 47
F1 "JJ65c02_support.sch" 47
$EndSheet
Text GLabel 4700 6950 0    47   Input Italic 0
IO~CS
Wire Wire Line
	4850 6950 4700 6950
Text GLabel 6600 1400 0    47   Input Italic 0
RAM~CS
Text GLabel 8150 1350 0    47   Input Italic 0
ROM~CS
Wire Wire Line
	6800 1400 6800 2550
Wire Wire Line
	8500 2750 8500 2550
Wire Wire Line
	8500 1350 8150 1350
Wire Wire Line
	5400 3250 5400 3900
Wire Wire Line
	7200 3250 7200 3900
Connection ~ 7200 3900
Wire Wire Line
	6800 1400 6600 1400
Text GLabel 2400 950  0    50   Input ~ 0
~RES
Wire Wire Line
	2900 950  2400 950 
Connection ~ 2900 950 
Wire Wire Line
	1800 2500 850  2500
Wire Wire Line
	850  2500 850  2300
Connection ~ 850  2300
Wire Wire Line
	2900 3900 5400 3900
Wire Wire Line
	4850 6950 4850 6750
Connection ~ 4850 6750
$Comp
L Device:R R10
U 1 1 615E6635
P 1150 2300
F 0 "R10" V 1050 2300 50  0000 C CNN
F 1 "4.7K" V 1150 2300 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" H 1150 2300 50  0001 C CNN
F 3 "~" H 1150 2300 50  0001 C CNN
	1    1150 2300
	0    1    1    0   
$EndComp
Wire Wire Line
	1000 2300 850  2300
Wire Wire Line
	8800 1800 8800 1950
$Comp
L Device:R R11
U 1 1 616329C6
P 9150 1950
F 0 "R11" V 9050 1950 50  0000 C CNN
F 1 "4.7K" V 9150 1950 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" H 9150 1950 50  0001 C CNN
F 3 "~" H 9150 1950 50  0001 C CNN
	1    9150 1950
	0    1    1    0   
$EndComp
Wire Wire Line
	8800 1800 9350 1800
Wire Wire Line
	9000 1950 8900 1950
Wire Wire Line
	8900 1950 8900 2050
Wire Wire Line
	8400 2050 8900 2050
Text Notes 5300 700  0    98   ~ 0
Main Schematic
Text Label 2850 2500 0    47   ~ 0
d0
Text Label 2850 2600 0    47   ~ 0
d1
Text Label 2850 2700 0    47   ~ 0
d2
Text Label 2850 2800 0    47   ~ 0
d3
Text Label 2850 2900 0    47   ~ 0
d4
Text Label 2850 3000 0    47   ~ 0
d5
Text Label 2850 3100 0    47   ~ 0
d6
Text Label 2850 3200 0    47   ~ 0
d7
Text Label 6500 2850 0    47   ~ 0
d7
Text Label 6500 2950 0    47   ~ 0
d6
Text Label 6500 3050 0    47   ~ 0
d5
Text Label 6500 3150 0    47   ~ 0
d4
Text Label 6500 3250 0    47   ~ 0
d3
Text Label 5250 2950 0    47   ~ 0
d0
Text Label 5250 3050 0    47   ~ 0
d1
Text Label 5250 3150 0    47   ~ 0
d2
Text Label 7150 2950 0    47   ~ 0
d0
Text Label 7150 3050 0    47   ~ 0
d1
Text Label 7150 3150 0    47   ~ 0
d2
Text Label 8450 2850 0    47   ~ 0
d7
Text Label 8450 2950 0    47   ~ 0
d6
Text Label 8450 3050 0    47   ~ 0
d5
Text Label 8450 3150 0    47   ~ 0
d4
Text Label 8450 3250 0    47   ~ 0
d3
Text Label 2500 5250 0    47   ~ 0
d7
Text Label 2500 5350 0    47   ~ 0
d6
Text Label 2500 5450 0    47   ~ 0
d5
Text Label 2500 5550 0    47   ~ 0
d4
Text Label 2500 5650 0    47   ~ 0
d3
Text Label 2500 5750 0    47   ~ 0
d2
Text Label 2500 5850 0    47   ~ 0
d1
Text Label 2500 5950 0    47   ~ 0
d0
Text Label 3550 5300 0    47   ~ 0
d0
Text Label 3550 5400 0    47   ~ 0
d1
Text Label 3550 5500 0    47   ~ 0
d2
Text Label 3550 5600 0    47   ~ 0
d3
Text Label 3550 5700 0    47   ~ 0
d4
Text Label 3550 5800 0    47   ~ 0
d5
Text Label 3550 5900 0    47   ~ 0
d6
Text Label 3550 6000 0    47   ~ 0
d7
Text Label 2950 3300 2    47   ~ 0
a15
Text Label 2950 3400 2    47   ~ 0
a14
Text Label 2950 3500 2    47   ~ 0
a13
Text Label 2950 3600 2    47   ~ 0
a12
Text Label 1650 2600 0    47   ~ 0
a0
Text Label 1650 2700 0    47   ~ 0
a1
Text Label 1650 2800 0    47   ~ 0
a2
Text Label 1650 2900 0    47   ~ 0
a3
Text Label 1650 3000 0    47   ~ 0
a4
Text Label 1650 3100 0    47   ~ 0
a5
Text Label 1650 3200 0    47   ~ 0
a6
Text Label 1650 3300 0    47   ~ 0
a7
Text Label 1650 3400 0    47   ~ 0
a8
Text Label 1650 3500 0    47   ~ 0
a9
Text Label 1650 3600 0    47   ~ 0
a10
Text Label 1650 3700 0    47   ~ 0
a11
Text Label 5250 1950 0    47   ~ 0
a14
Text Label 5250 2050 0    47   ~ 0
a12
Text Label 5250 2150 0    47   ~ 0
a7
Text Label 5250 2250 0    47   ~ 0
a6
Text Label 5250 2350 0    47   ~ 0
a5
Text Label 5250 2450 0    47   ~ 0
a4
Text Label 5250 2550 0    47   ~ 0
a3
Text Label 5250 2650 0    47   ~ 0
a2
Text Label 5250 2750 0    47   ~ 0
a1
Text Label 5250 2850 0    47   ~ 0
a0
Text Label 6550 2150 0    47   ~ 0
a13
Text Label 6550 2250 0    47   ~ 0
a8
Text Label 6550 2350 0    47   ~ 0
a9
Text Label 6550 2450 0    47   ~ 0
a11
Text Label 6550 2650 0    47   ~ 0
a10
Text Label 7250 1950 0    47   ~ 0
a14
Text Label 7250 2050 0    47   ~ 0
a12
Text Label 7250 2150 0    47   ~ 0
a7
Text Label 7250 2250 0    47   ~ 0
a6
Text Label 7250 2350 0    47   ~ 0
a5
Text Label 7250 2450 0    47   ~ 0
a4
Text Label 7250 2550 0    47   ~ 0
a3
Text Label 7250 2650 0    47   ~ 0
a2
Text Label 7250 2750 0    47   ~ 0
a1
Text Label 7250 2850 0    47   ~ 0
a0
Text Label 8700 2650 0    47   ~ 0
a10
Text Label 8700 2450 0    47   ~ 0
a11
Text Label 8700 2350 0    47   ~ 0
a9
Text Label 8700 2250 0    47   ~ 0
a8
Text Label 8700 2150 0    47   ~ 0
a13
Text Label 1000 5050 0    47   ~ 0
a4
Text Label 1250 6150 0    47   ~ 0
a0
Text Label 1250 6250 0    47   ~ 0
a1
Text Label 3550 6200 0    47   ~ 0
a5
Text Label 3575 4800 0    47   ~ 0
a0
Text Label 3575 4900 0    47   ~ 0
a1
Text Label 3575 5000 0    47   ~ 0
a2
Text Label 3575 5100 0    47   ~ 0
a3
Text Label 5650 5500 0    47   ~ 0
pb0
Text Label 5650 5600 0    47   ~ 0
pb1
Text Label 5650 5700 0    47   ~ 0
pb2
Text Label 5650 5800 0    47   ~ 0
pb3
Text Label 5650 5900 0    47   ~ 0
pb4
Text Label 5650 6000 0    47   ~ 0
pb5
Text Label 5650 6100 0    47   ~ 0
pb6
Text Label 5650 6200 0    47   ~ 0
pb7
Text Label 5000 6200 0    47   ~ 0
pb7
Text Label 5000 6100 0    47   ~ 0
pb6
Text Label 5000 6000 0    47   ~ 0
pb5
Text Label 5000 5900 0    47   ~ 0
pb4
Text Label 5000 5800 0    47   ~ 0
pb3
Text Label 5000 5700 0    47   ~ 0
pb2
Text Label 5000 5600 0    47   ~ 0
pb1
Text Label 5000 5500 0    47   ~ 0
pb0
Wire Wire Line
	3700 5000 3550 5000
Wire Wire Line
	3550 4900 3700 4900
Wire Wire Line
	3700 4800 3550 4800
Wire Wire Line
	3550 6000 3700 6000
Wire Wire Line
	3550 5800 3700 5800
Wire Wire Line
	3550 5700 3700 5700
Wire Wire Line
	3550 5600 3700 5600
Wire Wire Line
	3550 5500 3700 5500
Wire Wire Line
	3550 5400 3700 5400
Wire Wire Line
	3550 5300 3700 5300
Wire Wire Line
	3550 5100 3700 5100
$Comp
L Display_Character:NHD-0420H1Z LEDDisplay1
U 1 1 61334BF5
P 6300 5600
F 0 "LEDDisplay1" H 6300 6600 50  0000 C CNN
F 1 "HD44780" H 6300 6500 50  0000 C CNN
F 2 "Display:WC1602A" H 6300 5600 50  0001 L BNN
F 3 "" H 6300 5600 50  0001 L BNN
F 4 "N/A" H 6300 5600 50  0001 L BNN "MGF#"
F 5 "5V" H 6300 5600 50  0001 L BNN "VOLTAGE"
	1    6300 5600
	1    0    0    -1  
$EndComp
Wire Wire Line
	7050 5800 7050 5900
Wire Wire Line
	6700 5800 6850 5800
Wire Wire Line
	6850 5800 6850 5900
Wire Wire Line
	6850 5900 7050 5900
Connection ~ 7050 5900
Wire Wire Line
	7050 5900 7050 5950
Wire Wire Line
	6700 5900 6700 6400
Wire Wire Line
	5900 5000 5400 5000
Wire Wire Line
	5400 5000 5400 5200
Wire Wire Line
	5500 5100 5900 5100
Wire Wire Line
	5500 5100 5500 5300
Wire Wire Line
	5900 5200 5600 5200
Wire Wire Line
	5600 5200 5600 5400
Wire Wire Line
	4950 4250 8000 4250
Wire Wire Line
	5000 4300 7950 4300
Wire Wire Line
	5050 4350 7900 4350
Wire Wire Line
	5100 4400 7850 4400
$Comp
L Device:R R12
U 1 1 615D9CDA
P 3150 2200
F 0 "R12" V 3050 2200 50  0000 C CNN
F 1 "4.7K" V 3150 2200 50  0000 C CNN
F 2 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal" H 3150 2200 50  0001 C CNN
F 3 "~" H 3150 2200 50  0001 C CNN
	1    3150 2200
	0    1    1    0   
$EndComp
Wire Wire Line
	3300 2200 3500 2200
Wire Wire Line
	3000 2200 2800 2200
Wire Wire Line
	9300 1950 9350 1950
Wire Wire Line
	9350 1950 9350 1800
Connection ~ 9350 1800
Wire Wire Line
	1300 1900 1800 1900
Wire Wire Line
	1800 2100 1400 2100
Wire Wire Line
	1300 2300 1800 2300
Wire Wire Line
	6700 6400 6800 6400
Text GLabel 850  900  1    47   Input ~ 0
+5V
Text GLabel 3500 2050 1    47   Input ~ 0
+5V
Text GLabel 9350 1500 1    47   Input ~ 0
+5V
Text GLabel 6450 1900 1    47   Input ~ 0
+5V
Text GLabel 8550 4600 1    47   Input ~ 0
+5V
Text GLabel 5900 4800 0    47   Input ~ 0
+5V
Text GLabel 6800 6400 2    47   Input ~ 0
+5V
Text GLabel 4950 6500 2    47   Input ~ 0
+5V
Text GLabel 2650 6250 2    47   Input ~ 0
+5V
Text GLabel 8550 5950 3    47   Input ~ 0
GND
Text GLabel 7050 5950 3    47   Input ~ 0
GND
Text GLabel 2500 6500 3    47   Input ~ 0
GND
Text GLabel 6300 6400 3    47   Input ~ 0
GND
Text GLabel 950  4600 3    47   Input ~ 0
GND
Text GLabel 7200 4000 3    47   Input ~ 0
GND
Text GLabel 900  5750 0    47   Input ~ 0
GND
Wire Wire Line
	2400 6250 2650 6250
Wire Wire Line
	7200 5650 7200 4800
Wire Wire Line
	7200 4800 6400 4800
Wire Wire Line
	850  1900 850  2300
Wire Wire Line
	6300 4800 5900 4800
Text GLabel 1150 5850 0    47   Output ~ 0
TxD
Text GLabel 1150 6050 0    47   Output ~ 0
RxD
Wire Wire Line
	1400 5850 1150 5850
Wire Wire Line
	1150 6050 1400 6050
Wire Wire Line
	8400 2550 8500 2550
Connection ~ 8500 2550
Wire Wire Line
	8500 2550 8500 1350
Wire Wire Line
	8550 5850 8700 5850
Wire Wire Line
	8100 5850 8400 5850
Wire Wire Line
	8100 5850 8100 5750
Wire Wire Line
	8400 5750 8400 5850
Connection ~ 8400 5850
Wire Wire Line
	8400 5850 8550 5850
Wire Wire Line
	8700 5750 8700 5850
Connection ~ 8700 5850
Wire Wire Line
	8700 5850 9000 5850
Wire Wire Line
	9000 5750 9000 5850
Wire Wire Line
	8100 5100 8100 5300
Wire Wire Line
	8400 5100 8400 5200
Wire Wire Line
	8700 5100 8700 5350
Wire Wire Line
	9000 5100 9000 5250
Wire Wire Line
	8000 4250 8000 5200
Wire Wire Line
	8000 5200 8400 5200
Connection ~ 8400 5200
Wire Wire Line
	8400 5200 8400 5450
Wire Wire Line
	7950 4300 7950 5250
Wire Wire Line
	7950 5250 9000 5250
Connection ~ 9000 5250
Wire Wire Line
	9000 5250 9000 5450
Wire Wire Line
	7900 4350 7900 5300
Wire Wire Line
	7900 5300 8100 5300
Connection ~ 8100 5300
Wire Wire Line
	8100 5300 8100 5450
Wire Wire Line
	7850 4400 7850 5350
Wire Wire Line
	7850 5350 8700 5350
Connection ~ 8700 5350
Wire Wire Line
	8700 5350 8700 5450
Text GLabel 4900 6400 2    47   Output ~ 0
SND_IN
Wire Wire Line
	4900 6400 4700 6400
Wire Bus Line
	5150 3050 5150 3250
Wire Bus Line
	3200 6350 3200 6450
Wire Wire Line
	2800 2400 3450 2400
Wire Bus Line
	850  5000 850  5250
Wire Bus Line
	3450 4700 3450 5000
Wire Bus Line
	1100 6150 1100 6400
Wire Bus Line
	8650 2950 8650 3350
Wire Bus Line
	6900 2750 6900 3150
Wire Bus Line
	8950 2050 8950 2550
Wire Bus Line
	3050 3400 3050 4100
Wire Bus Line
	3050 2400 3050 3100
Wire Bus Line
	3450 5200 3450 5900
Wire Bus Line
	5350 5600 5350 6300
Wire Bus Line
	7150 1850 7150 2750
Wire Bus Line
	5150 1850 5150 2750
Wire Bus Line
	2750 5300 2750 6100
Wire Bus Line
	1550 2700 1550 4100
$EndSCHEMATC
