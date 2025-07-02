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

def delete_cache_files(directory, reference_checksum, name)
  Dir.glob(File.join(directory, "*")).each do |file|
    file_checksum = calculate_checksum(file)
    if file_checksum == reference_checksum
      puts "Uncaching (File): #{name}.svg"
      File.delete(file)
      file = file.delete_suffix(".svg") + ".json"
      if File.exist?(file)
        puts "Uncaching (File): #{name}.json"
        File.delete(file)
      end
    end
  end
end

def uncache(cache, file)
  chksm = calculate_checksum("structure/#{file}.svg")
  if chksm != nil
    delete_cache_files(cache, chksm, file)
  end
end

def search(ssub)
  search = ssub["Title"]
  log = "Searching: #{ssub["Title"]}"
  abr = ""
  unii = ""
  classes = nil
  if ssub["Abr"] != nil
    log += " (#{ssub["Abr"]})"
    abr = ssub["Abr"]
  end
  if ssub["Search"] != nil
    search = ssub["Search"]
  end
  if ssub["Classes"] != nil
    classes = ssub["Classes"]
  end
  if ssub["CID"] != nil
    search = "CID#{ssub["Search"]}"
  end
  if ssub["UNII"] != nil
    unii = ssub["UNII"]
  end
  puts log
  query(search, ssub["Title"], abr, unii, classes)
end

def iuncache(cache, single)
  list_content = File.read('index/substance.json')
  listi = nil
  if list_content != nil
    listi = JSON.parse(list_content)["Entries"]
  end
  for comp in listi
    if (comp["Title"] != nil && (single == "" || comp["Title"].downcase == single.downcase)) || (comp["Abr"] != nil && (single == "" || comp["Abr"].downcase == single.downcase))
      puts "Uncaching (Substance): #{comp["Title"]}" + (comp["Abr"] != nil ? " (#{comp["Abr"]})" : "")
      uncache(cache, comp["Title"].downcase)
      vars_file = "substance/#{comp["Title"].downcase.gsub(/\s+/, '_')}/vars.json"
      mods_file = "substance/#{comp["Title"].downcase.gsub(/\s+/, '_')}/mods.json"
      if File.exist?(vars_file)
        json_content = JSON.parse(File.read(vars_file))
        if json_content != nil
          if json_content["Salts"] != nil
            for salt in json_content["Salts"]
              if salt == "sodium"
                uncache(cache, "#{salt}_#{comp["Title"].downcase}")
              else
                uncache(cache, "#{comp["Title"].downcase}_#{salt}")
              end
            end
          end
          if json_content["Esters"] != nil
            for ester in json_content["Esters"]
              uncache(cache, "#{comp["Title"].downcase}_#{ester}")
            end
          end
        end
      end
      puts ""
    end
  end
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
    if (comp["NoBuild"] != true && comp["Title"] != nil && (single == "" || comp["Title"].downcase == single.downcase)) || (comp["NoBuild"] != true && comp["Abr"] != nil && (single == "" || comp["Abr"].downcase == single.downcase))
      search(comp)
    end
  end
end

handle_args()
if $options[:m] == "search"
  if ARGV.empty?
    isearch("")
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
    index_class(mpath, mclass, $to_index[0])
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
      iuncache($options[:c], arg.downcase)
    end
  end
elsif $options[:m] == "research"
    if ARGV.empty?
      puts "No substances to uncache defined"
      exit 1
    end

    for arg in ARGV
      iuncache($options[:c], arg.downcase)
      isearch(arg)
    end
else
  puts "Unknown mode: #{$options[:m]}"
  exit 1
end
exit 0
