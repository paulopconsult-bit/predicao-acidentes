###############################################################
# SCRIPT DIÁRIO — Atualização da acidentes_br116_base_viva
# Objetivo: gerar base viva diária e evitar duplicados usando Chave
###############################################################

library(httr)
library(jsonlite)
library(dplyr)
library(lubridate)

###############################################################
# 1. Configuração de ambiente (local vs GitHub Actions)
###############################################################

rodando_no_actions <- Sys.getenv("GITHUB_ACTIONS") == "true"

if (!rodando_no_actions) {
  library(dotenv)
  dotenv::load_dot_env("private/.env")
  
  supabase_url <- Sys.getenv("SUPABASE_URL")
  supabase_key <- Sys.getenv("SUPABASE_KEY")
} else {
  supabase_url <- Sys.getenv("SUPABASE_URL")
  supabase_key <- Sys.getenv("SUPABASE_KEY")
}

###############################################################
# 2. Funções auxiliares
###############################################################

# Ler tabela inteira do Supabase
ler_tabela <- function(nome_tabela) {
  url <- paste0(supabase_url, "/rest/v1/", nome_tabela, "?select=*")
  
  resp <- GET(
    url,
    add_headers(
      apikey = supabase_key,
      Authorization = paste("Bearer", supabase_key)
    )
  )
  
  df <- fromJSON(content(resp, "text", encoding = "UTF-8"))
  return(as.data.frame(df))
}

# Inserir lote no Supabase
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

###############################################################
# 3. Ler base limpa
###############################################################

cat("📌 Lendo acidentes_br116_base_limpa...\n")
base_limpa <- ler_tabela("acidentes_br116_base_limpa")

# Garantir que base limpa não tenha carga_id
if ("carga_id" %in% colnames(base_limpa)) {
  base_limpa$carga_id <- NULL
}

###############################################################
# 4. Sortear 150–200 registros
###############################################################

set.seed(as.numeric(format(Sys.time(), "%H%M%S")))
n_registros <- sample(150:200, 1)

sim <- base_limpa %>% sample_n(n_registros)

###############################################################
# 5. Criar carga_id (timestamp)
###############################################################

carga_id <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
sim$carga_id <- carga_id

###############################################################
# 6. Ler base viva
###############################################################

cat("📌 Lendo acidentes_br116_base_viva...\n")
base_viva <- ler_tabela("acidentes_br116_base_viva")

# Se estiver vazia, criar DF vazio com colunas corretas
if (nrow(base_viva) == 0) {
  base_viva <- base_limpa[0, ]
  base_viva$carga_id <- character(0)
}

###############################################################
# 7. Remover duplicados usando SOMENTE a coluna Chave
###############################################################

novos <- anti_join(sim, base_viva, by = "Chave")

cat("➡️ Registros sorteados:", nrow(sim), "\n")
cat("➡️ Registros novos (não duplicados):", nrow(novos), "\n")

if (nrow(novos) == 0) {
  cat("⚠️ Nenhum registro novo para inserir hoje.\n")
  quit(save = "no")
}

###############################################################
# 8. Inserir novos registros na base viva
###############################################################

cat("📌 Inserindo registros novos na acidentes_br116_base_viva...\n")

resp <- inserir_lote(novos, "acidentes_br116_base_viva")

if (resp$status_code >= 200 && resp$status_code < 300) {
  cat("🎉 Inserção concluída com sucesso!\n")
  cat("📊 Tamanho da amostra sorteada entre [150:200]:", nrow(sim), "\n")
  cat("📥 Registros realmente inseridos após remover duplicados:", nrow(novos), "\n")
} else {
  cat("❌ Erro ao inserir registros. Código:", resp$status_code, "\n")
  print(content(resp))
}

###############################################################
# FIM DO SCRIPT
###############################################################