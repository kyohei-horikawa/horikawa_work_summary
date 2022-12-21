# -*- coding: utf-8 -*-
#+name: ./bin/frenkel.rb
#+begin_src ruby -n
#+version: 0.2.1 : 2021-03-25 : adjust move_scale in AA
#+version: 0.2.0 : 2021-02-04 : add nec_ve options in vasp.rb
#+version: 0.1.1 : 2021-01-06 : add DEBUG option of :pos_save_all

require_relative "./poscar"
require_relative "./eam"
require_relative "./einstein"
require_relative "./vasp"
require "colorize"
include Math
FRENKEL = { one_site_fix: false } # false for all site free, true for one site fix
DEBUG = { verbose: true, pos_save: :period_100000 } # pos_save: :p_1 for all, :p_1000000 for never

class Frenkel
  def initialize
    puts "-----------"
    puts "Frenkel simulations by VASP"
    puts "  cc by Shigeto R. Nishitani 2020-1\n"
    puts "iter[start]: []: time[#{Time.now}]: [,] "

    puts "---initial conditions--------"
    @calc_sel = ARGV[0] || "eam"
    @cpu_no = ARGV[1] || "al3.2"
    @lambda = ARGV[2] || 1.0
    @lambda = @lambda.to_f
    @n_iter = ARGV[3] || 100
    @n_iter = @n_iter.to_i
    r_seed = ARGV[4] || 1
    srand(r_seed.to_i)
    @move_scale = ARGV[5] || "1.0"
    @move_scale = @move_scale.to_f

    temp = ARGV[6] || 800 # should be K
    @kT = temp.to_f * 8.617 * 10 ** (-5)

    [["%s", ["calculation select[vasp|eam]", @calc_sel]],
     ["%s", ["cpu number or eam model", @cpu_no]],
     ["%f", ["lambda parameter", @lambda]],
     ["%d", ["iteration number", @n_iter]],
     ["%s", ["DEBUG[:verbose]", DEBUG[:verbose]]],
     ["%s", ["DEBUG[:pos_save]", DEBUG[:pos_save]]],
     ["%d", ["Temperature[deg C]", temp.to_f-273]],
     ["%d", ["Temperature    [K]", temp.to_f]],
     ["%s", ["FRENKEL[:one_site_fix]",
             FRENKEL[:one_site_fix].to_s+" # false: all site free, true: one site"]],
     ["%7.5f", ["kT", @kT]],
     ["%d", ["r_seed", r_seed]],
     ["%4.2f", ["move_scale[AA]", @move_scale]]].each do |form, output|
      puts "%30s: #{form}" % output
    end
    puts "-----------\n\n"

    @vasp_dir = "vasp_dir"
    mk_dir(@vasp_dir)

    @save_count = 0
    @save_interval = DEBUG[:pos_save].to_s.split('_')[1].to_i
  end

  def mk_dir(dir)
    vasp_work_dir = dir
    begin
      FileUtils.mkdir(vasp_work_dir)
    rescue => e
      puts e
    end
  end

  def select_init
    puts "start selection."
    pos = "./POSCAR_init"
    pos0 = "./POSCAR_init_0"
    ks = Dir.glob("*ks.dat")
    ks = ks[0] || "fcc_ks.dat"
    puts "\n\n" + "-" * 5 + "pos = #{pos} " + "-" * 5
    puts File.read(pos)
    puts "-" * 5 + "pos0= #{pos0} " + "-" * 5
    puts File.read(pos0)
    puts "\n\n" + "-" * 5 + " #{ks} " + "-" * 5
    puts File.read(ks)
    return ks, pos, pos0
  end


  def save(iter, final: false)
    if (@save_count % @save_interval == 0)  or final
      @pos.write_poscar(File.join('poscars', "POSCAR_#{iter}")) # or @vasp_dir
    end
    @save_count += 1
  end

  def pre_loop
    @ks, pos_name, pos0_name = select_init
    p [@ks, pos_name, pos0_name]
    @pos = Poscar.new(pos_name)
    @pos0 = Poscar.new(pos0_name)

    @ein = Einstein.new(@ks, @pos0)
    @e0 = @ein.init_e0 #(-3.734685519)*32
    move(0.0)
    @res0 = energy_calc("init", @lambda)
    print "iter[-1]: [accepted]: time[#{Time.now}]: "
    p @res0

    @simulation_data = [@res0]
    save("init_from_frenkel", final: true)
  end

  def mk_iatoms_random_move(i_atoms, scale)
    di0 = {}
    scale_in_lat = scale/ @pos.lat_vec[0] # convert AA to POSCAR
    # lat_vecs are already included the whole_scale_parameter
    i_atoms.each do |i_atom|
      #dx = [rand() - 0.5, rand() - 0.5, rand() - 0.5]
      # dx.map! { |val| val * scale }
      # di0[i_atom] = dx

      # below are adjusted for irregular slab
      di0[i_atom] = [0.5773502693*(rand() - 0.5)*scale_in_lat, # 1.0/sqrt(3.0)*
                     0.5773502693*(rand() - 0.5)/(@pos.lat_vec[1]/@pos.lat_vec[0])*scale_in_lat,
                     0.5773502693*(rand() - 0.5)/(@pos.lat_vec[2]/@pos.lat_vec[0])*scale_in_lat]
    end
    return di0
  end

  def select_move(scale)
    n_atoms = @pos.n_atoms #32
    iatom = 0
    @max_atom = FRENKEL[:one_site_fix] ? n_atoms - 1 : n_atoms
    i_atoms = [*(iatom..(@max_atom - 1))].sort_by { rand }[0..(@max_atom - 1)]
    p ["i_atom", i_atoms.size]
    @di0 = mk_iatoms_random_move(i_atoms, scale)
    i_atoms.each do |i_atom, i|
      3.times do |j|
        @pos.atoms[i_atom].pos[j] = @pos.atoms[i_atom].pos[j] + @di0[i_atom][j]
      end
    end
  end

  def re_move()
    i_atoms = [*(0..@max_atom - 1)]
    i_atoms.each do |i_atom|
      3.times do |j|
        @pos.atoms[i_atom].pos[j] = @pos.atoms[i_atom].pos[j] - @di0[i_atom][j]
      end
    end
  end

  def move(scale)
    select_move(scale)
    @pos.write_poscar(File.join(@vasp_dir, "POSCAR")) if @calc_sel == "vasp"
  end

  def energy_calc(iter, lambda)
    vasp = case @calc_sel
      when "eam"; EAM.new(@pos, @cpu_no)
      when "vasp"; Vasp.new(@vasp_dir, @cpu_no)
      end
    vasp_e = vasp.total_energy()
    pos_center = @ein.calc_center(@pos) unless FRENKEL[:one_site_fix]
    p ["center", pos_center] if DEBUG[:verbose]

    @ein.move_center(pos_center) unless FRENKEL[:one_site_fix]
    e_e = @ein.total_energy(@pos)
    p ["vasp_e, e_e", vasp_e, e_e] if DEBUG[:verbose]

    total0 = @lambda * vasp_e + (1.0 - @lambda) * e_e
    @ein.reset_pos()
    return [total0, vasp_e - e_e]
  end

  def main_loop
    @n_iter.times do |iter|
      move(@move_scale)
      res = energy_calc(iter, @lambda)
      de = res[0] - @res0[0]
      print "iter[#{iter}]: "
      if exp(-de / @kT) > rand()
        @simulation_data << res
        @res0 = res
        print "[accepted]: "
        save(iter)
      else
        re_move()
        print "[rejected]: "
      end
      print "time[#{Time.now}]: "
      p res
    end
  end

  def gnuplot(simulation_data)
    require "numo/gnuplot"
    x, y1, y2 = [], [], []
    simulation_data.each_with_index do |(total_e, dudl), i|
      x << i
      y1 << total_e - @e0
      y2 << dudl
    end
    Numo.gnuplot do
      set size: "0.7,0.7"
      set yrange: -3..3.5
      plot([x, y1, w: :l, title: "total energy"],
           [x, y2, w: :l, title: "du/dl"])
    end
  end

  def print_summary
    printf("\n\n frenkel results summary\n\n")
    @simulation_data.each_with_index do |(total_e, dudl), i|
      printf("%5d:  %20.15f %20.15f\n", i, total_e, dudl)
    end
    case @calc_sel
    when "eam"
      gnuplot(@simulation_data)
    when "vasp"
    end
  end
end

frenkel = Frenkel.new
frenkel.pre_loop
frenkel.main_loop
frenkel.print_summary
frenkel.save("final", final: true)
#+end_src
