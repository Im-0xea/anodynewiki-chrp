require 'optparse'
require 'fileutils'

require_relative 'config'

def handle_args()
  OptionParser.new do |opts|
    opts.banner = "Usage: chrp.[OPTIONS] [ARGUMENTS]"
    opts.on("-h", "--help",       "Displays help message") do
      puts opts
      exit
    end
    opts.on("-v", "--verbose",    "Enable verbose logging") do
      $options[:v] = true
    end
    opts.on("-c", "--cache PATH", "Set cache path") do |c|
      $options[:c] = c
    end
    opts.on("-mMODE", "--mode=MODE",       "Set mode of operation") do |m|
      $options[:m] = m
    end
  end.parse!

  if $options[:m] == "index"
    if ARGV.empty?
    #  puts "Missing indexclass argument"
    #  exit
    else
      $to_index = [ ARGV[0], ARGV[1], ARGV[2] ]
    end
  end

  if $options[:m] == "search"
    if ARGV.empty?
      #puts "Missing searchterm argument"
      #exit
    else
      $compounds = [ ARGV[0] ]
    end
  end

  if $options[:c]
    if $options[:v]
      puts "Cache: " + $options[:c]
    end
    FileUtils.mkdir_p($options[:c])
  end
end
