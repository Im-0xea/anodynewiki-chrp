require 'json'
require 'date'

require_relative 'config'
require_relative 'fetch'

UNII_API = "https://gsrs.ncats.nih.gov/api/v1/substances("
#UNII_API = "https://gsrs.ncats.nih.gov/api/v1/substances/"
UNII_API_END = ")?view=internal"
#UNII_API_END = ""

UNII_SEARCH = "https://gsrs.ncats.nih.gov/api/v1/substances/search?q=root_names_name%3A%22%5E"
UNII_SEARCH_END = "%22&facet=Deprecated%2FNot%20Deprecated&top=10&skip=0&fdim=10"

def query_unii(prev_record, moieties, aminemoiety, acidmoiety)
  if prev_record == nil
    record = {}
  else
    record = prev_record
  end
  if record["UNII"] == nil
    return record
  end
  record["UNII"].delete_prefix("UNII-")

  url = UNII_API + record["UNII"] + UNII_API_END
  json_fetch = fetch(url, "application/json")
  if json_fetch == nil
    return record
  end
  json_props = JSON.parse(json_fetch)
  json_struct = json_props["structure"] # molfile, stereochemistry, opticalActivity
  if moieties
    if json_struct != nil && json_struct['stereochemistry'] != nil
      record["Chirality"] = json_struct['stereochemistry'].downcase
      if json_struct["opticalActivity"] != nil && json_struct["opticalActivity"] != "NONE"
        record["Opticalactivity"] = json_struct['opticalActivity']
      end
    end

    for rel in json_props["relationships"]
      if rel["type"] == "SALT/SOLVATE->PARENT"
        for key in SALTS.keys
          if (rel["relatedSubstance"]["name"].downcase.delete_prefix("#{json_props["_name"].downcase} ") == key.downcase || rel["relatedSubstance"]["name"].downcase.delete_suffix(" #{json_props["_name"].downcase}") == key.downcase) && (record["PrevSalts"] == nil || !record["PrevSalts"].include?(key))
            if record["Salts"] == nil
              record["Salts"] = []
              record["SaltsUNII"] = []
              record["SaltsAmineCount"] = []
              record["SaltsAcidCount"] = []
              record["FullSalts"] = []
            end
            record["Salts"] += [ key ]
            if record["PrevSalts"] == nil
              record["PrevSalts"] = []
            end
            record["PrevSalts"] += [ key ]
            record["SaltsUNII"] += [ rel["relatedSubstance"]["linkingID"] ]
            if key == "sodium"
              record["FullSalts"] += [ "Sodium #{$title.downcase}" ]
            else
              record["FullSalts"] += [ "#{$title} #{key}" ]
            end
            if moieties && json_struct != nil
              tmp_record = {}
              tmp_record["UNII"] = rel["relatedSubstance"]["linkingID"]
              tmp_record["Title"] = record["FullSalts"][record["FullSalts"].length - 1]
              tmp_record["SaltTitle"] = key
              hmoiety = json_struct["hash"].split("_")[0]
              tmp_record = query_unii(tmp_record, false, hmoiety, SALTS[key][:unii])
              if tmp_record["AmineMoietyCount"] != nil
                record["SaltsAmineCount"] += [ tmp_record["AmineMoietyCount"] ]
              else
                record["SaltsAmineCount"] += [ 0 ]
              end
              if tmp_record["AcidMoietyCount"] != nil
                record["SaltsAcidCount"] += [ tmp_record["AcidMoietyCount"] ]
              else
                record["SaltsAcidCount"] += [ 0 ]
              end
            end
          end
        end
      #elsif rel["type"] == "PRODRUG->METABOLITE ACTIVE"
      #  if record["Esters"] == nil
      #    record["Esters"] = []
      #  end
      #  record["Esters"] += [ rel["relatedSubstance"]["name"].downcase] #.sub(/^#{Regexp.escape("#{record["Title"].downcase} ")}/, '') ]
      elsif rel["type"] == "IMPURITY->PARENT"
        if record["Impurities"] == nil
          record["Impurities"] = []
        end
        record["Impurities"] += [ rel["relatedSubstance"]["name"].downcase]
        record["Impurities"] = record["Impurities"].uniq
      end
    end

    #if record["Esters"] != nil
    #  record["Esters"] = record["Esters"].uniq
    #  record["Esters"] = record["Esters"].flat_map { |str| ESTERS.keys.select { |filter| str.include?(filter) } }.uniq
    #  if record["Esters"].length == 0
    #    record["Esters"] = nil
    #  end
    #end

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
  elsif aminemoiety != nil || acidmoiety != nil
    log = "Fetching Form (Salt): #{record["SaltTitle"]}"
    mlog = ""
    if json_props["moieties"]
      for moi in json_props["moieties"]
        if moi["hash"].split("_")[0] == aminemoiety && moi["count"] != nil
          record["AmineMoietyCount"] = moi["count"]
          #log += "Amine: [Moiety Hash: #{moi["hash"].split("_")[0]}, Moiety Count: #{moi["count"]}] "
        elsif moi["hash"].split("_")[0] == acidmoiety && moi["count"] != nil
          record["AcidMoietyCount"] = moi["count"]
          #log += "Acid: [Moiety Hash: #{moi["hash"].split("_")[0]}, Moiety Count: #{moi["count"]}] "
        else
          if mlog == ""
            mlog += " ( "
          end
          mlog += "Unknown: [Moiety Hash: #{moi["hash"].split("_")[0]}, Moiety Count: #{moi["count"]}] "
        end
      end
    end
    if mlog != ""
      mlog += ")"
    end
    puts log + mlog
  end

  if record["Refs"] == nil
    record["Refs"] = []
    record["RefCount"] = 1
    record["RefCur"] = ""
  end

  now = Time.now
  record['Refs'] += [ "U.S. Food and Drug Administration; National Center for Advancing Translational Sciences. #{record['Title']}. UNII: #{record['UNII']}. Global Substance Registration System. Accessed #{now.strftime('%B')} #{now.day.to_s}, #{now.year.to_s}. <a href=https://gsrs.ncats.nih.gov/ginas/app/beta/substances/#{record['UNII']}>https://gsrs.ncats.nih.gov/ginas/app/beta/substances/#{record['UNII']}</a>" ]
  record["RefCount"] += 1

  return record
end
