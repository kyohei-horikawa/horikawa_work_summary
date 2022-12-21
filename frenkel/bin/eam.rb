class CartesianSystem
  attr_accessor :n_atoms
  def initialize(system)
    @system = system
    @lat_vec = @system.lat_vec
    @n_atoms = @system.n_atoms
  end
end

class EAM < CartesianSystem
  # for phi(r0)=-3.39, Ev=0.8, p=3.0 at r0, r0=2.8577
  EAM_PARAM_SETS = {
    'al2.89' => [
                 69.1378255, #A0
                 12.47431958, #B0
                 2.148157653, #P
                 2.893854749, #POQ
                 0.7423170267, #q
                 -3.39, # e0
                 2.857701344
                ],
    'al3.2' => [
                1121.65126200, #A0
                18.93477473, #B0
                3.20000000, #P
                3.60000000, #POQ
                0.88888889, #Q
                -3.73470161, #E0
                2.85790856, #R0
               ],
  }
  def initialize(system, poq='al2.89')
    super(system)
    @conf = eam_param_select(poq)
    mk_nl() if @system.atoms[0].nl == []
    # system.atoms.each{|atom| p atom}
  end

  def mk_nl
    @system.atoms[0 .. (@n_atoms - 1)].each_with_index do |iatom, i|
      @system.atoms[0 .. -1].each_with_index do |jatom, j|
        next if j <= i
        if distance(iatom.pos, jatom.pos) < @cut_off
          iatom.nl << j
          jatom.nl << i
        end
      end
    end
  end

  def distance(ipos, jpos)
    tmp = 0.0
    3.times do |i|
      x1 = ipos[i] - jpos[i]
      x = x1 - (x1/@lat_vec[i]).round * @lat_vec[i]
      tmp += x * x
    end
    Math.sqrt(tmp)
  end

  def eam_param_select(poq='al2.89')
    @a0, @b0, @p, @poq, @q, @e0, @r0 = EAM_PARAM_SETS[poq]
    @cut_off = 4.0414 * 0.82
  end

  include Math
  def atom_energy(i)
    rho = 0.0
    rep = 0.0
    ai = @system.atoms[i]
    ai.nl.each do |j|
      r = distance(ai.pos, @system.atoms[j].pos)
      rep += @a0 * exp(-@p * r)
      h = @b0 * exp(-@q * r)
      rho += h * h
    end
    bind = - sqrt(rho)
    [rep+bind, rep, bind]
  end

  def total_energy()
    sum = 0
    @n_atoms.times do |i|
      e, _r, _b = atom_energy(i)
      sum += e
    end
    sum
  end
end

