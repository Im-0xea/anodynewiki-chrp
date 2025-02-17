def index_drug_class(pclass, vclass, iclass)
  index_substances = []
  index = {} 
  if File.exist?("#{pclass}/#{iclass.downcase}.json")
    index_file_content = File.read("#{pclass}/#{iclass.downcase}.json")
    index = JSON.parse(index_file_content)
  end
  index['Name'] = iclass.downcase

  Dir.glob('substance/*').each do |file_path|
    begin
      title = Pathname(file_path).basename.to_s
      mw = ""
      abr = ""
      if File.exist?("#{file_path}/mods.json")
        mods_file_content = File.read("#{file_path}/mods.json")
        mods_data = JSON.parse(mods_file_content)
        if mods_data['Title'] != nil
          title = mods_data['Title']
        end
        if mods_data['MolecularWeight'] != nil
          mw = mods_data['MolecularWeight']
        end
        if mods_data['Abbreviation'] != nil
          abr = mods_data['Abbreviation']
        end
      end
      if File.exist?("#{file_path}/vars.json")
        vars_file_content = File.read("#{file_path}/vars.json")
        vars_data = JSON.parse(vars_file_content)
        if vars_data['Title'] != nil
          title = vars_data['Title']
        end
        if vars_data['MolecularWeight'] != nil
          mw = vars_data['MolecularWeight']
        end
        if vars_data['Abbreviation'] != nil
          abr = vars_data['Abbreviation']
        end
      end

      if mods_data != nil && mods_data.key?(vclass) && mods_data[vclass].is_a?(Array)
        if mods_data['IsClass'] != true
          if mods_data[vclass].include?(iclass)
            index_substances << { "Title": title, "MW": mw }
          end
        else
          if mods_data['ChemicalClasses'] && mods_data['ChemicalClasses'][0].downcase == iclass.downcase
            if index['First'].is_a?(String)
              fstr = index['First']
              index['First'] = {}
              index['First']['Title'] = fstr
            end
            if title != nil
              index['First']['Title'] = title
            end
            if abr != nil
              index['First']['Abr'] = abr
            end
            if mw != nil
              index['First']['MW'] = mw
            end
            for par in mods_data['ChemicalClasses'].drop(1)
              par_file_content = File.read("#{pclass}/#{par}.json")
              par_data = JSON.parse(par_file_content)
              if par_data['Children']
                if !par_data['Children'].include?(iclass.downcase)
                  par_data['Children'] += [ iclass.downcase ]
                end
              else
                par_data['Children'] = [ iclass.downcase ]
              end
              File.write("#{pclass}/#{par}.json", JSON.pretty_generate(par_data))
            end
          end
        end
      elsif vars_data != nil && vars_data.key?(vclass) && vars_data[vclass].is_a?(Array)
        if vars_data[vclass].include?(iclass)
          sub = { "Title": title, "Abr": abr, "MW": mw }
          index_substances << sub
        end
      end
    rescue => e
      puts "An error occurred with file #{file_path}: #{e.message}"
    end
  end

  index['Entries'] = index_substances
  File.write("#{pclass}/#{iclass.downcase}.json", JSON.pretty_generate(index))

  puts JSON.pretty_generate(index)
end
