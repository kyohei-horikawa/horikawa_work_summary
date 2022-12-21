require_relative './eam'
require 'matrix'

class Vector
  def pp
    cont = ''
    self.each{|v| cont << format("%10.5f ", v)}
    cont <<  "\n"
  end
end

class Einstein < CartesianSystem
  attr_reader :init_e0
  def initialize(k_s, pos0)
    @system0 = pos0
    @n_atoms = @system0.n_atoms
    @init_e0 = load_e0_ks(k_s)
    @p_center = Vector[0.0,0.0,0.0]
    @p_center = calc_center(@system0)
  end
  def load_e0_ks(k_s)
    p k_s
    lines=File.readlines(k_s)
    sum = 0.0
    lines.each_with_index do |line, i|
      e0,x,y,z=line.scanf("%f, %f, %f, %f")
      @system0.atoms[i].e0 =e0
      sum += e0
      @system0.atoms[i].ks = [x,y,z]
    end
    return sum
  end
  include Math
  def atom_energy(ai,i)
    ai0 = @system0.atoms[i]
    e = ai0.e0
    3.times do |i|
      dx = ai.pos[i] - ai0.pos[i]
      e += ai0.ks[i]*dx*dx
    end
    e
  end
  def total_energy(target_system)
    sum = 0
    @n_atoms.times do |i|
      e = atom_energy(target_system.atoms[i],i)
      sum += e
    end
    sum
  end
  def calc_center(target_system)
    sum = Vector[0,0,0]
    target_system.atoms.each do |atom|
      sum += Vector[*atom.pos.to_a]
    end
    return sum/@n_atoms.to_f
  end
  def move_center(center)
    p ['pos center in move_center    ', center.pp] if DEBUG[:verbose]
    p ['pos0 @p_center in move_center',@p_center.pp] if DEBUG[:verbose]
    diff = @p_center - center
    @system0.atoms.each {|atom| atom.pos -= diff }
  end
  def reset_pos
    @system0.atoms.each do |atom|
      3.times{|i| atom.pos[i] = atom.pos0[i]}
    end
  end
end
