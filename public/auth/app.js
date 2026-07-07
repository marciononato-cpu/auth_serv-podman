// Config da API
const API_BASE = '/api';
const TOKEN_KEY = 'admin_token';

// Estado
let currentPage = 1;
let currentSearch = '';
let allUsers = [];
let perPage = 10;

// === AUTO-LOGIN CHECK ===
document.addEventListener('DOMContentLoaded', () => {
  const token = localStorage.getItem(TOKEN_KEY);
  if (token) {
    showDashboard(token);
  } else {
    showLogin();
  }
  initLoginForm();
  initRegisterForm();
  initConfirmForm();
  initForgotForm();
  initResetForm();
  initSearch();
});

// === NAVEGAÇÃO ===
function showLogin() {
  const pages = ['login-page', 'register-page', 'confirm-page', 'forgot-page', 'reset-page', 'dashboard-page'];
  pages.forEach(id => {
    const el = document.getElementById(id);
    if (el) el.classList.toggle('hidden', id !== 'login-page');
  });
}

function showRegister() {
  ['login-page', 'confirm-page', 'forgot-page', 'reset-page', 'dashboard-page'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.classList.add('hidden');
  });
  document.getElementById('register-page').classList.remove('hidden');
  document.getElementById('register-error').classList.add('hidden');
  document.getElementById('register-success').classList.add('hidden');
}

function showConfirm(email) {
  ['login-page', 'register-page', 'forgot-page', 'reset-page', 'dashboard-page'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.classList.add('hidden');
  });
  document.getElementById('confirm-page').classList.remove('hidden');
  document.getElementById('confirm-email-display').textContent = `📬 ${email}`;
  document.getElementById('confirm-code').value = '';
  document.getElementById('confirm-error').classList.add('hidden');
  document.getElementById('confirm-success').classList.add('hidden');
  document.getElementById('btn-confirm').disabled = false;
  document.getElementById('btn-confirm').textContent = 'Confirmar Email';
  window._confirmEmail = email;
  setTimeout(() => document.getElementById('confirm-code').focus(), 100);
}

function showForgot() {
  ['login-page', 'register-page', 'confirm-page', 'reset-page', 'dashboard-page'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.classList.add('hidden');
  });
  document.getElementById('forgot-page').classList.remove('hidden');
  document.getElementById('forgot-email').value = '';
  document.getElementById('forgot-error').classList.add('hidden');
  document.getElementById('forgot-success').classList.add('hidden');
  document.getElementById('btn-forgot').disabled = false;
  document.getElementById('btn-forgot').textContent = 'Enviar Código';
  setTimeout(() => document.getElementById('forgot-email').focus(), 100);
}

function showReset(email) {
  ['login-page', 'register-page', 'confirm-page', 'forgot-page', 'dashboard-page'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.classList.add('hidden');
  });
  document.getElementById('reset-page').classList.remove('hidden');
  document.getElementById('reset-email').value = email || '';
  document.getElementById('reset-code').value = '';
  document.getElementById('reset-password').value = '';
  document.getElementById('reset-password-confirm').value = '';
  document.getElementById('reset-error').classList.add('hidden');
  document.getElementById('reset-success').classList.add('hidden');
  document.getElementById('btn-reset').disabled = false;
  document.getElementById('btn-reset').textContent = 'Redefinir Senha';
  // Se o email já veio preenchido, foca no campo do código
  if (email) {
    setTimeout(() => document.getElementById('reset-code').focus(), 100);
  } else {
    setTimeout(() => document.getElementById('reset-email').focus(), 100);
  }
}

function showDashboard(token) {
  ['login-page', 'register-page', 'confirm-page', 'forgot-page', 'reset-page'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.classList.add('hidden');
  });
  document.getElementById('dashboard-page').classList.remove('hidden');
  loadDashboard(token);
}

// === LOGIN ===
function initLoginForm() {
  const form = document.getElementById('login-form');
  if (!form) return;
  
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;
    const btn = document.getElementById('btn-login');
    const errorDiv = document.getElementById('login-error');
    
    btn.disabled = true;
    btn.textContent = 'Entrando...';
    errorDiv.classList.add('hidden');
    
    try {
      const res = await fetch(`${API_BASE}/users/sign_in`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user: { email, password } })
      });
      
      const data = await res.json();
      
      if (res.ok && data.token) {
        localStorage.setItem(TOKEN_KEY, data.token);
        localStorage.setItem('admin_email', data.user?.email || email);
        showDashboard(data.token);
      } else {
        errorDiv.textContent = data.error || data.errors?.[0] || 'Credenciais inválidas';
        errorDiv.classList.remove('hidden');
      }
    } catch (err) {
      errorDiv.textContent = 'Erro ao conectar com o servidor';
      errorDiv.classList.remove('hidden');
    } finally {
      btn.disabled = false;
      btn.textContent = 'Entrar';
    }
  });
}

// === REGISTRO ===
function initRegisterForm() {
  const form = document.getElementById('register-form');
  if (!form) return;
  
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = document.getElementById('reg-email').value;
    const password = document.getElementById('reg-password').value;
    const confirmPassword = document.getElementById('reg-password-confirm').value;
    const btn = document.getElementById('btn-register');
    const errorDiv = document.getElementById('register-error');
    const successDiv = document.getElementById('register-success');
    
    errorDiv.classList.add('hidden');
    successDiv.classList.add('hidden');
    
    if (password !== confirmPassword) {
      errorDiv.textContent = 'As senhas não conferem';
      errorDiv.classList.remove('hidden');
      return;
    }
    
    btn.disabled = true;
    btn.textContent = 'Criando...';
    
    try {
      const res = await fetch(`${API_BASE}/users`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          user: { email, password, password_confirmation: confirmPassword }
        })
      });
      
      const data = await res.json();
      
      if (res.ok || res.status === 201) {
        // Redireciona para página de confirmação
        showConfirm(email);
      } else {
        errorDiv.textContent = data.errors?.[0] || data.error || 'Erro ao criar conta';
        errorDiv.classList.remove('hidden');
      }
    } catch (err) {
      errorDiv.textContent = 'Erro ao conectar com o servidor';
      errorDiv.classList.remove('hidden');
    } finally {
      btn.disabled = false;
      btn.textContent = 'Criar Conta';
    }
  });
}

// === CONFIRMAÇÃO DE EMAIL ===
function initConfirmForm() {
  const form = document.getElementById('confirm-form');
  if (!form) return;
  
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = window._confirmEmail;
    const code = document.getElementById('confirm-code').value.trim();
    const btn = document.getElementById('btn-confirm');
    const errorDiv = document.getElementById('confirm-error');
    const successDiv = document.getElementById('confirm-success');
    
    if (!code || code.length !== 6) {
      errorDiv.textContent = 'Digite o código de 6 dígitos';
      errorDiv.classList.remove('hidden');
      return;
    }
    
    btn.disabled = true;
    btn.textContent = 'Confirmando...';
    errorDiv.classList.add('hidden');
    successDiv.classList.add('hidden');
    
    try {
      const res = await fetch(`${API_BASE}/users/confirm`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ confirmation: { email, code } })
      });
      
      const data = await res.json();
      
      if (res.ok && data.token) {
        successDiv.innerHTML = `<strong>Email confirmado com sucesso!</strong><br><br>Redirecionando para o login...`;
        successDiv.classList.remove('hidden');
        document.getElementById('confirm-code').value = '';
        // Pós-confirmação: salva token e vai pro dashboard
        setTimeout(() => {
          localStorage.setItem(TOKEN_KEY, data.token);
          localStorage.setItem('admin_email', email);
          showDashboard(data.token);
        }, 1500);
      } else {
        errorDiv.textContent = data.errors?.[0] || data.error || 'Código inválido';
        errorDiv.classList.remove('hidden');
        btn.disabled = false;
        btn.textContent = 'Confirmar Email';
      }
    } catch (err) {
      errorDiv.textContent = 'Erro ao conectar com o servidor';
      errorDiv.classList.remove('hidden');
      btn.disabled = false;
      btn.textContent = 'Confirmar Email';
    }
  });
}

async function resendCode() {
  const email = window._confirmEmail;
  if (!email) return;
  
  const btn = document.getElementById('btn-confirm');
  const errorDiv = document.getElementById('confirm-error');
  const successDiv = document.getElementById('confirm-success');
  
  btn.disabled = true;
  btn.textContent = 'Reenviando...';
  errorDiv.classList.add('hidden');
  successDiv.classList.add('hidden');
  
  try {
    const res = await fetch(`${API_BASE}/users/confirm/resend`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ confirmation: { email } })
    });
    
    if (res.ok || res.status === 202) {
      successDiv.textContent = '📧 Novo código enviado! Verifique seu email.';
      successDiv.classList.remove('hidden');
    } else {
      const data = await res.json();
      errorDiv.textContent = data.error || 'Erro ao reenviar código';
      errorDiv.classList.remove('hidden');
    }
  } catch (err) {
    errorDiv.textContent = 'Erro ao conectar com o servidor';
    errorDiv.classList.remove('hidden');
  } finally {
    btn.disabled = false;
    btn.textContent = 'Confirmar Email';
  }
}

// === ESQUECI SENHA ===
function initForgotForm() {
  const form = document.getElementById('forgot-form');
  if (!form) return;
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = document.getElementById('forgot-email').value;
    const btn = document.getElementById('btn-forgot');
    const errorDiv = document.getElementById('forgot-error');
    const successDiv = document.getElementById('forgot-success');
    btn.disabled = true; btn.textContent = 'Enviando...';
    errorDiv.classList.add('hidden'); successDiv.classList.add('hidden');
    try {
      const res = await fetch(`${API_BASE}/passwords`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password: { email } })
      });
      if (res.ok || res.status === 202) {
        successDiv.innerHTML = `<strong>✔️ Código enviado!</strong><br><br>Redirecionando para redefinir a senha...`;
        successDiv.classList.remove('hidden');
        // Auto-redireciona para página de redefinição com email já preenchido
        setTimeout(() => {
          showReset(email);
        }, 2000);
      } else {
        const data = await res.json();
        errorDiv.textContent = data.error || data.errors?.[0] || 'Erro ao enviar email';
        errorDiv.classList.remove('hidden');
      }
    } catch (err) {
      errorDiv.textContent = 'Erro ao conectar com o servidor';
      errorDiv.classList.remove('hidden');
    } finally {
      btn.disabled = false; btn.textContent = 'Enviar Código';
    }
  });
}

// === REDEFINIR SENHA ===
function initResetForm() {
  const form = document.getElementById('reset-form');
  if (!form) return;
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = document.getElementById('reset-email').value;
    const token = document.getElementById('reset-code').value.trim();
    const password = document.getElementById('reset-password').value;
    const confirmPassword = document.getElementById('reset-password-confirm').value;
    const btn = document.getElementById('btn-reset');
    const errorDiv = document.getElementById('reset-error');
    const successDiv = document.getElementById('reset-success');
    if (password !== confirmPassword) {
      errorDiv.textContent = 'As senhas não conferem';
      errorDiv.classList.remove('hidden'); return;
    }
    if (!token) {
      errorDiv.textContent = 'Digite o código de redefinição';
      errorDiv.classList.remove('hidden'); return;
    }
    btn.disabled = true; btn.textContent = 'Redefinindo...';
    errorDiv.classList.add('hidden'); successDiv.classList.add('hidden');
    try {
      const res = await fetch(`${API_BASE}/passwords`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password: { token, password, password_confirmation: confirmPassword } })
      });
      const data = await res.json();
      if (res.ok) {
        successDiv.innerHTML = `<strong>Senha redefinida com sucesso!</strong><br><br>Redirecionando para o login...`;
        successDiv.classList.remove('hidden');
        setTimeout(() => showLogin(), 2000);
      } else {
        errorDiv.textContent = data.errors?.[0] || data.error || 'Erro ao redefinir senha';
        errorDiv.classList.remove('hidden');
      }
    } catch (err) {
      errorDiv.textContent = 'Erro ao conectar com o servidor';
      errorDiv.classList.remove('hidden');
    } finally {
      btn.disabled = false; btn.textContent = 'Redefinir Senha';
    }
  });
}

// === LOGOUT ===
async function logout() {
  const token = localStorage.getItem(TOKEN_KEY);
  if (token) {
    try {
      await fetch(`${API_BASE}/users/sign_out`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
    } catch (e) {}
  }
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem('admin_email');
  showLogin();
  document.getElementById('email').value = '';
  document.getElementById('password').value = '';
}

// === DASHBOARD ===
async function loadDashboard(token) {
  const email = localStorage.getItem('admin_email');
  if (email) {
    document.getElementById('user-email').textContent = email;
  }
  
  try {
    await Promise.all([loadStats(token), loadUsers(token)]);
  } catch (err) {
    console.error('Erro ao carregar dashboard:', err);
  }
}

// === STATS ===
async function loadStats(token) {
  const res = await fetch(`${API_BASE}/users`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  
  if (!res.ok) return;
  
  const users = await res.json();
  const total = users.length;
  const confirmed = users.filter(u => u.confirmed_at).length;
  const pending = total - confirmed;
  const admins = users.filter(u => u.role === 'admin').length;
  
  document.getElementById('stat-total').textContent = total;
  document.getElementById('stat-confirmed').textContent = confirmed;
  document.getElementById('stat-pending').textContent = pending;
  document.getElementById('stat-admins').textContent = admins;
}

// === USERS LIST ===
async function loadUsers(token) {
  const res = await fetch(`${API_BASE}/users`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  
  if (!res.ok) return;
  
  allUsers = await res.json();
  renderUsers();
}

function renderUsers() {
  const tbody = document.getElementById('users-table-body');
  if (!tbody) return;
  
  // Filter
  let filtered = allUsers;
  if (currentSearch) {
    filtered = allUsers.filter(u => 
      u.email.toLowerCase().includes(currentSearch.toLowerCase())
    );
  }
  
  // Paginate
  const start = (currentPage - 1) * perPage;
  const end = start + perPage;
  const pageUsers = filtered.slice(start, end);
  
  if (pageUsers.length === 0) {
    tbody.innerHTML = `<tr><td colspan="6" class="text-center text-muted" style="padding: 40px;">Nenhum usuário encontrado</td></tr>`;
    return;
  }
  
  tbody.innerHTML = pageUsers.map(user => `
    <tr>
      <td>#${user.id}</td>
      <td>${escapeHtml(user.email)}</td>
      <td>${user.role === 'admin' ? '<span class="status-badge" style="background: #f59e0b20; color: #f59e0b;">Admin</span>' : 'User'}</td>
      <td>
        ${user.confirmed_at 
          ? '<span class="status-badge status-active">Confirmado</span>' 
          : '<span class="status-badge status-inactive">Pendente</span>'}
      </td>
      <td>${formatDate(user.created_at)}</td>
      <td>
        <button class="action-btn" onclick="deleteUser('${user.id}')">Remover</button>
      </td>
    </tr>
  `).join('');
  
  // Pagination
  renderPagination(filtered.length);
}

function renderPagination(totalItems) {
  const container = document.getElementById('pagination');
  if (!container) return;
  
  const totalPages = Math.ceil(totalItems / perPage);
  
  if (totalPages <= 1) {
    container.innerHTML = `Total: ${totalItems} usuário(s)`;
    return;
  }
  
  let html = `<span>Página ${currentPage} de ${totalPages}</span>`;
  html += '<div class="flex gap-2">';
  
  if (currentPage > 1) {
    html += `<button class="action-btn" onclick="goToPage(${currentPage - 1})">← Anterior</button>`;
  }
  
  for (let i = 1; i <= totalPages; i++) {
    html += `<button class="action-btn ${i === currentPage ? 'active' : ''}" onclick="goToPage(${i})">${i}</button>`;
  }
  
  if (currentPage < totalPages) {
    html += `<button class="action-btn" onclick="goToPage(${currentPage + 1})">Próxima →</button>`;
  }
  
  html += '</div>';
  container.innerHTML = html;
}

function goToPage(page) {
  currentPage = page;
  const token = localStorage.getItem(TOKEN_KEY);
  if (token) loadUsers(token);
}

// === SEARCH ===
function initSearch() {
  const box = document.getElementById('search-box');
  if (!box) return;
  
  let timeout;
  box.addEventListener('input', (e) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => {
      currentSearch = e.target.value;
      currentPage = 1;
      const token = localStorage.getItem(TOKEN_KEY);
      if (token) {
        // Re-fetch to get fresh data
        fetch(`${API_BASE}/users`, {
          headers: { 'Authorization': `Bearer ${token}` }
        }).then(r => r.json()).then(users => {
          allUsers = users;
          renderUsers();
        });
      }
    }, 300);
  });
}

// === DELETE USER ===
async function deleteUser(userId) {
  if (!confirm('Tem certeza que deseja remover este usuário?')) return;
  
  const token = localStorage.getItem(TOKEN_KEY);
  if (!token) return;
  
  try {
    const res = await fetch(`${API_BASE}/users/${userId}`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${token}` }
    });
    
    if (res.ok) {
      alert('Usuário removido com sucesso');
      loadDashboard(token);
    } else {
      const data = await res.json();
      alert(data.error || 'Erro ao remover usuário');
    }
  } catch (err) {
    alert('Erro ao conectar com o servidor');
  }
}

// === UTILS ===
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function formatDate(dateStr) {
  const date = new Date(dateStr);
  return date.toLocaleDateString('pt-BR') + ' ' + date.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
}
