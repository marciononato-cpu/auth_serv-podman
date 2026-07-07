class Admin::PasswordsController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  # Emails admin são resolvidos via ENV — sem fallback hardcoded com PII.
  # Configure ADMIN_EMAIL e ADMIN_BACKUP_EMAIL no deploy (.env ou Podman secret).
  # Se ADMIN_BACKUP_EMAIL não estiver setado, o código 2 será enviado apenas
  # para ADMIN_EMAIL e o endpoint público não listará nenhum email.
  ADMIN_EMAIL         = ENV.fetch('ADMIN_EMAIL')
  ADMIN_BACKUP_EMAIL  = ENV['ADMIN_BACKUP_EMAIL']

  # ─── POST /admin/passwords/initiate ────────────────────────────
  def initiate
    email = params[:email]&.downcase

    # Mensagem genérica + mesmo status, para não vazar qual email existe.
    return generic_response unless email && email == ADMIN_EMAIL

    user = User.find_by(email: email, role: :admin)
    return generic_response unless user

    code1 = rand(100000..999999).to_s
    code2 = rand(100000..999999).to_s

    user.update!(
      admin_reset_code1: code1,
      admin_reset_code2: code2,
      admin_reset_sent_at: Time.current
    )

    # Para dual-mail, é necessário ADMIN_BACKUP_EMAIL configurado.
    # Caso contrário, mantém o comportamento legado (ambos códigos no ADMIN_EMAIL).
    if ADMIN_BACKUP_EMAIL.present?
      AdminResetMailer.admin_reset_dual(ADMIN_EMAIL, ADMIN_BACKUP_EMAIL, code1, code2).deliver_now
    else
      AdminResetMailer.admin_reset_single(user, code1, code2).deliver_now
    end

    render json: { message: 'Se o email existir, você receberá instruções.' }, status: :accepted
  end

  # ─── POST /admin/passwords/reset ───────────────────────────────
  def reset
    email = params[:password][:email]&.downcase
    code1 = params[:password][:code1]
    code2 = params[:password][:code2]
    password = params[:password][:password]
    password_confirmation = params[:password][:password_confirmation]

    if email.nil? || email != ADMIN_EMAIL
      render json: { errors: ['Operação não permitida'] }, status: :unauthorized
      return
    end

    user = User.find_by(email: email, role: :admin)

    unless user && user.admin_reset_code1 && user.admin_reset_code2
      render json: { errors: ['Solicitação inválida. Solicite uma nova troca de senha.'] }, status: :unprocessable_entity
      return
    end

    if user.admin_reset_sent_at < 15.minutes.ago
      user.update!(admin_reset_code1: nil, admin_reset_code2: nil, admin_reset_sent_at: nil)
      render json: { errors: ['Códigos expirados. Solicite uma nova troca de senha.'] }, status: :unprocessable_entity
      return
    end

    unless code1 == user.admin_reset_code1 && code2 == user.admin_reset_code2
      render json: { errors: ['Um ou ambos os códigos estão incorretos'] }, status: :unauthorized
      return
    end

    if password != password_confirmation
      render json: { errors: ['As senhas não conferem'] }, status: :unprocessable_entity
      return
    end

    if password.length < 6
      render json: { errors: ['A senha deve ter pelo menos 6 caracteres'] }, status: :unprocessable_entity
      return
    end

    user.update!(
      password: password,
      password_confirmation: password_confirmation,
      admin_reset_code1: nil,
      admin_reset_code2: nil,
      admin_reset_sent_at: nil
    )

    render json: { message: 'Senha do administrador redefinida com sucesso!' }, status: :ok
  end

  private

  # Resposta única usada por caminhos de "não encontrado / não autorizado",
  # para que o cliente não consiga distinguir se o email existe.
  def generic_response
    render json: { message: 'Se o email existir, você receberá instruções.' }, status: :accepted
  end
end
