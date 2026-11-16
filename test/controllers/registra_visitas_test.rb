require "test_helper"

class RegistraVisitasTest < ActionDispatch::IntegrationTest
  NAVEGADOR = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36".freeze

  test "una página HTML vista queda registrada sin datos personales" do
    assert_difference -> { PageView.count }, 1 do
      get root_path(utm_source: "afiche", utm_campaign: "feria"),
          headers: { "User-Agent" => NAVEGADOR, "Referer" => "https://l.instagram.com/x" }
    end
    vista = PageView.last
    assert_equal "/", vista.path
    assert_equal "l.instagram.com", vista.referrer_host
    assert_equal "afiche", vista.utm_source
    assert_equal "feria", vista.utm_campaign
    assert_not vista.logged_in
    assert_no_match(/127\.0\.0\.1/, vista.visitor_digest)
  end

  test "el mismo visitante da el mismo código dentro del día y otro al día siguiente" do
    hoy = PageView.digest_for(ip: "1.2.3.4", user_agent: NAVEGADOR)
    assert_equal hoy, PageView.digest_for(ip: "1.2.3.4", user_agent: NAVEGADOR)
    assert_not_equal hoy, PageView.digest_for(ip: "1.2.3.4", user_agent: NAVEGADOR, on: Date.tomorrow)
  end

  test "no cuenta bots, precargas de Turbo, JSON ni errores" do
    assert_no_difference -> { PageView.count } do
      get root_path, headers: { "User-Agent" => "Googlebot/2.1" }
      get root_path, headers: { "User-Agent" => NAVEGADOR, "X-Sec-Purpose" => "prefetch" }
      get root_path, headers: { "User-Agent" => NAVEGADOR, "Accept" => "application/json" }
      get "/no-existe-este-perfil", headers: { "User-Agent" => NAVEGADOR }
    end
  end

  test "/explorar lleva a /explore conservando la búsqueda" do
    get "/explorar?q=gasfiter"
    assert_redirected_to "/explore?q=gasfiter"
  end
end
