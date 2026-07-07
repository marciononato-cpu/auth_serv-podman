require "ostruct"
class EmailVerificationsController < ActionController::Base
  # Sem layout — as views são HTML completos com estilo próprio
  layout false

  # Apenas validate_token (chamada server-side pelo varzea_fest) não precisa de CSRF
  # request_code e verify_code usam form_tag que já inclui token CSRF automaticamente
  skip_forgery_protection only: %i[validate_token]

  # ─── Constants ─────────────────────────────────────────────────
  CODE_TTL = 15.minutes
  TOKEN_TTL = 10.minutes

  # ─── GET /email_verification ───────────────────────────────────
  # Formulário para digitar o email
  def new
    render :new
  end

  # ─── POST /email_verification/request_code ─────────────────────
  # Gera e envia código de 6 dígitos via Redis (sem criar User)
  def request_code
    email = params[:email]&.downcase&.strip

    unless email.present? && email.match?(URI::MailTo::EMAIL_REGEXP)
      flash.now[:alert] = 'Email inválido'
      render :new, status: :unprocessable_entity
      return
    end

    redis = redis_connection
    unless redis
      flash.now[:alert] = 'Erro interno. Tente novamente em instantes.'
      render :new, status: :service_unavailable
      return
    end

    # Gera código de 6 dígitos
    code = format('%06d', rand(0..999_999))

    # Armazena no Redis com TTL (sem User no banco!)
    redis.set("email_verification:code:#{email}", code, ex: CODE_TTL)
    redis.set("email_verification:attempts:#{email}", 0, ex: CODE_TTL)

    # Envia email reutilizando o UserMailer existente
    # Criamos um objeto OpenStruct para simular o User que o mailer espera
    temp_user = OpenStruct.new(
      email: email,
      confirmation_code: code,
      backup_email: nil
    )

    begin
      UserMailer.confirmation_code(temp_user).deliver_now
    rescue => e
      Rails.logger.warn("[EmailVerification] Falha ao enviar email: #{e.message}")
      flash.now[:alert] = 'Erro ao enviar código. Tente novamente.'
      render :new, status: :internal_server_error
      return
    end

    redirect_to email_verification_verify_path(email: email),
                notice: 'Código enviado! Verifique seu email.'
  end

  # ─── GET /email_verification/verify ────────────────────────────
  # Formulário para digitar o código
  def verify
    @email = params[:email]
    unless @email.present?
      redirect_to email_verification_path, alert: 'Email não informado'
    end
  end

  # ─── POST /email_verification/verify_code ───────────────────────
  # Valida o código e redireciona para o varzea_fest
  def verify_code
    email = params[:email]&.downcase&.strip
    code = params[:code]&.strip

    unless email.present? && code.present?
      flash.now[:alert] = 'Dados incompletos'
      render :verify, status: :unprocessable_entity
      return
    end

    redis = redis_connection
    unless redis
      flash.now[:alert] = 'Erro interno. Tente novamente em instantes.'
      render :verify, status: :service_unavailable
      return
    end

    stored_code = redis.get("email_verification:code:#{email}")

    if stored_code.nil?
      flash.now[:alert] = 'Código expirado. Solicite um novo.'
      render :verify, status: :unprocessable_entity
      return
    end

    if stored_code != code
      attempts = redis.incr("email_verification:attempts:#{email}")
      if attempts >= 5
        redis.del("email_verification:code:#{email}")
        flash.now[:alert] = 'Muitas tentativas. Solicite um novo código.'
        render :verify, status: :unprocessable_entity
      else
        flash.now[:alert] = 'Código incorreto'
        render :verify, status: :unprocessable_entity
      end
      return
    end

    # Código válido! Gera token de verificação e armazena no Redis
    token = SecureRandom.hex(32)
    redis.set("email_verification:token:#{token}", email, ex: TOKEN_TTL)

    # Limpa dados temporários
    redis.del("email_verification:code:#{email}")
    redis.del("email_verification:attempts:#{email}")

    # Redireciona para o varzea_fest com token e email (via rede interna do Caddy)
    varzea_url = ENV.fetch('VARZEA_FEST_URL', 'https://varzeafest.duckdns.org')
    redirect_to "#{varzea_url}/cadastrar?email=#{CGI.escape(email)}&token=#{token}",
                allow_other_host: true,
                notice: 'Email verificado com sucesso!'
  end

  # ─── GET /email_verification/validate_token ─────────────────────
  # Chamado server-side pelo varzea_fest para validar o token
  def validate_token
    token = params[:token]
    email = params[:email]&.downcase&.strip

    unless token.present? && email.present?
      render json: { valid: false, error: 'Parâmetros incompletos' }, status: :bad_request
      return
    end

    redis = redis_connection
    unless redis
      render json: { valid: false, error: 'Erro interno no servidor' }, status: :service_unavailable
      return
    end

    stored_email = redis.get("email_verification:token:#{token}")

    if stored_email.nil?
      render json: { valid: false, error: 'Token inválido ou expirado' }, status: :unauthorized
      return
    end

    if stored_email != email
      render json: { valid: false, error: 'Email não corresponde ao token' }, status: :unauthorized
      return
    end

    # Token válido! Remove do Redis (uso único)
    redis.del("email_verification:token:#{token}")

    render json: { valid: true, email: email }
  end

  private

  def redis_connection
    @redis ||= begin
      if ENV['REDIS_URL'].present?
        Redis.new(url: ENV['REDIS_URL'])
      else
        Redis.new(
          host: ENV.fetch('REDIS_HOST', 'redis'),
          port: ENV.fetch('REDIS_PORT', 6379).to_i
        )
      end
    end
  rescue Redis::BaseError => e
    Rails.logger.error("[EmailVerification] Redis connection failed: #{e.message}")
    nil
  end
end
