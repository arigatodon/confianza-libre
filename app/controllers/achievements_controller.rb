class AchievementsController < ApplicationController
  def index
    @user    = Current.session.user
    @catalog = AchievementCatalog.new(@user)
  end
end
