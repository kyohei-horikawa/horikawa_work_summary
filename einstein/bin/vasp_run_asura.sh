#!/bin/sh
#$ -cwd
#$ -V -S /bin/bash
#$ -q all.q@asura2
#$ -pe smp 48
#$ -N r3x3_v10

# asura2  Xeon Gold 6248R, 3.00GHz, 48 cores(24x2), 192GB, CentOS 7.8
# asura3  Xeon Gold 6240 , 2.60GHz, 36 cores(18x2), 192GB, CentOS 7.7
# asura4  Xeon Gold 6248R, 3.00GHz, 48 cores(24x2), 192GB, CentOS 7.8
# asura5  Xeon Gold 6130,  2.10GHz, 32 cores(16x2), 192GB, CentOS 6.9
# asura6  Xeon E5-2680v2,  2.80GHz, 20 cores(10x2),  64GB, CentOS 6.5
# asura7  Xeon E5-2680v3,  2.50GHz, 24 cores(12x2), 128GB, CentOS 6.5
# asura8  Xeon E5-1660v3,  3.00GHz,  8 cores( 8x1),  64GB, CentOS 6.5


export VASP=/usr/local/vasp/vasp.5.4.4.pl2_CentOS7_oneAPI/bin/vasp

ruby ../bin/einstein_calc.rb '0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39' ''  ${NSLOTS}
#mpirun -np ${NSLOTS} ${VASP}
