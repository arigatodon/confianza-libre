class CommentsController < ApplicationController
  before_action :set_post

  def create
    @comment = @post.comments.build(comment_params.merge(user: Current.session.user))
    if @comment.save
      # El append del comment al #comments lo hace el broadcasts_to del modelo
      # para todos los viewers (incluido este). Acá sólo reseteamos el form
      # para el sender — eso sí es per-request.
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("new_comment", partial: "comments/form",
            locals: { post: @post, comment: @post.comments.build })
        end
        format.html { redirect_to @post, notice: "Comentario publicado." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("new_comment",
            partial: "comments/form", locals: { post: @post, comment: @comment }),
            status: :unprocessable_entity
        end
        format.html { redirect_to @post, alert: @comment.errors.full_messages.to_sentence }
      end
    end
  end

  def destroy
    @comment = @post.comments.find(params[:id])
    if @comment.user_id == Current.session.user_id || @post.user_id == Current.session.user_id
      # El remove del DOM lo hace el broadcasts_to en destroy.
      @comment.destroy
      respond_to do |format|
        format.turbo_stream { head :no_content }
        format.html { redirect_to @post, notice: "Comentario eliminado." }
      end
    else
      redirect_to @post, alert: "No puedes borrar este comentario."
    end
  end

  private

  def set_post
    @post = Post.friendly.find(params[:post_id])
  end

  def comment_params
    params.expect(comment: [ :body ])
  end
end
