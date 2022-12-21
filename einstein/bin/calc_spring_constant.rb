require 'scanf'
require 'matrix'

file = ARGV[0]

def gets_vals(line)
  data = line.split('],[')
  res = [data[0].scanf("[[%f, %f")]
  data[1..-1].each do |data|
    res <<  data.scanf("%f, %f")
  end
  res
end
def gets_data(lines)
  trans = {
    '* v' => :new_vol,
    '[[-' => :in_data,
    :default => :ignore
  }
  all_data,new_vol = [], []
  lines.each do |line|
    action = trans[line[0..2]] || trans[:default]
    case action
    when :ignore
    when :new_vol
      all_data << new_vol
      new_vol = [line.scanf("* volume =%f")[0]]
    when :in_data
      new_vol <<  gets_vals(line)
    end
  end
  p all_data << new_vol
  all_data.delete_at(0)
  return all_data
end

def fitting(xy_data)
  x0,y0 = [],[]
  xy_data.each do |x, y|
    x0 << x
    y0 << y
  end

  # make design matrix
  n, m = 3, x0.size
  av = Matrix.zero(m, n)
  yy = Vector.zero(m)
  n.times do |i|
    m.times do |j|
      av[j,i]=x0[j]**i
      yy[j] = y0[j]
    end
  end

  # calc inverse for non-square matrix
  ai = (av.transpose * av).inv
  b = av.transpose * yy
  return ai * b
end

def calc_spring_constants(data)
  res = []
  data.each do |data|
    vol = (data[0]-1)*100
    vals = fitting(data[1]).to_a
    res << [vol, vals[0]/256*32, vals[1], vals[2]]
  end
  res
end

def put_ks(ks)
  ks.each do |data|
    puts "[%f, %f, %f, %f] " % data.flatten
  end
end
lines = File.readlines(file)
p data = gets_data(lines)
ks = calc_spring_constants(data)
put_ks(ks)
