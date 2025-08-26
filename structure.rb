require 'open3'

require_relative 'config'
require_relative 'forms'

def generate_structure(record, mpca, subst)
  mpc = "java -cp molpic/target/molpic-1.0-SNAPSHOT.jar net.coderobe.molpic.Cli " + mpca
  title = record["Title"]
  title = record["SaltTitle"] if record["SaltTitle"] != nil
  return record if title == nil
  return record if record["SMILES"] == nil
  smiles = record["SMILES"]
  
  only_subst = false
  ENV["DISPLAY"] = ""
  if record["IsSalt"]
    if record["SaltFormula"] != ""
      smiles = record["SaltSMILES"]
      atoms = ""
      if record["SaltAmineCount"] > 1
        for at in 0...record["HeavyAtomCount"]
          if at == 0
            atoms += at.to_s
          else
            atoms += ",#{at.to_s}"
          end
        end
        atoms = " |Sg:n:#{atoms}:#{record["SaltAmineCount"]}:ht|"
      end
      mpc += " \"#{smiles}#{atoms}\" -a \"#{record["SaltFormula"]}\" -z \"#{record["SaltAcidCount"]}\"" #-u #{record[\"SaltAmineCount\"]}"
    end
  else
    mpc += " \"#{record["SMILES"]}\""
  end

  if !$options[:c].nil?
    cff = $options[:c] + "/" + Digest::MD5.hexdigest(mpc) + ".svg"
    cffj = nil
    if subst
      cffj = $options[:c] + "/" + Digest::MD5.hexdigest(mpc) + ".json"
      mpc += " -j \"#{cffj}\""
    end
    if File.exist?(cff) && File.size(cff) > 0 && ((Time.now - File.mtime(cff)) / (24 * 60 * 60)) < 1.0 #&& (scffc)
      if $options[:v]
        puts "Loading Cache: " + cff
      end
      if subst
        if File.exist?(cffj) && File.size(cffj) > 0
          json_file = File.read(cffj)
          json_data = JSON.parse(json_file)
          if json_data['ChemicalClasses'] != nil
            record['ChemicalClasses'] = json_data['ChemicalClasses']
          end
        else
          only_subst = true
          mpc += " -s"
        end
      end
    end
    mpc += " -o \"#{cff}\""
  else
    mpc += " -o \"structure/#{title.downcase.tr(" ", "_")}.svg\""
    mpc += " -j \"#{vars_file}\""
  end

  puts "#{mpc}" if !$options[:v].nil?
  ret = system(mpc)

  if !ret
    return record
  end
  svg_file = File.read(cff) if cff != nil
  json_file = File.read(cffj) if cffj != nil
  if !$options[:c].nil?
    FileUtils.cp(cff, "structure/#{title.downcase.gsub(/\s+/, '_')}.svg")
  end
  if subst && json_file != nil
    json_data = JSON.parse(json_file)
    if json_data['ChemicalClasses'] != nil
      if record['ChemicalClasses'] == nil
        record['ChemicalClasses'] = []
      end
      record['ChemicalClasses'] += json_data['ChemicalClasses']
    end
  end
  #puts svg_file
  log = "Generating Structure: #{title.downcase.gsub(/\s+/, '_')}.svg"
  formated = svg_with_white_background(svg_file)
  optimized = optimize_svg(formated)
  record["Structure"] = optimized
  if subst
    log += " (Substitutions:"
    record['ChemicalClasses'] = record['ChemicalClasses'].uniq
    for isubst in record['ChemicalClasses']
      if isubst == "amino acid"
        record["ChiralityAminoAcid"] = true
      end
      if isubst != record["ChemicalClasses"][0]
        log += ", "
      else
        log += " "
      end
      log += isubst
    end
    log += ")"
  end
  return record
end
