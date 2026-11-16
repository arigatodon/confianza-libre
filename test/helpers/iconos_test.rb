require "test_helper"

# Los íconos vienen de un subconjunto autoalojado de Material Symbols
# (app/assets/fonts/material-symbols-outlined.woff2). Un ícono que no está en el
# subconjunto se ve como texto ("dynamic_feed") en vez del dibujo: este test
# avisa antes de que pase en producción.
class IconosTest < ActiveSupport::TestCase
  LISTA = Rails.root.join("app/assets/fonts/material-symbols-iconos.txt")

  setup do
    @disponibles = File.readlines(LISTA, chomp: true).reject(&:blank?).to_set
  end

  test "la fuente de íconos y su lista existen" do
    assert File.exist?(Rails.root.join("app/assets/fonts/material-symbols-outlined.woff2"))
    assert_operator @disponibles.size, :>, 50
  end

  test "todo ícono escrito en las vistas está en el subconjunto" do
    usados = Dir[Rails.root.join("app/views/**/*.erb")].flat_map do |archivo|
      File.read(archivo).scan(/material-symbols-outlined[^>]*>\s*([a-z][a-z0-9_]*)\s*</).flatten
    end.to_set

    faltan = usados - @disponibles
    assert_empty faltan, "Íconos sin incluir en la fuente: #{faltan.to_a.sort.join(', ')}. Corre `bin/rails iconos:subset`."
  end

  test "los íconos que arman los helpers y catálogos están en el subconjunto" do
    # `icon: "x"` / `icono: "x"` en Ruby: PostsHelper, plantillas de vitrina,
    # catálogo de logros, etc.
    usados = Dir[Rails.root.join("app/**/*.rb")].flat_map do |archivo|
      File.read(archivo).scan(/\bicono?:\s*"([a-z][a-z0-9_]*)"/).flatten
    end.to_set
    assert_includes usados, "handyman" # el escaneo encuentra los de PostsHelper

    faltan = usados - @disponibles
    assert_empty faltan, "Íconos sin incluir en la fuente: #{faltan.to_a.sort.join(', ')}. Corre `bin/rails iconos:subset`."
  end
end
