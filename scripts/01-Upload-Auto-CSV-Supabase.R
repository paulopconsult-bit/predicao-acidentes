# ============================================================
# SEÇÃO 1 — INTRODUÇÃO
# SCRIPT DE INGESTÃO: Upload-Auto-CSV-Supabase.R
#
# OBJETIVO:
#   Fazer upload automático de um arquivo CSV para uma tabela
#   no Supabase (PostgreSQL), de forma genérica e reutilizável.
#
# COMPORTAMENTO:
#   1. Verifica se a tabela existe no Supabase.
#   2. Se NÃO existir: interrompe e avisa para criar manualmente.
#   3. Se JÁ existir: apaga o conteúdo (TRUNCATE) e insere
#      novamente todos os dados do CSV.
#
# OBS IMPORTANTE:
#   O Supabase removeu o endpoint /rpc/execute_sql.
#   Portanto, criação automática de tabela NÃO funciona mais.
#   A tabela deve ser criada manualmente UMA ÚNICA VEZ.
#
# USO:
#   - Ajustar:
#       - caminho do CSV
#       - nome da tabela
#       - URL do Supabase
#       - chave de API
#
# ============================================================
#
# ============================================================
# SEÇÃO 2 — CONFIGURAÇÕES DO USUÁRIO
# Ajuste estes parâmetros conforme o seu projeto.
# ============================================================

# Para acessar variável via arquivo ENV
library(dotenv) 
# Carrega o arquivo .env local 
dotenv::load_dot_env("private/.env")

# Caminho do arquivo CSV local
# Exemplo: "data/prepared/base_limpa_v1.csv"
csv_path <- "G:/Meu Drive/predicao-acidentes/data/prepared/base_limpa_v1.csv"

# Nome da tabela no Supabase
# Para o projeto "acidentes-BR-116", usamos:
nome_tabela <- "acidentes_br116_base_limpa"

# URL do projeto Supabase (sem /rest/v1), salva no .env
# Você encontra em: Project Settings → API → Project URL
supabase_url <- Sys.getenv("SUPABASE_URL")

# Chave de API (anon key), salva no .env
# Você encontra em: Project Settings → API Keys → anon key
supabase_key <- Sys.getenv("SUPABASE_KEY")

# Nome do schema no PostgreSQL (padrão é "public")
schema_nome <- "public"

# Tamanho do lote para inserção (evita enviar tudo de uma vez)
# Envia, aguarda resposta do API do Supabase, se ok repete até completar o envio.
tamanho_lote <- 1000

# ============================================================
# SEÇÃO 3 — FUNÇÕES AUXILIARES
# ============================================================

library(httr)
library(jsonlite)
library(dplyr)

# ------------------------------------------------------------
# Função: tabela_existe()
# Verifica se a tabela já existe no Supabase.
# ------------------------------------------------------------
tabela_existe <- function(nome_tabela) {
  url <- paste0(supabase_url, "/rest/v1/", nome_tabela, "?limit=1")
  
  resp <- GET(
    url,
    add_headers(
      apikey = supabase_key,
      Authorization = paste("Bearer", supabase_key)
    )
  )
  
  return(resp$status_code != 404)
}

# ------------------------------------------------------------
# Função: limpar_tabela()
# Apaga todo o conteúdo da tabela via REST (DELETE).
# ------------------------------------------------------------
limpar_tabela <- function(nome_tabela) {
  # usa uma coluna que SEMPRE tem valor (ex.: Automovel)
  url <- paste0(
    supabase_url,
    "/rest/v1/",
    nome_tabela,
    "?Automovel=not.is.null"
  )
  
  resp <- DELETE(
    url,
    add_headers(
      apikey = supabase_key,
      Authorization = paste("Bearer", supabase_key),
      Prefer = "return=minimal"
    )
  )
  
  if (resp$status_code >= 200 && resp$status_code < 300) {
    cat("✔️ Tabela limpa com sucesso.\n")
  } else {
    cat("❌ Erro ao limpar tabela. Código: ", resp$status_code, "\n")
    print(content(resp))
    stop("Interrompido devido a erro no DELETE.")
  }
}

# ------------------------------------------------------------
# Função: inserir_lote()
# Insere um lote de linhas no Supabase.
# ------------------------------------------------------------
inserir_lote <- function(df_lote, nome_tabela) {
  url <- paste0(supabase_url, "/rest/v1/", nome_tabela)
  
  POST(
    url,
    add_headers(
      apikey = supabase_key,
      Authorization = paste("Bearer", supabase_key),
      `Content-Type` = "application/json",
      Prefer = "return=minimal"
    ),
    body = toJSON(df_lote, auto_unbox = TRUE)
  )
}

# ============================================================
# SEÇÃO 3.1 — LÓGICA PRINCIPAL DO SCRIPT
# ============================================================

cat("📌 Lendo o arquivo CSV...\n")
df <- read.csv(csv_path, stringsAsFactors = FALSE)

cat("📌 Verificando se a tabela existe no Supabase...\n")
existe <- tabela_existe(nome_tabela)

if (!existe) {
  stop("❌ A tabela NÃO existe no Supabase. Crie manualmente uma única vez.")
} else {
  cat("📌 Tabela existe. Limpando conteúdo (DELETE)...\n")
  limpar_tabela(nome_tabela)
}

cat("📌 Iniciando envio dos dados em lotes...\n")

total_linhas <- nrow(df)
inicio <- 1

while (inicio <= total_linhas) {
  fim <- min(inicio + tamanho_lote - 1, total_linhas)
  lote <- df[inicio:fim, ]
  
  cat("➡️ Enviando linhas ", inicio, " até ", fim, "...\n", sep = "")
  
  resp <- inserir_lote(lote, nome_tabela)
  
  if (resp$status_code >= 200 && resp$status_code < 300) {
    cat("   ✔️ Lote enviado com sucesso.\n")
  } else {
    cat("   ❌ Erro ao enviar lote. Código: ", resp$status_code, "\n")
    print(content(resp))
    stop("Interrompido devido a erro no envio.")
  }
  
  inicio <- fim + 1
}

cat("🎉 Upload concluído com sucesso!\n")
#
