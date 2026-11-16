require "test_helper"
require "test_helpers/session_test_helper"

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    setup_economy!
  end

  test "GET /feedback/new accesible sin sesión" do
    get new_feedback_path
    assert_response :success
    assert_match "Tu opinión nos sirve", response.body
  end

  test "POST /feedback persiste y redirige con notice" do
    assert_difference -> { Feedback.count }, 1 do
      post feedbacks_path, params: { feedback: { kind: "idea", body: "Sería bueno tener notificaciones por email." } }
    end
    assert_redirected_to root_path
    assert_match "leemos cada feedback", flash[:notice]

    fb = Feedback.last
    assert_equal "idea", fb.kind
    assert_nil fb.user_id
    assert_equal "pending", fb.status
  end

  test "POST /feedback con sesión asocia user_id" do
    user = create_user(username: "betauser")
    sign_in_as(user)

    post feedbacks_path, params: { feedback: { kind: "bug", body: "El botón de explore no carga." } }
    assert_redirected_to root_path
    assert_equal user.id, Feedback.last.user_id
  end

  test "POST /feedback con body vacío re-renderea form" do
    assert_no_difference -> { Feedback.count } do
      post feedbacks_path, params: { feedback: { kind: "idea", body: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "GET /feedback requiere moderador" do
    user = create_user(username: "regular")
    sign_in_as(user)

    get feedbacks_path
    assert_redirected_to root_path
    assert_match "Sólo moderadores", flash[:alert]
  end

  test "GET /feedback accesible para moderador L3+" do
    mod = create_user(username: "modtest")
    mod.grant_moderation!
    sign_in_as(mod)

    Feedback.create!(kind: :bug, body: "Hay un bug en explore.", status: :pending)
    get feedbacks_path
    assert_response :success
    assert_match "Hay un bug en explore", response.body
  end

  test "PATCH /feedback/:id actualiza status (moderador)" do
    mod = create_user(username: "modup")
    mod.grant_moderation!
    sign_in_as(mod)

    fb = Feedback.create!(kind: :idea, body: "Idea brillante.", status: :pending)
    patch feedback_path(fb), params: { status: "done" }
    assert_redirected_to feedbacks_path
    assert_equal "done", fb.reload.status
  end

  test "GET /feedback/:id marca pending → read" do
    mod = create_user(username: "modshow")
    mod.grant_moderation!
    sign_in_as(mod)

    fb = Feedback.create!(kind: :other, body: "Hola.", status: :pending)
    get feedback_path(fb)
    assert_response :success
    assert_equal "read", fb.reload.status
  end
end
