# はじめに

/Users/kyohei/MyGradResearch/horikawa_work/einstein/bin/calc_site_ks.rbを理解するために，pythonに書き換える．
そのメモをここに残す．

# プログラム構成


自分がpythonを書いた順にメモを残していく．

# main


```python
def main():
    file = sys.argv[1]
    with open(file, 'r') as f:
        lines = f.readlines()
    res = re.match(r'\* volume=(.+)', lines[6])
    print(res)
    data = []

    for line in lines[7:-1]:
        res = re.match(r'\* volume=(.+)', line)
        if res:
            print('# for multiple volume calcs\n')
            print(f'# data_source: {file}\n')
            print(res)
            calc_ks(data, file)
            data = []
        else:
            data.append(line)

    print('# for multiple volume calcs\n')
    print(f'# data_source: {file}\n')
    calc_ks(data, file)
```

- main関数では，引数からばね定数を計算したいファイルを読み込み，
- 正規表現を用いて，```r'\* volume=(.+)'```というキーワードを探す．
- 次にそのキーワードが出てくるまで，lineを```data```に格納しておく．
- キーワードが出てきたら，lineを格納した```data```をcalc_ks関数に渡す．
