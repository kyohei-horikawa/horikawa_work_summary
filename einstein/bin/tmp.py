with open('../5x5/POSCAR_orig', 'r') as f:
    lines = f.readlines()

offset = 6
dynamics = ' '
for i, line in enumerate(lines[5:9]):
    if 'dynamics' in line:
        dynamics = ' T T T'
    if 'Direct' in line:
        offset += i

print(dynamics)
print(offset)

print(lines[offset])
