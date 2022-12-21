import re
import os
import sys
import subprocess
import datetime


class ModPoscar:
    def __init__(self, vol, site=0, idx=0, dev=0):
        with open('POSCAR_orig') as f:
            self.lines = f.readlines()
        self.offset = 6
        self.dynamics = ' '
        for i, line in enumerate(self.lines[5:9]):
            if 'dynamics' in line:
                self.dynamics = ' T T T'
            if 'Direct' in line:
                self.offset += i
        self.volume(vol)
        self.mod_site(site, idx, dev)
        with open('POSCAR', 'w')as f:
            f.writelines(self.lines)

    def mod_site(self, site, idx, dev):
        print(f'* fix calc kpoints:50, site:{site}, xyz_idx:{idx}, dev:{dev}')
        print(f'** start {datetime.datetime.now()}')
        r_dev = self.calc_dev(idx, dev)
        print(r_dev)
        xyz = re.findall(r'(\d\.\d*)', self.lines[site + self.offset])
        print(xyz)
        print(idx)
        xyz[idx] = float(xyz[idx]) + r_dev
        xyz[idx] = str(xyz[idx]) + self.dynamics
        self.lines[site + self.offset] = f'{float(xyz[0]):.15f} {float(xyz[1]):.15f} {float(xyz[2]):.15f}\n'

    def volume(self, vol):
        whole = re.findall(r'(\d\.\d*)', self.lines[1])[0]
        self.lines[1] = f'{float(whole)*float(vol):.15f}\n'

    def calc_dev(self, idx, dev):
        whole = re.findall(r'(\d\.\d*)', self.lines[1])[0]
        l_xyz = re.findall(r'(\d\.\d*)', self.lines[idx + 2])[idx]
        return float(dev) / float(l_xyz) / float(whole)


class VaspSubmit:
    def __init__(self, dir):
        subprocess.run(['cp', 'POSCAR_full_relaxed', 'POSCAR_orig'])
        subprocess.run(['mkdir', dir])
        subprocess.run(f'cp vasp_templates/* {dir}', shell=True)
        subprocess.run(['cp', 'POSCAR_orig', f'{dir}/POSCAR_orig'])

    def submit_vasp(self, k_point, relax, cpu):
        subprocess.run(['cp', '-f', f'KPOINTS_{k_point}', 'KPOINTS'])
        subprocess.run(['cp', f'INCAR_{relax}', 'INCAR'])
        vasp = os.environ['VASP']
        com = ['mpirun', '-np', cpu, vasp]
        print(' '.join(com))
        res = subprocess.run(com, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        print(res.stdout.decode('utf8'))


def main():
    sites = sys.argv[1]
    print(sites)
    direction = re.split(r'\s+', sites)[0].split('_')

    if len(direction) == 2:
        sites = [int(direction[0])]
        xyz_dir = [int(direction[1])]
        devs = sys.argv[2]
        devs = [-0.2, -0.1, 0.1, 0.2] if devs == '' else list(map(float, re.split(r'\s+', devs)))
        cpu = sys.argv[3]
    else:
        sites = list(map(int, re.split(r'\s+', sites)))
        xyz_dir = [0, 1, 2]
        devs = [-0.2, -0.1, 0.1, 0.2]
        cpu = sys.argv[3]

    vols = sys.argv[4]
    vols = list(map(float, re.split(r'\s+', vols)))

    print(['vols', vols])
    print(['sites', sites])
    print(['xyz_dir', xyz_dir])
    print(['devs', devs])
    print(['cpu', cpu])

    vasp = VaspSubmit('vasp_dir')
    os.chdir('vasp_dir')
    for vol in vols:
        print(f'* volume= {vol:5.3f}')
        if len(devs) > 2:
            ModPoscar(vol)
            vasp.submit_vasp('50', 'fix', cpu)

        for site in sites:
            for direction in xyz_dir:
                for dev in devs:
                    ModPoscar(vol, site, direction, dev)
                    vasp.submit_vasp('50', 'fix', cpu)


if __name__ == '__main__':
    main()
