#!/usr/bin/env python3

import re
import sys
import argparse

def opcode_to_hash(op):
    if op == '???':
        return '0000000000000000'
    start = 0b00010
    hash = []
    for c in op:
        diff = ord(c) - ord('A')
        val = start + diff
        binv = bin(val)[2:].zfill(5)
        hash.append(binv)
    ret = f'{hash[0]}{hash[1]}{hash[2]}0'
    return ret

def mode_to_num(mode_str):
    if mode_str == 'IMM':
        return 1
    elif mode_str == 'ZP':
        return 2
    elif mode_str == 'AB':
        return 3
    elif mode_str == 'IMP':
        return 4
    elif mode_str == 'ACC':
        return 5
    elif mode_str == 'INX':
        return 6
    elif mode_str == 'INY':
        return 7
    elif mode_str == 'ZPX':
        return 8
    elif mode_str == 'ABX':
        return 9
    elif mode_str == 'ABY':
        return 10
    elif mode_str == 'IND':
        return 11
    elif mode_str == 'ZPY':
        return 12
    elif mode_str == 'REL':
        return 13
    elif mode_str == 'INZP':
        return 14
    else:
        return 0

def main():

    parser = argparse.ArgumentParser(description="65c02 opcode parser")
    parser.add_argument('infile', nargs='?', type=str, default='/dev/stdin')
    parser.add_argument('--outfile', type=str, default='/dev/stdout')
    args = parser.parse_intermixed_args()

    input_file = args.infile
    output_file = args.outfile

    opcodes = []
    modeindex = []
    modename = []
    ohash = []
    opnames = []

    for i in range(256):
        opcodes.append('???')
        modeindex.append(0)
        modename.append('???')
        ohash.append('0000000000000000')

    with open(input_file, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()
        if line == '' or line.startswith(';'):
            continue

        parts = re.split(r'\s+', line)
        ops = parts[0].split('_')
        if len(ops) == 1:
            ops.append('IMP')

        opcode_num = int(parts[1], 16)
        mode_num = mode_to_num(ops[1])

        opcodes[opcode_num] = ops[0]
        modename[opcode_num] = ops[1]
        modeindex[opcode_num] = mode_num
        ohash[opcode_num] = opcode_to_hash(ops[0])
        if modename[opcode_num] not in opnames:
            opnames.append(modename[opcode_num])


    with open(output_file, 'w', encoding='utf-8', errors='ignore') as f:
        f.write('65C02 Opcode List:\n')
        for i in range(0, 256):
            f.write(f'{hex(i):4}:  {opcodes[i]}:   {hex(int(ohash[i],2)):6}   {modename[i]:4}  [{hex(modeindex[i])}]\n')

        f.write('\n\nMNEML:\n')
        counter = 0
        seen = {}
        idx = 0
        comments = []
        for i in range(0, 256):
            if opcodes[i] not in seen:
                seen[opcodes[i]] = idx
                idx += 1
            else:
                continue
            if counter == 0:
                f.write('    .byte ')
                comments = []
            counter += 1
            n = hex(int(ohash[i],2))
            if n == '0x0':
                n = '00'
            else:
                n = n[2:4]
            f.write(f'${n}{' ' if counter == 8 else ','}')
            comments.append(opcodes[i])
            if counter == 8:
                f.write(f'   ; {' '.join(comments)}\n')
                counter = 0
        f.write(f'   ; {' '.join(comments)}\n')

        f.write('\n;\nMNEMR:\n')
        counter = 0
        seen = {}
        idx = 0
        comments = []
        for i in range(0, 256):
            if opcodes[i] not in seen:
                seen[opcodes[i]] = idx
                idx += 1
            else:
                continue
            if counter == 0:
                f.write('    .byte ')
                comments = []
            counter += 1
            n = hex(int(ohash[i],2))
            if n == '0x0':
                n = '00'
            else:
                n = n[4:6]
            f.write(f'${n}{' ' if counter == 8 else ','}')
            comments.append(opcodes[i])
            if counter == 8:
                f.write(f'   ; {' '.join(comments)}\n')
                counter = 0
        f.write(f'   ; {' '.join(comments)}\n')

        f.write('\n;\nIDX_NAME:\n')
        for i in range(0, 256, 16):
            f.write('    .byte ')
            for j in range(16):
                f.write(f'${hex(seen[opcodes[i+j]])[2:].zfill(2)}{'\n' if j == 15 else ','}')

        f.write('\n;\nIDX_MODE2:\n')
        for i in range(0, 256, 16):
            f.write('    .byte ')
            for j in range(16):
                f.write(f'${hex(modeindex[i+j])[2:]}{'\n' if j == 15 else ','}')

if __name__ == '__main__':
    main()
