require "test_helper"

class DifundirPostJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::ConstantStubbing
  include Factories

  setup do
    setup_economy!
    @user = create_user(username: "difusor")
  end

  # --------------------------------------------------------- encolado (modelo)
  test "crear post con difundir encola el job" do
    assert_enqueued_with(job: DifundirPostJob) do
      create_post(user: @user, difundir: true)
    end
  end

  test "crear post sin difundir no encola nada" do
    assert_no_enqueued_jobs(only: DifundirPostJob) do
      create_post(user: @user, difundir: false)
    end
  end

  test "borrador con difundir no encola hasta publicarse" do
    post = nil
    assert_no_enqueued_jobs(only: DifundirPostJob) do
      post = create_post(user: @user, difundir: true, status: :draft)
    end
    assert_enqueued_with(job: DifundirPostJob) { post.update!(status: :published) }
  end

  test "editar texto de un post ya difundido no reencola" do
    post = create_post(user: @user, difundir: true)
    assert_no_enqueued_jobs(only: DifundirPostJob) do
      post.update!(description: "texto nuevo")
    end
  end

  # ----------------------------------------------------------------- ejecución
  test "sin redes configuradas no crea broadcasts" do
    post = create_post(user: @user, difundir: true)
    DifundirPostJob.perform_now(post.id)
    assert_equal 0, post.social_broadcasts.count
  end

  test "publica en la red configurada y registra el envío" do
    post = create_post(user: @user, difundir: true)

    adaptador = Class.new do
      const_set(:NETWORK, "fake")
      def self.configurada? = true
      def publicar(tarjeta_png:, texto:, url:, tarjeta_url: nil)
        raise "sin tarjeta" if tarjeta_png.blank?
        raise "sin url" unless url.include?("/posts/")
        raise "sin tarjeta_url" unless tarjeta_url.to_s.end_with?("/tarjeta.png")
        "id-externo-1"
      end
    end

    stub_const(DifundirPostJob, :ADAPTADORES, [ adaptador ]) do
      DifundirPostJob.perform_now(post.id)
    end

    difusion = post.social_broadcasts.find_by!(network: "fake")
    assert_equal "enviado", difusion.status
    assert_equal "id-externo-1", difusion.external_id
    assert difusion.sent_at.present?
  end

  test "no reenvía a una red ya enviada" do
    post = create_post(user: @user, difundir: true)
    post.social_broadcasts.create!(network: "fake", status: "enviado", external_id: "ya")

    llamadas = 0
    adaptador = Class.new do
      const_set(:NETWORK, "fake")
      def self.configurada? = true
    end
    adaptador.define_method(:publicar) { |**| llamadas += 1; "nuevo" }

    stub_const(DifundirPostJob, :ADAPTADORES, [ adaptador ]) do
      DifundirPostJob.perform_now(post.id)
    end

    assert_equal 0, llamadas
    assert_equal "ya", post.social_broadcasts.find_by!(network: "fake").external_id
  end

  test "si una red falla queda registrado el error y no rompe el job" do
    post = create_post(user: @user, difundir: true)

    adaptador = Class.new do
      const_set(:NETWORK, "fake")
      def self.configurada? = true
      def publicar(**) = raise("API caída")
    end

    stub_const(DifundirPostJob, :ADAPTADORES, [ adaptador ]) do
      assert_nothing_raised { DifundirPostJob.perform_now(post.id) }
    end

    difusion = post.social_broadcasts.find_by!(network: "fake")
    assert_equal "error", difusion.status
    assert_match "API caída", difusion.error_message
  end

  # ------------------------------------------------------- imagen IA de fondo

  # Doble de Difusion::ImagenIa: configurada, y genera lo que diga el bloque.
  def imagen_ia_falsa(&generar)
    resultado = Difusion::ImagenIa::Resultado
    Class.new do
      define_singleton_method(:configurada?) { true }
      define_singleton_method(:new) do
        instancia = Object.new
        instancia.define_singleton_method(:generar) { |_post| generar.call(resultado) }
        instancia
      end
    end
  end

  def adaptador_fake
    Class.new do
      const_set(:NETWORK, "fake")
      def self.configurada? = true
      def publicar(**) = "id-externo"
    end
  end

  test "post informativo sin foto genera y adjunta el fondo IA" do
    post = create_post(user: @user, difundir: true, kind: "noticia")
    fake = imagen_ia_falsa { |r| r.new(bytes: "png-falso", mime_type: "image/png") }

    stub_const(DifundirPostJob, :ADAPTADORES, [ adaptador_fake ]) do
      stub_const(Difusion, :ImagenIa, fake) do
        DifundirPostJob.perform_now(post.id)
      end
    end

    assert post.reload.imagen_difusion.attached?
    assert_equal "image/png", post.imagen_difusion.content_type
  end

  test "post no informativo no genera fondo IA aunque esté configurada" do
    post = create_post(user: @user, difundir: true, kind: "venta")
    fake = imagen_ia_falsa { raise "no debería llamarse" }

    stub_const(DifundirPostJob, :ADAPTADORES, [ adaptador_fake ]) do
      stub_const(Difusion, :ImagenIa, fake) do
        assert_nothing_raised { DifundirPostJob.perform_now(post.id) }
      end
    end

    assert_not post.reload.imagen_difusion.attached?
  end

  test "si la imagen IA falla la difusión sigue igual" do
    post = create_post(user: @user, difundir: true, kind: "noticia")
    fake = imagen_ia_falsa { raise "Gemini caído" }

    stub_const(DifundirPostJob, :ADAPTADORES, [ adaptador_fake ]) do
      stub_const(Difusion, :ImagenIa, fake) do
        assert_nothing_raised { DifundirPostJob.perform_now(post.id) }
      end
    end

    assert_not post.reload.imagen_difusion.attached?
    assert_equal "enviado", post.social_broadcasts.find_by!(network: "fake").status
  end

  test "post oculto por moderación no se difunde" do
    post = create_post(user: @user, difundir: true)
    post.update_columns(hidden_at: Time.current)

    DifundirPostJob.perform_now(post.id)
    assert_equal 0, post.social_broadcasts.count
  end
end
