require "test_helper"

class CreditLimitCalculatorTest < ActiveSupport::TestCase
  setup do
    setup_economy!
    @user = create_user(username: "leveler")
  end

  test "nivel 1 por default — usuario nuevo sin actividad" do
    result = CreditLimitCalculator.call(@user)
    assert_equal 1, result[:level]
    assert_equal 100, result[:credit_floor]
    assert_equal 50,  result[:tx_cap]
    refute result.key?(:credit_ceiling), "el techo no depende del nivel"
  end

  test "sube a nivel 2 con 3 completadas, 2 distinct, trust 3.5, 7 días, email verified" do
    @user.update!(verification_level: :email, trust_score: 3.5, created_at: 8.days.ago)
    3.times { |n|
      other = create_user(username: "n2_#{n}")
      i = create_interaction(post: create_post(user: @user), sender: other, receiver: @user)
      i.update_columns(status: 3)
    }
    # 3 completadas con 3 senders distintos (≥ 2 requerido).
    result = CreditLimitCalculator.call(@user.reload)
    assert_equal 2, result[:level]
    assert_equal 250, result[:credit_floor]
    assert_equal 100, result[:tx_cap]
  end

  test "techo común: el mismo para todos los niveles y gobernable por parámetro" do
    alto = create_user(username: "alto")
    alto.update_columns(level: 5, credit_floor: 2_000, tx_cap: 500)
    assert_equal 5_000, @user.credit_ceiling
    assert_equal @user.credit_ceiling, alto.credit_ceiling

    set_param("credit_ceiling", 8_000)
    assert_equal 8_000, @user.reload.credit_ceiling
    assert_equal 8_000, alto.reload.credit_ceiling
  end

  test "la distancia entre el nivel 1 y el 5 es acotada (≤ 20×)" do
    l1 = CreditLimitCalculator::LEVELS[1]
    l5 = CreditLimitCalculator::LEVELS[5]
    assert l5[:credit_floor] <= 20 * l1[:credit_floor]
    assert l5[:tx_cap]       <= 20 * l1[:tx_cap]
    assert l5[:credit_floor] < CreditLimitCalculator.common_ceiling,
           "nadie debería poder deber más de lo que cualquiera puede acumular"
  end

  test "no sube a nivel 2 si falta antigüedad" do
    @user.update!(verification_level: :email, trust_score: 5.0)
    # Creado hoy mismo (default), no llega a 7 días.
    3.times { |n|
      other = create_user(username: "young_#{n}")
      i = create_interaction(post: create_post(user: @user), sender: other, receiver: @user)
      i.update_columns(status: 3)
    }
    result = CreditLimitCalculator.call(@user.reload)
    assert_equal 1, result[:level]
  end

  test "puede bajar de nivel si trust_score cae" do
    # Forzar nivel 2 condicions excepto trust.
    @user.update!(verification_level: :email, trust_score: 2.0, created_at: 30.days.ago)
    5.times { |n|
      other = create_user(username: "down_#{n}")
      i = create_interaction(post: create_post(user: @user), sender: other, receiver: @user)
      i.update_columns(status: 3)
    }
    result = CreditLimitCalculator.call(@user.reload)
    assert_equal 1, result[:level]  # trust 2.0 < 3.5 requerido para L2
  end

  test "progress_to_next_level marca criterios met/no met" do
    @user.update!(verification_level: :email, trust_score: 3.0, created_at: 1.day.ago)
    progress = CreditLimitCalculator.progress_to_next_level(@user)
    assert progress.is_a?(Array)
    trust_row = progress.find { |r| r[:label] == "Trust score" }
    refute trust_row[:met], "trust 3.0 < 3.5 requerido para L2"

    age_row = progress.find { |r| r[:label] == "Antigüedad (días)" }
    refute age_row[:met], "1 día < 7 días requerido para L2"
  end

  test "progress_to_next_level es nil en nivel 5" do
    @user.update!(verification_level: :identity, trust_score: 5.0, created_at: 1.year.ago)
    # Forzar 200 completadas con 100 distintos.
    100.times { |n|
      other = create_user(username: "max_#{n}")
      2.times {
        i = create_interaction(post: create_post(user: @user), sender: other, receiver: @user)
        i.update_columns(status: 3)
      }
    }
    assert_nil CreditLimitCalculator.progress_to_next_level(@user.reload)
  end
end
