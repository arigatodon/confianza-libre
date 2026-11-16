require "test_helper"

class AvalTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    @curador1 = create_user(username: "curador1").tap { |u| u.grant_moderation! }
    @curador2 = create_user(username: "curador2").tap { |u| u.grant_moderation! }
    @curador3 = create_user(username: "curador3").tap { |u| u.grant_moderation! }
    @vecina   = create_user(username: "vecina")
  end

  test "un curador avala desde el perfil y la vecina recibe la notificación" do
    sign_in_as @curador1
    assert_difference "Endorsement.count", 1 do
      post endorsements_path(endorsed_id: @vecina.id)
    end
    assert_redirected_to profile_path(@vecina.username)
    assert @vecina.notifications.exists?(kind: "endorsement", actor_id: @curador1.id)
  end

  test "al juntar los avales requeridos la verificación sube a avalado por vecinos" do
    assert @vecina.verification_email?

    [ @curador1, @curador2 ].each { |c| Endorsement.create!(endorser: c, endorsed: @vecina) }
    assert @vecina.reload.verification_email?, "con 2 de 3 avales no debe subir"

    Endorsement.create!(endorser: @curador3, endorsed: @vecina)
    assert @vecina.reload.verification_phone?
  end

  test "el aval no baja a quien ya tiene identidad verificada" do
    @vecina.update_columns(verification_level: User::VERIFICATION_LEVELS[:identity])
    [ @curador1, @curador2, @curador3 ].each { |c| Endorsement.create!(endorser: c, endorsed: @vecina) }
    assert @vecina.reload.verification_identity?
  end

  test "nivel bajo no puede avalar, ni avalarse a sí mismo, ni repetir" do
    novato = create_user(username: "novatin")
    assert_not Endorsement.new(endorser: novato, endorsed: @vecina).valid?
    assert_not Endorsement.new(endorser: @curador1, endorsed: @curador1).valid?

    Endorsement.create!(endorser: @curador1, endorsed: @vecina)
    assert_not Endorsement.new(endorser: @curador1, endorsed: @vecina).valid?
  end

  test "no se puede avalar a cuentas sin email verificado" do
    fantasma = create_user(username: "fantasma", email_verified: false)
    e = Endorsement.new(endorser: @curador1, endorsed: fantasma)
    assert_not e.valid?
    assert_match(/no verificó su email/, e.errors.full_messages.to_sentence)
  end

  test "el perfil muestra el botón Avalar a curadores y el contador a todos" do
    sign_in_as @curador1
    get profile_path(@vecina.username)
    assert_match(/Avalar/, response.body)

    Endorsement.create!(endorser: @curador1, endorsed: @vecina)
    get profile_path(@vecina.username)
    assert_match(/Lo avalaste/, response.body)
    assert_match(/Avalado por 1 vecino/, response.body)
  end
end
