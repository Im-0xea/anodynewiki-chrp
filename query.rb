require 'fileutils'

require_relative 'config'
require_relative 'chemspider'
require_relative 'dosing'
require_relative 'erowid'
require_relative 'unii'
require_relative 'structure'
require_relative 'pubchem'

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

def query(compound, title, abr)
  $compound = compound
  $title = title
  record = {}
  record['Abbreviation'] = abr

  record = record.merge(query_chemspider record)
  record = record.merge(query_pubchem record)
  record = record.merge(query_unii record)
  record = record.merge(query_dosing record)

  if record['Title'] == nil
    return record
  end

  #exps = list_experiences
  #if exps != nil && exps.length != 0
  #  record["Erowid Experience Reports"] = exps
  #end

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

  generate_structure(record)

  FileUtils.mkdir_p("substance/#{$title.downcase.gsub(/\s+/, '_')}")
  File.write("substance/#{$title.downcase.gsub(/\s+/, '_')}/vars.json", JSON.pretty_generate(record))


  return record
end
