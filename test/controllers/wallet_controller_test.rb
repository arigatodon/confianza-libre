require "test_helper"

class WalletControllerTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    @user = create_user(username: "billetera_simple")
    sign_in_as(@user)
  end

  test "la billetera dice el saldo en palabras y qué falta para subir de nivel" do
    get wallet_path
    assert_response :success
    assert_match "Tienes", response.body
    assert_match "la comunidad te fía hasta", response.body
    assert_match "Para subir al Nivel 2:", response.body
    assert_match "Ofrece algo y gana créditos", response.body
  end

  test "la billetera no muestra jerga ni fracciones" do
    get wallet_path
    refute_match(/trust|tx_cap|cached|Rango del nivel|\d+ \/ \d+/i, response.body)
  end
end
