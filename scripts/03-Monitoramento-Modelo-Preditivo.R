###############################################################
# SCRIPT DIÁRIO — Monitoramento do Modelo de Severidade
# Objetivo: aplicar o modelo de produção na base viva acumulada,
# calcular métricas reais e registrar no Supabase.
###############################################################

library(httr)
library(jsonlite)
library(dplyr)
library(lubridate)
library(pROC)

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

inserir_registro <- function(df, nome_tabela) {
  url <- paste0(supabase_url, "/rest/v1/", nome_tabela)
  
  POST(
    url,
    add_headers(
      apikey = supabase_key,
      Authorization = paste("Bearer", supabase_key),
      `Content-Type` = "application/json",
      Prefer = "return=minimal"
    ),
    body = toJSON(df, auto_unbox = TRUE)
  )
}

###############################################################
# 3. Ler baseline (cutoff e métricas de referência)
###############################################################

cat("📌 Lendo acidentes_br116_modelo_baseline...\n")

baseline <- ler_tabela("acidentes_br116_modelo_baseline") %>%
  arrange(desc(data_treinamento)) %>%
  slice(1)

cutoff_base <- baseline$cutoff

###############################################################
# 4. Ler base viva acumulada
###############################################################

base_viva <- ler_tabela("acidentes_br116_base_viva")
n_linhas_base_viva <- nrow(base_viva)

###############################################################
# 5. Carregar o modelo de produção (.rds)
###############################################################

modelo_original <- readRDS("modelos/modelo_producao.rds")

###############################################################
# 6. Ajustar níveis categóricos conforme o modelo original
###############################################################

niveis_treino <- modelo_original$xlevels

for (var in names(niveis_treino)) {
  base_viva[[var]] <- factor(
    base_viva[[var]],
    levels = niveis_treino[[var]]
  )
}

# Remover linhas incompatíveis
base_viva <- base_viva %>%
  filter(if_all(all_of(names(niveis_treino)), ~ !is.na(.x)))

###############################################################
# 7. Gerar probabilidade usando o modelo original
###############################################################

base_viva$probabilidade <- predict(modelo_original, base_viva, type = "response")

###############################################################
# 8. Calcular AUC e Sensibilidade
###############################################################

roc_obj <- pROC::roc(base_viva$Gravemente_feridos_Mortos,
                     base_viva$probabilidade)

auc_viva <- as.numeric(pROC::auc(roc_obj))

base_viva$Predito <- ifelse(base_viva$probabilidade > cutoff_base, 1, 0)

TP <- sum(base_viva$Predito == 1 & base_viva$Gravemente_feridos_Mortos == 1)
FN <- sum(base_viva$Predito == 0 & base_viva$Gravemente_feridos_Mortos == 1)

sensibilidade_viva <- TP / (TP + FN)

###############################################################
# 8A. Validação automática do KS — evita KS = 1 artificial
###############################################################

ks_valido <- TRUE
motivo_invalidacao <- NULL

# 1) Base muito pequena
if (nrow(base_viva) < 200) {
  ks_valido <- FALSE
  motivo_invalidacao <- "Base viva pequena"
}

# 2) Classe positiva ausente
if (sum(base_viva$Gravemente_feridos_Mortos == 1) == 0) {
  ks_valido <- FALSE
  motivo_invalidacao <- "Sem positivos na base viva"
}

# 3) Classe negativa ausente
if (sum(base_viva$Gravemente_feridos_Mortos == 0) == 0) {
  ks_valido <- FALSE
  motivo_invalidacao <- "Sem negativos na base viva"
}

# 4) Probabilidades colapsadas
q <- quantile(base_viva$probabilidade, probs = c(0, 0.25, 0.5, 0.75, 1))
if (length(unique(q)) <= 2) {
  ks_valido <- FALSE
  motivo_invalidacao <- "Probabilidades colapsadas"
}

# 5) Separação perfeita
if (ks_valido) {
  pos <- base_viva$probabilidade[base_viva$Gravemente_feridos_Mortos == 1]
  neg <- base_viva$probabilidade[base_viva$Gravemente_feridos_Mortos == 0]
  
  if (length(pos) > 0 && length(neg) > 0 && min(pos) > max(neg)) {
    ks_valido <- FALSE
    motivo_invalidacao <- "Separação perfeita detectada"
  }
}

# 6) Aplicar validação
if (!ks_valido) {
  cat("\n⚠️ KS INVALIDADO:", motivo_invalidacao, "\n")
  ks_viva <- NA
} else {
  ks_viva <- max(abs(roc_obj$sensitivities - roc_obj$specificities))
}

###############################################################
# 9. Capturar o último carga_id da base viva
###############################################################

carga_atual <- max(base_viva$carga_id)

###############################################################
# 10. Inserir métricas brutas no Supabase
###############################################################

registro <- list(
  carga_id = carga_atual,
  data_execucao = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  n_linhas_base_viva = n_linhas_base_viva,
  auc_viva = ifelse(is.na(auc_viva), 0, auc_viva),
  ks_viva = ifelse(is.na(ks_viva), 0, ks_viva),
  sensibilidade_viva = ifelse(is.na(sensibilidade_viva), 0, sensibilidade_viva),
  cutoff_usado = cutoff_base
)

print(registro)

resp <- inserir_registro(registro, "acidentes_br116_modelo_monitoramento")

cat("\nSTATUS CODE: ", resp$status_code, "\n")
cat("RESPOSTA DO SUPABASE:\n")
print(content(resp, "text", encoding = "UTF-8"))

###############################################################
# FIM DO SCRIPT
###############################################################
