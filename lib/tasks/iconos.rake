# Íconos autoalojados: subconjunto de Material Symbols Outlined con solo los
# íconos que usa la app. La fuente completa desde Google pesaba ~4 MB (todos
# los ejes); el subconjunto pesa decenas de KB, lo que importa en celulares de
# gama media con datos móviles.
#
# Cuándo correrla: al usar un ícono nuevo. El test IconosTest avisa si una
# vista usa un ícono que no está en la lista.
#
#   bin/rails iconos:subset
#
# Qué hace:
#   1. Descarga la lista oficial de nombres de Material Symbols.
#   2. Junta toda palabra de app/ (vistas, Ruby y JS) que sea un nombre de
#      ícono válido. Es una búsqueda amplia a propósito: incluye íconos que se
#      arman en Ruby (helpers, catálogos) aunque sobren algunos.
#   3. Pide a Google Fonts la fuente recortada a esos nombres (eje FILL 0..1,
#      peso 500 y tamaño óptico 24 fijos) y la guarda en app/assets/fonts/.
namespace :iconos do
  desc "Regenera el subconjunto autoalojado de Material Symbols con los íconos que usa la app"
  task :subset do
    require "net/http"
    require "uri"

    codepoints_url = "https://raw.githubusercontent.com/google/material-design-icons/master/" \
                     "variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.codepoints"
    user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"

    fetch = lambda do |url|
      uri = URI(url)
      res = Net::HTTP.get_response(uri, { "User-Agent" => user_agent })
      abort "iconos:subset: #{url} respondió #{res.code}" unless res.is_a?(Net::HTTPSuccess)
      res.body
    end

    validos = fetch.call(codepoints_url).lines.map { |l| l.split.first }.compact.to_set

    raiz = Rails.root.join("app")
    archivos = Dir[raiz.join("**/*.{erb,rb,js}")]
    usados = archivos.flat_map { |f| File.read(f).scan(/\b[a-z][a-z0-9_]*\b/) }.to_set & validos
    nombres = usados.to_a.sort

    lista = Rails.root.join("app/assets/fonts/material-symbols-iconos.txt")
    File.write(lista, nombres.join("\n") + "\n")

    css_url = "https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:" \
              "opsz,wght,FILL,GRAD@24,500,0..1,0&icon_names=#{nombres.join(',')}&display=block"
    woff2_url = fetch.call(css_url)[%r{url\((https://[^)]+)\)}, 1] ||
                abort("iconos:subset: la respuesta de Google Fonts no trae una URL de fuente")
    fuente = Rails.root.join("app/assets/fonts/material-symbols-outlined.woff2")
    File.binwrite(fuente, fetch.call(woff2_url))

    puts "#{nombres.size} íconos → #{fuente.relative_path_from(Rails.root)} (#{File.size(fuente) / 1024} KB)"
  end
end
