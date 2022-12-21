#+begin_src ruby -n

require 'command_line/global'
require 'scanf'
require 'date'

class ModPoscar
  def initialize(vol, site=0, idx=0, dev=0.0)
    @lines = File.readlines('POSCAR_orig')
    @offset = 6
    @dynamics = ' '
    @lines[5..9].each_with_index do |line, i|
      @dynamics = ' T T T' if line.include?('dynamics')
      @offset += i if line.include?('Direct')
    end
#    @offset = @lines[7].include?('Direct') ? 8 : 9
#    p @offset
    volume(vol)
    mod_site(site,idx,dev)
    File.write('POSCAR', @lines.join)
  end

  def mod_site(site, idx, dev)
    puts "* fix calc kpoints:50, site:#{site}, xyz_idx:#{idx}, dev:#{dev}"
    puts "** start: #{DateTime.now}"
    p r_dev = calc_dev(idx, dev)
    p xyz = @lines[site+@offset].scanf("%f %f %f")
    p idx
    xyz[idx] =xyz[idx]+r_dev
    xyz << @dynamics
    @lines[site+@offset] = sprintf("%20.15f %20.15f %20.15f %s\n", *xyz)
  end

  def volume(vol)
    whole = @lines[1].scanf("%f")[0]
    @lines[1] = sprintf("%20.15f\n", whole*vol.to_f)
  end

  def calc_dev(idx, dev)
    whole = @lines[1].scanf("%f")[0]
    l_xyz = @lines[idx+2].scanf("%f %f %f")[idx]
    return dev/l_xyz/whole
  end
end

class VaspSubmit
  def initialize(dir)
    system "cp POSCAR_full_relaxed POSCAR_orig"
    system "mkdir #{dir}"
    system "cp vasp_templates/* #{dir}"
    system "cp POSCAR_orig #{dir}/POSCAR_orig"
  end

  def submit_vasp(k_point, relax, cpu)
    system "cp -f KPOINTS_#{k_point} KPOINTS"
    system "cp INCAR_#{relax} INCAR"
    vasp = ENV['VASP']
    p com = "mpirun -np #{cpu} #{vasp}"
    res = command_line com
    puts res.stdout
  end
end

sites = ARGV[0] || '0' # '0_0 0_1 0_2'
p sites
direction = sites.split(/\s+/)[0].split('_')
if direction[1]
  sites = [direction[0].to_i]
  xyz_dir = [direction[1].to_i]
  devs = ARGV[1]
  devs = devs == '' ? [-0.2, -0.1, 0.1, 0.2] : devs.split(/\s+/).map(&:to_f)
  cpu = ARGV[2] || 48
else
  sites = sites.split(/\s+/).map(&:to_i)
  xyz_dir = [0, 1, 2]
  devs = [-0.2, -0.1, 0.1, 0.2] # 4
  cpu = ARGV[2] || 48
end


vols = ARGV[3] || '1.00'
vols = vols.split(/\s+/).map(&:to_f)
p ['vols', vols]

p ['devs', devs]
p ['sites', sites]
p ['xyz_dir', xyz_dir]
p ['cpu', cpu]

vasp = VaspSubmit.new('vasp_dir')
Dir.chdir('vasp_dir') do
  vols.each do |vol| # vols, 5
    puts "* volume= %5.3f" % vol
    if devs.size>2 # specific direction and deviation only
      ModPoscar.new(vol)
      vasp.submit_vasp('50', 'fix', cpu)
    end
    sites.each do |site| # sites, 40
      xyz_dir.each do |direction| # xyz 3
        devs.each do |dev| # 4 devs
          ModPoscar.new(vol, site, direction, dev)
          vasp.submit_vasp('50', 'fix', cpu)
        end
      end
    end
  end
end


#+end_src
