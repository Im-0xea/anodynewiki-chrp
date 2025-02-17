require_relative 'config'

def list_experiences()
  url = "https://665557fe1d8e.ngrok.app/erw?q=#{$title}"
  json_syms = JSON.parse(fetch(url, "application/json"))
  exps = []
  for exp in json_syms
    if exp["drug"].downcase.include?($title.downcase)
      exps += [ { Title: exp["title"], Id: exp["extra"]["exp_id"] } ]
    end
  end
  return exps
end
