###############################################################
# SCRIPT DIÁRIO — Monitoramento do Modelo de Severidade
# Objetivo: ajustar o modelo na base viva acumulada,
# calcular métricas brutas e registrar no Supabase.
###############################################################

library(httr)
library(jsonlite)
library(dplyr)
library(lubridate)
library(pROC)
library(InformationValue)

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
# 3. Ler baseline (apenas métricas de referência)
###############################################################

cat("📌 Lendo acidentes_br116_modelo_baseline...\n")

baseline <- ler_tabela("acidentes_br116_modelo_baseline") %>%
  arrange(desc(data_treinamento)) %>%
  slice(1)

auc_base_treino <- baseline$auc_treino
auc_base_teste  <- baseline$auc_teste
ks_base_treino  <- baseline$ks_treino
ks_base_teste   <- baseline$ks_teste
cutoff_base     <- baseline$cutoff

###############################################################
# 4. Ler base viva acumulada
###############################################################

base_viva <- ler_tabela("acidentes_br116_base_viva")

n_linhas_base_viva <- nrow(base_viva)

###############################################################
# 4.1 — Ajustar tipos (ESSENCIAL)
###############################################################

# Transformar Periodo em factor com os mesmos níveis do treino
base_viva$Periodo <- factor(
  base_viva$Periodo,
  levels = c("manha", "noturno", "vespertino")  # MESMOS níveis do treino
)

# Transformar Km_cat em factor com os mesmos níveis do treino
base_viva$Km_cat <- factor(
  base_viva$Km_cat,
  levels = c("(0,25]", "(25,50]", "(50,75]", "(75,100]", "(100,125]",
             "(125,150]", "(150,175]", "(175,200]", "(200,225]",
             "(225,250]", "(250,300]", "(300,400]", "(400,500]", "(500,600]")
)

###############################################################
# 5. Ajustar modelo na base viva (mesma fórmula da produção)
###############################################################

modelo_viva <- glm(
  Gravemente_feridos_Mortos ~ Automovel + Bicicleta + Caminhao +
    Moto + Onibus + Outros + Utilitario +
    Periodo + Km_cat,
  family = binomial(link = "logit"),
  data = base_viva
)

###############################################################
# 6. Probabilidade
###############################################################

base_viva$probabilidade <- predict(modelo_viva, base_viva, type = "response")

###############################################################
# 7. Métricas (MESMO CRITÉRIO DO BASELINE)
###############################################################

# KS
ks_viva <- ks_stat(
  actuals = base_viva$Gravemente_feridos_Mortos,
  predictedScores = base_viva$probabilidade
)

# AUC
roc_obj <- pROC::roc(base_viva$Gravemente_feridos_Mortos,
                     base_viva$probabilidade)
auc_viva <- as.numeric(pROC::auc(roc_obj))

# Sensibilidade com cutoff do baseline
base_viva$Predito <- ifelse(base_viva$probabilidade > cutoff_base, 1, 0)

TP <- sum(base_viva$Predito == 1 & base_viva$Gravemente_feridos_Mortos == 1)
FN <- sum(base_viva$Predito == 0 & base_viva$Gravemente_feridos_Mortos == 1)

sensibilidade_viva <- TP / (TP + FN)


###############################################################
# 8. Capturar o último carga_id da base viva
###############################################################

carga_atual <- max(base_viva$carga_id)

###############################################################
# 9. Inserir métricas brutas no Supabase
###############################################################

registro <- list(
  carga_id = carga_atual,
  data_execucao = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  n_linhas_base_viva = n_linhas_base_viva,
  auc_viva = ifelse(is.na(auc_viva), 0, auc_viva),
  ks_viva = ifelse(is.na(ks_viva), 0, ks_viva),
  sensibilidade_viva = ifelse(is.na(sensibilidade_viva), 0, sensibilidade_viva),
  cutoff_usado = ifelse(is.na(cutoff_base), 0, cutoff_base)
)

print(registro)

resp <- inserir_registro(registro, "acidentes_br116_modelo_monitoramento")
# STATUS CODE: 201

cat("\nSTATUS CODE: ", resp$status_code, "\n")
cat("RESPOSTA DO SUPABASE:\n")
print(content(resp, "text", encoding = "UTF-8"))


###############################################################
# FIM DO SCRIPT
###############################################################


