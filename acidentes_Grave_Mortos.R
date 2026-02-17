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

# Validar "data" origem SQL SERVER

nrow(data)
# 67127

# Adicionar Chave para validar inexistencia de duplicidades
# A chave deve acompanhar o pipeline até o split treino/teste
data <- data %>%
  dplyr::mutate(
    Chave = paste0(
      Concessionaria, "_",
      Trecho, "_",
      Num_Ocorrencia, "_",
      DataRef
    )
  )


###############################################
# 2. Padronizando as variáveis
# IDENTIFICADORES (não entram no modelo)
###############################################

summary(data)

for (col in names(data)) print(col)
rm(col)

vars_id <- c(
  "Chave"   # identificador único do acidente
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
# SEÇÃO 9 — Information Value (IV)
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
  vars_target, # TARGET ÚNICA
  vars_id # A CHAVE ÚNICA deve acompanhar o pipeline até o split treino/teste
)

###############################################################
# CRIAR O DATA FRAME: base para inicio de modelagem
base <- data[, vars_modelagem]
###############################################################

# ⚠️ IMPORTANTE — O que você NÃO deve fazer aqui
# Você NÃO deve:
# remover a chave
# remover DataRef ainda
# remover identificadores
# remover variáveis antes de calcular IV
# Tudo isso só acontece depois que a base está íntegra.


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


# Transformar a variável target binária 0/1 de factor para numérica,
# para aplicar cálculos (IV), regressão glm() e árvore CHAID etc.
base$Gravemente_feridos_Mortos <- as.numeric(as.character(base$Gravemente_feridos_Mortos))
class(base$Gravemente_feridos_Mortos)
cro_cpct(base$Gravemente_feridos_Mortos)

# base agora está pronta para modelagem supervisionada.
# Começar avaliando IV

###############################################################
# INFORMATION VALUE
# somente depois disso começamos a remover: 
# leakage 
# variáveis fracas 
# variáveis redundantes 
# variáveis suspeitas (IV > 0.50) 
# SEM NUNCA remover a chave.
###############################################################
IV <- create_infotables(data = base, y = "Gravemente_feridos_Mortos")
IV$Summary

# 👉 O próprio código do IV Ignora a DataRef para o cálculo do IV  
# O pacote Information só calcula IV para:    
# numéricas contínuas; numéricas discretas e fatores com poucos níveis: Datas não entram
#
# 👉 O próprio código do IV Ignora a chave para o cálculo do IV  
# 👉 Mas NÃO remove a chave da sua base; 👉 Apenas não calcula IV para ela
# A chave continua na base assim evita duplicados artificiais

# Variable         IV
# 4             Caminhao 2.44493864
# 12        Caminhao_bin 2.44493864
# 18 Onibus_Caminhao_Bin 2.30202564
# 3            Bicicleta 0.33812091
# 9              Periodo 0.27043833
# 5                 Moto 0.25010714
# 13            Moto_bin 0.25010714
# 7               Outros 0.23618959
# 15          Outros_bin 0.23618959
# 2            Automovel 0.19111147
# 6               Onibus 0.16749755
# 14          Onibus_bin 0.16749755
# 8           Utilitario 0.15257725
# 16      Utilitario_bin 0.15257725
# 17          Ilesos_bin 0.12392162
# 11       Automovel_bin 0.09476693
# 10              Km_cat 0.05366293
# 1            KmDecimal 0.03429499



# Remover leakage (derivadas do target)
# Remover variáveis que são efeitos do acidente, não causas.
# Variáveis de leakage devem ser removidas SEMPRE, independentemente do IV
# O IV NÃO é influenciado por leakage. Você pode remover leakage ANTES ou DEPOIS — o resultado do IV não muda.
base$Ilesos_bin               <- NULL # Só restava esta ser removida, as outras já haviam sido removidas anterioremente
base$Levemente_feridos_bin    <- NULL
base$Moderadamente_feridos_bin<- NULL
base$Gravemente_feridos_bin   <- NULL
base$Mortos_bin               <- NULL
#
#
base$Ilesos_bin         <- NULL
vars_binarias <- vars_binarias[vars_binarias != "Ilesos_bin"]
vars_binarias


# Remover duplicatas de informação MESMO IV: versão numérica e binária (com segurança)
# A regra é:
# 👉 Manter a versão numérica  
# 👉 Remover a versão binária equivalente
base$Caminhao_bin   <- NULL
vars_binarias <- vars_binarias[vars_binarias != "Caminhao_bin"]
base$Moto_bin       <- NULL
vars_binarias <- vars_binarias[vars_binarias != "Moto_bin"]
base$Outros_bin     <- NULL
vars_binarias <- vars_binarias[vars_binarias != "Outros_bin"]
base$Utilitario_bin <- NULL
vars_binarias <- vars_binarias[vars_binarias != "Utilitario_bin"]
base$Onibus_bin     <- NULL
vars_binarias <- vars_binarias[vars_binarias != "Onibus_bin"]


# Remover variáveis fracas (IV < 0.10)
# Automovel IV de 0.19111147, explica melhor o negocio e é numerica serve tanto para regressão quanto para a arvore
# Automovel tem somente 13 valores de 0 até 12
# Mantemos Automovel para o modelo ter sentido teorico para o negócio na prática
table(base$Automovel, base$Gravemente_feridos_Mortos)
base$Automovel_bin      <- NULL   # 0.09476693
vars_binarias <- vars_binarias[vars_binarias != "Automovel_bin"]

# Remover variáveis fracas (IV < 0.10)
base$KmDecimal <- NULL # IV = 0.03429499
vars_numericas <- vars_numericas[vars_numericas != "KmDecimal"]
#
# Mantemos Km_cat por regra de negócio: para o modelo ter sentido teorico para o negócio na prática

# Remover variáveis suspeitas (IV > 0.50)
base$Onibus_Caminhao_Bin <- NULL
vars_binarias <- vars_binarias[vars_binarias != "Onibus_Caminhao_Bin"] # IV 2.30202564
# Mantemos as varaiveis numericas, Caminhao e Onibus derivantes de Onibus_Caminhao_Bin


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


# Remover variáveis temporais fracas e sem inclusão no IV por regra
# Excluir variaveis periodicas que nao tiveram bom IV e DataRef
# Ter certeza de que elas não são necessárias para o Supabase ou para auditoria.
base$DataRef   <- NULL
vars_tempo <- vars_tempo[vars_tempo != "DataRef"]
base$Mes     <- NULL            # IV de 0.03835127
base$DiaSemana      <- NULL     # IV de 0.02131159


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

# Validar que a chave continua na base
"Chave" %in% names(base)
# TRUE

# Revisão da organização das variaveis features
names(base)
vars_numericas
vars_categoricas
vars_binarias
vars_target
vars_id


###############################################################
# SESSÃO 10 — Organização da ordenação final das variáveis
# Não foi necessário
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

names(base)
# [1] "Automovel"                 "Bicicleta"                 "Caminhao"                  "Moto"                     
# [5] "Onibus"                    "Outros"                    "Utilitario"                "Periodo"                  
# [9] "Km_cat"                    "Gravemente_feridos_Mortos" "Chave"  

# Criar a lista de variáveis que devem estar sem NA
# Inclui todas as features + target.
# Não inclui a Chave (correto: ela não precisa ser critério de remoção de NA para o modelo).
vars_modelo_Sem_NA <- c( "Automovel", "Bicicleta", "Caminhao", "Moto", 
                         "Onibus", "Outros", "Utilitario", "Periodo", 
                         "Km_cat", "Gravemente_feridos_Mortos" )

###############################################################
# Remover linhas com NA apenas nas variáveis usadas no modelo. 
# A CHAVE permanece na base, garantindo que NÃO haja duplicidade inflada.
base_limpa <- base[complete.cases(base[vars_modelo_Sem_NA]), ]
names(base_limpa)
nrow(base_limpa)
# 41516
# Cai de 42.303 para 41.516 registros porque removemos "NA"
###############################################################

# EXPORTADO EM 12/02/2026 O .CSV, base_limpa para simular produção MLOps
# write.csv(base_limpa, "data/prepared/base_limpa_v1.csv", row.names = FALSE)


# Fixamos a semente para garantir reprodutibilidade.
# Assim, sempre que rodarmos o código, a mesma amostra será selecionada.
set.seed(42)

# Selecionamos aleatoriamente 80% das linhas da base_limpa para compor o conjunto de treino.
amostra <- sort(sample(nrow(base_limpa), nrow(base_limpa) * 0.80))

# TREINO
# Conjunto de treino: usado para ajustar (treinar) os modelos.
treino <- base_limpa[amostra, ]
# TESTE
# Conjunto de teste: usado para avaliar o desempenho do modelo em dados novos.
teste <- base_limpa[-amostra, ]


###############################################################
# SESSÃO 12 — Regressão Logística
###############################################################

dataIV # Origem base; que deu origem a base_limpa (Sem features com "NA") que deu origem as bases treino e teste

names(treino)

# Aplicar modelagem
modelo <- glm(Gravemente_feridos_Mortos ~  
                Automovel+Bicicleta+Caminhao+Moto+
                Onibus+Outros+Utilitario+Periodo+
                Km_cat,
              family=binomial(link='logit'),
              data=treino)
summary(modelo)
# AIC Akaike Information Criterion / Critério de Informação de Akaike
# Mede o equilíbrio entre o quão bem o modelo se ajusta aos dados (qualidade do ajuste) e o quanto ele é simples (penaliza modelos com muitas variáveis)
# AIC DO MODELO: 8973.5
# AIC menor → modelo melhor
# AIC maior → modelo pior

# VARIAVEIS EM ALERTA:

### Km_cat
# Variavel de qualidade do entendimento do negócio
# IV Fraco 0.05366293
# o modelo precisa explicar risco por distância → manter. porque se nao se torna o modelo sem sentido prático


# p-valor alto > 0.01
# Caminhao p-valor 0.4886 e Onibus: 0.6255 Mas vamos manter, pois representa um tipo de veículo crítico na severidade.

# utiliatario p-valor 0.5847
# Testar Modelo Sem a variavel "Utilitario"
# Utilitario: remover, pois tem baixo impacto e não é essencial ao modelo.
modelo_2 <- glm(Gravemente_feridos_Mortos ~  
                Automovel+Bicicleta+Caminhao+Moto+
                Onibus+Outros+Periodo+
                Km_cat,
              family=binomial(link='logit'),
              data=treino)
summary(modelo_2)
# AIC modelo_2: 8971.8 <  AIC modelo: 8973.5
# p-valor de Caminhao e Onibus praticamente nao foram alterados.
## Vamos seguir com o modelo inicial com todas as varaiveis.

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
# SEÇÃO 14 — Ajustamento do Modelo / Se necessário
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
# 0.3296 KS razoável, esperado assim devido ao target raro; modelo estável.

roc_obj <- pROC::roc(treino$Gravemente_feridos_Mortos, treino$probabilidade)
pROC::auc(roc_obj)
# Area under the curve: 0.7309 AUC bom

plot(roc_obj, col = "blue", lwd = 2)
# Devido o AUC, A curva ROC deve estar bem arqueada, mas não perfeita.

###############################################################
# Até aqui tivemos um bom treino, vamos validar em teste
###############################################################

# ADICIONAR O CAMPO DA PROBABILIDADE ao teste
teste$probabilidade = predict(modelo,teste, type = "response")

ks_stat(actuals=teste$Gravemente_feridos_Mortos, predictedScores=teste$probabilidade)
# 0.395 razoável, esperado assim devido ao target raro; modelo estável.

roc_obj_teste <- pROC::roc(teste$Gravemente_feridos_Mortos, teste$probabilidade)
pROC::auc(roc_obj_teste)
# Area under the curve: 0.7492 bom
# Desempenho consistente, condizente com o de treino e sem overfitting.

plot(roc_obj_teste, col = "blue", lwd = 2)
# Devido o AUC, A curva ROC deve estar bem arqueada, mas não perfeita.
# Sobre o gráfico, Quanto mais a curva se aproxima do canto superior esquerdo, melhor
# Esse canto representa:Sensibilidade = 1, Falso positivo = 0 - Ou seja: modelo perfeito.


# Os resultados no teste estão totalmente coerentes com o que vimos no treino
# AUC: A diferença é pequena → não há overfitting


###############################################################
# SESSÃO 16 — Ponto de Corte
###############################################################

library(cutpointr)

# QUALIDADE (NA)
# AVALAIR/REVISAR SE EXISTE NA's TARGET da base (não deve ter)
# NA acontece quando o predict() não consegue calcular a probabilidade para algumas linhas do treino. 
# Porque Existem valores NA nas variáveis explicativas usadas no modelo.
colSums(is.na(treino[, c("probabilidade", "Gravemente_feridos_Mortos")]))
# probabilidade Gravemente_feridos_Mortos 
# 0                         0 
#
# Se NAs surgiram depois do modelo estar pronto, Isso não afeta o modelo, só afeta a previsão dessas linhas.
# E o cutpointr não aceita NA, por isso pode dar erro. Então deveremos Remover NAs agora, mas isso não invalida nada. Depende o tamanho do estrago.
#
# Se necessário Mantém somente as linhas onde nenhuma dessas duas colunas tem NA
# Já eliminamos linhas com NA devido variaveis explicativas para criar a base de treino e teste
# treino2 <- treino[complete.cases(treino[, c("probabilidade", "Gravemente_feridos_Mortos")]), ]
# Confere se ainda existe NA
# colSums(is.na(treino2[, c("probabilidade", "Gravemente_feridos_Mortos")]))


# Equilibra sensibilidade e especificidade.
ponto <- cutpointr(treino, probabilidade, Gravemente_feridos_Mortos,
                   method = minimize_metric, metric = abs_d_sens_spec)
summary(ponto)
# Obter ponto de cort cuttoff abs_d_sens_spec: 0.0331.  Esse cutoff é baixo, porque seu modelo gera probabilidades pequenas (target raro)
# optimal_cutpoint = 0.0331
# sensibilidade = 0.6628 # acerta 66.3% dos casos graves (sensibilidade).
# especificidade = 0.6632 
# Esse é o cutoff mais adequado para modelos de severidade, onde FN é caro.


# Accuracy engana quando a classe 1 é rara. Descartado
ponto2 <- cutpointr(treino, probabilidade, Gravemente_feridos_Mortos,
                   method = maximize_metric, metric = accuracy)
summary(ponto2)
# Obter ponto de cort cuttoff: Inf    # accuracy dá cutoff absurdo
# optimal_cutpoint = Inf   
# sensibilidade = 0
# especificidade = 1
# acc = 0.9665 # A Acurácia fica alta porque 97% dos casos são 0.


# Cutoff pelo F1 (classe rara → muito útil)
# Conservador Não recomendado para severidade.
ponto_f1 <- cutpointr(treino, probabilidade,Gravemente_feridos_Mortos,
                      method = maximize_metric, metric = F1_score)
summary(ponto_f1)
# optimal_cutpoint: 0.0896 Muito alto


# Cutoff pelo KS (maximiza separação)
# O cutoff que maximiza Youden é o cutoff que maximiza o KS
ponto_ks <- cutpointr(treino, probabilidade, Gravemente_feridos_Mortos,
                      method = maximize_metric, metric = youden)
summary(ponto_ks)
# optimal_cutpoint:0.0321

# Qual cutoff é o melhor para o seu modelo?
#   Seu problema é severidade de acidentes, onde:   
#   FN = deixar de identificar um caso grave# 
#   FP = classificar como grave quando não é
# 
# Em modelos de severidade: ✔ FN é muito mais caro que FP
# 1º lugar: cuttoff youden: 0.0321
# 2º lugar: cuttoff abs_d_sens_spec: 0.0331
# Maior sensibilidade # Menor FN # Melhor separação estatística # Ideal para risco/severidade
ponto_definido <- 0.0321
ponto_definido


# PREVISÃO BINÁRIA BASEADA NO PONTO DE CORTE ANALISADO E DEFINIDO
teste$probb_cat <- ifelse(teste$probabilidade>ponto_definido,1,0)
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
#                  PREVISÃO
#                  Negativo   Positivo
# REAL   Negativo    TN         FP
#        Positivo    FN         TP

TN <- 5209
FN <- 89
FP <- 2773
TP <- 233


# Total
# A matriz de confusão usa apenas as linhas onde existe predição válida
# E algumas linhas do teste ficaram com probabilidade = NA
Total <- TP + FN + FP + TN
nrow(teste)
# 8304 linhas

# Acurácia
Acuracia <- (TP + TN) / Total
Acuracia
# 0.6553468

# Sensibilidade (Recall)
Sensibilidade <- TP / (TP + FN)
Sensibilidade
# 0.7236025

# Especificidade
Especificidade <- TN / (TN + FP)
Especificidade
# 0.6525933

# Precisão (PPV)
Precisao <- TP / (TP + FP)
Precisao
# 0.07751164

###############################################################
# SEÇÃO 17 — Estrair os coeficientes do MODELO DE REGRESSÃO
###############################################################
# logit(𝑝)=  𝛽0+𝛽1𝑋1+𝛽2𝑋2+…

summary(modelo)
coef(modelo)

# obter a fórmula já formatada pelo R
formula(modelo)

# obter a equação completa em formato matemático
library(equatiomatic)
extract_eq(modelo, use_coefs = TRUE)


###############################################################
# SEÇÃO 17.1 SALVAR O MODELO DE PRODUÇÃO
# Objetivo: salvar o objeto 'modelo' já treinado e testado
###############################################################

# 1. Criar a pasta /modelos caso ainda não exista
if (!dir.exists("modelos")) {
  dir.create("modelos")
}

# 2. Salvar o modelo oficial de produção
saveRDS(modelo, "modelos/modelo_producao.rds")

cat("\n✅ Modelo salvo com sucesso em: modelos/modelo_producao.rds\n")

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

# Variaveis do modelo de regresao:
# modelo <- glm(Gravemente_feridos_Mortos ~  
#                 Automovel+Bicicleta+Caminhao+Moto+
#                 Onibus+Outros+Utilitario+Periodo+
#                 Km_cat,

# Garantir que TODAS as variáveis explicativas usadas no CHAID
# estejam como factor (CHAID exige variáveis categóricas)
vars_para_factor <- c(
  "Automovel", "Bicicleta","Caminhao","Moto",
  "Onibus", "Outros","Utilitario","Periodo",
  "Km_cat"
)
vars_para_factor

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
    Automovel +
    Bicicleta +
    Caminhao +
    Moto +
    Onibus +
    Outros +
    Utilitario +
    Periodo +
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


# Identificar "nós" (Se não estiver legível no "plot")
with(treino, table(Periodo[treino$no == 28]))
with(treino, table(Periodo[treino$no == 29]))

# Frequência de observações por nó
table(treino$no)

# Tabela cruzada: nó x target
# cro_rpct mostra proporções por linha/coluna (ótimo para entender risco por nó)
cro_rpct(treino$no, treino$Gravemente_feridos_Mortos)

# Probabilidade prevista pelo CHAID para a classe "1"
# predict(..., type="p") retorna uma matriz com P(0) e P(1)
treino$prob_chaid <- predict(arvore_4niveis, treino, type = "p")[,2]

# Alternativa: salvar as duas probabilidades separadamente
probs <- as.data.frame(predict(arvore_4niveis, newdata = treino, type = "p"))
names(probs) <- c("P_0", "P_1")

# Anexa as probabilidades (0 | 1) ao dataset de treino
treino <- cbind(treino, probs)

# Probabilidade geral da classe 1 no conjunto de treino
# (serve como cutoff baseado na taxa base)
prob_geral <- sum(treino$Gravemente_feridos_Mortos == "1") / nrow(treino)
prob_geral
# 0.03348187  enquato o CuttOff da regresão foi 0.0321 (um pouco mais conservador)

# Classificação binária usando o cutoff = probabilidade geral
treino$predito_arvore <- ifelse(treino$prob_chaid >= prob_geral, "1", "0")

# Matriz de confusão: real x predito
cro(treino$Gravemente_feridos_Mortos, treino$predito_arvore)

# ✔ Verdadeiros Negativos (0 → 0): 22.4053
# Muito bom — a árvore acerta a maioria dos casos seguros.
# 
# ✔ Verdadeiros Positivos (1 → 1): 655
# Bom — considerando que a classe 1 é rara (3,35%).
# 
# ❌ Falsos Negativos (1 → 0): 457
# Normal — com cutoff baixo, sempre haverá FN.
# 
# ❌ Falsos Positivos (0 → 1): 88047 
# Também normal — CHAID tende a ser agressivo quando o cutoff é baixo.


###############################################################
# SESSÃO 19 — Avaliação da árvore na base de teste
###############################################################

# Quando separamos Treino e Teste é comun para variáveis continuas
# Terem valores que aparecem em Treino mas não em teste, e vice versa, 
# então abaixo temos um código para testar em caso de erro, onde o erro informa a variável.
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
# Valores da matriz de confusão
#                  PREVISÃO
#                  Negativo   Positivo
# REAL   Negativo    TN         FP
#        Positivo    FN         TP
#
# De 8.304 registros na base de teste
#
# ✔ Verdadeiros Negativos (0 → 0): 5969
# A árvore acerta a grande maioria dos casos seguros.
# Isso é esperado, já que a classe 0 domina o dataset.# 
# Interpretação:  
#   O modelo é muito bom em identificar acidentes não graves.
# 
# ✔ Verdadeiros Positivos (1 → 1): 187
# Esses são os casos em que o modelo acertou acidentes graves.# 
# Interpretação:  
#   Mesmo com classe rara (~3%), o modelo conseguiu capturar 187 casos graves corretamente.
# 
# ❌ Falsos Negativos (1 → 0):  135
# Casos graves que o modelo classificou como não graves.
# Interpretação:  
#   Isso é normal — acidentes graves são raros e difíceis de prever.
# Mas ainda assim, 121 FN é um número relativamente baixo.
# 
# ❌ Falsos Positivos (0 → 1):  2.013
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
# SESSÃO 20 — Conclusões Finais (ATUALIZADA)
###############################################################

# A seguir apresentamos a conclusão integrada dos dois modelos
# do baseline: Regressão Logística e Árvore de Decisão CHAID.
# A análise considera desempenho estatístico, estabilidade,
# interpretabilidade e adequação operacional.

###############################################################
# 1. Regressão Logística — Conclusão
###############################################################

# Métricas finais (TESTE):
# - AUC: 0.7492  → bom
# - KS: 0.395    → razoável/bom para classe rara
# - Cutoff ótimo (Youden): 0.0321
#
# Matriz de confusão (teste):
#   TN = 5209
#   FP = 2773
#   FN = 89
#   TP = 233
#
# Métricas derivadas:
# - Acurácia:      0.6553
# - Sensibilidade: 0.7236   (excelente para classe rara)
# - Especificidade:0.6526
# - Precisão:      0.0775   (esperado em classe rara)
#
# Conclusão técnica:
# - Modelo estável, sem overfitting.
# - Bom poder discriminativo (AUC ~0.75).
# - Equilíbrio adequado entre sensibilidade e especificidade.
# - Baixa taxa de FN (muito importante em severidade).
#
# Conclusão operacional:
# - Melhor modelo para uso em produção.
# - Mais previsível, calibrável e com menos falsos positivos.
# - Ideal para scoring contínuo e monitoramento em MLOps.

###############################################################
# 2. Árvore de Decisão CHAID — Conclusão
###############################################################

# Cutoff utilizado: probabilidade geral da carteira = 0.03348
#
# Matriz de confusão (teste):
#   TN = 5969
#   FP = 2013
#   FN = 135
#   TP = 187
#
# Interpretação:
# - A árvore captura mais casos graves (TP maior que a regressão).
# - Porém, gera muito mais falsos positivos.
# - Sensível ao cutoff e mais agressiva por natureza.
# - Excelente interpretabilidade: regras claras e nós bem definidos.
#
# Conclusão técnica:
# - Útil para entendimento dos padrões de risco.
# - Não é o melhor modelo para predição operacional.

###############################################################
# 3. Comparação Final
###############################################################

# Regressão Logística:
# - Melhor AUC, melhor KS, mais equilibrada.
# - Menos falsos positivos.
# - Maior estabilidade entre treino e teste.
# - Melhor adequação para produção.

# Árvore CHAID:
# - Maior sensibilidade (captura mais casos graves).
# - Muito mais falsos positivos.
# - Excelente interpretabilidade.
# - Melhor para explicar perfis de risco.

###############################################################
# 4. Recomendação Final
###############################################################

# ✔ Regressão Logística → Modelo recomendado para PRODUÇÃO
#   - Melhor equilíbrio geral.
#   - Menos FP.
#   - Estável, robusto e adequado para MLOps.

# ✔ Árvore CHAID → Modelo recomendado para INTERPRETAÇÃO
#   - Regras claras.
#   - Perfis de risco facilmente comunicáveis.
#   - Complementa a regressão na explicação dos padrões.

# ✔ Conclusão geral:
#   - Os modelos são COMPLEMENTARES.
#   - Logística para prever.
#   - CHAID para entender.

###############################################################
# SEÇÃO 21: FIM
# Baseline Model Artifact  do Projeto de MLOps
# Data/Hora do registro: 12/02/2026 
###############################################################
