require "test_helper"

class MatchNotificationJobTest < ActiveSupport::TestCase
  setup do
    setup_economy!
    @servicios = Category.find_by!(name: "Servicios")
    @productos = Category.find_by!(name: "Productos")

    # Oferente con una publicación de oferta en Servicios (coords del factory).
    @oferente = create_user(username: "oferente")
    create_post(user: @oferente, category: @servicios, title: "Ofrezco gasfitería", pedido: false)

    # Autor del pedido.
    @pidiente = create_user(username: "pidiente")
  end

  def publicar_pedido(user: @pidiente, category: @servicios, **attrs)
    create_post(user: user, category: category, pedido: true,
                title: "Busco gásfiter urgente", **attrs)
  end

  test "publicar un pedido avisa a un oferente cercano de la misma categoría" do
    pedido = publicar_pedido
    assert_difference -> { @oferente.notifications.where(kind: "match").count }, 1 do
      MatchNotificationJob.perform_now(pedido.id)
    end
    n = @oferente.notifications.where(kind: "match").last
    assert_equal pedido, n.notifiable
    assert_equal @pidiente, n.actor
  end

  test "no avisa al propio autor del pedido" do
    # El pidiente también ofrece algo en Servicios: no debe auto-notificarse.
    create_post(user: @pidiente, category: @servicios, title: "Yo ofrezco algo", pedido: false)
    pedido = publicar_pedido
    MatchNotificationJob.perform_now(pedido.id)
    assert_equal 0, @pidiente.notifications.where(kind: "match").count
  end

  test "no avisa a quien apagó los avisos de match" do
    @oferente.update!(match_notifications: false)
    pedido = publicar_pedido
    MatchNotificationJob.perform_now(pedido.id)
    assert_equal 0, @oferente.notifications.where(kind: "match").count
  end

  test "no avisa si la oferta del candidato está fuera de su radio" do
    @oferente.update!(match_radius_km: 1)
    # Su oferta lejana (otra ciudad) queda fuera de su radio de 1km.
    @oferente.posts.destroy_all
    create_post(user: @oferente, category: @servicios, title: "Oferta lejana",
                pedido: false, latitude: -36.8, longitude: -73.05)
    pedido = publicar_pedido
    MatchNotificationJob.perform_now(pedido.id)
    assert_equal 0, @oferente.notifications.where(kind: "match").count
  end

  test "no avisa de una categoría que el candidato no ofrece ni eligió" do
    pedido = publicar_pedido(category: @productos) # el oferente sólo tiene Servicios
    MatchNotificationJob.perform_now(pedido.id)
    assert_equal 0, @oferente.notifications.where(kind: "match").count
  end

  test "no repite el aviso al mismo usuario por el mismo pedido" do
    pedido = publicar_pedido
    MatchNotificationJob.perform_now(pedido.id)
    assert_no_difference -> { @oferente.notifications.where(kind: "match").count } do
      MatchNotificationJob.perform_now(pedido.id)
    end
  end

  test "respeta el tope diario gobernable match_daily_cap" do
    set_param(:match_daily_cap, 1)

    MatchNotificationJob.perform_now(publicar_pedido.id)
    # Segundo pedido el mismo día: ya llegó al tope de 1.
    MatchNotificationJob.perform_now(publicar_pedido.id)
    assert_equal 1, @oferente.notifications.where(kind: "match").count
  end

  test "publicar una oferta avisa a autores de pedidos cercanos compatibles" do
    buscador = create_user(username: "buscador")
    create_post(user: buscador, category: @servicios, title: "Busco algo en servicios", pedido: true)

    oferta = create_post(user: create_user(username: "nuevo_oferente"),
                         category: @servicios, title: "Ofrezco servicio nuevo", pedido: false)
    assert_difference -> { buscador.notifications.where(kind: "match").count }, 1 do
      MatchNotificationJob.perform_now(oferta.id)
    end
  end
end
