require "test_helper"

# Tests del chain de jobs: review → RecalculateUserTrustJob → RecalculateUserLevelJob.
class RecalculateJobsTest < ActiveJob::TestCase
  setup do
    setup_economy!
    @user = create_user(username: "scored")
  end

  test "Review.after_create_commit encola RecalculateUserTrustJob para el reviewed_user" do
    i = create_completed_interaction(sender: create_user(username: "rev1"), receiver: @user, agreed_credits: 0)
    assert_enqueued_with(job: RecalculateUserTrustJob, args: [ @user.id ]) do
      create_review(interaction: i, reviewer: i.sender, score: 5)
    end
  end

  test "RecalculateUserTrustJob persiste el nuevo trust_score y encola el level recalc" do
    # 3 reviewers con score 5 → trust 5.0
    3.times do |n|
      other = create_user(username: "rev#{n}")
      i = create_completed_interaction(sender: other, receiver: @user, agreed_credits: 0)
      create_review(interaction: i, reviewer: other, score: 5)
    end

    assert_enqueued_with(job: RecalculateUserLevelJob, args: [ @user.id ]) do
      RecalculateUserTrustJob.perform_now(@user.id)
    end

    assert_in_delta 5.0, @user.reload.trust_score, 0.01
  end

  test "Interaction status → completed encola RecalculateUserLevelJob para sender y receiver" do
    sender = create_user(username: "leveler1")
    receiver = create_user(username: "leveler2")
    post = create_post(user: receiver)
    i = create_interaction(post: post, sender: sender, receiver: receiver,
                            status: :in_progress, agreed_credits: 0)

    assert_enqueued_with(job: RecalculateUserLevelJob, args: [ sender.id ]) do
      assert_enqueued_with(job: RecalculateUserLevelJob, args: [ receiver.id ]) do
        i.update!(status: :completed)
      end
    end
  end

  test "RecalculateUserLevelJob persiste credit_floor/ceiling/tx_cap del nivel calculado" do
    # Configurar todo para que califique a nivel 2.
    @user.update!(verification_level: :email, trust_score: 3.5, created_at: 10.days.ago)
    3.times { |n|
      i = create_interaction(post: create_post(user: @user),
                             sender: create_user(username: "lev#{n}"),
                             receiver: @user)
      i.update_columns(status: 3)
    }

    RecalculateUserLevelJob.perform_now(@user.id)
    assert_equal 2, @user.reload.level
    assert_equal 1_000,  @user.credit_floor
    assert_equal 10_000, @user.credit_ceiling
    assert_equal 250,    @user.tx_cap
  end
end
