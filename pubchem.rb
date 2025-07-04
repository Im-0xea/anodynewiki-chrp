require 'json'
require 'date'
#require 'pubchem_api'

require_relative 'config'
require_relative 'fetch'
require_relative 'icons'
require_relative 'text'
require_relative 'refs'

PUBCHEM_URL = "https://pubchem.ncbi.nlm.nih.gov/"
PUG_REST = PUBCHEM_URL + "rest/pug"
PUG_VIEW = PUBCHEM_URL + "rest/pug_view"

REST_PROPS = [ "Title", "MolecularFormula", "MolecularWeight", "SMILES", "InChI", "InChIKey", "IUPACName", "XLogP", "HeavyAtomCount" ]
MAX_SYMS = 10
VIEW_PROPS = [
  "CAS", "European Community (EC) Number", "UNII", "DrugBank ID", "DSSTox Substance ID", "HMDB ID", "KEGG ID", "Wikidata", "Wikipedia",
  "Physical Description", "Color/Form", "Odor", "Taste", "Density", "Melting Point", "Boiling Point", "Flash Point",
  "Solubility", "Stability/Shelf Life", "Decomposition", "pH",
  "Human Drugs", "Drug Indication", "Drug Classes", "Clinical Trials", "Therapeutic Uses", "Drug Warnings", "Reported Fatal Dose",
  #"Chemical Classes"
  "Pharmacodynamics",
  "MeSH Pharmacological Classification", "FDA Pharmacological Classification", "Pharmacological Classes", "ATC Code",
  # "Absorption, Distribution and Excretion", "Metabolism/Metabolites",
  "Biological Half-Life",
  # "Mechanism of Action",
  #"Impurities",
]
VIEW_A_PROPS = [
  "Record Description",
]

#def generate_substitutions()
#  for subst in $subst_classes
#    url = PUG_REST + "/compound/name/#{subst[:key]}/property/title,complexity/JSON"
#    json_props = JSON.parse(fetch(url, "application/json"))
#    properties = json_props["PropertyTable"]["Properties"][0]
#    subst["CID"] = properties["CID"]
#    subst["Complexity"] = properties["Complexity"]
#  end
#  File.write('substitutions.json', JSON.pretty_generate($subst_classes))
#end

#def load_substitutions()
#  file_content = File.read('substitutions.json')
#  if file_content != nil
#    $subst_classes = JSON.parse(file_content)
#  else
#    generate_substitutions()
#  end
#end

def html_formula(formula)
  pattern = /([A-Z][a-z]*)(\d*)/
  
  html_formula = formula.gsub(pattern) do |match|
    element, number = $1, $2
    
    if number.empty?
      "#{element}"
    else
      "#{element}<sub>#{number}</sub>"
    end
  end
  html_formula
end

def recurse_section(record, compound, json_obj)
  prop_set = 0
  for prop in VIEW_PROPS
    if json_obj["TOCHeading"] == prop && json_obj["Information"] != nil
      #puts json_obj["TOCHeading"]
      json_obj["Information"].each do |info|
        if info["Value"] != nil && info["Value"]["StringWithMarkup"] != nil
          info["Value"]["StringWithMarkup"].each do |stringwm|
            if prop_set == 0 || stringwm["String"] == record["Title"] || stringwm["String"] == compound

              record[prop] = stringwm["String"]
              prop_set += 1
            end
          end
        end
      end
    end
  end
  for prop in VIEW_A_PROPS
    if json_obj["TOCHeading"] == prop && json_obj["Information"] != nil
      #puts json_obj["TOCHeading"]
      json_obj["Information"].each do |info|
        if info["Value"] != nil && info["Value"]["StringWithMarkup"] != nil
          info["Value"]["StringWithMarkup"].each do |stringwm|
            if record[prop] == nil
              record[prop] = []
            end
            record[prop] += [ stringwm["String"] ]
          end
        end
      end
    end
  end

  if json_obj["Section"] != nil
    tmp_unii = nil
    if record["UNII"] != nil
      tmp_unii = record["UNII"]
    end
    json_obj["Section"].each do |section|
      recurse_section(record, compound, section)
    end
    if tmp_unii != record["UNII"] && record["UNII"] != nil && tmp_unii != nil

      if record["StoreUNII"] == nil
        record["StoreUNII"] = [ tmp_unii, record["UNII"] ]
      else
        if !record["StoreUNII"].include?(record["UNII"])
          record["StoreUNII"] += [ record["UNII"] ]
        end
      end
    end
  end
end

def query_pubchem(prev_record, title, compound, stereoisomer)
  if prev_record == nil
    record = {}
  else
    record = prev_record
  end

  #load_substitutions()

  #client = PubChemAPI::Client.new
  #begin
  #  compound = client.get_compound_by_name($compound, 'record')
  #  record["PubChemId"] = compound.cid
  #  record["IUPACName"] = compound.iupac_name
  #  record["MolecularFormula"] = compound.molecular_formula
  #  record["MolecularWeight"] = compound.molecular_weight
  #  record["CanonicalSmiles"] = compound.canonical_smiles
  #  record["InChI"] = compound.inchi
  #  record["InChIKey"] = compound.inchi_key
  #rescue PubChemAPI::APIError => e
  #  puts "API Error (#{e.code}): #{e.message}"
  #  return record
  #end

  if compound.start_with?("CID")
    url = PUG_REST + "/compound/cid/#{compound[3..-1]}/property/"
  else
    url = PUG_REST + "/compound/name/#{replace_symbols(compound)}/property/"
  end
  for prop in 0...REST_PROPS.length
    if prop != 0
      url += ","
    end
    url += REST_PROPS[prop]
  end
  url += "/JSON"
  
  json_content = fetch(url, "application/json")
  if json_content == nil
    if !stereoisomer
      puts "failed to query: #{compound}"
    end
    return record
  end
  json_props = JSON.parse(json_content)
  properties = json_props["PropertyTable"]["Properties"][0]
  for prop in REST_PROPS
    record[prop] = properties[prop]
  end
  record["PubChemId"] = properties["CID"]
  record["Title"] = title

  url = PUG_VIEW + "/data/compound/#{record['PubChemId']}/JSON"
  json_syms = JSON.parse(fetch(url, "application/json"))
  sections = json_syms["Record"]["Section"]
  sections.each do |section|
    recurse_section(record, compound, section)
  end

  url = PUG_REST + "/compound/cid/#{record['PubChemId']}/description/JSON"
  json_syms = JSON.parse(fetch(url, "application/json"))
  infos = json_syms["InformationList"]["Information"]
  #if record["Record Description"] != nil
  #  record["Record Description"] = [ record["Record Description"] ]
  #else
  #  record["Record Description"] = []
  #end
  for info in infos
    if info["Description"] != nil
      record["Record Description"] += [ info["Description"] ]
    end
  end

  if record["MolecularFormula"] != nil
    record["MolecularFormula"] = html_formula(record["MolecularFormula"])
  end
  if record["MolecularWeight"] != nil
    record["MolecularWeight"] = record["MolecularWeight"].sub(/#{Regexp.escape(" Da")}$/, '')
    record["MolecularWeight"] += " g/mol"
  end
  if record["Density"] != nil
    matches = record["Density"].match(/^\d+(\.\d+)?/)
    if matches != nil
      " g/cm<sup>3</sup>"
    end
    record["Density"] += " g/cm<sup>3</sup>"
  end
  if record["Melting Point"] != nil
    match = record["Melting Point"].sub(/^#{Regexp.escape("MP: ")}/, '').match(/^\d+(\.\d+)?\ \°C?/)
    if match != nil
      record["Melting Point"] = match[0]
    end
  end
  if record["Boiling Point"] != nil
    match = record["Boiling Point"].sub(/^#{Regexp.escape("BP: ")}/, '').match(/^\d+(\.\d+)?\ \°C?/)
    if match != nil
      record["Boiling Point"] = match[0]
    end
  end

  #url = PUG_REST + "/compound/fastsuperstructure/cid/#{record['PubChemId']}/cids/JSON?StripHydrogen=true&Stereo=nonconflicting&MaxRecords=1000000"
  #json_content = fetch(url, "application/json")
  #if json_content != nil
  #  json_syms = JSON.parse(json_content)
  #  similar_cids = json_syms["IdentifierList"]["CID"]
    #record["ChemicalClasses"] = []
    #for subst in $subst_classes
    #  for scid in similar_cids
    #    if scid == subst["CID"]
    #      if scid == record["PubChemId"]
    #        record["IsClass"] = true
    #      else
    #        if record["IsClass"] == nil
    #          record["IsClass"] = false
    #        end
    #        record["ChemicalClasses"] += [ subst["name"] ]
    #      end
    #    end
    #  end
    #end
    #record["ChemicalClasses"] = record["ChemicalClasses"].uniq
  #end

  url = PUG_REST + "/compound/cid/#{record["PubChemId"]}/synonyms/JSON"
  json_fetch = fetch(url, "application/json")
  if json_fetch != nil && json_fetch.length != 0
    json_syms = JSON.parse(json_fetch)
    synonyms = json_syms["InformationList"]["Information"][0]["Synonym"].uniq
    unwanted_synonyms = [ record["Title"], record["Title"].upcase, record["Title"].downcase, "#{record["Title"].capitalize()}, DL-", record["CAS"], record["InChIKey"].capitalize(), record["IUPACName"], record["DSSTox Substance ID"], record["Wikidata"], record["UNII"], record["Abbreviation"] ] # record["ChemicalClasses"][0]
    strip_prefixes = [ "dl-", "DL-", "Dl-", "(+/-)", "(+-)", "(-)-",
      "U.S.P. "
    ]
    strip_postfixes = [
      "[WHO-DD]",
      "[USAN]",
      "(ester)",
      "(hydrochloride)",
      " Hydrochloride",
      "(citrate)",
      "(base)",
      "[HSDB]",
      " HCL",
      " free acid",
      ", Anhydrous",
      " (pharmaceutical)",
      " ratiopharm",
      ", (+/-)-",
      ", cis-(+,-)-",
      " compound",
      ", DL",
      ", dl-"
    ]
    if record["Abbreviation"]
      strip_postfixes += [ " (" + record["Abbreviation"] + ")" ]
    end
    unwanted_prefixes = [ "BRD", "NS", "DTXCID", "AC-", "GLXC-", "BDBM", "BRN", "HSDB", "MFCD", "BCP", "AKOS", "SCHEMBL", "LKA", "FD", "DB-", "BNB", "RT", "FM" ]
    unwanted_postfixes = [ 
      "[Latin]",
      "(Latin)",
      "[Spanish]",
      "[INN-Spanish]",
      "[INN-Latin]",
      "[German]",
      "[Czech]",
      "[MI]",
    ]
    filtSynonyms = []
    filtSynonyms[0] = record["Title"]
    filtSynonyms += synonyms
    for strip in strip_prefixes
      filtSynonyms = filtSynonyms.map { |str| str.sub(/^#{Regexp.escape(strip)}/, "") }
    end
    for strip in strip_postfixes
      filtSynonyms = filtSynonyms.map { |str| str.sub(/#{Regexp.escape(strip)}$/, "") }
    end
    filtSynonyms = filtSynonyms.reject { |str| unwanted_prefixes.any? { |prefix| str.start_with?(prefix) } }
    filtSynonyms = filtSynonyms.reject { |str| unwanted_postfixes.any? { |postfix| str.end_with?(postfix) } }
    uniiSyms = filtSynonyms.select { |str| str.start_with?("UNII") }
    if uniiSyms.length != 0
      new_unii = uniiSyms[0].delete_prefix("UNII").delete_prefix("-")
      if record["UNII"] == nil
        record["UNII"] = new_unii
      end
      if record["StoreUNII"] == nil
        record["StoreUNII"] = []
      end
      if !record["StoreUNII"].include?(new_unii)
        record["StoreUNII"] += [ new_unii ]
      end
      filtSynonyms = filtSynonyms.reject { |str| str.start_with?("UNII") }
    end
    chemblSyms = filtSynonyms.select { |str| str.start_with?("CHEMBL") }
    if chemblSyms.length != 0
      record["ChEMBL"] = chemblSyms[0]
      filtSynonyms = filtSynonyms.reject { |str| str.start_with?("CHEMBL") }
    end
    chebiSyms = filtSynonyms.select { |str| str.start_with?("CHEBI") }
    if chebiSyms.length != 0
      record["ChEBI"] = chebiSyms[0]
      filtSynonyms = filtSynonyms.reject { |str| str.start_with?("CHEBI") }
    end
    dtxsidSyms = filtSynonyms.select { |str| str.start_with?("DTXSID") }
    if dtxsidSyms.length != 0
      record["DSSTox Substance ID"] = dtxsidSyms[0]
      filtSynonyms = filtSynonyms.reject { |str| str.start_with?("DTXSID") }
    end
    aminoSyms = filtSynonyms.select { |str| str.start_with?("D-") || str.start_with?("L-") }
    if aminoSyms.length != 0
      for aminoSt in aminoSyms
        if (aminoSt.start_with?("D-") && (record["Stereoisomers"] == nil || !record["Stereoisomers"].any? { |name| name.start_with?("D-") })) || (aminoSt.start_with?("L-") && (record["Stereoisomers"] == nil || !record["Stereoisomers"].any? { |name| name.start_with?("L-") }))
          #if record["Stereoisomers"] == nil
          #  record["Stereoisomers"] = []
          #end
          #record["Stereoisomers"] += [ aminoSt ]
        end
      end
      if !stereoisomer
        filtSynonyms = filtSynonyms.reject { |str| str.start_with?("D-") || str.start_with?("L-") || str.start_with?("DL-") }
      end
    end
    # safe UNII Id and make ref
    deaSyms = filtSynonyms.select { |str| str.start_with?("DEA N") }
    if deaSyms.length != 0
      record["DEA no"] = deaSyms[0][/\d+/].to_i
      filtSynonyms = filtSynonyms.reject { |str| str.start_with?("DEA N") }
    end

    einecsSyms = filtSynonyms.select { |str| str.start_with?("EINECS ") }
    if einecsSyms.length != 0
      record["EINECS"] = einecsSyms[0].delete_prefix("EINECS ")
      filtSynonyms = filtSynonyms.reject { |str| str.start_with?("EINECS ") }
    end
      
    pdSyms = filtSynonyms.select { |str| str.match?(/\APD(?!SP)/) }
    if pdSyms.length != 0
      record["PD"] = pdSyms[0]
      filtSynonyms = filtSynonyms.reject { |str| str.match?(/\APD(?!SP)/) }
    end
    nflisSyms = filtSynonyms.select { |str| str.end_with?("[NFLIS-DRUG]") || str.end_with?("(NFLIS-DRUG)") }
    if nflisSyms.length != 0
      filtSynonyms = filtSynonyms.reject { |str| str.end_with?("[NFLIS-DRUG]") || str.end_with?("(NFLIS-DRUG)") }
      # [NFLIS-DRUG]
    end
    slangSyms = filtSynonyms.select { |str| str.end_with?("[Street Name]") }
    if slangSyms.length != 0
      record["Slang"] = slangSyms.map { |str| str.sub(/#{Regexp.escape("[Street Name]")}$/, "") }
      filtSynonyms = filtSynonyms.reject { |str| str.end_with?("[Street Name]") }
    end
    slangSyms = filtSynonyms.select { |str| str.end_with?("[Street Name]dd") }
    if slangSyms.length != 0
      record["Slang"] += slangSyms.map { |str| str.sub(/#{Regexp.escape("[Street Name]dd")}$/, "") }
      filtSynonyms = filtSynonyms.reject { |str| str.end_with?("[Street Name]dd") }
    end
    filtSynonyms = filtSynonyms.map { |str| str.gsub(/\s*[\[(]INN[^\])]*[\])]\s*$/, '') }
    filtSynonyms = filtSynonyms.map { |str| replace_names(str) }
    filtSynonyms = filtSynonyms.map { |str| (str.length > 10 && str.scan(/[A-Za-z]/).all? { |c| c == c.upcase }) ? str.downcase.sub(/([a-zA-Z])/) { |m| m.upcase } : str }
    filtSynonyms = filtSynonyms.map { |str| str.rstrip }
    filtSynonyms = filtSynonyms.map { |str| str.gsub(/\s\[[^\]]+\]$/, '') }
    filtSynonyms = filtSynonyms.map { |str| str.gsub(/\s\([^\)]+\)$/, '') }
    filtSynonyms = filtSynonyms.uniq
    if filtSynonyms[0] != nil
      record["Title"] = filtSynonyms[0]
    end
    filtSynonyms = filtSynonyms - unwanted_synonyms

    # [Street Name] (Street Name)
    # [PMID: 2999404]
    # (1.0mg/ml
    # FREE BASE
    # ChemDiv1_018926
    # CBMicro_005622
    record["Aliases"] = filtSynonyms[0, MAX_SYMS]
  end

  if record["Refs"] == nil
    record["Refs"] = []
    record["RefCount"] = 1
    record["RefCur"] = ""
  end

  now = Time.now
  record["Refs"] += [ "National Center for Biotechnology Information. PubChem Compound Summary for CID " + record["PubChemId"].to_s + ", " + record["Title"] +". Accessed #{now.strftime('%B')} #{now.day.to_s}, #{now.year.to_s}. <a href=https://pubchem.ncbi.nlm.nih.gov/compound/" + record["PubChemId"].to_s + ">https://pubchem.ncbi.nlm.nih.gov/compound/" + record["PubChemId"].to_s + "</a>" ]
  record["RefCount"] += 1

  return record
end
