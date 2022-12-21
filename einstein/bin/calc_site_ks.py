import sys
import re
import numpy as np

PHRASE = r'^\* fix calc kpoints:50, site:(\d+), xyz_idx:(\d), dev:(.+)'


def calc_ks(data, file):
    results = read_results(data)
    all_data = prepare_fitting_data(results)
    title = file.split('.')[0]
    output_fitted_spring_constants(all_data, title)


def read_results(lines):
    flag = False
    results = []
    for line in lines:
        if not flag:
            res = re.match(PHRASE, line)
            if res:
                head = res.groups()[0] + '_' + res.groups()[1]
                flag = True
        else:
            res = re.findall(r'E0', line)
            if res:
                val = re.findall(r'(-\.\d*E\+\d+)', line)[0]
                results.append([head, float(val)])
                flag = False
            res = re.findall(r'EDDAV', line)
            if res:
                val = 0.0
                results.appned([head, val])
                flag = False

    return results


def prepare_fitting_data(results):
    e0 = results[0][1]
    all_data, data = [], []
    for i, res in enumerate(results[1:]):
        data.append(res[1])
        if (i - 3) % 4 == 0:
            all_data.append([data[0], data[1], e0, data[2], data[3], res[0]])
            # print([data[0], data[1], e0, data[2], data[3], res[0]])
            # (-0.4, -0.2, 0, 0.2, 0.4, site_xyz)
            data = []
    return all_data


def output_fitted_spring_constants(all_data, title):
    sum, vals = 0.0, []
    # n_atom = len(all_data) / 3
    conts = f'{title}=[\n'
    for i, data in enumerate(all_data):
        val = fitting(data)
        # print(val)
        sum += val[0]
        vals.append(val[2])
        if (i + 1) % 3 == 0:
            num = data[-1].split('_')[0]
            conts += (f"[{num}, n_atom, {sum/3.0:10.5f}, {vals[0]:10.5f}, {vals[1]:10.5f}, {vals[2]:10.5f}],\n")
            sum = 0.0
            vals = []
    conts += ']'
    print(conts)


def fitting(y):
    x = [-20 / 100.0, -10 / 100.0, 0, 10 / 100.0, 20 / 100.0]

    n = 3
    m = len(x)

    av = np.zeros((m, n))
    yy = np.zeros(m)
    for i in range(n):
        for j in range(m):
            av[j, i] = x[j]**i
            yy[j] = y[j]
    # print(np.dot(av.transpose(), av))
    ai = np.linalg.inv(np.dot(av.transpose(), av))
    # print(ai)
    b = np.dot(av.transpose(), yy)
    return np.dot(ai, b)


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


if __name__ == '__main__':
    main()
