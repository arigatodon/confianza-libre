require "test_helper"

# Lo que ve la gente sobre la economía: palabras, no tablas ni decimales.
class EconomiaHelperTest < ActionView::TestCase
  include EconomiaHelper

  test "creditos usa espacio duro entre el número y la C" do
    assert_equal "1.250 C", creditos(1250)
  end

  test "contar pluraliza en español" do
    assert_equal "1 intercambio", contar(1, "intercambio")
    assert_equal "2 intercambios", contar(2, "intercambio")
    assert_equal "3 personas nuevas", contar(3, "persona nueva", "personas nuevas")
  end

  test "estrellas en palabras, sin decimales" do
    assert_equal "4 estrellas", estrellas_en_palabras(4.0)
    assert_equal "3 estrellas y media", estrellas_en_palabras(3.5)
    assert_equal "más de 4 estrellas", estrellas_en_palabras(4.3)
  end

  test "los requisitos de nivel se vuelven pasos en palabras, primero lo pendiente" do
    progresion = [
      { label: "Interacciones completadas", current: 1, required: 3, met: false },
      { label: "Contrapartes distintas", current: 2, required: 2, met: true },
      { label: "Trust score", current: 3.0, required: 3.5, met: false, unit: "★" },
      { label: "Antigüedad (días)", current: 6, required: 7, met: false },
      { label: "Verificación", current: "email", required: "email", met: true, kind: :enum }
    ]
    pasos = pasos_para_subir(progresion)

    assert_equal [
      "Cierra 2 intercambios más",
      "Que tus reseñas lleguen a 3 estrellas y media",
      "Espera 1 día más",
      "Ya intercambiaste con 2 personas distintas",
      "Verificaste tu email"
    ], pasos.map { |p| p[:texto] }
    refute pasos.any? { |p| p[:texto].match?(/trust|\d+ \/ \d+/i) }
  end

  test "estrellas se dibujan con texto para lectores de pantalla" do
    html = estrellas(3.5)
    assert_includes html, "3,5 de 5 estrellas"
    assert_includes html, "star_half"
  end
end
