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
  "benzodiazepine"
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
  if record["Drug Classes"]
    desc = record["Drug Classes"]
    matches = DRUG_CLASSES.select { |drug_class| desc.downcase.include?(drug_class.downcase) }
    record["DrugClasses"] = matches.uniq if matches.any?
  end

  generate_structure(record)

  FileUtils.mkdir_p("substance/#{$title.downcase.gsub(/\s+/, '_')}")
  File.write("substance/#{$title.downcase.gsub(/\s+/, '_')}/vars.json", JSON.pretty_generate(record))


  return record
end
