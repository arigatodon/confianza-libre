require "test_helper"

class TrustScoreCalculatorTest < ActiveSupport::TestCase
  setup do
    setup_economy!
    @user = create_user(username: "rated")
  end

  test "devuelve NEUTRAL_DEFAULT (3.0) cuando el user no tiene reviews recibidas" do
    assert_equal TrustScoreCalculator::NEUTRAL_DEFAULT, TrustScoreCalculator.call(@user)
  end

  test "sigue en NEUTRAL_DEFAULT hasta acumular MIN_DISTINCT_REVIEWERS (3) reviewers distintos" do
    2.times do |n|
      reviewer = create_user(username: "rev#{n}")
      i = create_interaction(post: create_post(user: @user), sender: reviewer, receiver: @user)
      i.update_columns(status: 3)
      create_review(interaction: i.reload, reviewer: reviewer, score: 5)
    end
    assert_equal TrustScoreCalculator::NEUTRAL_DEFAULT, TrustScoreCalculator.call(@user)
  end

  test "calcula avg ponderado cuando hay ≥3 reviewers distintos" do
    # 3 reviews con weight = trust_weight de Servicios (3): scores 5, 4, 3.
    # avg = (5*3 + 4*3 + 3*3) / 9 = 4.0
    3.times do |n|
      reviewer = create_user(username: "rev#{n}")
      i = create_interaction(post: create_post(user: @user), sender: reviewer, receiver: @user)
      i.update_columns(status: 3)
      create_review(interaction: i.reload, reviewer: reviewer, score: 5 - n)
    end
    assert_in_delta 4.0, TrustScoreCalculator.call(@user), 0.01
  end

  test "respeta pesos distintos por categoría" do
    info_cat = Category.find_or_create_by!(name: "Información") do |c|
      c.trust_weight = 1; c.allows_credit = false; c.max_credit_multiplier = 0.2
    end
    serv_cat = Category.find_by!(name: "Servicios")
    # 2 reviews score=5 con weight 3 (Servicios), 1 review score=1 con weight 1 (Información).
    # avg = (5*3 + 5*3 + 1*1) / (3+3+1) = 31/7 = 4.43
    [ serv_cat, serv_cat, info_cat ].each_with_index do |cat, n|
      reviewer = create_user(username: "rr#{n}")
      post = create_post(user: @user, category: cat)
      i = create_interaction(post: post, sender: reviewer, receiver: @user)
      i.update_columns(status: 3)
      create_review(interaction: i.reload, reviewer: reviewer, score: (cat == serv_cat ? 5 : 1))
    end
    assert_in_delta 4.43, TrustScoreCalculator.call(@user), 0.01
  end
end
