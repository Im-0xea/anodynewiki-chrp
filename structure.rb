require_relative 'config'

def generate_structure(record)
  mpc = "java -cp molpic/target/molpic-1.0-SNAPSHOT.jar net.coderobe.molpic.Cli "
  mpinput = "#{$compound}"
  only_subst = false

  mods_file = "substance/#{$title.downcase.gsub(/\s+/, '_')}/mods.json"
  vars_file = "substance/#{$title.downcase.gsub(/\s+/, '_')}/vars.json"
  if File.exist?(mods_file)
    json_content = JSON.parse(File.read(mods_file))
    if json_content["MolpicInput"]
      mpinput = json_content["MolpicInput"]
    end
    if json_content["CanonicalSMILES"]
      mpinput = json_content["CanonicalSMILES"]
    end
    if json_content["MolpicFlip"]
      mpc += " -f#{json_content["MolpicFlip"]}"
    end
    if json_content["MolpicRotation"]
      mpc += " -r#{json_content["MolpicRotation"]}"
    end
  end
  if File.exist?(vars_file)
    xjson_content = JSON.parse(File.read(vars_file))
    if xjson_content["CanonicalSMILES"]
      mpinput = xjson_content["CanonicalSMILES"]
    end
  end

  ENV["DISPLAY"] = ""
  mpc += " \"#{mpinput}\""

  if !$options[:c].nil?
    cff = $options[:c] + "/" + Digest::MD5.hexdigest(mpc) + ".svg"
    cffj = $options[:c] + "/" + Digest::MD5.hexdigest(mpc) + ".json"
    if File.exist?(cff) && File.size(cff) > 0 && ((Time.now - File.mtime(cff)) / (24 * 60 * 60)) < 1.0
      if $options[:v]
        puts "Load Cache: " + url
      end
      if File.exist?(cffj) && File.size(cffj) > 0
        json_file = File.read(cffj)
        json_data = JSON.parse(json_file)
        if json_data['ChemicalClasses'] != nil
          record['ChemicalClasses'] = json_data['ChemicalClasses']
        end
        return
      else
        only_subst = true
        mpc += " -s"
      end
    end
    mpc += " -o \"#{cff}\""
    mpc += " -j \"#{cffj}\""
  else
    def to_snake_case(str)
      str.strip.downcase.gsub(/\s+/, '_').gsub(/[^a-z0-9_]/, '')
    end    
    mpc += " -o \"structure/#{to_snake_case($title)}.svg\""
    mpc += " -j \"#{vars_file}\""
  end
  ret = system(mpc)

  if !ret
    puts "#{mpc}"
    return
  end
  if !$options[:c].nil?
    FileUtils.cp(cff, "structure/#{$title.downcase.gsub(/\s+/, '_')}.svg")
    json_file = File.read(cffj)
    json_data = JSON.parse(json_file)
    if json_data['ChemicalClasses'] != nil
      record['ChemicalClasses'] = json_data['ChemicalClasses']
    end
  else
    json_file = File.read(vars_file)
    json_data = JSON.parse(json_file)
    if json_data['ChemicalClasses'] != nil
      record['ChemicalClasses'] = json_data['ChemicalClasses']
    end
  end
  puts "generated structure/#{$title.downcase.gsub(/\s+/, '_')}.svg"
end
