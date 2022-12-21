# +name: ./bin/calc_site_ks.rb
#+begin_src ruby
# +begin_src ruby:./bin/calc_site_ks.rb -n
require 'scanf'
require 'matrix'

PHRASE = '^\* fix calc kpoints:50, site:(\d+), xyz_idx:(\d), dev:(.+)'
KEY_PHRASE = Regexp.new PHRASE

def read_results(lines)
  state = 'out'
  m, results, head = [], [], ''
  lines.each do |line|
    case state
    when 'out'
      if m = line.match(KEY_PHRASE)
        head = m[1] + '_' + m[2]
        state = 'in'
      end
    when 'in'
      if line.match(/E0/)
        val = line.scanf('%d F= %f')[1]
        results << [head, val]
        state = 'out'
      end
      if line.match(/EDDDAV/)
        val = 0.0
        results << [head, val]
        state = 'out'
      end
    end
  end
  return results
end

def prepare_fitting_data(results, ad_opts = {})
  opts = { print: false, sites: [] }
  opts = opts.merge(ad_opts) # avoid using reverse_merge in active support
  e0 = results[0][1]
  data_all, data = [], []
  num = 1
  results[1..-1].each_with_index do |res, i|
    data << res[1]
    if (i - 3) % 4 == 0
      if opts[:print]
        if opts[:sites].include?(res[0]) or opts[:sites][0] == 'all'
          print "d[%d] := [%10.5f, %10.5f, %10.5f, %10.5f, %10.5f]: # %s\n" %
                  [num, data[0], data[1], e0, data[2], data[3], res[0]]
        end
      end
      data_all << [data[0], data[1], e0, data[2], data[3], res[0]]
      data = []
      num += 1
    end
  end
  return data_all
end

def fitting(d_y)
  x = [-20 / 100.0, -10 / 100.0, 0, 10 / 100.0, 20 / 100.0]
  y = d_y

  # make design matrix
  n, m = 3, x.size
  av = Matrix.zero(m, n)
  yy = Vector.zero(m)
  n.times do |i|
    m.times do |j|
      av[j, i] = x[j] ** i
      yy[j] = y[j]
    end
  end

  # calc inverse for non-square matrix
  ai = (av.transpose * av).inv
  b = av.transpose * yy
  return ai * b
end

def output_fitted_spring_constants(data_all, title = 'vol_0', ad_opts = {})
  opts = { maple: false }
  opts = opts.merge(ad_opts) # avoid using reverse_merge in active support
  sum, vals = 0.0, []
  if opts[:maple]
    printf("# [%2s, %10s, %10s, %10s, %10s],\n", 'no', 'E_0', 'k_x', 'k_y', 'k_z')
    conts = title + ":=[\n"
  else
    conts = ''
  end

  num_atom = data_all.length / 3
  data_all.each_with_index do |data, i|
    val = fitting(data)
    sum += val[0]
    vals << val[2]
    if (i + 1) % 3 == 0
      num = data[-1].split('_')[0]
      if opts[:maple]
        conts << sprintf("[%2d, %s, %10.5f, %10.5f, %10.5f, %10.5f],\n",
                         num.to_i, 'n_atom', sum / 3.0, *vals)
      else
        conts << sprintf("%10.5f, %10.5f, %10.5f, %10.5f,\n",
                         sum / 3.0 / num_atom, *vals)
      end
      sum, vals = 0.0, []
    end
  end
  conts[-3..-1] = "]]:\n" if opts[:maple]
  return conts
end

def mk_header
  puts 'layer:=1;'
  puts 'equi_n:=[1' + ',1' * 3 + ']; # put equivalent number for each site'
  puts 'n_equi:=nops(equi_n);'
  puts 'n_atom:= 40 * layer; # put POSCAR n_atom'
  puts 'ss0:=(4.0414*1.5811388301)^2; # put lx*ly in POSCAR of vol_100'
end

def calc_ks_from_one_file(lines, file = '', opts = { print: false })
  results = read_results(lines)
  title = File.basename(file, '.*')
  data_all = prepare_fitting_data(results, opts) #, print: true, sites: ['0_2', '19_2'])
  puts output_fitted_spring_constants(data_all, title, maple: true)
end

if ARGV[0] == '-v'
  opts = { print: true, sites: ['all'] }
  ARGV.shift
  files = ARGV
else
  opts = { print: false }
  files = ARGV
end

lines = File.readlines(files[0])
if ARGV.size == 1 and lines[1].include?('vols')
  one_volume = []
  p lines[6].match(/^* volume=(.+)/)
  lines[7..-1].each do |line|
    if m = line.match(/^* volume=(.+)/)
      puts '# for multiple volume calcs'
      print "\n# data_source: #{files}\n"
      calc_ks_from_one_file(one_volume, files[0], opts)
      one_volume = []
      p m
    else
      one_volume << line
    end
  end
  puts '# for multiple volume calcs'
  print "\n# data_source: #{files}\n"
  calc_ks_from_one_file(one_volume, files[0], opts)
else
  # for multiple files calcs
  files.each do |file|
    print "\n# data_source: #{file}\n"
    lines = File.readlines(file)
    calc_ks_from_one_file(lines, file, opts)
  end
end
#+end_src
