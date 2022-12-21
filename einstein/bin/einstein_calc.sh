#+begin_src bash
#!/bin/sh
#$ -cwd
#$ -V -S /bin/bash
#$ -q all.q@asura3
#$ -pe smp 36
#$ -N twist

export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/libgmp

ruby einstein_calc.rb '0' 48

#+end_src
