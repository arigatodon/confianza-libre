require "test_helper"

class SponsorTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    # sin override de sponsor_floor_boost: cae al default del controller (5).
    @padrino = create_user(username: "padrino")
  end

  test "registro con sponsor_code válido setea el sponsor y aplica el bonus al floor" do
    post users_path, params: { user: {
      username: "ahijado", email_address: "ahijado@test.local",
      password: "password123", password_confirmation: "password123",
      sponsor_code: "padrino"
    } }
    assert_redirected_to root_path

    ahijado = User.find_by(username: "ahijado")
    assert_equal @padrino.id, ahijado.sponsor_id
    assert_equal 5, ahijado.sponsor_bonus_floor
  end

  test "sponsor_code admite '@' como prefijo" do
    post users_path, params: { user: {
      username: "ahijada", email_address: "ahijada@test.local",
      password: "password123", password_confirmation: "password123",
      sponsor_code: "@padrino"
    } }
    assert_redirected_to root_path
    assert_equal @padrino.id, User.find_by(username: "ahijada").sponsor_id
  end

  test "sponsor_code inexistente bloquea el registro con error explícito" do
    post users_path, params: { user: {
      username: "ahuerfano", email_address: "ahuerfano@test.local",
      password: "password123", password_confirmation: "password123",
      sponsor_code: "no_existe"
    } }
    assert_response :unprocessable_entity
    assert_nil User.find_by(username: "ahuerfano")
    assert_match(/no encontramos a tu padrino/i, response.body)
  end

  test "sponsor_code en blanco se ignora y el registro funciona sin sponsor" do
    post users_path, params: { user: {
      username: "solitario", email_address: "solitario@test.local",
      password: "password123", password_confirmation: "password123",
      sponsor_code: ""
    } }
    assert_redirected_to root_path
    u = User.find_by(username: "solitario")
    assert_nil u.sponsor_id
    assert_equal 0, u.sponsor_bonus_floor
  end

  test "CreditLimitCalculator suma el sponsor_bonus_floor al floor base del nivel" do
    @padrino.update!(sponsor_bonus_floor: 42)
    limits = CreditLimitCalculator.call(@padrino)
    base   = CreditLimitCalculator::LEVELS[1][:credit_floor]
    assert_equal base + 42, limits[:credit_floor]
  end
end
