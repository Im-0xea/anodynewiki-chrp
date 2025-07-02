require_relative 'refs'

def generate_icon_css()
  css = ""
  REFS.each do |ref|
    if ref[:icon] != nil
      css += "a.logo[href *='#{ref[:url]}'] { background: url(#{ref[:icon]}) center right no-repeat; background-size: 16px; padding-right: 18px }\n"
    end
  end
  File.write('css/icons.css', css)
end
