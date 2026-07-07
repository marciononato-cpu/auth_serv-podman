class AuthMiddleware
  def initialize(app)
    @app = app
  end

  # Prefixos de caminhos que não precisam de autenticação
  # (qualquer path que comece com estes prefixos é liberado)
  PUBLIC_PREFIXES = %w[/auth/ /assets/ /rails/ /email_verification].freeze

  # Rotas exatas que NÃO precisam de autenticação
  # Inclui versões com e sem /api para funcionar com ou sem Nginx
  PUBLIC_PATHS = {
    'POST' => [
      '/users', '/api/users',
      '/sessions', '/api/sessions',
      '/users/sign_in', '/api/users/sign_in',
      '/users/confirm', '/api/users/confirm',
      '/users/confirm/resend', '/api/users/confirm/resend',
      '/users/confirmation_code', '/api/users/confirmation_code',
      '/passwords', '/api/passwords',
      '/email_verification/request_code', '/email_verification/verify_code'
    ],
    'PUT'  => ['/passwords', '/api/passwords'],
    'PATCH'=> ['/passwords', '/api/passwords'],
    'GET'  => ['/up', '/', '/index.html', '/50x.html', '/robots.txt',
                '/auth', '/auth/', '/auth/index.html', '/auth/app.js', '/auth/style.css',
                '/email_verification', '/email_verification/verify',
                '/email_verification/validate_token'],
    'OPTIONS' => [
      '/users', '/api/users',
      '/sessions', '/api/sessions',
      '/users/sign_in', '/api/users/sign_in',
      '/users/confirm', '/api/users/confirm',
      '/users/confirm/resend', '/api/users/confirm/resend',
      '/passwords', '/api/passwords',
      '/users/sign_out', '/api/users/sign_out'
    ],
    'DELETE' => ['/users/sign_out', '/api/users/sign_out']
  }.freeze

  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Se é rota pública, deixa passar
    if is_public?(request)
      return @app.call(env)
    end
    
    # Extrai e valida o token JWT
    token = extract_token(request)
    
    if token.nil? || token.empty?
      return [401, { 'Content-Type' => 'application/json' },
              [{ error: 'unauthorized', message: 'Token não fornecido' }.to_json]]
    end
    
    # Verifica se o token foi blacklistado no logout
    begin
      redis = Redis.new(host: ENV.fetch('REDIS_HOST', '127.0.0.1'), port: ENV.fetch('REDIS_PORT', 6379).to_i)
      if redis.get("jwt:blacklist:#{token}")
        return [401, { 'Content-Type' => 'application/json' },
                [{ error: 'unauthorized', message: 'Sessão encerrada' }.to_json]]
      end
    rescue
      # Se Redis falhar, continua com validação JWT normal
    end
    
    # Decodifica o token
    begin
      payload = JWT.decode(
        token,
        JWT_CONFIG[:secret_key],
        true,
        { algorithm: JWT_CONFIG[:algorithm], iss: JWT_CONFIG[:issuer] }
      )
      
      # Salva user_id e role no env para uso nos controllers
      request.env['auth_user_id'] = payload[0]['sub'].to_i
      request.env['auth_role'] = payload[0]['role']
      request.env['auth_token'] = token
      
    rescue JWT::ExpiredSignature
      return [401, { 'Content-Type' => 'application/json' },
              [{ error: 'unauthorized', message: 'Token expirado' }.to_json]]
    rescue JWT::DecodeError
      return [401, { 'Content-Type' => 'application/json' },
              [{ error: 'unauthorized', message: 'Token inválido' }.to_json]]
    rescue => e
      Rails.logger.error("[AuthMiddleware] #{e.message}")
      return [500, { 'Content-Type' => 'application/json' },
              [{ error: 'internal_error', message: 'Erro de autenticação' }.to_json]]
    end
    
    @app.call(env)
  end
  
  private
  
  def is_public?(request)
    path = request.path
    method = request.method
    
    # Checagem exata por method + path
    return true if PUBLIC_PATHS[method]&.include?(path)
    
    # Se for GET, checa prefixos públicos (arquivos estáticos, frontend)
    return true if method == 'GET' && PUBLIC_PREFIXES.any? { |prefix| path.start_with?(prefix) }
    
    false
  end
  
  def extract_token(request)
    auth_header = request.headers['Authorization']
    return nil unless auth_header
    
    # Espera formato "Bearer <token>"
    parts = auth_header.split
    return nil unless parts.length == 2 && parts.first == 'Bearer'
    
    parts.last
  end
end
