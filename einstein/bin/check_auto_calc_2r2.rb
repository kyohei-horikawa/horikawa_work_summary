#+begin_src ruby
require 'scanf'
require 'matrix'

class ReadData
  attr_reader :all_data
  TRANS = {
    '* volu' => :new_vol,
    '* volu' => :new_vol,
    '* fix ' => :in_data,
    '   1 F' => :match_data,
    :default => :ignore
  }
  def initialize(file)
    read(file)
    puts_raw
  end
  def read(file)
    @all_data = []
    new_vol , data = [], []
    File.readlines(file).each do |line|
      action = TRANS[line[0..5]] || TRANS[:default]
      case action
      when :ignore
      when :new_vol
        @all_data << new_vol
        new_vol = [line.scanf("* volume=%f")[0]]
      when :in_data
        data = [line.scanf("* fix calc kpoints:%d, site:%f, xyz_idx:%f, dev:%f")[-1]]
      when :match_data
        data << line.scanf("1 F= %f E0= %f  d E =%f")[0]
        new_vol << data.flatten
      end
    end
    @all_data << new_vol
    @all_data.delete_at(0)
  end
  def puts_raw
    @all_data.each do |data|
      puts "* volume = %f" % data[0]
      zero = data[1]
      output='['
      data[2..-1].each_with_index do |i_data, i|
        output << sprintf("[%5.3f, %10.5f],", *i_data)
        case i%4
        when 1
          output << sprintf("[%5.3f, %10.5f],", *zero)
        when 3
          print output[0..-2]+"]\n"
          output = '['
        end
      end
    end
  end
end
class CalcSpringConstant
  def initialize(data)
    @all_data = data
    calc_spring_constants
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
    begin
      ai = (av.transpose * av).inv
      b = av.transpose * yy
    rescue
      puts "not regular matrix"
      return [0,0,0]
    else
      return ai * b
    end
  end
  def calc_spring_constants
    @ks = @all_data.collect do |data|
      p vol = (data[0]-1)*100
      vals = fitting(data[1..-1]).to_a
      [vol, vals[0]/$n_atom*32, vals[1], vals[2]]
    end
  end
  def puts_ks
    @ks.each{|data| puts "[%f, %f, %f, %f], " % data.flatten}
  end
end

$n_atom = File.readlines('POSCAR_full_relaxed')[5].to_i

files = ARGV[0] || "./*.o*"
data = Dir.glob(files).collect do |file|
  p file
  ReadData.new(file).all_data
end
p data.flatten(1)
CalcSpringConstant.new(data.flatten(1)).puts_ks
#+end_src
