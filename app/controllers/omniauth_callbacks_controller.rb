class OmniauthCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def google_oauth2
    handle_omniauth('google_oauth2')
  end

  def apple
    handle_omniauth('apple')
  end

  private

  def handle_omniauth(provider)
    auth_hash = request.env['omniauth.auth']

    unless auth_hash
      return render json: { errors: ['Falha na autenticação OAuth'] }, status: :unprocessable_entity
    end

    uid = auth_hash['uid']
    email = auth_hash['info']['email']
    name = auth_hash['info']['name']
    image = auth_hash['info']['image']

    unless email
      return render json: { errors: ['Email não fornecido pelo provedor'] }, status: :unprocessable_entity
    end

    user = User.find_or_create_from_oauth(provider, uid, auth_hash)

    token = encode_token(user)

    render json: {
      message: 'Login OAuth realizado com sucesso!',
      token: token,
      user: user.as_json(only: [:id, :email, :role, :name])
    }, status: :ok

  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error("[OmniauthCallbacksController] #{e.message}")
    render json: { errors: ['Erro interno no servidor'] }, status: :internal_server_error
  end

  def encode_token(user)
    payload = {
      sub: user.id,
      role: user.role,
      exp: Time.now.to_i + 86400
    }
    JWT.encode(payload, JWT_CONFIG[:secret_key], JWT_CONFIG[:algorithm])
  end
end
