require 'base64'
require 'digest'
require 'open-uri'
require 'nokogiri'
require 'json'

require_relative 'args'
require_relative 'config'
require_relative 'indexer'
require_relative 'query'

def calculate_checksum(file_path)
  return nil unless File.exist?(file_path)
  Digest::SHA256.file(file_path).hexdigest
end

def delete_cache_files(directory, reference_checksum)
  Dir.glob(File.join(directory, "*")).each do |file|
    file_checksum = calculate_checksum(file)
    if file_checksum == reference_checksum
      jsonfile = nil
      if file.end_with?(".svg")
        jsonfile = file.sub(/\.svg\z/, "") + ".json"
      end
      File.delete(file)
      puts "deleted cached file #{file}"
      if jsonfile != nil && File.exist?(jsonfile)
        File.delete(jsonfile)
        puts "deleted cached file #{jsonfile}"
      end
    end
  end
end

def uncache(cache, file)
  chksm = calculate_checksum("structure/" + file.downcase)
  if chksm != nil
    delete_cache_files(cache, chksm)
  end
end

def search(ssub)
  search = ssub["Title"]
  log = "generating #{ssub["Title"]}"
  abr = ""
  if ssub["Abr"] != nil
    log += " (#{ssub["Abr"]})"
    abr = ssub["Abr"]
  end
  if ssub["Search"] != nil
    search = ssub["Search"]
  end
  if ssub["CID"] != nil
    search = "CID#{ssub["Search"]}"
  end
  puts log
  query(search, ssub["Title"], abr)
end

def isearch(single)
  list_content = File.read('index/substance.json')
  listi = nil
  if list_content != nil
    listi = JSON.parse(list_content)["Entries"]
  end
  if $options[:v]
    puts "list: #{listi.length}"
  end
  for comp in listi
    if comp["Title"] != nil && (single == nil || comp["Title"] == single)
      search(comp)
    end
  end
end

handle_args()
if $options[:m] == "search"
  if ARGV.empty?
    isearch()
  else
    isearch($compounds[0])
    exit 0
    #query($compounds[0], $compounds[0], "")
  end
elsif $options[:m] == "index"
  list_content = File.read('classes.json')
  $vclasses = []
  if list_content != nil
    $vclasses = JSON.parse(list_content)["VClasses"]
  end
  if ARGV.empty?
    for vclass in $vclasses
      for iclass in vclass['Classes']
        puts "Indexing: #{iclass}"
        index_drug_class(vclass['Path'], vclass['JName'], iclass)
      end
    end
  else
    mpath = $to_index[2]
    mclass = $to_index[1]
    for vclass in $vclasses
      for iclass in vclass['Classes']
        if iclass == $to_index[0]
          mpath = vclass['Path']
          mclass = vclass['JName']
        end
      end
    end
    index_drug_class(mpath, mclass, $to_index[0])
  end
elsif $options[:m] == "init"
  generate_icon_css()
  #generate_substitutions()
elsif $options[:m] == "uncache"
  if $options[:c] != nil
    if ARGV.empty?
      puts "No substances to uncache defined"
      exit 1
    end

    for arg in ARGV
      uncache($options[:c], arg + ".svg")
    end
  end
elsif $options[:m] == "research"
    if ARGV.empty?
      puts "No substances to uncache defined"
      exit 1
    end

    for arg in ARGV
      uncache($options[:c], arg + ".svg")
      isearch(arg)
    end
else
  puts "Unknown mode: #{$options[:m]}"
  exit 1
end
exit 0
