require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  setup do
    setup_economy!
    @sender   = create_user(username: "rev_sender")
    @receiver = create_user(username: "rev_receiver")
    @post     = create_post(user: @receiver, category: Category.find_by!(name: "Servicios"))
    @interaction = create_completed_interaction(sender: @sender, receiver: @receiver, agreed_credits: 0)
  end

  test "review sender→receiver: categoría = categoría del post" do
    r = create_review(interaction: @interaction, reviewer: @interaction.sender, score: 5)
    assert_equal "Servicios", r.category.name
    assert_equal 3, r.category_weight  # snapshot del trust_weight
  end

  test "review receiver→sender (dueño del post): categoría = Cliente" do
    r = create_review(interaction: @interaction, reviewer: @interaction.receiver, score: 4)
    assert_equal "Cliente", r.category.name
    assert_equal 2, r.category_weight  # trust_weight de Cliente
  end

  test "Category.publishable excluye Cliente" do
    refute Category.publishable.exists?(name: "Cliente")
    assert Category.publishable.exists?(name: "Servicios")
  end
end
