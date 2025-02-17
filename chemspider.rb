require 'json'

require_relative 'config'
require_relative 'fetch'

CHEMSPIDER_API = 'https://www.chemspider.com/api/search?value='

def query_chemspider(prev_record)
  if prev_record == nil
    record = {}
  else
    record = prev_record
  end

  url = CHEMSPIDER_API + $compound
  json_props = JSON.parse(fetch(url, "application/json"))
  json_rec = json_props["Records"][0]
  if json_rec == nil
    return record
  end

  record["chemspiderId"] = json_rec["ChemSpiderId"]

  return record
end
