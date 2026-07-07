class Admin::StatsController < ApplicationController
  # GET /admin/stats — estatísticas do dashboard (admin apenas)
  def show
    return render json: { errors: ['Acesso negado'] }, status: :forbidden unless admin?

    total = User.count
    confirmed = User.where.not(confirmed_at: nil).count
    pending = total - confirmed
    admins = User.where(role: :admin).count

    render json: {
      total_users: total,
      confirmed_users: confirmed,
      pending_users: pending,
      admin_users: admins
    }, status: :ok
  end

  private

  def current_user_role
    request.env['auth_role']
  end

  def admin?
    current_user_role == 'admin'
  end
end
