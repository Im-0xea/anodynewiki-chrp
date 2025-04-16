require 'json'

require_relative 'config'
require_relative 'fetch'

UNII_API = "https://gsrs.ncats.nih.gov/api/v1/substances("
UNII_API_END = ")?view=internal"

UNII_SEARCH = "https://gsrs.ncats.nih.gov/api/v1/substances/search?q=root_names_name%3A%22%5E"
UNII_SEARCH_END = "%22&facet=Deprecated%2FNot%20Deprecated&top=10&skip=0&fdim=10"
SALTS = [
  "carbonate",
  "bicarbonate",
  "tosylate",
  "arsenate",
  "arsenate dihydrate",
  "nitrate",
  "acetate",
  "hydrochloride",
  "hydrochloride dihydrate",
  "hydrocloride",
  "hydrobromide",
  "hydriodide",
  "phosphate",
  "phosphate dihydrate",
  "tartrate",
  "bitartrate",
  "maleate",
  "monohydrate",
  "dihydrate",
  "chlorphenoxyacetate",
  "tannate",
  "malate",
  "citrate",
  "mesylate",
  "dimesylate",
  "adipate",
  "aspartate",
  "saccharate",
  "succinate",
  "fumarate",
  "valerate",
  "oxalate",
  "salicylate",
  "hypophosphite",
  "hypophosphite dihydrate",
  "sulfate",
  "sulphate",
  "laurylsulfate",
  "laurylsulphate",
  "hemisulfate",
  "hemisulphate",
  "sulfate monohydrate",
  "sulphate monohydrate",
  "sulfate pentahydrate",
  "sulphate pentahydrate"
]


def query_unii(prev_record)
  if prev_record == nil
    record = {}
  else
    record = prev_record
  end
  if record["UNII"] == nil
    return record
  end

  url = UNII_API + record["UNII"] + UNII_API_END
  json_props = JSON.parse(fetch(url, "application/json").body)
  json_struct = json_props["structure"] # molfile, stereochemistry, opticalActivity
  if json_struct['stereochemistry'] != nil
    record["Chirality"] = json_struct['stereochemistry'].downcase
    if json_struct["opticalActivity"] != nil && json_struct["opticalActivity"] != "NONE"
      record["Opticalactivity"] = json_struct['opticalActivity']
    end
  end

  for rel in json_props["relationships"]
    if rel["type"] == "SALT/SOLVATE->PARENT"
      if record["Salts"] == nil
        record["Salts"] = []
      end
      record["Salts"] += [ rel["relatedSubstance"]["name"].downcase] #.sub(/^#{Regexp.escape("#{record["Title"].downcase} ")}/, '') ]
    elsif rel["type"] == "IMPURITY->PARENT"
      if record["Impurities"] == nil
        record["Impurities"] = []
      end
      record["Impurities"] += [ rel["relatedSubstance"]["name"].downcase]
      record["Impurities"] = record["Impurities"].uniq
    end
  end
  if record["Salts"] != nil
    #record["Salts"] = record["Salts"].uniq
    record["Salts"] = record["Salts"].flat_map { |str| SALTS.select { |filter| str.include?(filter) } }.uniq
  end

  for code in json_props["codes"]
    if code["codeSystem"] == "LIVERTOX" || code["codeSystem"] == "WIKIPEDIA"
      if code["comments"] != nil
        if record["Record Description"] == nil
          record["Record Description"] = []
        end
        record["Record Description"] += [ code["comments"] ]
      end
    end
  end

  return record
end
