require "test_helper"

# Fase 1.3 — los gates de moderación usan el flag moderator?, no el nivel.
class ModerationAccessTest < ActionDispatch::IntegrationTest
  setup { setup_economy! }

  test "un usuario de nivel alto SIN el flag no accede a /moderacion" do
    ricachon = create_user(username: "ricoperonomod")
    ricachon.update_columns(level: 5)
    sign_in_as(ricachon)
    get moderation_path
    assert_redirected_to root_path
  end

  test "un moderador (flag) accede a /moderacion aunque sea de nivel bajo" do
    mod = create_user(username: "modhumilde")
    mod.update_columns(level: 1)
    mod.grant_moderation!
    sign_in_as(mod)
    get moderation_path
    assert_response :success
  end
end
