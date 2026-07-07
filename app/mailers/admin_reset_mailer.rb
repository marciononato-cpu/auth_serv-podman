class AdminResetMailer < ApplicationMailer
  # Modo single-recipient (legado): ambos os códigos vão para o mesmo e-mail.
  # Usado quando ADMIN_BACKUP_EMAIL não está configurado.
  def admin_reset_single(user, code1, code2)
    @user  = user
    @code1 = code1
    @code2 = code2

    mail(
      to: @user.email,
      subject: 'Códigos de redefinição de senha administrativa - LABONO'
    )
  end

  # Modo dual-recipient: cada código vai para um e-mail distinto.
  # ADMIN_EMAIL recebe code1, ADMIN_BACKUP_EMAIL recebe code2.
  def admin_reset_dual(primary_email, backup_email, code1, code2)
    @primary_email = primary_email
    @backup_email  = backup_email
    @code1 = code1
    @code2 = code2

    @first_email  = primary_email
    @second_email = backup_email

    mail(
      to: [primary_email, backup_email],
      subject: 'Códigos de redefinição de senha administrativa - LABONO'
    )
  end
end
