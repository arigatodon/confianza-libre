require "test_helper"

class NovedadesTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    @admin  = create_user(username: "fundador", admin: true)
    @vecino = create_user(username: "vecina")
  end

  def publicar!(title: "Cambio de prueba publicado", kind: "cambio")
    Announcement.create!(
      title: title, kind: kind, user: @admin, published_at: Time.current,
      body:  "Un cuerpo suficientemente largo que explica el cambio en simple para toda la comunidad."
    )
  end

  test "el índice de novedades es público, indexable y con feed RSS" do
    novedad = publicar!
    get announcements_path
    assert_response :success
    assert_includes response.body, novedad.title
    assert_select "meta[name=description]"
    assert_select "link[rel=alternate][type='application/rss+xml']"

    get announcements_path(format: :rss)
    assert_response :success
    assert_includes response.body, novedad.title
  end

  test "el show emite JSON-LD BlogPosting y canonical" do
    novedad = publicar!
    get announcement_path(novedad)
    assert_response :success
    assert_includes response.body, "BlogPosting"
    assert_select "link[rel=canonical][href=?]", announcement_url(novedad)
  end

  test "el admin publica una novedad y un usuario común no puede" do
    sign_in_as @admin
    post announcements_path, params: {
      publish: "1",
      announcement: { kind: "cambio", title: "Novedad oficial del proyecto",
                      body: "Contamos en simple qué cambió y por qué le sirve a la red." }
    }
    novedad = Announcement.order(:id).last
    assert_redirected_to announcement_path(novedad)
    assert novedad.published?

    sign_in_as @vecino
    assert_no_difference "Announcement.count" do
      post announcements_path, params: {
        announcement: { kind: "cambio", title: "Intruso publica",
                        body: "Esto no debería poder publicarse jamás de los jamases." }
      }
    end
    assert_redirected_to announcements_path
  end

  test "los borradores no son visibles para el público" do
    borrador = Announcement.create!(
      title: "Borrador secreto", kind: "cambio", user: @admin,
      body: "Texto del borrador que todavía no está listo para publicarse."
    )
    get announcement_path(borrador)
    assert_redirected_to announcements_path

    get announcements_path
    refute_includes response.body, "Borrador secreto"
  end

  test "apoyar una consulta suma y vuelve a tocar quita el apoyo" do
    consulta = publicar!(title: "Consulta a la comunidad", kind: "consulta")
    sign_in_as @vecino

    post support_announcement_path(consulta)
    assert_equal 1, consulta.reload.supports_count

    post support_announcement_path(consulta)
    assert_equal 0, consulta.reload.supports_count
  end

  test "el sitemap incluye novedades publicadas y el manifiesto" do
    novedad = publicar!
    get sitemap_path
    assert_includes response.body, announcement_url(novedad)
    assert_includes response.body, manifesto_url
  end

  test "el manifiesto es público" do
    get manifesto_path
    assert_response :success
    assert_includes response.body, "samurái"
    assert_select "link[rel=canonical][href=?]", manifesto_url
  end

  test "la política de privacidad es pública" do
    get privacy_path
    assert_response :success
    assert_includes response.body, "no se venden"
    assert_select "link[rel=canonical][href=?]", privacy_url
  end
end
