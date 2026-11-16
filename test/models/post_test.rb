require "test_helper"

class PostTest < ActiveSupport::TestCase
  include Factories

  setup do
    setup_economy!
    @owner = create_user(username: "owner1")
  end

  # ------------------------------------------------------------------ search
  test "search ignora blanks" do
    a = create_post(user: @owner, title: "Pan casero")
    b = create_post(user: @owner, title: "Verduras orgánicas")
    assert_equal [ a.id, b.id ].sort, Post.search(nil).pluck(:id).sort
    assert_equal [ a.id, b.id ].sort, Post.search("").pluck(:id).sort
  end

  test "search matchea por title case-insensitive" do
    a = create_post(user: @owner, title: "Pan Casero")
    _b = create_post(user: @owner, title: "Verduras orgánicas")
    assert_equal [ a.id ], Post.search("pan").pluck(:id)
    assert_equal [ a.id ], Post.search("CASERO").pluck(:id)
  end

  test "search matchea por description" do
    a = create_post(user: @owner, title: "Algo", description: "incluye delivery")
    _b = create_post(user: @owner, title: "Otro", description: "solo retiro")
    assert_equal [ a.id ], Post.search("delivery").pluck(:id)
  end

  test "search tolera acentos y raíz de palabra (gasfiter → gásfiter, gasfitería)" do
    con_acento = create_post(user: @owner, title: "Se ofrece gásfiter")
    derivada   = create_post(user: @owner, title: "Trabajos de gasfitería")
    _otro      = create_post(user: @owner, title: "Clases de guitarra")

    ids = Post.search("gasfiter").pluck(:id)
    assert_includes ids, con_acento.id
    assert_includes ids, derivada.id
    assert_equal 2, ids.size
  end

  test "search compone con los demás filtros" do
    servicios = Category.find_by!(name: "Servicios")
    productos = Category.find_by!(name: "Productos")
    a = create_post(user: @owner, title: "Reparación de bicicletas", category: servicios)
    _b = create_post(user: @owner, title: "Reparación de zapatos", category: productos)

    ids = Post.search("reparacion").in_category(servicios.id).pluck(:id)
    assert_equal [ a.id ], ids
  end

  # ------------------------------------------------------- ofertas / pedidos
  test "offers, pedidos y of_market separan las dos mitades del mercado" do
    oferta = create_post(user: @owner, title: "Ofrezco", pedido: false)
    pedido = create_post(user: @owner, title: "Busco", pedido: true)

    assert_equal [ oferta.id ], Post.offers.pluck(:id)
    assert_equal [ pedido.id ], Post.pedidos.pluck(:id)
    assert_equal [ oferta.id ], Post.of_market("ofertas").pluck(:id)
    assert_equal [ pedido.id ], Post.of_market("pedidos").pluck(:id)
    assert_equal [ oferta.id, pedido.id ].sort, Post.of_market(nil).pluck(:id).sort
  end

  # -------------------------------------------------------------- in_category
  test "in_category filtra y no-op cuando blank" do
    servicios = Category.find_by!(name: "Servicios")
    productos = Category.find_by!(name: "Productos")
    a = create_post(user: @owner, category: servicios)
    _b = create_post(user: @owner, category: productos)
    assert_equal [ a.id ], Post.in_category(servicios.id).pluck(:id)
    assert_equal 2,        Post.in_category(nil).count
    assert_equal 2,        Post.in_category("").count
  end

  # ------------------------------------------------------------------- of_kind
  test "of_kind valida contra KINDS y no-op cuando blank o inválido" do
    a = create_post(user: @owner, kind: "venta")
    _b = create_post(user: @owner, kind: "servicio")
    assert_equal [ a.id ], Post.of_kind("venta").pluck(:id)
    assert_equal 2,        Post.of_kind(nil).count
    assert_equal 2,        Post.of_kind("inexistente").count
  end

  # ------------------------------------------------------- with_max_credits
  test "with_max_credits incluye los nil y los <= máximo" do
    a = create_post(user: @owner, suggested_credits: 10)
    b = create_post(user: @owner, suggested_credits: 50)
    c = create_post(user: @owner, suggested_credits: nil)
    assert_equal [ a.id, c.id ].sort, Post.with_max_credits(30).pluck(:id).sort
    assert_equal [ a.id, b.id, c.id ].sort, Post.with_max_credits(100).pluck(:id).sort
    assert_equal 3, Post.with_max_credits(nil).count
  end
end
