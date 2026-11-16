require "test_helper"

class AchievementCatalogTest < ActiveSupport::TestCase
  setup { ensure_base_categories! }

  test "usuario nuevo: catálogo no vacío y email verificado desbloqueado" do
    u   = create_user(email_verified: true)
    cat = AchievementCatalog.new(u)

    assert cat.total.positive?
    assert_operator cat.unlocked_count, :<=, cat.total
    assert cat.badges.find { |b| b.key == "email_verified" }.unlocked
    assert_not cat.badges.find { |b| b.key == "first_post" }.unlocked
  end

  test "publicar desbloquea 'primera publicación'" do
    u = create_user
    create_post(user: u)
    cat = AchievementCatalog.new(u)
    assert cat.badges.find { |b| b.key == "first_post" }.unlocked
  end

  test "un badge con progreso reporta porcentaje entre 0 y 100" do
    b = AchievementCatalog.new(create_user).badges.find { |x| x.key == "network_weaver" }
    assert b.progress?
    assert_includes 0..100, b.percent
  end

  test "grouped respeta el orden declarado de categorías" do
    keys = AchievementCatalog.new(create_user).grouped.keys
    assert_equal keys.sort_by { |c| AchievementCatalog::CATEGORIES.index(c) }, keys
  end
end
