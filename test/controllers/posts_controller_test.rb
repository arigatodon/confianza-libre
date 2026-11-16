require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ensure_base_categories!
    @user = create_user
    sign_in_as(@user)
    @post = create_post(user: @user)
    @post.media.attach(
      io: File.open(file_fixture("sample.png")),
      filename: "sample.png",
      content_type: "image/png"
    )
    assert_equal 1, @post.media.count
  end

  test "editar sin subir archivo conserva la multimedia existente" do
    patch post_path(@post), params: { post: { title: "Título editado" } }
    assert_redirected_to @post

    @post.reload
    assert_equal "Título editado", @post.title
    assert_equal 1, @post.media.count, "no debe borrar la imagen al editar sin subir nada"
  end

  test "subir un archivo nuevo lo agrega sin reemplazar el existente" do
    patch post_path(@post), params: {
      post: {
        title: @post.title,
        media: [ fixture_file_upload("sample.png", "image/png") ]
      }
    }
    assert_redirected_to @post

    @post.reload
    assert_equal 2, @post.media.count, "el archivo nuevo debe sumarse, no reemplazar"
  end

  test "remove_media purga sólo el adjunto marcado" do
    attachment_id = @post.media_attachments.first.id

    perform_enqueued_jobs do
      patch post_path(@post), params: {
        post: { title: @post.title },
        remove_media: [ attachment_id ]
      }
    end
    assert_redirected_to @post

    @post.reload
    assert_equal 0, @post.media.count, "debe quitar el adjunto marcado"
  end
end
