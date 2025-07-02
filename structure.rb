require_relative 'config'
require_relative 'forms'

def generate_structure(record, mpinput, mpca, subst)
  mpc = "java -cp molpic/target/molpic-1.0-SNAPSHOT.jar net.coderobe.molpic.Cli " + mpca
  title = mpinput
  if record["Title"] != nil && record["Title"].length != 0
    title = record["Title"]
  end
  if record["SMILES"] != nil && record["SMILES"].length != 0
    mpinput = record["SMILES"]
  end
  #salts = nil
  #fullsalts = nil
  #if record["Salts"] != nil && record["Salts"].length != 0 && record["FullSalts"] != nil && record["FullSalts"].length != 0
  #  salts = record["Salts"]
  #  fullsalts = record["FullSalts"]
  #end
  #smpcs = []
  only_subst = false

  ENV["DISPLAY"] = ""
  if record["IsSalt"]
    if record["SaltFormula"] != ""
      atoms = ""
      if record["AmineCount"] > 1
        for at in 0...record["HeavyAtomCount"]
          if at == 0
            atoms += at.to_s
          else
            atoms += ",#{at.to_s}"
          end
        end
        atoms = " |Sg:n:#{atoms}:#{record["AmineCount"]}:ht|"
      end
      mpc += " \"#{mpinput}#{atoms}\" -a \"#{record["SaltFormula"]}\" -z \"#{record["AcidCount"]}\"" # -u #{SALTS[salts[sl]][:amine_count]}
    end
  else
    mpc += " \"#{mpinput}\""
  end

  if !$options[:c].nil?
    cff = $options[:c] + "/" + Digest::MD5.hexdigest(mpc) + ".svg"
    #scffs = []
    #scffc = true
    #if salts != nil
    #  for sl in 0...salts.length
    #    if smpcs[sl] != ""
    #      scffs[sl] = $options[:c] + "/" + Digest::MD5.hexdigest(smpcs[sl]) + "_" + salts[sl].tr(" ", "_") + ".svg"
    #      smpcs[sl] += " -o \"#{scffs[sl]}\""
    #      if !File.exist?(scffs[sl]) || File.size(scffs[sl]) == 0
    #        scffc = false
    #      end
    #    end
    #  end
    #end
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
          #if salts.length == 0 || scffc
          #  return
          #end
        else
          only_subst = true
          mpc += " -s"
        end
      end
    end
    mpc += " -o \"#{cff}\""
    #if salts != nil
    #  for sl in 0...salts.length
    #    if smpcs[sl] != ""
    #      smpcs[sl] += " -o \"#{scffs[sl]}\""
    #    end
    #  end
    #end
  else
    mpc += " -o \"structure/#{title.downcase.tr(" ", "_")}.svg\""
    #if salts != nil
    #  for sl in 0...salts.length
    #    smpcs[sl] += " -o \"structure/#{fullsalts[sl].downcase.tr(" ", "_")}.svg\""
    #  end
    #end
    mpc += " -j \"#{vars_file}\""
  end
  ret = system(mpc)

  if !ret
    puts "#{mpc}"
    return
  end
  #if salts != nil
  #  for sl in 0...salts.length
  #    if smpcs[sl] != ""
  #      if $options[:v]
  #        puts "Exec: " + smpcs[sl]
  #      end
  #      ret = system(smpcs[sl])
  #      if !ret
  #        #puts "#{smpcs[sl]}"
  #        return
  #      end
  #    end
  #  end
  #end

  json_file = nil
  if !$options[:c].nil?
    FileUtils.cp(cff, "structure/#{title.downcase.gsub(/\s+/, '_')}.svg")
    #if salts != nil
    #  for sl in 0...salts.length
    #    if smpcs[sl] != ""
    #      FileUtils.cp(scffs[sl], "structure/#{fullsalts[sl].downcase.tr(" ", "_")}.svg")
    #    end
    #  end
    #end
    if cffj != nil
      json_file = File.read(cffj)
    end
  else
    if cffj != nil
      json_file = File.read(vars_file)
    end
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
  log = "Generating Structure: #{title.downcase.gsub(/\s+/, '_')}.svg"
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
  puts log
  #if salts != nil
  #  for sl in 0...salts.length
  #    if smpcs[sl] != ""
  #      puts "Generated Structure: #{fullsalts[sl].downcase.tr(" ", "_")}.svg"
  #    end
  #  end
  #end
end
