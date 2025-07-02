def index_class(pclass, vclass, iclass)
  index_substances = []
  index = {} 
  iclass = iclass.downcase
  mods_data = {}
  vars_data = {}
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

      if mods_data != nil && mods_data.key?('ChemicalClasses') && mods_data['ChemicalClasses'].include?(iclass.downcase)
        if mods_data['IsClass'] != true && mods_data[vclass].include?(iclass)
            index_substances << { "Title": title, "MW": mw }
            return nil
        end
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
      if vars_data != nil && vars_data['ChemicalClasses'] && vars_data['ChemicalClasses'].include?(iclass.downcase)
        if vars_data['IsClass'] != true && mods_data[vclass].include?(iclass)
          index_substances << { "Title": title, "MW": mw }
          return nil
        end
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

    rescue => e
      puts "An error occurred with file #{file_path}: #{e.message}"
    end
  end

  index['Entries'] = index_substances
  File.write("#{pclass}/#{iclass.downcase}.json", JSON.pretty_generate(index))

  puts JSON.pretty_generate(index)
end
