require "test_helper"

module Api
  module V1
    class PostsControllerTest < ActionDispatch::IntegrationTest
      include ActiveJob::TestHelper

      setup do
        setup_economy!
        @user = create_user(username: "panadera", latitude: -33.05, longitude: -71.44)
        @key, @token = ApiKey.generate_for(@user, name: "Netlify")
      end

      def headers(token = @token)
        { "Authorization" => "Bearer #{token}", "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json" }
      end

      def json = JSON.parse(response.body)

      # ------------------------------------------------------------ autenticación
      test "sin clave responde 401 en JSON" do
        get api_v1_me_path
        assert_response :unauthorized
        assert_match "API key", json["error"]
      end

      test "clave revocada responde 401" do
        @key.revoke!
        get api_v1_me_path, headers: headers
        assert_response :unauthorized
      end

      test "acepta la clave también por X-Api-Key" do
        get api_v1_me_path, headers: { "X-Api-Key" => @token }
        assert_response :success
        assert_equal "panadera", json["username"]
        assert_equal @key.masked, json.dig("api_key", "prefix")
      end

      test "email sin verificar responde 403" do
        @user.update!(email_verified_at: nil)
        get api_v1_me_path, headers: headers
        assert_response :forbidden
        assert_match "Verifica tu email", json["error"]
      end

      test "usar la clave registra last_used_at" do
        get api_v1_me_path, headers: headers
        assert @key.reload.last_used_at
      end

      # ------------------------------------------------------------------ crear
      test "crea una publicación publicada, ubicada en el usuario y con difusión por defecto" do
        assert_enqueued_with(job: DifundirPostJob) do
          post api_v1_posts_path, headers: headers, params: {
            title: "Pan amasado de campo",
            description: "Sábados en la mañana",
            category: "productos",
            suggested_credits: 20
          }.to_json
        end
        assert_response :created

        post = Post.last
        assert_equal @user, post.user
        assert_equal "Pan amasado de campo", post.title
        assert_equal "Productos", post.category.name
        assert_equal "venta", post.kind, "kind se infiere de la categoría"
        assert post.published?
        assert post.difundir?
        assert_equal 20, post.suggested_credits
        assert_in_delta(-33.05, post.latitude, 0.0001)
        assert_in_delta(-71.44, post.longitude, 0.0001)

        assert_equal post.id, json["id"]
        assert_equal post_url(post), json["url"]
        assert_equal "productos", json["category"]
        assert_match %r{/tarjeta\.png\z}, json["tarjeta_url"]
        assert_equal api_v1_post_url(post), response.headers["Location"]
      end

      test "difundir false no encola la difusión" do
        assert_no_enqueued_jobs(only: DifundirPostJob) do
          post api_v1_posts_path, headers: headers, params: { title: "Silencioso", difundir: false }.to_json
        end
        assert_response :created
        assert_not Post.last.difundir?
      end

      test "categoría por defecto es servicios y acepta el nombre con mayúsculas" do
        post api_v1_posts_path, headers: headers, params: { title: "Gasfitería" }.to_json
        assert_equal "servicios", json["category"]

        post api_v1_posts_path, headers: headers, params: { title: "Torta", category: "Productos" }.to_json
        assert_equal "productos", json["category"]
      end

      test "categoría desconocida responde 422 con las válidas" do
        post api_v1_posts_path, headers: headers, params: { title: "X", category: "criptomonedas" }.to_json
        assert_response :unprocessable_entity
        assert_match "criptomonedas", json["error"]
        assert_match "servicios", json["detalles"].join
        assert_equal 0, @user.posts.count
      end

      test "acepta el envoltorio post: {} y convierte km a metros" do
        post api_v1_posts_path, headers: headers, params: {
          post: { title: "Con envoltorio", visibility_radius_km: 2.5, pedido: true, latitude: -33.4, longitude: -70.6 }
        }.to_json
        assert_response :created
        p = Post.last
        assert_equal 2500, p.visibility_radius
        assert p.pedido?
        assert_in_delta(-33.4, p.latitude, 0.0001)
        assert_equal 2.5, json["visibility_radius_km"]
      end

      test "sin título responde 422 con los errores del modelo" do
        post api_v1_posts_path, headers: headers, params: { description: "sin título" }.to_json
        assert_response :unprocessable_entity
        assert json["detalles"].any? { |d| d =~ /Title|Título/i }
      end

      test "estado desconocido responde 422" do
        post api_v1_posts_path, headers: headers, params: { title: "X", status: "volando" }.to_json
        assert_response :unprocessable_entity
        assert_match "volando", json["error"]
      end

      test "image_url válida queda adjunta a la publicación" do
        imagen = ImagenRemota::Imagen.new(io: File.open(file_fixture("sample.png")), filename: "sample.png", content_type: "image/png")
        con_stub(ImagenRemota, :descargar, imagen) do
          post api_v1_posts_path, headers: headers, params: { title: "Con foto", image_url: "https://misitio.cl/foto.png" }.to_json
        end
        assert_response :created
        assert_equal 1, Post.last.media.count
        assert_equal 1, json["imagenes"].size
      end

      test "image_url que falla responde 422 y no crea la publicación" do
        fallo = ->(_url) { raise ImagenRemota::Error, "la URL no apunta a una imagen" }
        con_stub(ImagenRemota, :descargar, fallo) do
          assert_no_difference -> { Post.count } do
            post api_v1_posts_path, headers: headers, params: { title: "Con foto rota", image_url: "https://misitio.cl/pagina" }.to_json
          end
        end
        assert_response :unprocessable_entity
        assert_match "image_url", json["error"]
      end

      # ------------------------------------------------------ listar / ver / editar
      test "index lista solo las publicaciones propias con su difusión" do
        mio  = create_post(user: @user, title: "Mío")
        mio.social_broadcasts.create!(network: "instagram", status: "enviado", external_id: "ig1", sent_at: Time.current)
        create_post(user: create_user, title: "Ajeno")

        get api_v1_posts_path, headers: headers
        assert_response :success
        titulos = json["posts"].map { |p| p["title"] }
        assert_includes titulos, "Mío"
        assert_not_includes titulos, "Ajeno"
        difusion = json["posts"].find { |p| p["id"] == mio.id }["difusion"]
        assert_equal [ { "network" => "instagram", "status" => "enviado" } ], difusion.map { |d| d.slice("network", "status") }
      end

      test "show acepta id o slug y no muestra publicaciones ajenas" do
        mio = create_post(user: @user, title: "Clases de guitarra")
        get api_v1_post_path(mio.slug), headers: headers
        assert_response :success
        assert_equal mio.id, json["id"]

        ajeno = create_post(user: create_user)
        get api_v1_post_path(ajeno.id), headers: headers
        assert_response :not_found
      end

      test "update cambia campos y estado sin tocar la difusión" do
        mio = create_post(user: @user, title: "Viejo", difundir: false)
        patch api_v1_post_path(mio), headers: headers, params: { title: "Nuevo", status: "paused" }.to_json
        assert_response :success
        mio.reload
        assert_equal "Nuevo", mio.title
        assert mio.paused?
        assert_not mio.difundir?, "editar no activa la difusión por su cuenta"
      end

      test "destroy elimina la publicación propia" do
        mio = create_post(user: @user)
        assert_difference -> { Post.count }, -1 do
          delete api_v1_post_path(mio), headers: headers
        end
        assert_response :no_content
      end
    end
  end
end
