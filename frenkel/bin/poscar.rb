require 'scanf'
class Atom
  attr_accessor :pos, :pos0, :nl, :ks, :e0
  def initialize(pos = [0.0, 0.0, 0.0])
    @pos = Vector[0.0,0.0,0.0]
    @pos0 = Vector[0.0,0.0,0.0]
    3.times{|i| @pos[i] = pos[i]}
    3.times{|i| @pos0[i] = pos[i]}
    @nl = []
    @ks = [0.0,0.0,0.0]
    @e0 = 0.0
  end
end

class Poscar
  attr_accessor :la, :ions, :element, :title, :atoms, :n_atoms, :lat_vec
  def initialize(file)
    @la, @ions = read_poscar(file)
    @lat_vec = [@la[0][0],@la[1][1],@la[2][2]]
    mk_atoms
  end
  def report(opts)
    case opts[:key]
    when :pos_comp
      @atoms.each do |atom|
        printf("%10.5f %10.5f %10.5f -", *atom.pos0)
        printf("%10.5f %10.5f %10.5f\n", *atom.pos)
      end
    end
  end
  def read_poscar(file)
    lines = File.readlines(file)
    nums = lines[6].scanf("%d %d %d")
    nums = lines[5].scanf("%d %d %d") if nums.size == 0
    @element = lines[7]
    atom = nums.inject(0){|s, i| s+=i }
    la = Array.new(3){Vector[0.0,0.0,0.0]}
    ions = Array.new(atom){Vector[0.0,0.0,0.0]}
    section = []
    index = 0
    lines.each_with_index do |line, i|
      @title = line.chomp if i==0
      if i== 1
        @whole_scale = line.chomp.to_f
        section.push 'la'
        next
      end
      if i==5
        section.pop
        next
      end

      case line
      when /^[D|d]irect/
        section.push 'ions'
        index = 0
        next
      when /^\s*\n/
        p [i,line] if DEBUG[:verbose]
        break
      end

      case section
      when ["la"]
        line.split(' ').each_with_index{|ele, i| la[index][i] = ele.to_f*@whole_scale }
        index += 1
      when ['ions']
        line.split(' ')[0..2].each_with_index{|ele, i| ions[index][i] = ele.to_f}
        index += 1
      else
      end
    end
    return la, ions
  end
  def expand_la(i, j, k)
    @la[0]*i + @la[1]*j + @la[2]*k
  end
  def expand(nx, ny, nz)
    @la[0][0] = @la[0][0]*nx
    @la[1][1] = @la[1][1]*ny
    @la[2][2] = @la[2][2]*nz
    new_ions = []
    nx.times do |i|
      ny.times do |j|
        nz.times do |k|
          ions.each do |ion|
            new_ion = DFloat::zeros(3)
            new_ion[0] = (i+ion[0])/nx
            new_ion[1] = (j+ion[1])/ny
            new_ion[2] = (k+ion[2])/nz
            new_ions << new_ion
          end
        end
      end
    end
    @ions = new_ions
  end
  def mk_atoms
    @n_atoms = @ions.size
    @atoms = []
    @ions.each do |ion|
      tmp = Vector[0.0,0.0,0.0]
      3.times{|i| tmp[i] = ion[i]*@la[i][i] }
      @atoms << Atom.new(tmp)
    end
  end
  def write_poscar(file, message = "poscar")
    cont = message+"\n"
    cont << "#{@whole_scale}\n"
    @la.each do |l|
      cont << sprintf("%15.10f %15.10f %15.10f\n",
                      l[0]/@whole_scale,l[1]/@whole_scale,l[2]/@whole_scale)
    end
    cont << "#{ions.size}\n"
    cont << "Selective dynamics\nDirect\n"
    @atoms.each do |ion|
      cont << sprintf("%15.10f %15.10f %15.10f T T T\n",
                      ion.pos[0]/@la[0][0],
                      ion.pos[1]/@la[1][1],
                      ion.pos[2]/@la[2][2])
    end
    File.write(file, cont)
  end
end

