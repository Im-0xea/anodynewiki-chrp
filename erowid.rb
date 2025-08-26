require 'httparty'

def query_experiences(search, record)
  headers = {
    "Authorization" => "Basic eGVhOkZ2Y0suUHM5Y2gwbjR2dFdpS2khNjc4JQ=="
  }
  url = "https://api.erowid.io/search/drug?drug=#{record["Title"]}&fuzzy=false&limit=26"
  json_text = HTTParty.get(encode_symbols(url), headers: headers)
  if json_text.code == 200
    json_syms = JSON.parse(json_text.body)
    exps = []
    for exp in json_syms["results"]
      if exp["drug"].downcase.include?(record["Title"].downcase)
        exps += [ { Title: exp["title"], Author: exp["author"], Id: exp["extra"]["exp_id"] } ]
      end
    end
  end
  
  if record["Abbreviation"] && record["Abbreviation"] != record["Title"]
    url = "https://api.erowid.io/search/drug?drug=#{record["Abbreviation"]}&fuzzy=false&limit=26"
    json_text = HTTParty.get(encode_symbols(url), headers: headers)
    if json_text.code == 200
      json_syms = JSON.parse(json_text.body)
      for exp in json_syms["results"]
        if exp["drug"].downcase.include?(record["Abbreviation"].downcase)
          exps += [ { Title: exp["title"], Author: exp["author"], Id: exp["extra"]["exp_id"] } ]
        end
      end
    end
  end

  if search && search != record["Title"]
    url = "https://api.erowid.io/search/drug?drug=#{search}&fuzzy=false&limit=26"
    json_text = HTTParty.get(encode_symbols(url), headers: headers)
    if json_text.code == 200
      json_syms = JSON.parse(json_text.body)
      for exp in json_syms["results"]
        if exp["drug"].downcase.include?(search.downcase)
          exps += [ { Title: exp["title"], Author: exp["author"], Id: exp["extra"]["exp_id"] } ]
        end
      end
    end
  end

  if record["Erowid Experience Reports"] == nil and exps != nil and exps.length != 0
    record["Erowid Experience Reports"] = exps.dup
  end
  return record
end
