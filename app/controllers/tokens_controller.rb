# frozen_string_literal: true

class TokensController < ApplicationController
  # POST /tokens/verify
  # Expects Authorization: Bearer <jwt>
  def verify
    token = extract_token(request)
    if token.blank?
      render json: { error: 'unauthorized', message: 'Token não fornecido' }, status: :unauthorized and return
    end

    begin
      payload = JWT.decode(
        token,
        JWT_CONFIG[:secret_key],
        true,
        { algorithm: JWT_CONFIG[:algorithm], iss: JWT_CONFIG[:issuer] }
      ).first
      render json: { user_id: payload['sub'], role: payload['role'] }, status: :ok
    rescue JWT::ExpiredSignature
      render json: { error: 'unauthorized', message: 'Token expirado' }, status: :unauthorized
    rescue JWT::DecodeError
      render json: { error: 'unauthorized', message: 'Token inválido' }, status: :unauthorized
    end
  end

  private

  def extract_token(request)
    auth_header = request.headers['Authorization']
    return nil unless auth_header
    parts = auth_header.split
    return nil unless parts.size == 2 && parts.first == 'Bearer'
    parts.last
  end
end
