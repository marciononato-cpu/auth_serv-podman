Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # ─── Email Verification (bridge com varzea_fest) ────────────────
  # Usa Redis para armazenar códigos temporários (sem criar User)
  get  "email_verification",          to: "email_verifications#new", as: :email_verification
  post "email_verification/request_code", to: "email_verifications#request_code", as: :email_verification_request_code
  get  "email_verification/verify",   to: "email_verifications#verify", as: :email_verification_verify
  post "email_verification/verify_code", to: "email_verifications#verify_code", as: :email_verification_verify_code
  get  "email_verification/validate_token", to: "email_verifications#validate_token", as: :email_verification_validate_token

  # ─── Auth routes ─────────────────────────────────────────────────
  post "users/sign_in", to: "users/sessions#create"
  delete "users/sign_out", to: "users/sessions#destroy"
  post "users", to: "users/registrations#create"
  post "users/confirm", to: "users/confirmations#create"
  post "users/confirm/resend", to: "users/confirmations#resend"
  get "users", to: "users#index"
  delete "users/:id", to: "users#destroy"

  # ─── Password reset ──────────────────────────────────────────────
  post "passwords", to: "users/passwords#create"
  patch "passwords", to: "users/passwords#update"
  put "passwords", to: "users/passwords#update"

  # ─── Admin password reset (dual-code) ────────────────────────────
  post "admin/passwords/initiate", to: "admin/passwords#initiate"
  post "admin/passwords/reset", to: "admin/passwords#reset"

  # ─── Admin dashboard stats ───────────────────────────────────────
  get "admin/stats", to: "admin/stats#show"

  # ─── OAuth ───────────────────────────────────────────────────────
  get "/auth/google_oauth2/callback", to: "omniauth_callbacks#google_oauth2"
  get "/auth/apple/callback", to: "omniauth_callbacks#apple"

  # ─── Rotas com prefixo /api (compatibilidade sem Nginx) ─────────
  # O frontend JS usa /api/*, e o Nginx também faz proxy passando /api.
  # Estas rotas garantem funcionamento com ou sem Nginx.
  scope "/api" do
    post "users/sign_in", to: "users/sessions#create"
    delete "users/sign_out", to: "users/sessions#destroy"
    post "users", to: "users/registrations#create"
    post "users/confirm", to: "users/confirmations#create"
    post "users/confirm/resend", to: "users/confirmations#resend"
    get "users", to: "users#index"
    delete "users/:id", to: "users#destroy"
    post "passwords", to: "users/passwords#create"
    patch "passwords", to: "users/passwords#update"
    put "passwords", to: "users/passwords#update"
    post "admin/passwords/initiate", to: "admin/passwords#initiate"
    post "admin/passwords/reset", to: "admin/passwords#reset"
    get "admin/stats", to: "admin/stats#show"
    # Token verification endpoint (both plain and /api)
    post "tokens/verify", to: "tokens#verify"
  end

  # Token verification endpoint for direct access (no /api prefix)
  # (route removed to avoid duplicate definition)
end