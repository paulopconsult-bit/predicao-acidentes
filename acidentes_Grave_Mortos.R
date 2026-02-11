###############################################################
# SESSÃO 1 — Configuração inicial e bibliotecas
###############################################################

setwd("G:\\Meu Drive\\predicao-acidentes")
# working directory

#Bibliotecas
library(dplyr)
library(readxl)
library(expss)
library(Information) 
library(arules)
library(smbinning)
library(HH)
library(InformationValue) 
library(scorecard)
library(partykit)
library(CHAID)
library(gtools)
library(expss)
library(devtools)
library(Hmisc)


#install.packages("devtools")
#devtools::install_github("cran/InformationValue")


###############################################################
# SESSÃO 1.1 — Importação da base e preparação inicial
###############################################################

# ******************************************
# METODOLOGIA INICIAL PARA MONTAR O MODELO #
# ******************************************

library(readxl)
options(scipen=999)

# Conectar o R diretamente ao Excel
# data <- read_excel("dados.xlsx",sheet="Plan1") 
# data<-as.data.frame(data)


# Conectar o R diretamente ao SQL Server
#install.packages("odbc")
#install.packages("DBI")
library(DBI)
library(odbc)

# Conectar
conex_SQL <- dbConnect(odbc(),
                 Driver = "SQL Server",
                 Server = "PAULO",
                 Database = "TCC_FIA_2",
                 Trusted_Connection = "True")

# Testar conexão
dbGetQuery(conex_SQL, "
    SELECT TABLE_NAME 
    FROM INFORMATION_SCHEMA.TABLES 
    WHERE TABLE_SCHEMA = 'dbo'
")

# Desconectar
# dbDisconnect(conex_SQL) 

# Puxar a tabela do SQL e salvar no objeto data -- 67.127 registros
data <- dbGetQuery(conex_SQL, "
    SELECT *
    FROM dbo.base_acidentes_BR116_SP
")


# EXPORTAR O .CSV, origem SQL SERVER para BACKUP Silver
# Avalair se precisa sobrepor. Se houver alteração no SQL, exportar novamente.
# write.csv(data, "data/silver/data.csv", row.names = FALSE)

# rm(data)


###############################################
# 2. Padronizando as clases das variáveis
# IDENTIFICADORES (não entram no modelo)
###############################################

summary(data)

for (col in names(data)) print(col)

vars_id <- c(
  "Num_Ocorrencia"   # identificador único do acidente
)

vars_tempo <- ("DataRef")

###############################################
# 2.1 VARIÁVEIS EXPLICATIVAS (X)
###############################################

# 2.1.1 Variáveis categóricas explicativas
vars_categoricas <- c(
  "Concessionaria",
  "Periodo",
  "Trecho",
  "Pista",
  "SentidoPadrao"
)

# 2.2.2 Variáveis numéricas explicativas (contagens)
vars_numericas <- c(
  "KmDecimal",
  "Automovel", "Bicicleta", "Caminhao", "Moto", "Onibus", "Outros", "Utilitario",
  "Ilesos", "Levemente_feridos", "Moderadamente_feridos",
  "Gravemente_feridos", "Mortos"
)

# 2.1.3 Variáveis binárias explicativas (0/1)
vars_binarias <- c(
  "Automovel_bin", "Bicicleta_bin", "Caminhao_bin", "Moto_bin",
  "Onibus_bin", "Outros_bin", "Utilitario_bin",
  "Ilesos_bin", "Levemente_feridos_bin", "Moderadamente_feridos_bin",
  "Gravemente_feridos_bin", "Mortos_bin"
)


###############################################
# 2.2 POSSÍVEIS TARGETS (Y)
###############################################

# Estudo univariado, pontual
summary(data$TipoDeOcorrenciaPadrao)
cro(data$TipoDeOcorrenciaPadrao)

vars_target <- c(
  "TipoDeOcorrenciaPadrao",     # tipo de ocorrência (multiclasse)
  "Vitimas",                   # acidente teve vítimas (qualquer gravidade)
  "Gravemente_feridos_Mortos" # acidente grave (feridos graves ou mortos)
)

###############################################
# 2.3 TRATAMENTO DE VALORES VAZIOS
#    "" → NA (decisão metodológica documentada)
# regressão logística não aceita strings vazias
# árvores de decisão tratam vazio como categoria válida, o que distorce tudo
# modelos preditivos ficam enviesados
# métricas ficam erradas
# variáveis binárias ficam quebradas
# Transformar vazios em NA é obrigatório antes de seguir.
###############################################

# Avaliação
colSums(is.na(data))
colSums(data == "")

# Substituir todos os vazios por NA
data[data == ""] <- NA

# Teste, para ver os NA reais.
colSums(is.na(data))

###############################################
# 2.4 CONVERSÃO DE TIPOS
###############################################

# 2.4.1 Converter variáveis numéricas
data[vars_numericas] <- lapply(data[vars_numericas], as.numeric)

# 2.4.2 Converter variáveis binárias (0/1)
data[vars_binarias] <- lapply(data[vars_binarias], as.numeric)

# 2.4.3 Converter variáveis categóricas
data[vars_categoricas] <- lapply(data[vars_categoricas], as.factor)

# TipoDeOcorrenciaPadrao é categórico (multiclasse)
data$TipoDeOcorrenciaPadrao <- as.factor(data$TipoDeOcorrenciaPadrao)

# 2.4.4 Converter data
data$DataRef <- as.Date(data$DataRef)
# ou
data[vars_tempo] <- lapply(data[vars_tempo], as.Date)

# 2.4.5 Converter targets
# Vitimas e Gravemente_feridos_Mortos são binários
data$Vitimas <- as.numeric(data$Vitimas)
data$Gravemente_feridos_Mortos <- as.numeric(data$Gravemente_feridos_Mortos)


###############################################################
# SESSÃO 3 — Avaliação das TARGETS
# a target define o problema
###############################################################
str(data[vars_target]) 

cro(data$Vitimas)
cro_cpct(data$Vitimas)

cro(data$Gravemente_feridos_Mortos)
cro_cpct(data$Gravemente_feridos_Mortos)

cro(data$TipoDeOcorrenciaPadrao)
cro_cpct(data$TipoDeOcorrenciaPadrao)


# Vitimas é ampla demais e mistura leve, moderado, grave e morte.
# TipoDeOcorrenciaPadrao só separa “com vítima” e “sem vítima”, não mede severidade.
# Gravemente_feridos_Mortos foca exatamente nos casos severos e representa 5,2% dos acidentes, refletindo melhor a realidade que queremos modelar.
#
# Conclusão: a target mais coerente e robusta para prever severidade é Gravemente_feridos_Mortos.

vars_target <- setdiff(vars_target, "Vitimas")
vars_target <- setdiff(vars_target, "TipoDeOcorrenciaPadrao")
#
vars_target
str(data[vars_target]) 
# TARGET ESCOLHIDA
# Gravemente_feridos_Mortos 

###############################################################
# SESSÃO 4 — Análise Exploratória Univariada (AED) e Bivariada
# Em análise univariada e bivariada → manter NA é o certo
# objetivo: entender o fenômeno # Aqui NA é informação
###############################################################

summary(data)

library(skimr)
skim (data)

names(data)

#Quantitativa
cro(data$Automovel) # o cro() oculta os NA por padrão.

# Tabela de frequencias
for (vars_numericas_analise in vars_numericas) {
  cat("\n\n==============================\n")
  cat("Frequência de:", vars_numericas_analise, "\n")
  cat("==============================\n")
  print(table(data[[vars_numericas_analise]], useNA = "ifany"))
}


#Qualitativas / Categóricas

str(data[vars_categoricas])

cro_cpct(data$Concessionaria) # Desbalanceamento extremo O modelo não aprende nada sobre a categoria minoritária, por isso não vamos usar no modelo
cro_cpct(data$Trecho) # O Trecho é extremamente desbalanceado e, portanto, não tem poder explicativo para o modelo.

vars_categoricas <- setdiff(vars_categoricas, "Concessionaria") # removido, mas mantido na base original para efeito de controle visual do dashboard
vars_categoricas <- setdiff(vars_categoricas, "Trecho") # removido

cro_cpct(data$Pista) # Como filtramos da base original apenas a BR‑116/SP, o campo perdeu variabilidade
vars_categoricas <- setdiff(vars_categoricas, "Pista")

cro_cpct(data$SentidoPadrao) # O campo não é confiável, mesmo após tratamento continua (50/50).
vars_categoricas <- setdiff(vars_categoricas, "SentidoPadrao")

cro_cpct(data$Periodo) # tem distribuição saudável ou seja Variabilidade boa, Não é colinear

#Binárias
str(data[vars_binarias])

cro_cpct(data$Automovel_bin) # Boa, tem variabilidade

cro_cpct(data$Bicicleta_bin) # Ruim, Variável extremamente rara, Quase não aparece na base
vars_binarias <- setdiff(vars_binarias, "Bicicleta_bin")

cro_cpct(data$Caminhao_bin) # Boa, tem variabilidade

cro_cpct(data$Moto_bin) # Boa, tem variabilidade

cro_cpct(data$Onibus_bin) # ≥ 5% → variável aceitável, não é rara demais  

cro_cpct(data$Outros_bin) # Boa, tem variabilidade

cro_cpct(data$Utilitario_bin) # ≥ 5% → variável aceitável, não é rara demais 

cro_cpct(data$Ilesos_bin) # ≥ 5% → variável aceitável, não é rara demais 

cro_cpct(data$Levemente_feridos_bin) # Boa, tem variabilidade
vars_binarias <- setdiff(vars_binarias, "Levemente_feridos_bin") # Remove também por que tem mais haver com target do que com explicação

cro_cpct(data$Moderadamente_feridos_bin) # Boa, tem variabilidade
vars_binarias <- setdiff(vars_binarias, "Moderadamente_feridos_bin") # Remove também por que tem mais haver com target do que com explicação

cro_cpct(data$Gravemente_feridos_bin) # Fraca e usei para criar uma possivel target,não deve entrar como preditora
vars_binarias <- setdiff(vars_binarias, "Gravemente_feridos_bin") # Remove também por que tem mais haver com target do que com explicação

cro_cpct(data$Mortos_bin) # Fraca e usei para criar uma possivel target,não deve entrar como preditora
vars_binarias <- setdiff(vars_binarias, "Mortos_bin") # Remove também por que tem mais haver com target do que com explicação

vars_binarias

###############################################################
# SESSÃO 5 — Categorização de variáveis numéricas
# Análise Exploratória Univariada (AED) e Bivariada
###############################################################
str(data[vars_numericas]) 

str(data$Automovel)
summary(data$Automovel)

# Discretização de Variavel com NA, 
qs_Automovel <- quantile(data$Automovel, probs = seq(0, 1, 0.25), na.rm = TRUE)
qs_Automovel <- unique(qs_Automovel)  # evita quantis repetidos
data$Automovel_cat <- cut(data$Automovel, breaks = qs_Automovel, include.lowest = TRUE)
rm(qs_Automovel)

sum(is.na(data$Automovel))
cro_cpct(data$Automovel_cat)
table(data$Automovel, data$Automovel_cat)
table(data$Automovel_cat, data$Gravemente_feridos_Mortos)

table(data$Automovel, data$Gravemente_feridos_Mortos)

sum(is.na(data$Automovel))
sum(is.na(data$Automovel_cat))

# Automovel é uma variável numérica com informação rica.
# Automovel_cat destrói granularidade

# Removendo variaveis que respondem como Target ou possuem relação direta com a Target escolhida.
str(data[vars_numericas]) 

vars_numericas <- setdiff(vars_numericas, "Ilesos") # Remove também por que tem mais haver com target do que com explicação
vars_numericas <- setdiff(vars_numericas, "Levemente_feridos")
vars_numericas <- setdiff(vars_numericas, "Moderadamente_feridos")
vars_numericas <- setdiff(vars_numericas, "Gravemente_feridos")
vars_numericas <- setdiff(vars_numericas, "Mortos")

# Avaliando demais variáveis numericas
str(data[vars_numericas]) 

# Distribuição regular - vamos estudar no modelo - Removemos a versão bin, vamos manter esta
table(data$Bicicleta, data$Gravemente_feridos_Mortos)

# Boa distribuição, vamos manter esta
table(data$Caminhao, data$Gravemente_feridos_Mortos)

# Boa distribuição, vamos manter esta
table(data$Moto, data$Gravemente_feridos_Mortos)

# Distribuição regular - vamos estudar no modelo, vamos manter esta
table(data$Onibus, data$Gravemente_feridos_Mortos)

# Boa distribuição, vamos manter esta
table(data$Outros, data$Gravemente_feridos_Mortos)

# Não muito Boa distribuição, vamos manter esta para testar adiante
table(data$Utilitario, data$Gravemente_feridos_Mortos)

###############################################################
# SESSÃO 6 — Optimal Binning : binning supervisionado
# binning supervisionado só para variáveis numéricas contínuas
# Até aproximadamente 10 valores distintos (decimal ou inteiro)
###############################################################
str(data[vars_numericas]) 

library(smbinning)


# Para analise individual
KmDecimal_optbin<-smbinning(df=data,y="Gravemente_feridos_Mortos",x="KmDecimal",p=0.05) 
KmDecimal_optbin
KmDecimal_optbin$iv
KmDecimal_optbin$ivtable  
#
# Adicionando na base
data<-smbinning.gen(data,KmDecimal_optbin, chrname="KmDecimal_optbin_cat")

# CRIANDO uma nova variavel binning, não ficamos coerentes com a realidade
# O que seria de utilidade prever Y até ante de X Km e após de X Km, neste caso 97 Km
sum(is.na(data$KmDecimal_optbin_cat))
table(data$KmDecimal_optbin_cat, data$Gravemente_feridos_Mortos)
cro_cpct(data$KmDecimal_optbin_cat)
summary(data$KmDecimal)


# KmDecimal é uma variável espacial, não uma variável preditiva comum
summary(data$KmDecimal)
table(data$KmDecimal, data$Gravemente_feridos_Mortos)

# O nome técnico desta operação é Binning Manual
#### Arbitrei em 11 faixas para ficar mais próximo da realidade ############
# A categoria (200,250] tinha 34,1% dos casos — um monstrão desbalanceado.
# Agora, (200,225] → 25,7% e (225,250] → 8,4%, melhora a sensibilidade da regressão e da árvore e evita que uma categoria gigante “engula” o efeito das outras
data$Km_cat <- cut(
  data$KmDecimal,
  breaks = c(0, 50, 100, 150, 200, 225, 250, 300, 350, 400, 450, 500, 600),
  include.lowest = TRUE
)
table(data$Km_cat, data$Gravemente_feridos_Mortos)
cro_cpct(data$Km_cat)
summary(data$Km_cat)

# DE 0 a 250 km concentra praticamente 80% dos acidentes # A rodovia é “densa” até 250 km e “rala” depois disso.
# Criar mais faixas abaixo de 250 km e manter faixas maiores acima disso.
data$Km_cat <- cut(
  data$KmDecimal,
  breaks = c(0, 25, 50, 75, 100, 125, 150, 175, 200, 225, 250, 300, 400, 500, 600),
  include.lowest = TRUE
)
# A probabilidade de 1 sobre 0 nessa faixa  "(200,225] 10442 515" é similar às faixas vizinhas, A faixa é grande, mas estável
cro_cpct(data$Km_cat)
table(data$Km_cat, data$Gravemente_feridos_Mortos)
summary(data$Km_cat)



vars_categoricas <- c(vars_categoricas, "Km_cat")
vars_categoricas



###############################################################
# SESSÃO 7 — Criação de variáveis derivadas
###############################################################
dim(data)
head(data)
str(data)
nrow(data)



data$Onibus_Caminhao_Bin <- ifelse(data$Onibus_bin==1 | data$Caminhao_bin == 1, 1, 0)
table(data$Onibus_Caminhao_Bin, data$Gravemente_feridos_Mortos)
cro_cpct(data$Onibus_Caminhao_Bin)
summary(data$Onibus_Caminhao_Bin)

vars_binarias <- c(vars_binarias, "Onibus_Caminhao_Bin")
vars_binarias

###############################################################
# SESSÃO 8 — Conversão de variáveis para modelagem
# Transformar variáveis que são categorias (e não números contínuos) em fatores, para que:
# a regressão logística trate como categorias, a CHAID funcione corretamente, o R não interprete números como valores contínuos
###############################################################

str(data)
library(dplyr)

# Transformar todas as variáveis categóricas em factor
data[vars_categoricas] <- lapply(data[vars_categoricas], as.factor)

# Transformar todas as variáveis binárias em factor
data[vars_binarias] <- lapply(data[vars_binarias], as.factor)

# Variáveis numéricas (revisão)
data[vars_numericas] <- lapply(data[vars_numericas], as.numeric)


###############################################################
# SESSÃO 8.1 — Transformas TARGET em factor 
# (regressão aceita target númerico), mas vamos simplificar e garantir quando factor
# Transformamos o target em fator para que o modelo trate como variável categórica (0 e 1)
###############################################################

# Transformar a target em factor
data[vars_target] <- lapply(data[vars_target], as.factor)
# OU
data$Gravemente_feridos_Mortos <- as.factor(data$Gravemente_feridos_Mortos)

# Definimos o nível "0" como referência, garantindo que o modelo estime P(Y = 1),
# ou seja, a probabilidade de ocorrer um acidente grave ou com morte
data$Gravemente_feridos_Mortos <- relevel(data$Gravemente_feridos_Mortos, ref = "0")
#Validar o relevel
levels(data$Gravemente_feridos_Mortos)
# Retornar -> [1] "0" "1"
# “0” é o nível de referência
# “1” é o evento modelado


# ---------------------------------------------------------------
# Quando usar a target como NUMÉRICA (0/1) vs FACTOR
#
# Métodos que exigem target NUMÉRICA (0/1):
# - IV / WOE
# - Regressão logística
# - XGBoost / LightGBM (binário)
# - Métricas de performance (AUC, KS, Lift, LogLoss, Sensibilidade, etc.)
#
# Métodos que exigem target FACTOR:
# - Árvores de decisão (rpart, C5.0, party)
# - Random Forest (classificação)
# - SVM / kNN / Naive Bayes
#
# Resumo:
# Use target NUMÉRICA para cálculos estatísticos e modelos baseados em probabilidade.
# Use target FACTOR para modelos de classificação baseados em classes.
# ---------------------------------------------------------------


###############################################################
# SESSÃO 9 — Information Value (IV)
# CRIAR base para MODELO
# -------------------------------------------------------------
# Tabela de Interpretação do Information Value (IV)
#
# IV < 0.02        -> Sem poder preditivo
# 0.02 – 0.10      -> Baixo poder preditivo
# 0.10 – 0.30      -> Médio poder preditivo
# 0.30 – 0.50      -> Forte poder preditivo
# IV > 0.50        -> Suspeito (pode indicar leakage)
# -------------------------------------------------------------
###############################################################

library(Information)

vars_modelagem <- c(
  vars_tempo,
  vars_numericas,
  vars_categoricas,
  vars_binarias,
  vars_target
)
# Criar o data frame final de modelagem
base <- data[, vars_modelagem]

# Removendo registro quando target = NA
# O target tem valores NA na base
sum(is.na(base$Gravemente_feridos_Mortos))/nrow(base)
# 36,9% da base está com o target NA
nrow(base)-sum(is.na(base$Gravemente_feridos_Mortos))
# A base sem NA deverá contar 42303 registros

# remover apenas os registros com NA no target
base <- base[!is.na(base$Gravemente_feridos_Mortos), ]
cro_cpct(base$Gravemente_feridos_Mortos)
summary(base$Gravemente_feridos_Mortos)
nrow(base)
# 5,25% têm vítima grave e/ou morta
# Ou seja, seu target é fortemente desbalanceado, o que é absolutamente normal em modelos de severidade.
# base agora está pronta para modelagem supervisionada.

# Transformar a variável target binária 0/1 de factor para numérica,
# para aplicar cálculos (IV), regressão glm() e árvore CHAID
base$Gravemente_feridos_Mortos <- as.numeric(as.character(base$Gravemente_feridos_Mortos))
class(base$Gravemente_feridos_Mortos)
cro_cpct(base$Gravemente_feridos_Mortos)

# IV
IV <- create_infotables(data = base, y = "Gravemente_feridos_Mortos")
IV$Summary



# Variáveis de leakage devem ser removidas SEMPRE, independentemente do IV
# Deixamos escapar nas analises anteriores
# são derivadas do próprio target ou contêm informação direta sobre ele.
# Remover variáveis que são efeitos do acidente, não causas.
base$Ilesos_bin         <- NULL
vars_binarias <- vars_binarias[vars_binarias != "Ilesos_bin"]
vars_binarias

# Baixo poder preditivo ou sem poder preditivo IV <0.10
base$KmDecimal      <- NULL                    # IV = 0.03429499
base$Automovel_bin      <- NULL   # 0.09476693


# Onibus e Caminhao
base$Onibus     <- NULL
base$Caminhao    <- NULL
# Removemos porque Onibus e Caminho explicam bem e ficamos com a versão binária delas

# Variaveis que a a nova variavel generica binaria teve o IV igual, então deixamos a binaria e removemos a numerica
base$Moto     <- NULL
base$Outros      <- NULL
base$Utilitario  <- NULL

# Automovel IV de 0.19111147, explica melhor o negocio e é numerica serve tanto para regressão quanto para a arvore
# Automovel tem somente 13 valores de 0 até 12
table(base$Automovel, base$Gravemente_feridos_Mortos)


# CRIAR VARIAVEIS PERIODICAS
# Criar Mês (01 a 12)
base$Mes <- format(base$DataRef, "%m")

# Criar Dia da Semana
base$DiaSemana <- weekdays(base$DataRef)

# Padronizar nomes (Ajuda no CHAID e regressão)
base$DiaSemana <- factor(base$DiaSemana,
                         levels = c("segunda-feira","terça-feira","quarta-feira",
                                    "quinta-feira","sexta-feira","sábado","domingo"))


# Avaliar IV
IV <- create_infotables(data = base, y = "Gravemente_feridos_Mortos")
IV$Summary


# Excluir variaveis periodicas que nao tiveram bom IV e DataRef
base$DataRef   <- NULL
base$Mes     <- NULL
base$DiaSemana      <- NULL


# Onibus_Caminhao_Bin IV 2.30202564, Suspeito e temos a orginais Onibus e Caminhao , vamos remove-la
base$Onibus_Caminhao_Bin      <- NULL

# Avaliar IV
IV <- create_infotables(data = base, y = "Gravemente_feridos_Mortos")
IV$Summary
# Tabela IV
dataIV <- IV$Summary
dataIV$Classif_IV <- ifelse(dataIV$IV <= 0.02, "Fraquissimo",
                            ifelse(dataIV$IV <= 0.1 ,"Fraco",
                                   ifelse(dataIV$IV <= 0.3 ,"Média",
                                          ifelse(dataIV$IV <= 0.5 ,"Forte",
                                                 "Suspeita"))))
dataIV




###############################################################
# SESSÃO 10 — Organização final das variáveis
# Se necessário
###############################################################

# names(base)
# base <- base[, c("Periodo",
#                  "Automovel",
#                  "Caminhao_bin", "Moto_bin", "Onibus_bin", "Utilitario_bin",
#                  "Bicicleta_bin", "Outros_bin",
#                  "Km_cat",
#                  "Gravemente_feridos_Mortos")]
# names(base)
# str(base)


###############################################################
# SESSÃO 11 — Divisão Treino/Teste
# Sempre avaliar Tratar NAs nas variáveis do modelo, verificar se antecipa nesta etapa.
# Para modelagem → remover NA apenas nas variáveis do modelo é o certo
# objetivo: ajustar um modelo matemático; NA atrapalha
###############################################################

# Verificar NAs no treino e teste
colSums(is.na(base))

# Criar a lista de variáveis que devem estar sem NA
vars_modelo_Sem_NA <- c( "Automovel", "Bicicleta", "Caminhao_bin", "Moto_bin", 
                         "Onibus_bin", "Outros_bin", "Utilitario_bin", "Periodo", 
                         "Km_cat", "Gravemente_feridos_Mortos" )

# Remover todas as linhas com NA nessas variáveis
base_limpa <- base[complete.cases(base[vars_modelo_Sem_NA]), ]

# EXPORTAR O .CSV, base_limpa para simular produção MLOps
# write.csv(base_limpa, "data/prepared/base_limpa_v1.csv", row.names = FALSE)



# Fixamos a semente para garantir reprodutibilidade.
# Assim, sempre que rodarmos o código, a mesma amostra será selecionada.
set.seed(42)

# Selecionamos aleatoriamente 80% das linhas da base_limpa para compor o conjunto de treino.
amostra <- sort(sample(nrow(base_limpa), nrow(base_limpa) * 0.80))

# Conjunto de treino: usado para ajustar (treinar) os modelos.
treino <- base_limpa[amostra, ]
# Conjunto de teste: usado para avaliar o desempenho do modelo em dados novos.
teste <- base_limpa[-amostra, ]


###############################################################
# SESSÃO 12 — Regressão Logística
###############################################################

dataIV

# Aplicar modelagem
modelo <- glm(Gravemente_feridos_Mortos ~    
                Periodo+
                Automovel+Bicicleta+
                Caminhao_bin+Moto_bin+Onibus_bin+Outros_bin+Utilitario_bin+
                Km_cat,
              family=binomial(link='logit'),
              data=treino)
summary(modelo)
# AIC Akaike Information Criterion / Critério de Informação de Akaike
# Mede o equilíbrio entre o quão bem o modelo se ajusta aos dados (qualidade do ajuste) e o quanto ele é simples (penaliza modelos com muitas variáveis)
# AIC DO MODELO: 8967.9
# AIC menor → modelo melhor
# AIC maior → modelo pior

# VARIAVEIS EM ALERTA:

### Caminhao_bin p-valor ruim e IV ótimo
table(treino$Caminhao_bin)
prop.table(table(treino$Caminhao_bin))
# IV 2.44493864 suspeita
# p-valor 0.6873 alto
# VIF excelente

### Onibus_bin p-valor ruim e IV médio
table(treino$Onibus_bin)
prop.table(table(treino$Onibus_bin))
# IV 0.16749755 Média
# p-valor 0.3956 alto
# VIF excelente

### Utilitario_bin p-valor ruim e IV ótimo
table(treino$Utilitario_bin)
prop.table(table(treino$Utilitario_bin))
# IV 0.15257725 médio, O IV não é forte o suficiente para justificar manter.
# p-valor  0.3514  alto
# VIF excelente

### Km_cat
# Variavel de qualidade do entendimento do negócio
# IV Fraco
# VIF excelente
# o modelo precisa explicar risco por distância → manter. porque se nao se torna irrelevante


# Km_cat: manter, pois é variável central para explicar risco por distância.
# Caminhao_bin e Onibus_bin: manter, pois representa um tipo de veículo crítico na severidade.
# Utilitario_bin: remover, pois tem baixo impacto e não é essencial ao modelo.

# Frequência da variável
# Se for rara → remover ou agrupar.
#
# VIF (colinearidade) - alto → remover
#
# Impacto no desempenho (AIC/AUC)
# Se o modelo piora sem ela → manter
# Se nada muda → remover
#
# Na regressão logística 
# Avaliar Estimate (coeficiente) → interpretação do efeito no risco

###############################################################
# SESSÃO 13 — VIF
# VIF = Variance Inflation Factor  
# É um indicador que mostra quanto a variância do coeficiente de uma variável está sendo inflada por causa da multicolinearidade.
# VIF mede se uma variável está “brigando” com outra dentro do modelo.
# VIF entre 1 e 2 Excelente, sem colinearidade
# VIF < 5 → seguro
# VIF entre 5 e 10 → atenção
# VIF > 10 → problema sério
###############################################################


library(HH)
vif(modelo)

# O modelo está coerente com a realidade operacional
# Usar a coluna: GVIF^(1/(2*Df))
# Todos VIF excelentes: Não existe colinearidade relevante


###############################################################
# SESSÃO 14 — Ajustamento do Modelo / Se necessário
###############################################################


# Aplicar modelagem
# modelo <- glm(Gravemente_feridos_Mortos ~    
#                 Periodo+
#                 Automovel+Bicicleta+
#                 Caminhao_bin+Moto_bin+Onibus_bin+Outros_bin+
#                 Km_cat,
#               family=binomial(link='logit'),
#               data=treino)
# summary(modelo)
# Remove Utilitario_bin
# AIC DO MODELO: 9145.3
# AIC: 9145.3, manteve o mesmo valor - Utilitario_bin realmente não contribuía com nada
# O modelo ficou mais simples
# Não perdeu qualidade (AIC igual)


###############################################################
# SESSÃO 15 — KS (Kolmogorov-Smirnov), AUC e ROC
# KS: 0.00–0.20 muito fraco; 0.20–0.30 fraco; 0.30–0.40 razoável; 0.40–0.50 bom; >0.50 excelente.
# AUC: 0.50 aleatório; 0.50–0.60 fraco; 0.60–0.70 razoável; 0.70–0.80 bom; 0.80–0.90 muito bom; >0.90 suspeito.
# ROC: Interpretação visual
# Curva próxima da diagonal = fraco; levemente acima = razoável;
# bem arqueada = bom; muito arqueada = excelente; quase perfeita = suspeito (overfitting).

###############################################################

library(pROC)

# ADICIONAR O CAMPO DA PROBABILIDADE ao treino
treino$probabilidade = predict(modelo,treino, type = "response")

ks_stat(actuals=treino$Gravemente_feridos_Mortos, predictedScores=treino$probabilidade)
# 0.3389 razoável, mas esperado devido ao target raro; modelo estável.

roc_obj <- pROC::roc(treino$Gravemente_feridos_Mortos, treino$probabilidade)
pROC::auc(roc_obj)
# Area under the curve: 0.7313 bom

plot(roc_obj, col = "blue", lwd = 2)
# Devido o AUC, A curva ROC deve estar bem arqueada, mas não perfeita.


# ADICIONAR O CAMPO DA PROBABILIDADE ao teste
teste$probabilidade = predict(modelo,teste, type = "response")

ks_stat(actuals=teste$Gravemente_feridos_Mortos, predictedScores=teste$probabilidade)
# 0.3982 razoável, mas esperado devido ao target raro; modelo estável.

roc_obj_teste <- pROC::roc(teste$Gravemente_feridos_Mortos, teste$probabilidade)
pROC::auc(roc_obj_teste)
# Area under the curve: 0.7494 bom

plot(roc_obj_teste, col = "blue", lwd = 2)
# Devido o AUC, A curva ROC deve estar bem arqueada, mas não perfeita.

# Area under the curve: 0.7225 bom; desempenho consistente com o de treino e sem overfitting.
# Sobre o gráfico, Quanto mais a curva se aproxima do canto superior esquerdo, melhor
# Esse canto representa:Sensibilidade = 1, Falso positivo = 0 - Ou seja: modelo perfeito.


# Os resultados no teste estão totalmente coerentes com o que vimos no treino
# AUC: A diferença é pequena → não há overfitting


###############################################################
# SESSÃO 16 — Ponto de Corte
###############################################################

library(cutpointr)

# AVALAIR/revisar SE EXISTE NA's na base (não deve ter)
colSums(is.na(treino[, c("probabilidade", "Gravemente_feridos_Mortos")]))
#  NA acontece quando o predict() não consegue calcular a probabilidade para algumas linhas do treino, porque Existem valores NA nas variáveis explicativas usadas no modelo.

# Se NAs surgiram depois do modelo estar pronto, Isso não afeta o modelo, só afeta a previsão dessas linhas.
# E o cutpointr não aceita NA, por isso deu erro. Remover NAs agora não invalida nada

# Se necessário Mantém somente as linhas onde nenhuma dessas duas colunas tem NA
# Já eliminamos linhas com NA devido variaveis explicativas para criar a base de treino e teste
# treino2 <- treino[complete.cases(treino[, c("probabilidade", "Gravemente_feridos_Mortos")]), ]
# Confere se ainda existe NA
# colSums(is.na(treino2[, c("probabilidade", "Gravemente_feridos_Mortos")]))


# Equilibra sensibilidade e especificidade.
ponto <- cutpointr(treino, probabilidade, Gravemente_feridos_Mortos,
                   method = minimize_metric, metric = abs_d_sens_spec)
summary(ponto)
# Obter ponto de cort cuttoff: 0.0327  Esse cutoff é baixo, porque seu modelo gera probabilidades pequenas (target raro)
# optimal_cutpoint = 0.0327 
# sensibilidade = 0.6637 # acerta 66.4% dos casos graves (sensibilidade).
# especificidade = 0.6636 
# Esse é o cutoff mais adequado para modelos de severidade, onde FN é caro.


# Accuracy engana quando a classe 1 é rara. Descartado
ponto2 <- cutpointr(treino, probabilidade, Gravemente_feridos_Mortos,
                   method = maximize_metric, metric = accuracy)
summary(ponto2)
# Obter ponto de cort cuttoff: Inf    # accuracy dá cutoff absurdo
# optimal_cutpoint = Inf   
# sensibilidade = 0
# especificidade = 1
# acc = 0.9665 # Acurácia fica alta porque 97% dos casos são 0.


# Cutoff pelo F1 (classe rara → muito útil)
# Conservador Não recomendado para severidade.
ponto_f1 <- cutpointr(treino, probabilidade,Gravemente_feridos_Mortos,
                      method = maximize_metric, metric = F1_score)
summary(ponto_f1)
# optimal_cutpoint: 0.0893


# Cutoff pelo KS (maximiza separação)
# O cutoff que maximiza Youden é o cutoff que maximiza o KS
ponto_ks <- cutpointr(treino, probabilidade, Gravemente_feridos_Mortos,
                      method = maximize_metric, metric = youden)
summary(ponto_ks)
# optimal_cutpoint:0.0306

# Qual cutoff é o melhor para o seu modelo?
#   Seu problema é severidade de acidentes, onde:   
#   FN = deixar de identificar um caso grave# 
#   FP = classificar como grave quando não é
# 
# Em modelos de severidade: ✔ FN é muito mais caro que FP
# 1º lugar: KS (0.0306)
# Maior sensibilidade # Menor FN # Melhor separação estatística # Ideal para risco/severidade


# INCLUIR A PROBABILIDADE DO PONTO DE CORTE ESCOLHIDO NO TESTE (SOBREPOR)
teste$probabilidade <- predict(modelo, teste, type = "response")

teste$probb_cat <- ifelse(teste$probabilidade>0.0306,1,0)
# Gerar a matriz cruzada (confusão)
cro(teste$Gravemente_feridos_Mortos, teste$probb_cat)



###############################################################
# SESSÃO 16 — Métricas de desempenho do TESTE
###############################################################

# matriz cruzada (confusão)
teste$Real <- teste$Gravemente_feridos_Mortos
teste$Predito <- teste$probb_cat
cro(teste$Real, teste$Predito)
# OU
cro(teste$Gravemente_feridos_Mortos, teste$probb_cat)

# Valores da matriz de confusão
TP <- 251
FN <- 71
FP <- 3024
TN <- 4958

# Total
# A matriz de confusão usa apenas as linhas onde existe predição válida
# E algumas linhas do teste ficaram com probabilidade = NA
Total <- TP + FN + FP + TN
nrow(teste)

# Acurácia
Acuracia <- (TP + TN) / Total
Acuracia

# Sensibilidade (Recall)
Sensibilidade <- TP / (TP + FN)
Sensibilidade

# Especificidade
Especificidade <- TN / (TN + FP)
Especificidade

# Precisão (PPV)
Precisao <- TP / (TP + FP)
Precisao


###############################################################
# SESSÃO 17 — Estrair os coeficientes do MODELO DE REGRESSÃO
###############################################################
# logit(𝑝)=  𝛽0+𝛽1𝑋1+𝛽2𝑋2+…

summary(modelo)
coef(modelo)

# obter a fórmula já formatada pelo R
formula(modelo)

# obter a equação completa em formato matemático
library(equatiomatic)
extract_eq(modelo, use_coefs = TRUE)



# PAREI AQUI#
###############################################################
# SESSÃO 18 — Árvore de Decisão CHAID
# Usamos as mesmas variáveis finais do modelo de regressão,
# exceto:
# - CHAID não aceita variáveis numéricas contínuas → precisam ser factor
# - CHAID não aceita variáveis com leakage
# - CHAID não aceita variáveis com NA
# - CHAID não usa variáveis descartadas por IV ou negócio
###############################################################

dataIV   # Apenas para consulta da força preditiva das variáveis

# Variáveis usadas no modelo de regressão:
# glm(Gravemente_feridos_Mortos ~    
#                 Periodo+
#                 Automovel+Bicicleta+
#                 Caminhao_bin+Moto_bin+Onibus_bin+Outros_bin+Utilitario_bin+
#                 Km_cat,

# Garantir que TODAS as variáveis explicativas usadas no CHAID
# estejam como factor (CHAID exige variáveis categóricas)
vars_para_factor <- c(
  "Periodo", "Automovel","Bicicleta","Caminhao_bin","Moto_bin",
  "Onibus_bin","Outros_bin","Utilitario_bin","Km_cat"
)

treino[vars_para_factor] <- lapply(treino[vars_para_factor], as.factor)
teste[vars_para_factor]  <- lapply(teste[vars_para_factor], as.factor)

# Garantir que a variável TARGET esteja como factor
# (CHAID não funciona com target numérica)
treino$Gravemente_feridos_Mortos <- as.factor(treino$Gravemente_feridos_Mortos)
teste$Gravemente_feridos_Mortos  <- as.factor(teste$Gravemente_feridos_Mortos)

library(CHAID) 
library(dplyr)

# Controle da árvore: maxheight limita profundidade para evitar overfitting
# Controla quantos níveis de splits a árvore pode ter
controle <- chaid_control(maxheight = 4)

# Ajuste da árvore CHAID usando exatamente as variáveis finais do modelo
arvore_4niveis <- chaid(
  Gravemente_feridos_Mortos ~
    Periodo +
    Automovel +
    Bicicleta +
    Caminhao_bin +
    Moto_bin +
    Onibus_bin +
    Outros_bin +
    Utilitario_bin +
    Km_cat,
  data = treino,
  control = controle
)

# Plot da árvore (visualização padrão e uniforme)
plot(arvore_4niveis, uniform = TRUE, compress = TRUE, gp = gpar(cex = 0.6))


###############################################################
# SESSÃO 19 — Probabilidades e nós da árvore
###############################################################

# Identifica o número do nó terminal para cada observação do TREINO
# Isso permite analisar quais perfis caem em cada nó
treino$no <- predict(arvore_4niveis, treino, type = "node")


# Identificar "nós"
with(treino, table(Periodo[treino$no == 28]))
with(treino, table(Periodo[treino$no == 29]))


# Frequência de observações por nó
table(treino$no)

# Tabela cruzada: nó x target
# cro_rpct mostra proporções por linha/coluna (ótimo para entender risco por nó)
cro_rpct(treino$no, treino$Gravemente_feridos_Mortos)

# Probabilidade prevista pelo CHAID para a classe "1"
# predict(..., type="p") retorna uma matriz com P(0) e P(1)
treino$prob <- predict(arvore_4niveis, treino, type = "p")[,2]

# Alternativa: salvar as duas probabilidades separadamente
probs <- as.data.frame(predict(arvore_4niveis, newdata = treino, type = "p"))
names(probs) <- c("P_0", "P_1")

# Anexa as probabilidades ao dataset de treino
treino <- cbind(treino, probs)

# Probabilidade geral da classe 1 no conjunto de treino
# (serve como cutoff baseado na taxa base)
prob_geral <- sum(treino$Gravemente_feridos_Mortos == "1") / nrow(treino)
prob_geral

# Classificação binária usando o cutoff = probabilidade geral
treino$predito_arvore <- ifelse(treino$prob >= prob_geral, "1", "0")

# Matriz de confusão: real x predito
cro(treino$Gravemente_feridos_Mortos, treino$predito_arvore)

# ✔ Verdadeiros Negativos (0 → 0): 23.652
# Muito bom — a árvore acerta a maioria dos casos seguros.
# 
# ✔ Verdadeiros Positivos (1 → 1): 659
# Bom — considerando que a classe 1 é rara (3,35%).
# 
# ❌ Falsos Negativos (1 → 0): 453
# Normal — com cutoff baixo, sempre haverá FN.
# 
# ❌ Falsos Positivos (0 → 1): 8.448
# Também normal — CHAID tende a ser agressivo quando o cutoff é baixo.


###############################################################
# SESSÃO 19 — Avaliação da árvore na base de teste
###############################################################


# 0. Forma de avaliar, quando separamos Treino e Teste é comun para variáveis continuas
# Terem valores que aparecem em Treino mas não em teste, e vice versa, 
# então abaixo temos um código para testar em caso de erro, onde o erro informa a variáve.
# verificar quais níveis existem em cada base
# levels(treino$Bicicleta)
# levels(factor(teste$Bicicleta))
# Ou
# setdiff(unique(teste$Bicicleta), levels(treino$Bicicleta))


# 1. Alinhar níveis do teste com os níveis do treino
# Cada variável do teste passa a ter exatamente os mesmos níveis do treino.  
# Qualquer nível "novo" em teste vira NA.  
for(v in vars_para_factor){
  teste[[v]] <- factor(teste[[v]], levels = levels(treino[[v]]))
}

# 2. Gerar probabilidades da árvore
teste$prob_arvore <- predict(arvore_4niveis, teste, type = "p")[,2]

# 3. Criar predição binária usando o cutoff prob_geral
teste$predito_arvore <- ifelse(teste$prob_arvore >= prob_geral, "1", "0")

# 4. Matriz de confusão
cro(teste$Gravemente_feridos_Mortos, teste$predito_arvore)

# 5. Interpretação dos quatro quadrantes

# ✔ Verdadeiros Negativos (0 → 0): 5851
# A árvore acerta a grande maioria dos casos seguros.
# Isso é esperado, já que a classe 0 domina o dataset.
# 
# Interpretação:  
#   O modelo é muito bom em identificar acidentes não graves.
# 
# ✔ Verdadeiros Positivos (1 → 1): 201
# Esses são os casos em que o modelo acertou acidentes graves.
# 
# Interpretação:  
#   Mesmo com classe rara (~3%), o modelo conseguiu capturar 201 casos graves corretamente.
# 
# ❌ Falsos Negativos (1 → 0): 121
# Casos graves que o modelo classificou como não graves.
# 
# Interpretação:  
#   Isso é normal — acidentes graves são raros e difíceis de prever.
# Mas ainda assim, 121 FN é um número relativamente baixo.
# 
# ❌ Falsos Positivos (0 → 1): 2131
# Casos não graves que o modelo classificou como graves.
# 
# Interpretação:  
#   O modelo está agressivo, marcando muitos casos como risco alto.
# Isso é típico quando o cutoff é baixo (como o seu prob_geral).


# Conclusão
# A árvore está funcionando bem para um problema com classe rara.
# Ela é conservadora: prefere errar para o lado de alertar risco (FP) do que deixar passar acidentes graves (FN).
# 
# Isso é perfeito para aplicações de segurança viária.



###############################################################
# SESSÃO 20 — Conclusões Finais
###############################################################

# h) Qual modelo, dentre árvore de decisão e regressão logística, você recomenda?

# A regressão logística apresentou melhor desempenho geral, com métricas mais equilibradas
# entre sensibilidade e especificidade. É um modelo mais estável, com menor quantidade de
# falsos positivos e melhor adequação para uso operacional.

# A árvore CHAID, por outro lado, apresentou maior sensibilidade, identificando mais casos
# graves, mas ao custo de muitos falsos positivos. Sua principal vantagem é a interpretabilidade:
# regras claras, nós bem definidos e perfis de risco facilmente comunicáveis.

# Conclusão:
# - Regressão Logística → melhor para previsão e uso operacional.
# - Árvore CHAID → melhor para interpretação, explicação e entendimento dos padrões.
# Os modelos são complementares: logística para prever, árvore para entender.


###############################################################
# SEÇÃO 21: RESUMO GERAL DO PROJETO
# Baseline Model Artifact  do Projeto de MLOps
# Data/Hora do registro:  
#   10/02/2026 — 17:12 (Horário de Brasília)
###############################################################

# 1. Preparação da base
# - Importação, limpeza e transformação em data.frame.
# - Análise exploratória univariada.
# - Identificação da distribuição da variável-alvo (~3,3% de casos graves).

# 2. Criação e tratamento das variáveis
# - Categorizações importantes (Automovel, Km).
# - Criação de variáveis binárias (Onibus_bin, Caminhao_bin, etc.).
# - Conversão de variáveis categóricas para fator.

# 3. Seleção de variáveis (IV)
# - Cálculo do Information Value.
# - Remoção de variáveis fracas ou sem variação.
# - Retenção apenas das variáveis com poder explicativo relevante.

# 4. Divisão da base
# - Separação em treino (80%) e teste (20%).
# - Garantia de avaliação realista e sem overfitting.

# 5. Regressão Logística
# - Ajuste do modelo com variáveis selecionadas.
# - Avaliação de estabilidade (KS e AUC satisfatórios).
# - Modelo final robusto e equilibrado.

# 6. Ponto de corte da Regressão
# - Cutoff escolhido: 0.0318.
# - Geração de predições binárias e matriz de confusão.

# 7. Desempenho da Regressão (Teste)
# - Acurácia ≈ 68,6%
# - Especificidade ≈ 68,7%
# - Sensibilidade ≈ 66,9%
# - Taxa de conversão ≈ 7%

# 8. Árvore de Decisão (CHAID)
# - Ajuste com variáveis categóricas.
# - Obtenção de nós, regras e probabilidades por nó.
# - Probabilidade individual = probabilidade do nó.

# 9. Predição da Árvore
# - Cutoff utilizado: probabilidade geral da carteira (~3,27%).
# - Geração de predições binárias e matriz de confusão.

# 10. Desempenho da Árvore (Teste) — ATUALIZADO
# Matriz de confusão:
#                 Predito
#                 0      1
# Real 0        5851   2131
# Real 1         121    201
#
# - Acurácia: 72,8%
# - Especificidade: 73,3%
# - Sensibilidade: 62,4%
# - Taxa de conversão: 201 / (201 + 2131) ≈ 8,6%
#
# A árvore é mais agressiva, gerando muitos falsos positivos, mas captura boa parte dos casos graves.

# 11. Conclusão dos modelos
# - Regressão Logística: melhor desempenho geral, mais equilibrada, menos falsos positivos.
# - Árvore CHAID: melhor interpretabilidade, regras claras, maior sensibilidade.
# - Modelos são complementares: logística para previsão, árvore para entender perfis de risco.
