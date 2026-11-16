module Api
  module V1
    # Publicaciones del dueño de la API key.
    #
    #   GET    /api/v1/posts          lista (propias, cualquier estado)
    #   POST   /api/v1/posts          crea — por defecto publicada y con difusión
    #   GET    /api/v1/posts/:id      detalle (acepta id o slug)
    #   PATCH  /api/v1/posts/:id      edita / pausa / cierra
    #   DELETE /api/v1/posts/:id      elimina
    #
    # Crear una publicación aquí es exactamente lo mismo que hacerlo desde la
    # web: el modelo Post encola la difusión a redes (si difundir) y el
    # matching con vecinos. La API no tiene camino propio para eso.
    class PostsController < BaseController
      CAMPOS = %i[title description category pedido suggested_credits latitude longitude
                  visibility_radius_km difundir image_url status].freeze

      # Crear es lo costoso (tarjeta + redes): tope aparte, más bajo.
      rate_limit to: 30, within: 1.hour, only: :create,
                 by: -> { @api_key&.id || request.remote_ip },
                 with: -> { render_error("Máximo 30 publicaciones por hora por API key.", :too_many_requests) }

      before_action :set_post, only: %i[show update destroy]

      def index
        posts = current_user.posts.includes(:category, :social_broadcasts).order(created_at: :desc).limit(100)
        render json: { posts: posts.map { |p| serializar(p) } }
      end

      def show
        render json: serializar(@post)
      end

      def create
        atributos = atributos_desde(cuerpo, creando: true)
        return if performed?

        post = current_user.posts.build(atributos)
        adjuntar_imagen(post, cuerpo[:image_url])
        return if performed?

        if post.save
          render json: serializar(post), status: :created, location: api_v1_post_url(post)
        else
          render_error("La publicación no es válida.", :unprocessable_entity, detalles: post.errors.full_messages)
        end
      end

      def update
        atributos = atributos_desde(cuerpo, creando: false)
        return if performed?

        adjuntar_imagen(@post, cuerpo[:image_url])
        return if performed?

        if @post.update(atributos)
          render json: serializar(@post)
        else
          render_error("La publicación no es válida.", :unprocessable_entity, detalles: @post.errors.full_messages)
        end
      end

      def destroy
        @post.destroy
        head :no_content
      end

      private

      def set_post
        @post = current_user.posts.friendly.find(params[:id])
      end

      # Traduce el JSON del cliente a atributos del modelo. Defaults al crear:
      # publicada, con difusión, ubicada donde el usuario. Un error de datos
      # responde 422 y deja `performed?` en true.
      def atributos_desde(datos, creando:)
        permitidos = datos.permit(*CAMPOS)
        atributos  = {}

        atributos[:title]       = permitidos[:title]       if permitidos.key?(:title)
        atributos[:description] = permitidos[:description] if permitidos.key?(:description)

        if permitidos.key?(:category)
          categoria = resolver_categoria(permitidos[:category])
          return render_error(
            "Categoría desconocida: #{permitidos[:category]}.", :unprocessable_entity,
            detalles: [ "Usa una de: #{Category.publishable.order(:name).pluck(:slug).join(', ')}" ]
          ) unless categoria
          atributos[:category] = categoria
          atributos[:kind]     = nil # se vuelve a inferir de la categoría
        elsif creando
          atributos[:category] = Category.publishable.friendly.find("servicios")
        end

        atributos[:pedido]            = booleano(permitidos[:pedido])          if permitidos.key?(:pedido)
        atributos[:suggested_credits] = permitidos[:suggested_credits].presence&.to_i if permitidos.key?(:suggested_credits)
        atributos[:visibility_radius] = (permitidos[:visibility_radius_km].to_f * 1000).to_i if permitidos[:visibility_radius_km].present?

        if permitidos.key?(:latitude) || permitidos.key?(:longitude)
          atributos[:latitude]  = permitidos[:latitude].presence&.to_f
          atributos[:longitude] = permitidos[:longitude].presence&.to_f
        elsif creando
          atributos[:latitude]  = current_user.latitude
          atributos[:longitude] = current_user.longitude
        end

        if permitidos.key?(:status)
          estado = permitidos[:status].to_s
          return render_error(
            "Estado desconocido: #{estado}.", :unprocessable_entity,
            detalles: [ "Usa uno de: #{Post::STATUSES.keys.join(', ')}" ]
          ) unless Post::STATUSES.key?(estado.to_sym)
          atributos[:status] = estado
        elsif creando
          atributos[:status] = :published
        end

        atributos[:difundir] = permitidos.key?(:difundir) ? booleano(permitidos[:difundir]) : creando

        atributos
      end

      def resolver_categoria(valor)
        texto = valor.to_s.strip
        return nil if texto.blank?
        Category.publishable.find_by(slug: texto.parameterize) ||
          Category.publishable.find_by("LOWER(name) = ?", texto.downcase)
      end

      def booleano(valor)
        ActiveModel::Type::Boolean.new.cast(valor) == true
      end

      # Descarga image_url y la adjunta (se persiste con el save del post).
      # Si falla, 422 con el motivo y no se toca nada.
      def adjuntar_imagen(post, url)
        return if url.blank?
        imagen = ImagenRemota.descargar(url)
        post.media.attach(io: imagen.io, filename: imagen.filename, content_type: imagen.content_type)
      rescue ImagenRemota::Error => e
        render_error("No pudimos usar image_url: #{e.message}", :unprocessable_entity)
      end

      def serializar(post)
        {
          id:                post.id,
          slug:              post.slug,
          url:               post_url(post),
          tarjeta_url:       tarjeta_post_url(post) + ".png",
          title:             post.title,
          description:       post.description,
          category:          post.category&.slug,
          kind:              post.kind,
          status:            post.status,
          pedido:            post.pedido,
          suggested_credits: post.suggested_credits,
          latitude:          post.latitude,
          longitude:         post.longitude,
          visibility_radius_km: post.visibility_radius.to_f / 1000,
          difundir:          post.difundir,
          difusion:          post.social_broadcasts.map { |b|
            { network: b.network, status: b.status, external_id: b.external_id, sent_at: b.sent_at }
          },
          imagenes:          post.media.map { |m| url_for(m) },
          created_at:        post.created_at,
          updated_at:        post.updated_at
        }
      end
    end
  end
end
