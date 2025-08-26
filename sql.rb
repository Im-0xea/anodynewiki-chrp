require 'json'
require 'sqlite3'

def dump_to_db(db, record)
  return if record["Title"] == nil
  abrs = []
  if record["SAliases"]
    abrs = record["SAliases"]
    record.delete("SAliases")
  end
  abrs += record["Abbreviation"] if record["Abbreviation"]
  abrs += record["Formating"] if record["Formating"]
  abrs += record["Aliases"] if record["Aliases"]
  abrs += record["FullSalts"] if record["FullSalts"]
  abrs += record["StereoisomersUNII"] if record["StereoisomersUNII"]
  abrs += record["SaltsUNII"] if record["SaltsUNII"]
  abrs += record["Stereoisomers"] if record["Stereoisomers"]
  abrs += record["Slang"] if record["Slang"]
  abrs += [ record["MolecularFormula"].gsub("<sub>", "").gsub("</sub>", "") ] if record["MolecularFormula"] != nil
  if record["StereoTitles"] != nil
    for stereotitle in record["StereoTitles"]
      abrs += [ stereotitle["Title"] ]
    end
  end
  appn = [ record["UNII"], record["StereoisomerRacemic"], record["SMILES"], "CID#{record["PubChemId"]}", record["InChI"], record["InChIKey"], record["IUPACName"], record["CAS"], record["Wikidata"], record["European.Community.(EC).Number"], record["HMDB.ID"], record["ChEMBL"], record["ChEBI"], record["EINECS"] ]

  clean_record = record.dup
  clean_record = clean_record.reject{ |_, v| v.respond_to?(:empty?) ? v.empty? : v.nil? }

  for str in appn
    abrs += [ str ] if str != nil
  end
  abrs = abrs.compact.uniq
  record.delete("HMDB Metabolite")
  puts "INSERT INTO substances (#{record["Title"]})"
  db.execute("INSERT OR REPLACE INTO substances (title, aliases, data_json) VALUES (?, ?, ?)",
             [record["Title"], abrs.to_json, record.to_json])
end
