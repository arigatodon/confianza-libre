require "test_helper"

class NewsMailerTest < ActionMailer::TestCase
  include Factories

  test "el digest sale con la campaña de difusión y los links clave" do
    setup_economy!
    user = create_user(username: "emprendedora")

    mail = NewsMailer.novedades_digest(user)
    assert_equal [ "emprendedora@test.local" ], mail.to
    assert_match(/viajan más lejos/i, mail.subject)

    html = mail.html_part.body.to_s
    assert_includes html, "t.me/confianzaWorld"
    assert_includes html, "/invita/emprendedora"
    assert_includes html, "Difundir en las redes de Confianza"
    assert_includes html, "Publicar lo que ofrezco"

    text = mail.text_part.body.to_s
    assert_includes text, "/invita/emprendedora"
  end

  test "la variante para no verificados abre con el link de verificación válido" do
    setup_economy!
    user = create_user(username: "dormido", email_verified: false)

    mail = NewsMailer.novedades_verifica(user)
    assert_equal [ "dormido@test.local" ], mail.to

    html = mail.html_part.body.to_s
    assert_includes html, "Verificar mi cuenta"
    assert_includes html, "manifiesto"

    # El token del mail tiene que ser canjeable de verdad.
    token = html[%r{/verificar-email/([^"]+)"}, 1]
    assert_equal user, User.find_by_token_for(:email_verification, CGI.unescape(token))
  end
end
