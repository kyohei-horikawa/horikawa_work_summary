file = ARGV[0] || Dir.glob("*.o*")[0]
require "scanf"

vals = `grep iter #{file}|grep accepted`.split("\n").inject([]) do |data, line|
  iter = line.split("]:")[0].scanf("iter[%d")[0]
  ene, dudl = line.split("]:")[-1].scanf(" [%f, %f]")
  data << [ene, dudl, iter]
end

val0 = vals[0][0]
vals.each_with_index do |val, i|
  print "%4d " % i
  puts "%10.5f %10.5f %5d" % [val[0] - val0, val[1], val[2]]
end
