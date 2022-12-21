# 2021-03-25 : remove them and mk same as einstein.
# 2021-02-04 : add nec_ve options


require 'fileutils'
require 'command_line/global'
require 'scanf'

class Vasp
  def initialize(vasp_dir, cpu_no)
    @vasp_work_dir = vasp_dir
    @cpu_no = cpu_no
    ['INCAR','KPOINTS','POTCAR'].each do |file|
      FileUtils.cp(file, @vasp_work_dir)
    end
  end
  def total_energy()
    out = Dir.chdir(@vasp_work_dir) do
#      ve_opts = Dir.exist?('/opt/nec/ve') ? '-gpath '+ENV['PATH'] : ''
#      res = command_line("mpirun #{ve_opts} -np #{@cpu_no} vasp")
      vasp = ENV['VASP']
      p com = "mpirun -np #{@cpu_no} #{vasp}"
      res = command_line com
      res.stdout
    end
    puts out
    m = []
    val = 0.0
    out.split("\n").each do |line|
      if m= line.match(/F= (.+)/)
        val = m[0].scanf("F= %f E0= %f  d E =%f")[1]
      end
    end
    p val
    return val
  end
end
