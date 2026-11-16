require "test_helper"

class ReactivacionMailerTest < ActionMailer::TestCase
  setup { setup_economy! }

  test "sin publicaciones invita a crear la vitrina y responde a la casilla de contacto" do
    previo = ENV["CONTACTO_EMAIL"]
    ENV["CONTACTO_EMAIL"] = "contacto@example.org"
    user = create_user(username: "vecina")
    mail = ReactivacionMailer.vuelve(user)

    assert_equal [ user.email_address ], mail.to
    assert_equal [ "contacto@example.org" ], mail.reply_to
    assert_match "¿te ayudo a armar tu vitrina", mail.subject
    assert_match "/bienvenida/vitrina", mail.text_part.body.to_s
    assert_match "/invita/vecina", mail.html_part.body.to_s
  ensure
    ENV["CONTACTO_EMAIL"] = previo
  end

  test "con publicaciones habla de activar la vitrina" do
    user = create_user(username: "maestro")
    create_post(user: user)
    assert_match "ya está lista para compartir", ReactivacionMailer.vuelve(user).subject
  end
end
