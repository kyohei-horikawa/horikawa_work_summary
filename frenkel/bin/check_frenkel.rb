require 'scanf'
file = ARGV[0] || "frenkel_p_32.o22824"

TRANS = {
  'iter[' => :match_data,
  :default => :ignore
}

action = :ignore
all_data = []
File.readlines(file).each do |line|
  action = TRANS[line[0..4]] || TRANS[:default]
  case action
  when :ignore
  when :match_data
    split_line = line.chomp.split(':')
    if split_line[1].include?('accepted')
      iter = split_line[0].scanf("iter[%d]:")[0]
      energies = split_line[-1].scanf(" [%f, %f]")
      all_data << [iter, energies].flatten
    end
  end
end

e_init = (ARGV[1] || all_data[0][1]).to_f

sum0, sum1, num = 0.0, 0.0, 0
sum_start_step = (all_data.size*2.0/3.0).to_i
all_data.each_with_index do |data, i|
  data[1] -= e_init
  puts "%4d %15.10f %15.10f" % [i,data[1..2]].flatten
  if i > sum_start_step
    sum0 += data[1]
    sum1 += data[2]
    num += 1
  end
end

STDERR.puts "\nUsage: ruby check_frenkel.rb frenkel.o* -148.00 > test.dat"
STDERR.puts "gnuplot"
STDERR.puts "plot \"test.dat\" using 1:2, \"test.dat\" using 1:3 with lines"
STDERR.puts "or gnuplot ../bin/frenkel_gnuplot.gp"
STDERR.puts "\nResults source file : %s" % file
STDERR.puts "average init: %5d" % sum_start_step
STDERR.puts "average size: %4d" % num
STDERR.puts "Total energy: %10.5f" % (sum0/num)
STDERR.puts " dudl energy: %10.5f" % (sum1/num)
STDERR.puts "          E0: %10.5f" % e_init
STDERR.puts "%7.3f/%7.3f" % [(sum0/num),(sum1/num)]


