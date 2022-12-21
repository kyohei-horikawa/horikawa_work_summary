@@@
title=einsteinのpythonへの書き換え
private=true
tags=物理，einstein
tweet=false
id=5f402778c914af71e24c
@@@

/Users/kyohei/MyGradResearch/horikawa_work/einstein/bin/einstein_calc.py


# プログラムの構成

```
class ModPoscar
ポスカーを変更する

class VaspSubmit
vaspにjobを投げる

def main
上記クラスを使用する．

```

```
python ../bin/einstein_calc.py '6 1 9 33 26 4 2 36 3 49 0 28 25' '' ${NSLOTS} '0.96 0.98 1 1.02 1.04'
```

というふうにシェルスクリプトから呼び出す．

pythonでは，引数には，プログラムのファイル名から始まるので，

```
['../bin/einstein_calc.py', '6 1 9 33 26 4 2 36 3 49 0 28 25', '', ${NSLOTS}, '0.96 0.98 1 1.02 1.04']
```

のように配列に格納される．

故に，

- sys.argv[1]には，原子番号,
- sys.argv[2]には，deviation,
- sys.argv[3]には，cpu数,
- sys.argv[4]には，計算するvolume,
が入る．

# class ModPoscar

## __init__
```python
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
```

- poscar_origの中身を，linesに入れる．
- offset=6,dynamics=' 'とする．


```
❯❯❯ head ../5x5/POSCAR_orig                                                                                                                          (base)
n_sigma=   5, theta=  0.1974, angle= 11.
   4.04140000000000
     2.5503321132000001    0.0000000000000000    0.0000000000000000
     0.0000000000000000    2.5503321132000001    0.0000000000000000
     0.0000000000000000    0.0000000000000000    4.1356034498999996
   Al
   104
Direct
  0.0000000000000000  0.0000000000000000  0.9968443471426198
  0.1639555382115034  0.2316767551741705  0.0076740347486322
```

- poscar_origの先頭は，上記のようになっており，```self.lines[5:9]```には，5-8行目の```['   Al\n', '   104\n', 'Direct\n', '  0.0000000000000000  0.0000000000000000  0.9968443471426198\n']```が入る．
- これらの要素の中に，```dynamics```,```Direct```の記述があれば，dynamics,offsetを変更する．
- 後述するvolume関数を呼び出し，lines[1]を変更．
- 後述するmod_site関数を呼び出す．
- 最後にPOSCARとして保存する．

lines[offset]は原子位置の情報がはじまるところを示す．

## mod_site
```python
def mod_site(self, site, idx, dev):
    print(f'* fix calc kpoints:50, site:{site}, xyz_idx:{idx}, dev:{dev}')
    print(f'** start {datetime.datetime.now()}')
    r_dev = self.calc_dev(idx, dev)
    print(r_dev)
    xyz = re.findall(r'(\d\.\d*)', self.lines[site + self.offset])
    xyz[idx] = xyz[idx] + r_dev
    xyz[idx] += self.dynamics
    self.lines[site + self.offset] = f'{xyz[0]:.15f} {xyz[1]:.15f} {xyz[2]:.15f}\n'
```

- 初めに計算の情報や，日時をprintする．
- 原子をどれだけずらすかのdeviationを計算する．(後述)
- xyzには，正規表現を用いて，```['0.0000000000000000',  '0.0000000000000000',  '0.9968443471426198']```のように，原子のx,y,z座標をそれぞれ格納する．
- indexに基づいて，deviaton分,座標をずらす．(index=0ならx座標，index=1ならy座標，index=2ならz座標)
- dynamicsの記述を追加する．
- 上記情報に基づいて，原子位置を更新する．

## volume
```python
def volume(self, vol):
    whole = re.findall(r'(\d\.\d*)', self.lines[1])[0]
    self.lines[1] = f'{whole*float(vol):.15f}\n'
```

- linesの２行目のwhole_scaleを読み取る．re.findallは配列を返すので，[0]をつけることを忘れない．
- それにvolumeを掛けて，更新する．

## calc_dev
```python
def calc_dev(self, idx, dev):
    whole = re.findall(r'(\d\.\d*)', self.lines[1])[0]
    l_xyz = re.findall(r'(\d\.\d*)', self.lines[idx + 2])[idx]
    return float(dev) / float(l_xyz) / float(whole)
```

- linesの２行目のwhole_scaleを読み取る．re.findallは配列を返すので，[0]をつけることを忘れない．
- indexに基づいて，格子定数を読み取る．
- dev/l_xyz/wholeを計算しreturnする．これが原子をずらすdeviationとなる．

# class VaspSubmit

## __init__
```python
def __init__(self, dir):
    subprocess.run(['cp', 'POSCAR_full_relaxed', 'POSCAR_orig'])
    subprocess.run(['mkdir', dir])
    subprocess.run(f'cp vasp_templates/* {dir}', shell=True)
    subprocess.run(['cp', 'POSCAR_orig', f'{dir}/POSCAR_orig'])
```

- ```poscar_full_relaxed```を```poscar_orig```にリネーム．
- dirを作る．
- vasp_templatesの中身を全て，dirの中にコピー．(*を使うときは，shell=Trueを記述)
- poscar_origもdirへコピー．

vaspのための準備をする．

## submit_vasp
```python
def submit_vasp(k_point, relax, cpu):
    subprocess.run(['cp', '-f', f'KPOINTS_{k_point}', 'KPOINTS'])
    subprocess.run(['cp', f'INCAR_{relax}', 'INCAR'])
    vasp = os.environ['VASP']
    res = subprocess.run(['mpirun', '-np', cpu, vasp], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    print(res.stdout.decode('utf8'))
```

# def main
```python
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

    print('vols', vols)
    print('devs', devs)
    print('sites', sites)
    print('xyz_dir', xyz_dir)
    print('cpu', cpu)

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
```

- 引数から計算する原子番号を取り，print．

