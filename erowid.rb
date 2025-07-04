def query_experiences(search, record)
  url = "https://api.erowid.io/search/drug?drug=#{record["Title"]}&fuzzy=false&limit=26"
  json_text = fetch(encode_symbols(url), "application/json")
  if json_text
    json_syms = JSON.parse(json_text)
    exps = []
    for exp in json_syms["results"]
      if exp["drug"].downcase.include?(record["Title"].downcase)
        exps += [ { Title: exp["title"], Author: exp["author"], Id: exp["extra"]["exp_id"] } ]
      end
    end
  end
  
  if record["Abbreviation"] && record["Abbreviation"] != record["Title"]
    url = "https://api.erowid.io/search/drug?drug=#{record["Abbreviation"]}&fuzzy=false&limit=26"
    json_text = fetch(encode_symbols(url), "application/json")
    if json_text
      json_syms = JSON.parse(json_text)
      for exp in json_syms["results"]
        if exp["drug"].downcase.include?(record["Abbreviation"].downcase)
          exps += [ { Title: exp["title"], Author: exp["author"], Id: exp["extra"]["exp_id"] } ]
        end
      end
    end
  end

  if search && search != record["Title"]
    url = "https://api.erowid.io/search/drug?drug=#{search}&fuzzy=false&limit=26"
    json_text = fetch(encode_symbols(url), "application/json")
    if json_text
      json_syms = JSON.parse(json_text)
      for exp in json_syms["results"]
        if exp["drug"].downcase.include?(search.downcase)
          exps += [ { Title: exp["title"], Author: exp["author"], Id: exp["extra"]["exp_id"] } ]
        end
      end
    end
  end

  record["Erowid Experience Reports"] = exps
  return record
end
