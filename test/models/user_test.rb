require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "crear un usuario le crea su cuenta de créditos en saldo 0" do
    setup_economy!
    user = create_user(username: "utcuenta")
    assert user.credit_account.present?
    assert_equal 0, user.credit_account.cached_balance
    assert_equal "user", user.credit_account.account_type
  end

  test "mark_email_verified! sube verification_level a email sin pisar niveles mayores" do
    setup_economy!
    user = create_user(username: "utverif", email_verified: false)
    assert user.verification_unverified?

    user.mark_email_verified!
    assert user.email_verified?
    assert user.verification_email?

    # Un nivel superior no se degrada al re-verificar el email.
    user.update_columns(verification_level: User::VERIFICATION_LEVELS[:identity],
                        email_verified_at: nil)
    user.mark_email_verified!
    assert user.reload.verification_identity?
  end

  test "mark_email_verified! es idempotente" do
    setup_economy!
    user = create_user(username: "utidem", email_verified: false)
    user.mark_email_verified!
    first_at = user.email_verified_at
    user.mark_email_verified!
    assert_equal first_at, user.reload.email_verified_at
  end

  test "available_balance = cached_balance + credit_floor" do
    setup_economy!
    user = create_user(username: "utsaldo")
    user.credit_account.update!(cached_balance: -15)
    assert_equal(-15 + user.credit_floor.to_i, user.available_balance)
  end

  test "whatsapp se normaliza y valida formato internacional" do
    user = User.new(whatsapp: "+56 9 1234-5678")
    assert_equal "+56912345678", user.whatsapp

    user.whatsapp = "no-es-numero"
    user.valid?
    assert user.errors[:whatsapp].any?

    user.whatsapp = ""
    user.valid?
    assert_empty user.errors[:whatsapp]
  end

  test "vitrina_plantilla y accent_color solo aceptan valores del catálogo" do
    user = User.new(vitrina_plantilla: "tienda", accent_color: "#0f5238")
    user.valid?
    assert_empty user.errors[:vitrina_plantilla]
    assert_empty user.errors[:accent_color]

    user.vitrina_plantilla = "inventada"
    user.accent_color = "#ff0000"
    user.valid?
    assert user.errors[:vitrina_plantilla].any?
    assert user.errors[:accent_color].any?
  end

  test "plantilla devuelve la config del rubro o la clásica por defecto" do
    assert_equal "Catálogo", User.new(vitrina_plantilla: "tienda").plantilla[:seccion_posts]
    assert User.new(vitrina_plantilla: "tienda").plantilla[:posts_primero]
    assert_equal "Publicaciones", User.new.plantilla[:seccion_posts]
    refute User.new.plantilla[:posts_primero]
  end

  test "los links de la vitrina solo aceptan http/https" do
    user = User.new(link_web: "https://ejemplo.cl")
    user.valid?
    assert_empty user.errors[:vitrina_links]

    user.link_web = "javascript:alert(1)"
    user.valid?
    assert user.errors[:vitrina_links].any?, "javascript: debe rechazarse (XSS en el perfil público)"
  end

  test "whatsapp_url arma el link wa.me con el contexto de la vitrina" do
    user = User.new(username: "almacenlaesquina", whatsapp: "+56912345678")
    assert_includes user.whatsapp_url, "wa.me/56912345678"
    assert_includes user.whatsapp_url, "text="
    assert_nil User.new(username: "sinfono").whatsapp_url
  end

  test "moderator? depende del flag moderator_since, no del nivel económico" do
    setup_economy!
    user = create_user(username: "utmod")
    refute user.moderator?
    user.update_columns(level: 5) # nivel máximo, sin flag
    refute user.moderator?, "subir de nivel no otorga moderación (Fase 1.3)"
    user.grant_moderation!
    assert user.moderator?
    user.revoke_moderation!
    refute user.moderator?
  end
end
