require "test_helper"

class SavedSearchAlertJobTest < ActiveSupport::TestCase
  setup do
    setup_economy!
    @servicios = Category.find_by!(name: "Servicios")
    @productos = Category.find_by!(name: "Productos")

    @vecino = create_user(username: "vecino_alerta")
    @autor  = create_user(username: "autor_post")
  end

  # Centro en las coords por defecto del factory de posts (-33.5413, -71.6111).
  def alerta(**attrs)
    @vecino.saved_searches.create!({
      latitude: -33.5413, longitude: -71.6111, radius_km: 10
    }.merge(attrs))
  end

  def publicar(**attrs)
    create_post(user: @autor, category: @servicios, title: "Ofrezco gásfiter", **attrs)
  end

  test "un post que coincide con la alerta notifica al dueño" do
    alerta(query: "gasfiter", category: @servicios)
    post = publicar
    assert_difference -> { @vecino.notifications.where(kind: "saved_search").count }, 1 do
      SavedSearchAlertJob.perform_now(post.id)
    end
    assert_equal post, @vecino.notifications.where(kind: "saved_search").last.notifiable
  end

  test "no notifica al propio autor del post" do
    @autor.saved_searches.create!(category: @servicios, latitude: -33.5413, longitude: -71.6111, radius_km: 10)
    SavedSearchAlertJob.perform_now(publicar.id)
    assert_equal 0, @autor.notifications.where(kind: "saved_search").count
  end

  test "un post fuera del radio de la alerta NO notifica" do
    alerta(category: @servicios, radius_km: 1)
    # Post lejano (otra ciudad) fuera del radio de 1 km.
    post = publicar(latitude: -36.82, longitude: -73.05)
    SavedSearchAlertJob.perform_now(post.id)
    assert_equal 0, @vecino.notifications.where(kind: "saved_search").count
  end

  test "un post de otra categoría NO notifica" do
    alerta(category: @productos)
    SavedSearchAlertJob.perform_now(publicar.id) # publicar usa Servicios
    assert_equal 0, @vecino.notifications.where(kind: "saved_search").count
  end

  test "filtra por mercado (pedidos vs ofertas)" do
    alerta(market: "pedidos")
    SavedSearchAlertJob.perform_now(publicar(pedido: false).id) # oferta
    assert_equal 0, @vecino.notifications.where(kind: "saved_search").count

    SavedSearchAlertJob.perform_now(publicar(pedido: true, title: "Busco algo").id)
    assert_equal 1, @vecino.notifications.where(kind: "saved_search").count
  end

  test "no repite el aviso al mismo usuario por el mismo post" do
    alerta(category: @servicios)
    post = publicar
    SavedSearchAlertJob.perform_now(post.id)
    assert_no_difference -> { @vecino.notifications.where(kind: "saved_search").count } do
      SavedSearchAlertJob.perform_now(post.id)
    end
  end

  test "respeta el tope diario global de descubrimiento" do
    set_param(:match_daily_cap, 1)
    alerta(category: @servicios)
    # Ya consumió su cupo con un aviso de match hoy.
    Notification.create!(recipient: @vecino, kind: "match", body: "x",
                         notifiable: create_post(user: @autor, category: @servicios))
    SavedSearchAlertJob.perform_now(publicar.id)
    assert_equal 0, @vecino.notifications.where(kind: "saved_search").count
  end
end
