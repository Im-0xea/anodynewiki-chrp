require 'fileutils'

require_relative 'config'
require_relative 'structure'
require_relative 'forms'
require_relative 'text'
require_relative 'refs'
require_relative 'effects'

require_relative 'chemspider'
require_relative 'dosing'
require_relative 'erowid'
require_relative 'unii'
require_relative 'hmdb'
require_relative 'pubchem'
require_relative 'wikipedia'
require_relative 'sciencemadness'
require_relative 'swisstargetprediction'

DRUG_CLASSES = [
  "deliriant",
  "nootropic",
  "cannabinoid",
  "calcium channel blocker",
  "entactogen",
  "dissociative",
  "psychedelic",
  "hallucinogens",
  "antidepressant",
  "antipsychotic",
  "hormone",
  "opioid",
  "stimulant",
  "depressant",
]

PHARM = [
  "Human Drugs", "Drug Indication", "Drug Classes", "Clinical Trials", "Therapeutic Uses", "Drug Warnings", "Reported Fatal Dose", "Pharmacodynamics", "MeSH Pharmacological Classification", "FDA Pharmacological Classification", "Pharmacological Classes", "ATC Code"
]

def query(compound, title, abr, unii, classes)
  $compound = compound
  $title = title
  record = {}
  record['Abbreviation'] = abr
  record['Classes'] = classes
  record["Refs"] = []
  record["RefCount"] = 1
  record['Subjective Effects'] = get_effects(classes)
  if unii != nil && unii != ""
    record['UNII'] = unii
    record['StoreUNII'] = []
    record['StoreUNII'] += [ unii ]
  end

  #record = record.merge(query_chemspider record)
  nc = $compound
  CHIRAL_PREFIXES.each do |key, value|
    if value[:prefixes] != nil
      nc = value[:prefixes].find { |str| nc.start_with?(str) }&.then { |str| nc[str.length..-1] } || nc
    end
  end
  for prefix in CHIRAL_PREFIXES["racemic"][:prefixes]
    tmp_record = {}
    tmp_record = query_pubchem(tmp_record, nc, prefix + nc, true)
    if tmp_record["Title"] != nil
      record = record.merge(tmp_record)
    end
  end
  if record["Title"] == nil
    record = record.merge(query_pubchem(record, $title, compound, false))
  end
  if record["UNII"] != nil
    record["PrevSalts"] = []
    record = record.merge(query_unii(record, true, nil, nil))
    if record["Chirality"] == "racemic"
      puts "Fetching Form (Stereoisomer): racemic"
      record["StereoisomerRacemic"] = CHIRAL_PREFIXES["logical-racemic"][:prefered] + record["Title"]
    end
  end
  if record["HMDB ID"] != nil
    record = record.merge(query_hmdb(record))
  end
  record = record.merge(query_wikipedia(record))
  record = record.merge(query_sciencemadness(record))
  record["References"] = generate_references(record)
  #record = record.merge(query_swtp(record))
  mpinput = $compound
  mpca = ""
  mods_file = "substance/#{$title.downcase.gsub(/\s+/, '_')}/mods.json"
  if File.exist?(mods_file)
    json_content = JSON.parse(File.read(mods_file))
    if json_content["SMILES"]
      mpinput = json_content["SMILES"]
    end
    if json_content["MolpicFlip"]
      mpca += " -f#{json_content["MolpicFlip"]}"
    end
    if json_content["MolpicRotation"]
      mpca += " -r#{json_content["MolpicRotation"]}"
    end
  end
  generate_structure(record, mpinput, mpca, true)
  if record["Chirality"] == "racemic"
    puts "Fetching Form (Stereoisomer): racemic"
    record["StereoisomerRacemic"] = (record["ChemicalClasses"] != nil && record["ChemicalClasses"].include?("amino acid") ? CHIRAL_PREFIXES["logical-racemic"][:prefered] : CHIRAL_PREFIXES["racemic"][:prefered]) + record["Title"]
  end
  stereo_records = []
  CHIRAL_PREFIXES.each do |key, value|
    if key != "racemic" && (((record["ChemicalClasses"] != nil && record["ChemicalClasses"].include?("amino acid")) || (key != "logical-racemic" && key != "dexter" && key != "laevus")) && ((record["ChemicalClasses"] == nil || !record["ChemicalClasses"].include?("amino acid")) || (key != "left-handed" && key != "right-handed"))) && record["Chirality"] != "absolute"
      for prefix in value[:prefixes]
        tmp_record = {}
        if record["Wikipedia"] != nil
          tmp_record["OldWikipedia"] = record["Wikipedia"]
        end
        tmp_record = query_pubchem(tmp_record, value[:prefered] + nc, prefix + nc, true)
        tmp_record = tmp_record.reject { |k, v| record[k] == v }
        tmp_record["References"] = generate_references(tmp_record)
        #tmp_record["Title"] = value[:prefered] + nc
        if tmp_record["Title"] != nil && tmp_record["PubChemId"] != record["PubChemId"]
          puts "Fetching Form (Stereoisomer): #{key}"
          if record["Stereoisomers"] == nil
            record["Stereoisomers"] = []
          end
          if record["StereoisomersUNII"] == nil
            record["StereoisomersUNII"] = []
          end
          record["Stereoisomers"] += [ tmp_record["Title"] ]
          if tmp_record["UNII"] == nil
            record["StereoisomersUNII"] += [ "" ]
          else
            record["StereoisomersUNII"] += [ tmp_record["UNII"] ]
            tmp_record["StereoSearch"] = prefix + nc
            tmp_record["AltChirality"] = key
            tmp_record["PrevSalts"] = record["Salts"]
            tmp_record = query_unii(tmp_record, true, nil, nil)
            if tmp_record["Salts"] != nil
              if record["Salts"] == nil
                record["Salts"] = []
                record["SaltsUNII"] = []
                record["SaltsAmineCount"] = []
                record["SaltsAcidCount"] = []
                record["FullSalts"] = []
              end
              for salt in 0...tmp_record["Salts"].length
                if !record["Salts"].include?(tmp_record["Salts"][salt])
                  record["Salts"] += [ tmp_record["Salts"][salt] ]
                  record["SaltsUNII"] += [ tmp_record["SaltsUNII"][salt] ]
                  record["SaltsAmineCount"] += [ tmp_record["SaltsAmineCount"][salt] ]
                  record["SaltsAcidCount"] += [ tmp_record["SaltsAcidCount"][salt] ]
                  if tmp_record["Salts"][salt] == "sodium"
                    record["FullSalts"] += [ "Sodium #{nc.downcase}" ]
                  else
                    record["FullSalts"] += [ "#{nc} #{tmp_record["Salts"][salt]}" ]
                  end
                end
              end
            end
            #puts JSON.pretty_generate(tmp_record)
            stereo_records += [ tmp_record ]
            if key != "vague"
              break
            end
          end
        end
      end
    end
  end
  #if record["StereoisomersUNII"] != nil
  #  for siunii in record["StereoisomersUNII"]
  #  end
  #end
  salt_records = []
  if record["Salts"] != nil
    for salt in 0...record["Salts"].length
      tmp_record = {}
      tmp_record["IsSalt"] = true
      tmp_record["SMILES"] = record["SMILES"]
      tmp_record["SaltFormula"] = SALTS[record["Salts"][salt]][:formula]
      tmp_record["SaltTitle"] = record["Salts"][salt]
      tmp_record["SaltSearch"] = record["FullSalts"][salt]
      tmp_record["HeavyAtomCount"] = record["HeavyAtomCount"]
      tmp_record["AmineCount"] = [SALTS[record["Salts"][salt]][:amine_count], record["SaltsAmineCount"][salt]].max
      tmp_record["AcidCount"] = [SALTS[record["Salts"][salt]][:acid_count], record["SaltsAcidCount"][salt]].max
      tmp_record["Title"] = record["FullSalts"][salt]
      #tmp_record = query_pubchem(tmp_record, record["FullSalts"][salt], record["FullSalts"][salt], true)
      #if tmp_record["Title"] != nil #&& tmp_record["PubChemId"] != record["PubChemId"]
        salt_records += [ tmp_record ]
      #end
    end
  end
  ester_records = []
  for ester in ESTERS
    tmp_record = {}
    tmp_record = query_pubchem(tmp_record, "#{nc} #{ester}", "#{nc} #{ester}", true)
    #tmp_record["Title"] = "#{nc} #{key}"
    if tmp_record["Title"] != nil && tmp_record["PubChemId"] != record["PubChemId"]
      puts "Fetching Form (Ester): #{ester}"
      if record["Esters"] == nil
        record["Esters"] = []
      end
      record["Esters"] += [ ester ]
      tmp_record["EsterSearch"] = "#{nc} #{ester}"
      tmp_record["AltEster"] = ester
      ester_records += [ tmp_record ]
    end
  end
  record = record.merge(query_dosing record)

  if record['Title'] == nil
    return record
  end

  record = record.merge(query_experiences($compound, record))

  classStrs = []
  record["DrugClasses"] = []
  for phrm in PHARM
    if record[phrm] != nil
      classStrs += [ record[phrm] ]
    end
  end

  if classStrs.length != 0
    for desc in classStrs
      matches = DRUG_CLASSES.select { |drug_class| desc.downcase.include?(drug_class.downcase) }
      if matches.any?
        record["DrugClasses"] += matches
      end
    end
    record["DrugClasses"] = record["DrugClasses"].uniq
  end

  mods_file = "substance/#{$title.downcase.gsub(/\s+/, '_')}/mods.json"
  if File.exist?(mods_file)
    json_content = JSON.parse(File.read(mods_file))
    if json_content["StereoTitles"] != nil
      for stt in json_content["StereoTitles"]
        for stereo in stereo_records
          if stt["Chirality"] == stereo["AltChirality"]
            stereo["Title"] = stt["Title"]
          end
        end
        if record["Stereoisomers"] != nil
          for si in 0...record["Stereoisomers"].length
            if CHIRAL_PREFIXES[stt["Chirality"]][:prefered] + nc == record["Stereoisomers"][si]
              record["Stereoisomers"][si] = stt["Title"]
            end
          end
        end
      end
    end
  end
  puts ""
  if contains_symbols(record["Title"])
    raw_t = replace_symbols(record["Title"].downcase)
    FileUtils.mkdir_p("substance/#{raw_t}")
    File.write("substance/#{raw_t}/vars.json", JSON.pretty_generate({ SubstanceRedirectSource: raw_t, SubstanceRedirect: "#{record['Title'].downcase.gsub(/\s+/, '_')}"}))#, SubstanceRedirectAnchor: "Stereochemistry" }))
    puts "Linking to alias: #{raw_t}"
  end
  for stereo in stereo_records
    for st_ref in stereo["References"]
      for ref_it in 0...record["References"].length
        if st_ref[:Name] == record["References"][ref_it][:Name]
          for url in st_ref[:Urls]
            url[:Name] = stereo["Title"]
            url[:Sub] = true
            record["References"][ref_it][:Urls] += [ url ]
          end
        end
      end
    end
    puts "Linking to alias: #{stereo['Title'].downcase.gsub(/\s+/, '_')}"
    FileUtils.mkdir_p("substance/#{stereo["Title"].downcase.gsub(/\s+/, '_')}")
    File.write("substance/#{stereo['Title'].downcase.gsub(/\s+/, '_')}/vars.json", JSON.pretty_generate({ SubstanceRedirectSource: stereo['Title'], SubstanceRedirect: "#{record['Title'].downcase.gsub(/\s+/, '_')}", SubstanceRedirectAnchor: "Stereochemistry" }))
    generate_structure(stereo, stereo["StereoSearch"], mpca, false)
  end
  for salt in salt_records
    generate_structure(salt, salt["Title"], mpca, false)
  end
  for ester in ester_records
    FileUtils.mkdir_p("substance/#{ester["Title"].downcase.gsub(/\s+/, '_')}")
    File.write("substance/#{ester['Title'].downcase.gsub(/\s+/, '_')}/vars.json", JSON.pretty_generate({ SubstanceRedirectSource: ester['Title'], SubstanceRedirect: "#{record['Title'].downcase.gsub(/\s+/, '_')}", SubstanceRedirectAnchor: "Chemistry" }))
    generate_structure(ester, ester["EsterSearch"], mpca, false)
  end

  for subst in record["ChemicalClasses"]
    subst_file = "substituted/#{subst.downcase.gsub(/\s+/, '_')}.json"
    if File.exist?(subst_file)
      json_content = JSON.parse(File.read(subst_file))
      if json_content != nil && json_content["Entries"] != nil
        eset = false
        for entr in json_content["Entries"]
          if entr["Title"].downcase == $title.downcase
            entr["Abr"] = record["Abbreviation"]
            entr["MW"] = record["MolecularWeight"]
            eset = true
            break
          end
        end
        if json_content["First"] != nil
          if json_content["First"]["Title"].downcase == $title.downcase
            json_content["First"]["Title"] = record["Title"]
            json_content["First"]["Abr"] = record["Abbreviation"]
            json_content["First"]["MW"] = record["MolecularWeight"]
            eset = true
          end
        end
        if eset == false
          json_content["Entries"] += [ { "Title": $title, "Abr": record["Abbreviation"], "MW": record["MolecularWeight"] } ]
        end
        File.write(subst_file, JSON.pretty_generate(json_content))
      end
    end
  end

  puts "substance/#{$title.downcase.gsub(/\s+/, '_')}"
  FileUtils.mkdir_p("substance/#{$title.downcase.gsub(/\s+/, '_')}")
  File.write("substance/#{$title.downcase.gsub(/\s+/, '_')}/vars.json", JSON.pretty_generate(record))

  return record
end
