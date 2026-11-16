require "test_helper"

class ApiKeyTest < ActiveSupport::TestCase
  setup { @user = create_user }

  test "generate_for devuelve el token una vez y guarda solo el hash" do
    key, token = ApiKey.generate_for(@user, name: "Mi Netlify")

    assert token.start_with?("cw_")
    assert_equal "Mi Netlify", key.name
    assert_equal token.first(11), key.prefix
    assert_equal Digest::SHA256.hexdigest(token), key.token_digest
    assert_not_includes key.attributes.values, token
  end

  test "authenticate encuentra la clave activa por su token" do
    key, token = ApiKey.generate_for(@user)
    assert_equal key, ApiKey.authenticate(token)
    assert_nil ApiKey.authenticate("cw_otra")
    assert_nil ApiKey.authenticate(nil)
    assert_nil ApiKey.authenticate("sin_prefijo")
  end

  test "una clave revocada deja de autenticar" do
    key, token = ApiKey.generate_for(@user)
    key.revoke!
    assert_not key.active?
    assert_nil ApiKey.authenticate(token)
  end

  test "touch_usage! marca uso como mucho una vez por hora" do
    key, _ = ApiKey.generate_for(@user)
    key.touch_usage!
    primera = key.reload.last_used_at
    assert primera
    key.touch_usage!
    assert_equal primera, key.reload.last_used_at
  end

  test "el nombre vacío cae al default" do
    key, _ = ApiKey.generate_for(@user, name: "")
    assert_equal "Mi web", key.name
  end
end
