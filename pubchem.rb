require 'json'
require 'pubchem_api'

require_relative 'config'
require_relative 'fetch'
require_relative 'refs'
require_relative 'icons'

PUBCHEM_URL = "https://pubchem.ncbi.nlm.nih.gov/"
PUG_REST = PUBCHEM_URL + "rest/pug"
PUG_VIEW = PUBCHEM_URL + "rest/pug_view"

REST_PROPS = [ "Title", "MolecularFormula", "MolecularWeight", "CanonicalSMILES", "InChI", "InChIKey", "IUPACName", "XLogP" ]
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

#$subst_classes = [
#  { name: "lysergamide", key: "lysergic acid diethylamide" },
#  { name: "estrone", key: "estrone" },
#  { name: "pregnane", key: "pregnane" },
#  { name: "steroid", key: "steroid" },
#  { name: "morphinan", key: "morphinan" },
#  { name: "morphinan", key: "normorphine" },
#  { name: "morphinan", key: "morphine" },
#  { name: "triazolobenzodiazepine", key: "triazolobenzodiazepine" },
#  { name: "triazolobenzodiazepine", key: "alprazolam" },
#  { name: "thienodiazepine", key: "thienodiazepine" },
#  { name: "benzodiazepine", key: "benzodiazepine" },
#  { name: "benzodiazepine", key: "diazepam" },
#  { name: "benzodiazepine", key: "bromazepam" },
#  { name: "tryptamine", key: "tryptamine" },
#  { name: "pyrrolidinophenone", key: "pyrrolidinophenone" },
#  { name: "phenidate", key: "ritalinic-acid" },
#  { name: "aminorex", key: "aminorex" },
#  { name: "hexedrone", key: "hexedrone" },
#  { name: "pentedrone", key: "pentedrone" },
#  { name: "methcathinone", key: "methcathinone" },
#  { name: "cathinone", key: "cathinone" },
#  { name: "methamphetamine", key: "methamphetamine" },
#  { name: "amphetamine", key: "amphetamine" },
#  { name: "phenethylamine", key: "phenethylamine" },
#  { name: "benzofuran", key: "benzofuran" },
#  { name: "xanthine", key: "xanthine" },
#  { name: "tropane", key: "tropane" },
#  { name: "racetam", key: "piracetam" },
#  { name: "gabapentinoid", key: "gamma-aminobutyric-acid" },
#  { name: "amine", key: "methylamine" },
#  { name: "amine", key: "ammonia" },
#]

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

def recurse_section(record, json_obj)
  prop_set = 0
  for prop in VIEW_PROPS
    if json_obj["TOCHeading"] == prop && json_obj["Information"] != nil
      #puts json_obj["TOCHeading"]
      json_obj["Information"].each do |info|
        if info["Value"] != nil && info["Value"]["StringWithMarkup"] != nil
          info["Value"]["StringWithMarkup"].each do |stringwm|
            if prop_set == 0 || stringwm["String"] == record["Title"] || stringwm["String"] == $compound

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
    json_obj["Section"].each do |section|
      recurse_section(record, section)
    end
  end
end

def query_pubchem(prev_record)
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

  if $compound.start_with?("CID")
    url = PUG_REST + "/compound/cid/#{$compound[3..-1]}/property/"
  else
    url = PUG_REST + "/compound/name/#{$compound}/property/"
  end
  for prop in REST_PROPS
    url += prop + ","
  end
  url += "/JSON"

  json_content = fetch(url, "application/json")
  if json_content == nil
    puts "failed to query: #{$compound}"
    return record
  end
  json_props = JSON.parse(json_content.body)
  properties = json_props["PropertyTable"]["Properties"][0]
  for prop in REST_PROPS
    record[prop] = properties[prop]
  end
  record["PubChemId"] = properties["CID"]
  record["Title"] = $title

  url = PUG_VIEW + "/data/compound/#{record['PubChemId']}/JSON"
  json_syms = JSON.parse(fetch(url, "application/json").body)
  sections = json_syms["Record"]["Section"]
  sections.each do |section|
    recurse_section(record, section)
  end

  url = PUG_REST + "/compound/cid/#{record['PubChemId']}/description/JSON"
  json_syms = JSON.parse(fetch(url, "application/json").body)
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
    json_syms = JSON.parse(json_fetch.body)
    synonyms = json_syms["InformationList"]["Information"][0]["Synonym"].uniq
    filtSynonyms = synonyms - [ record["Title"], record["Title"].upcase, record["Title"].downcase, "(+/-)-#{record["Title"].capitalize()}", "dl-#{record["Title"].capitalize()}", "dl-#{record["Title"]}", record["CAS"], record["IUPACName"], record["UNII"], record["DSSTox Substance ID"], record["Wikidata"] ] # record["ChemicalClasses"][0]
    filtSynonyms = filtSynonyms.reject { |str| str.start_with?("SCHEMBL") }
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
    filtSynonyms = filtSynonyms.reject { |str| str.start_with?("UNII") }
    # safe UNII Id and make ref
    filtSynonyms = filtSynonyms.reject { |str| str.start_with?("BRD") }
    filtSynonyms = filtSynonyms.reject { |str| str.start_with?("NS") }
    filtSynonyms = filtSynonyms.reject { |str| str.start_with?("DTXCID") }
    filtSynonyms = filtSynonyms.reject { |str| str.start_with?("BCP") }
    pdSyms = filtSynonyms.select { |str| str.start_with?("PD") }
    if pdSyms.length != 0
      record["PD"] = pdSyms[0]
      filtSynonyms = filtSynonyms.reject { |str| str.start_with?("PD") }
    end
    # [NFLIS-DRUG]
    # [Street Name] (Street Name)
    # [PMID: 2999404]
    record["Aliases"] = filtSynonyms[0, MAX_SYMS]
  end

  record["References"] = []
  for ref in $refs
    if record["#{ref[:key]}"] != nil
      record["References"] += [
        {name: ref[:name], url: "#{ref[:url]}#{record["#{ref[:key]}"]}#{ref[:end]}"}
      ]
      if ref[:clean] == true
        record.delete(ref[:key])
      end
    end
  end

  return record
end
