/* ============================================================
   SESSÃO 1 — CRIAÇÃO DO BANCO DE DADOS
   ============================================================ */

/********* CRIANDO BD PARA EXERCICIO *******/
create database TCC_FIA_2;
go


/* ============================================================
   SESSÃO 2 — ACESSAR O BANCO DE DADOS
   ============================================================ */

/********* ACESSANDO BD PARA EXERCICIO *******/
USE TCC_FIA_2
GO


/* ============================================================
   SESSÃO 3 — INFORMAÇÕES SOBRE A ORIGEM DOS DADOS
   ============================================================ */

/* 
# 1 
Fiz o download em CSV:
https://dados.gov.br/dataset/acidentes-rodovias
Última Atualização  2 de Abril de 2021, 01:01 (UTC-03:00)
Campo   Valor
Autor   ANTT/SUROD
Última Atualização  2 de Abril de 2021, 01:01 (UTC-03:00)
Criado  2 de Outubro de 2020, 01:05 (UTC-03:00)
Categorias no VCGE  Transporte Rodoviário [http://vocab.e.gov.br/id/governo#transporte-rodoviario]
Cobertura temporal  Anual
Frequência de atualização   Mensal
Granularidade geográfica    Nacional

# 2
Salvei o arquivo demonstrativo_acidentes.csv do .CSV para o formato .TXT

# 3 
Botão direito no BD de destino -> Tarefas -> ImportarDados -> 
Escolhi Flat File Source -> Procurar o arquivo TXT desejado -> 
NEXT; delimitador de Linha {LF} e {;}
# 4 
Destino -> SQL Server NAtive cliente 11.0
-> FAz a leitura e carregamento das linhas, pode dar um erro -> 
CLOSE só fechar e estar carga
*/


/* ============================================================
   SESSÃO 4 — VERIFICAR BANCO ATUAL — CONFERIR TABELA IMPORTADA
   ============================================================ */

USE TCC_FIA_2
SELECT DB_NAME() AS BancoAtual;
go

select * FROM demonstrativo_acidentes -- 1.326.780 linhas
GO

SELECT COUNT(*) AS total_linhas
FROM demonstrativo_acidentes;
GO

/* ============================================================
   SESSÃO 5 — CRIAR TABELA DE TRABALHO "fato_acidentes"
   ============================================================ */

-- Pega a tabela original demonstrativo_acidente copia para a tabela acidentes
select * INTO fato_acidentes FROM demonstrativo_acidentes
GO

SELECT COUNT(*) AS total_linhas
FROM fato_acidentes;
GO


/* ============================================================
   SESSÃO 6 — COMANDOS ÚTEIS (SEUS COMENTÁRIOS MANTIDOS)
   ============================================================ */

/*  ALGUNS COMANDOS UTEIS
DROP TABLE IF EXISTS table_name;;
ALTER TABLE dbo.doc_exb DROP COLUMN column_b;
Alterar nome da coluna na tabela e o próprio nome da tabela:
sp_rename 'old_table_name', 'new_table_name';
sp_rename 'table_name.old_column_name', 'new_column_name', 'COLUMN';
*/


/* ============================================================
   SESSÃO 7 — ESTRUTURA DA TABELA
   ============================================================ */

exec sp_help fato_acidentes
GO

SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'fato_acidentes'
GO


/* ============================================================
   SESSÃO 8 — VALIDAÇÕES INICIAIS
   ============================================================ */

SELECT COUNT(No_DaOcorrencia) FROM fato_acidentes -- 1326780
go


/* ============================================================
   SESSÃO 9 — AVALIAR DUPLICIDADE
   ============================================================ */

SELECT COUNT(*) AS TotalLinhas, COUNT(DISTINCT No_DaOcorrencia) AS LinhasUnicas FROM fato_acidentes
go
-- 1.326.780
-- 5.759 linhas únicas

SELECT 
    CASE 
        WHEN GROUPING(No_DaOcorrencia) = 1 THEN 'Total Geral'
        WHEN No_DaOcorrencia IS NULL THEN 'Valor Nulo'
        ELSE No_DaOcorrencia
    END AS No_DaOcorrencia,
    COUNT(*) AS Contador
FROM fato_acidentes
GROUP BY ROLLUP (No_DaOcorrencia)
ORDER BY GROUPING(No_DaOcorrencia), COUNT(*) DESC
GO


select * from fato_acidentes where No_DaOcorrencia = '65'
go
-- Exemplo: No_DaOcorrencia = '65' tem 3.833 registros
go


/* ============================================================
   SESSÃO 10 — REMOVER ESPAÇOS VAZIOS: No_DaOcorrencia
   ============================================================ */
   
-- Higienização
UPDATE fato_acidentes
SET No_DaOcorrencia =
    REPLACE(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(
                        LTRIM(RTRIM(No_DaOcorrencia)),
                    ' ', ''),        -- espaço normal
                CHAR(160), ''),      -- espaço invisível (NBSP)
            CHAR(9), ''),            -- TAB
        CHAR(13), ''),               -- CR
    CHAR(10), '')                    -- LF
go


/* teste */
   SELECT
    No_DaOcorrencia AS ValorOriginal,
    SUBSTRING(
        No_DaOcorrencia,
        CHARINDEX('-', No_DaOcorrencia) + 1,
        LEN(No_DaOcorrencia)
    ) AS TextoAposHifen
FROM fato_acidentes
WHERE CHARINDEX('-', No_DaOcorrencia) > 0
ORDER BY No_DaOcorrencia;
go


/* ============================================================
   SESSÃO 11 — CRIAR COLUNAS & POPULAR Num_Ocorrencia e Pista
   ============================================================ */

-- CRIAR COLUNAS Num_Ocorrencia
ALTER TABLE fato_acidentes
ADD Num_Ocorrencia VARCHAR(50) NULL
go

-- CRIAR COLUNAS Pista
ALTER TABLE fato_acidentes
ADD 
Pista VARCHAR(20) NULL;
go

select top 100 * from fato_acidentes
go


/* ============================================================
   SESSÃO 11.1  e Pista
   -- Se No_DaOcorrencia tiver hífen: 
   -- Num_Ocorrencia = parte antes do hífen + '00' 
   -- Pista = 'Contorno' 
   -- Se No_DaOcorrencia não tiver hífen: 
   -- Num_Ocorrencia = valor inteiro + '01' 
   -- Pista = 'Normal'
   ============================================================ */

--POPULAR:
UPDATE fato_acidentes
SET 
    Num_Ocorrencia =
        CASE 
            WHEN CHARINDEX('-', No_DaOcorrencia) > 0 THEN 
                LEFT(No_DaOcorrencia, CHARINDEX('-', No_DaOcorrencia) - 1) + '00'
            ELSE 
                No_DaOcorrencia + '01'
        END,
        
    Pista =
        CASE
            WHEN CHARINDEX('-', No_DaOcorrencia) > 0 THEN 'Contorno'
            ELSE 'Normal'
        END;
GO


/* teste */
   SELECT
    No_DaOcorrencia AS ValorOriginal,
    SUBSTRING(
        No_DaOcorrencia,
        CHARINDEX('-', No_DaOcorrencia) + 1,
        LEN(No_DaOcorrencia)
    ) AS TextoAposHifen, Num_Ocorrencia, Pista
FROM fato_acidentes
WHERE CHARINDEX('-', No_DaOcorrencia) = 0 -- Maior que zero terá Pista com contono e igual a zero, pista Normal.
ORDER BY No_DaOcorrencia;
go


select top 100 * from fato_acidentes
go

-- LIMPEZA: Atualização direta na coluna Num_Ocorrencia
UPDATE fato_acidentes
SET Num_Ocorrencia =
    REPLACE(
    REPLACE(
    REPLACE(
    REPLACE(
    REPLACE(
        Num_Ocorrencia,
        '.', ''),     -- ponto
        ',', ''),     -- vírgula
        ';', ''),     -- ponto e vírgula
        '/', ''),     -- barra
        '-', ''       -- hífen
    )
go


/* ============================================================
   SESSÃO 12 — REMOVER LINHAS DUPLICADAS REAIS
   ============================================================ */


/* Listar todas as colunas */
SELECT COLUMN_NAME 
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'fato_acidentes';
go

-- ANALISAR: De 1.326.780 registros, temos 615.931 linhas duplicadas e restará 710.849 linhas distintas
SELECT 
    TotalLinhas,
    LinhasDuplicadas,
    TotalLinhas - LinhasDuplicadas AS LinhasRemanescentes
FROM (
    SELECT 
        COUNT(*) AS TotalLinhas,
        COUNT(*) - COUNT(DISTINCT 
            CONCAT_WS('|',
                Concessionaria,
                Data,
                Horario,
                No_DaOcorrencia,
                TipoDeOcorrencia,
                Km,
                Trecho,
                Sentido,
                TipoDeAcidente,
                Automovel,
                Bicicleta,
                Caminhao,
                Moto,
                Onibus,
                Outros,
                Tracao_animal,
                Transp__Cargas_Especiais,
                Trator__maquinas,
                Utilitario,
                Ilesos,
                Levemente_feridos,
                Moderadamente_feridos,
                Gravemente_feridos,
                Mortos,
                Num_Ocorrencia,
                Pista
            )
        ) AS LinhasDuplicadas
    FROM fato_acidentes
) AS t;
go


/* Remover linhas duplicadas */
WITH Duplicadas AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY 
                   Concessionaria,
                   Data,
                   Horario,
                   No_DaOcorrencia,
                   TipoDeOcorrencia,
                   Km,
                   Trecho,
                   Sentido,
                   TipoDeAcidente,
                   Automovel,
                   Bicicleta,
                   Caminhao,
                   Moto,
                   Onibus,
                   Outros,
                   Tracao_animal,
                   Transp__Cargas_Especiais,
                   Trator__maquinas,
                   Utilitario,
                   Ilesos,
                   Levemente_feridos,
                   Moderadamente_feridos,
                   Gravemente_feridos,
                   Mortos,
                   Num_Ocorrencia,
                   Pista
               ORDER BY (SELECT NULL)
           ) AS rn
    FROM fato_acidentes
)
DELETE FROM Duplicadas
WHERE rn > 1;
go

select * from fato_acidentes -- Ficou 710.849 registros distintos na se
go


/* ============================================================
   SESSÃO 12.1 — VALIDAÇÃO DUPLICADAS REAIS
   ============================================================ */

SELECT 
    ISNULL(Num_Ocorrencia, 'Total') AS Agrupa_Num_Ocorrencia,
    COUNT(Num_Ocorrencia) AS Contador
FROM fato_acidentes
GROUP BY ROLLUP (Num_Ocorrencia)
ORDER BY 
    CASE WHEN Num_Ocorrencia IS NULL THEN 1 ELSE 0 END,
    COUNT(Num_Ocorrencia) DESC;
GO

-- Num_Ocorrencia = '6501' com 1.944 registros
select * from fato_acidentes where Num_Ocorrencia = '6501'
ORDER BY Num_Ocorrencia, Concessionaria
go

/* ============================================================
   SESSÃO 13 — VALIDAÇÃO CAMPOS:
   -- Concessionaria: Somente nomes distintos
   -- Data: Padrão dd/mm/aa com todos os valores com 08 caracteres
   ============================================================ */


SELECT 
	CASE 
        WHEN GROUPING(Data) = 1 THEN 'Total Geral'
        WHEN Data IS NULL THEN 'Valor Nulo'
        ELSE Data
    END AS Data,
    COUNT(*) AS Contador
FROM fato_acidentes
GROUP BY ROLLUP (Data)
ORDER BY GROUPING(Data), Data ASC
GO

-- Quatidade de caracteres (todos registros com 08 caracteres)
SELECT 
    Data,
    LEN(Data) AS Tamanho,
    COUNT(*) AS Qtde
FROM fato_acidentes
WHERE LEN(Data) = 8
GROUP BY Data, LEN(Data)
ORDER BY LEN(Data), Data;
GO

-- No_DaOcorrencia = '65' com 1.944 linhas
select * from fato_acidentes where No_DaOcorrencia = '65'
go



/* ============================================================
   SESSÃO 14 — CRIAR CAMPO - DE: Data PARA: DataRef
   -- Data: Padrão dd/mm/aa com todos os valores com 08 caracteres
   ============================================================ */


/*** ADD NOVA COLUNA DATA E ADICIONANDO VALORES DE DATA ***/
-- ALTER TABLE acidentes DROP COLUMN dataRef;

select * from fato_acidentes -- Ficou 710.849 registros distintos
go

alter table fato_acidentes
    add DataRef date
go

-- Conversão dos valores
UPDATE fato_acidentes
    SET DataRef = CAST(Data AS DATE);
GO

select top 20 *, Data as 'DataParaComparar' from fato_acidentes;
GO

-- Avaliando
SELECT 
    DataRef,
    LEN(DataRef) AS Tamanho,
    COUNT(*) AS Qtde
FROM fato_acidentes
GROUP BY DataRef, LEN(DataRef)
ORDER BY LEN(DataRef), DataRef DESC;
GO


-- Maior data 01/07/2023 e menordata em 01/01/2010
SELECT 
    MIN(DataRef) AS MenorDataRef,
    MAX(DataRef) AS MaiorDataRef
FROM fato_acidentes;
GO


/* Identificando o tipo de dado de todas as variáveis da tabela 'fato_acidentes' é varchar exceto DataRef */
exec sp_help fato_acidentes
GO


/* ============================================================
   SESSÃO 15 — HORÁRIOS AM PM
   -- Data: Padrão dd/mm/aa com todos os valores com 08 caracteres
   ============================================================ */

   -- OS HORARIOS POSSUEM VERSOES AM e PM: Coluna HorarioPadrao
   -- Se o horário termina com "AM", Remover "AM" e depois Converter o valor restante para TIME
   -- Se o horário termina com "PM", Remover "PM" e Se a hora for "12" Converter diretamente para TIME, Se Não Converter para TIME e somar 12 horas
   -- Se não contém AM nem PM, Converter o horário diretamente para TIME



-- IDENTIFICAR quais valores são inválidos sem quebrar a query.
-- Alem dos caracteres esperados AM e PM, tmos horarios com "h" no final
SELECT DISTINCT Horario
FROM fato_acidentes
WHERE TRY_CONVERT(TIME, REPLACE(REPLACE(Horario,'AM',''),'PM','')) IS NULL; -- TRY_CONVERT → retorna NULL se falhar
GO

-- Tem caracter estranho "h" alem de AM e PM
select top 20 * from fato_acidentes
where Horario like '%h%'
GO

-- LIMPAR o campo original Horario removendo espaços em branco
UPDATE fato_acidentes
SET Horario = LTRIM(RTRIM(
        REPLACE(REPLACE(REPLACE(REPLACE(Horario,
            CHAR(9), ''),   -- TAB
            CHAR(10), ''),  -- LF
            CHAR(13), ''),  -- CR
            CHAR(160), '') -- NBSP
        ));
GO


-- CRIAR coluna intermediária HorarioAMPM
ALTER TABLE fato_acidentes
ADD HorarioAMPM VARCHAR(20) NULL;
GO

-- POPULAR coluna intermediária HorarioAMPM
UPDATE fato_acidentes
SET HorarioAMPM =
    CASE
        WHEN Horario LIKE '%h' THEN
            CASE
                -- 00:00h até 11:59h → HH:MMAM
                WHEN TRY_CONVERT(TIME, REPLACE(Horario,'h','')) BETWEEN '00:00' AND '11:59'
                    THEN REPLACE(Horario,'h','') + 'AM'

                -- 12:00h até 23:59h → HH:MM (sem AM/PM)
                WHEN TRY_CONVERT(TIME, REPLACE(Horario,'h','')) BETWEEN '12:00' AND '23:59'
                    THEN REPLACE(Horario,'h','')

                ELSE Horario
            END

        ELSE
            Horario
    END;
GO


-- CRIAR coluna HorarioPadrao padronizada
ALTER TABLE fato_acidentes
ADD HorarioPadrao TIME NULL;
GO

-- ATUALIZAÇÃO POPULANDO novo campo HorarioPadrao:
UPDATE fato_acidentes
SET HorarioPadrao = 
    CASE
        WHEN HorarioAMPM LIKE '%AM' THEN
            TRY_CONVERT(TIME, REPLACE(HorarioAMPM,'AM',''))

        WHEN HorarioAMPM LIKE '%PM' THEN
            CASE
                WHEN LEFT(REPLACE(HorarioAMPM,'PM',''),2) = '12' THEN
                    TRY_CONVERT(TIME, REPLACE(HorarioAMPM,'PM',''))
                ELSE
                    DATEADD(HOUR, 12,
                        TRY_CONVERT(TIME, REPLACE(HorarioAMPM,'PM',''))
                    )
            END

        ELSE
            TRY_CONVERT(TIME, HorarioAMPM)
    END;
GO

-- Estuda o campo Horario - Frequência por formato original
SELECT 
    Horario,
    LEN(Horario) AS Tamanho,
    COUNT(*) AS Qtde
FROM fato_acidentes
GROUP BY Horario, LEN(Horario)
ORDER BY LEN(Horario) DESC, Horario;
go

/* Valores para validar conversão
10:00:00 AM onze dígitos -- 1:19:00 PM dez dígitos -- 00:00:00 oito -- 23:59:00 oito - 0:00:00 sete
00:32 seis --   16:10 seis -- 5:19 quatro -- 10:00 cinco -- 23:59 cinco
0:00 quatro --  9:59 quatro - 9:59:00
 */
 GO

 -- TESTE: Retorna quantidade especificada de caracteres
SELECT Horario, HorarioPadrao
from fato_acidentes
WHERE Horario = '9:59'
GO

select * from fato_acidentes -- Ficou 710.849 registros distintos
go

/* ============================================================
   SESSÃO 16 — SELECIONAR SOMENTE BR 116 em SP
   -- Trecho 'SP-BR116', 'BR-116/SP', 'BR-116/SP EXP', 'BR-116/SP MARG'
   -- NOVA BASE: fato_acidentes_BR116_SP
   ============================================================ */

-- Agrupar para estudar
SELECT 
    Concessionaria,
    Trecho,
    COUNT(*) AS Qtde
FROM fato_acidentes
WHERE Trecho LIKE '%SP%'
GROUP BY 
    Concessionaria,
    Trecho, 
    LEN(Trecho)
ORDER BY 
    LEN(Trecho),
    Trecho ASC,
	Concessionaria;
GO

-- 67.342 registros
SELECT *
FROM fato_acidentes
WHERE Trecho IN (
    'SP-BR116',
    'BR-116/SP',
    'BR-116/SP EXP',
    'BR-116/SP MARG'
);

-- Criando NOVA tabela:

SELECT *
INTO fato_acidentes_BR116_SP
FROM fato_acidentes
WHERE Trecho IN (
    'SP-BR116',
    'BR-116/SP',
    'BR-116/SP EXP',
    'BR-116/SP MARG'
);

-- 67.342 registros
select * from fato_acidentes_BR116_SP
where TipoDeOcorrencia = '3 - Acidente com Danos Materiais'


/* ============================================================
   SESSÃO 17 — VALIDAÇÃO CAMPO:
   -- Km: Padronizado ponto como separador decimal KmDecimal
   ============================================================ */

   -- Avaliando
SELECT 
    Km,
    LEN(Km) AS Tamanho,
    COUNT(*) AS Qtde
FROM fato_acidentes_BR116_SP
GROUP BY Km, LEN(Km)
ORDER BY LEN(Km), Km DESC;
GO

select * from fato_acidentes_BR116_SP 
where Km = ''
go

-- remover espaços em branco no início e no fim do campo Km -- 67.342 registros afetados
UPDATE fato_acidentes_BR116_SP
SET Km = LTRIM(RTRIM(Km));
go


--  Substituir vazio por 0
UPDATE fato_acidentes_BR116_SP
SET Km = '0'
WHERE Km = '' OR Km IS NULL;
go


-- CRIAR coluna KmDecimal
ALTER TABLE fato_acidentes_BR116_SP
ADD KmDecimal DECIMAL(10,2) NULL;
GO


-- Padronizar separador decimal para ponto
UPDATE fato_acidentes_BR116_SP
SET KmDecimal =
    CASE 
        WHEN ISNUMERIC(
                REPLACE(REPLACE(Km, ',', '.'), '+', '.')
             ) = 1
        THEN CAST(
                CAST(
                    REPLACE(REPLACE(Km, ',', '.'), '+', '.') 
                AS FLOAT
            ) AS DECIMAL(10,0))
        ELSE NULL
    END;
GO


-- Teste
select top 100 * from fato_acidentes_BR116_SP -- Ficou 710.849 registros distintos
where Km like '0,%'
go


/* ============================================================
   SESSÃO 18 — VALIDAÇÃO CAMPO:
   -- Trecho categorizando trechos operacionais novo campo: TrechoRegiao 
   ============================================================ */

   -- Avaliando
SELECT 
    Concessionaria,
    Trecho,
    LEN(Trecho) AS Tamanho,
    COUNT(*) AS Qtde
FROM fato_acidentes_BR116_SP
GROUP BY 
    Concessionaria,
    Trecho, 
    LEN(Trecho)
ORDER BY 
    LEN(Trecho),
    Trecho ASC,
	Concessionaria;
GO


-- NOVA COLUNA
ALTER TABLE fato_acidentes_BR116_SP
ADD TrechoRegiao VARCHAR(30) NULL;
GO

-- POPULANDO TrechoRegiao

UPDATE fato_acidentes_BR116_SP
SET TrechoRegiao =
    CASE
        WHEN Trecho = 'SP-BR116'          THEN 'CAPITAL TRECHO NORMAL'
        WHEN Trecho = 'BR-116/SP EXP'     THEN 'CAPITAL TIETEPINHEIROS EXP'
        WHEN Trecho = 'BR-116/SP MARG'    THEN 'CAPITAL TIETEPINHEIROS MARG'
        ELSE 'FORA DA CAPITAL'
    END;
GO


-- Teste
select top 100 * from fato_acidentes_BR116_SP
go


/* ============================================================
   SESSÃO 19 — VALIDAÇÃO CAMPO:
   -- TrechoRegiao gera TrechoRegiao2 com duas categorias
   -- categorias demais → ruído
   -- categorias muito específicas → overfitting
   -- categorias com baixa frequência → instabilidade
   ============================================================ */

   -- Avaliando
SELECT 
    Concessionaria,
    TrechoRegiao,
    LEN(TrechoRegiao) AS Tamanho,
    COUNT(*) AS Qtde
FROM fato_acidentes_BR116_SP
GROUP BY 
    Concessionaria,
    TrechoRegiao, 
    LEN(TrechoRegiao)
ORDER BY 
    LEN(TrechoRegiao),
    TrechoRegiao ASC,
	Concessionaria;
GO


-- NOVA COLUNA 
ALTER TABLE fato_acidentes_BR116_SP
ADD TrechoRegiao2 VARCHAR(20) NULL;
GO

-- POPULANDO
UPDATE fato_acidentes_BR116_SP
SET TrechoRegiao2 =
    CASE
        WHEN TrechoRegiao = 'FORA DA CAPITAL' THEN 'FORA DA CAPITAL'
        ELSE 'CAPITAL'
    END;
GO


-- Teste
select top 100 * from fato_acidentes_BR116_SP
go


   -- Avaliando
SELECT 
    Concessionaria,
    TrechoRegiao,
	TrechoRegiao2,
    LEN(TrechoRegiao2) AS Tamanho,
    COUNT(*) AS Qtde
FROM fato_acidentes_BR116_SP
GROUP BY 
    Concessionaria,
    TrechoRegiao, 
	TrechoRegiao2,
    LEN(TrechoRegiao2)
ORDER BY 
    LEN(TrechoRegiao2),
    TrechoRegiao2 ASC,
	Concessionaria;
GO

/* ============================================================
   SESSÃO 20 — VALIDAÇÃO CAMPO:
   -- Sentido - Padronização do campo Sentido → SentidoPadrao
   ============================================================ */

      -- Avaliando
SELECT 
    TrechoRegiao,
    Sentido,
    LEN(Sentido) AS Tamanho,
    COUNT(*) AS Qtde
FROM fato_acidentes_BR116_SP
GROUP BY 
    TrechoRegiao,
    Sentido, 
    LEN(Sentido)
ORDER BY 
    TrechoRegiao,
    LEN(Sentido),
    Sentido DESC;
GO


select top 100 * from fato_acidentes_BR116_SP 
where Sentido = 'SUL'
go

-- NOVA COLUNA 
ALTER TABLE fato_acidentes_BR116_SP 
ADD SentidoPadrao VARCHAR(10) NULL; 
GO


-- POPULANDO 
UPDATE fato_acidentes_BR116_SP 
SET SentidoPadrao = 
CASE 
WHEN Sentido LIKE '%Norte%' THEN 'NORTE' 
WHEN Sentido LIKE '%Sul%' THEN 'SUL' 
ELSE NULL END; 
GO

-- Avaliando resultado 
SELECT Sentido, SentidoPadrao, COUNT(*) AS Qtde 
FROM fato_acidentes_BR116_SP 
GROUP BY Sentido, SentidoPadrao 
ORDER BY Sentido; 
GO

/* ============================================================
   SESSÃO  21 — VALIDAÇÃO CAMPO:
   -- TipoDeOcorrencia Padronizando para TipoDeOcorrenciaPadrao
   ============================================================ */

-- Avaliando TipoDeOcorrencia
SELECT 
    TipoDeOcorrencia,
    LEN(TipoDeOcorrencia) AS Tamanho,
    COUNT(*) AS Qtde
FROM fato_acidentes_BR116_SP
--where TipoDeOcorrencia ='3 - Acidente com Danos Materiais'
GROUP BY TipoDeOcorrencia, LEN(TipoDeOcorrencia)
ORDER BY LEN(TipoDeOcorrencia), TipoDeOcorrencia DESC;
GO

-- Retorna o nome das colunas
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'fato_acidentes_BR116_SP';
GO

-- ver padrão dos campos da tabela
exec sp_help fato_acidentes_BR116_SP
GO


-- teste 
select * from fato_acidentes_BR116_SP
where TipoDeOcorrencia ='3 - Acidente com Danos Materiais'
go

-- NOVA COLUNA
ALTER TABLE fato_acidentes_BR116_SP
ADD TipoDeOcorrenciaPadrao VARCHAR(20) NULL;
GO

-- POPULAR
UPDATE fato_acidentes_BR116_SP
SET TipoDeOcorrenciaPadrao =
    CASE
        -- REGRA 1: qualquer ferido/morto diferente de 0, 00 ou vazio → COM VITIMA
        WHEN TRY_CAST(NULLIF(LTRIM(RTRIM(Levemente_feridos)), '') AS INT) > 0
          OR TRY_CAST(NULLIF(LTRIM(RTRIM(Moderadamente_feridos)), '') AS INT) > 0
          OR TRY_CAST(NULLIF(LTRIM(RTRIM(Gravemente_feridos)), '') AS INT) > 0
          OR TRY_CAST(NULLIF(LTRIM(RTRIM(Mortos)), '') AS INT) > 0
        THEN 'Com vitima'

        -- REGRA 2: logica textual (quando nao ha feridos/mortos)
        WHEN TipoDeOcorrencia LIKE '%sem vitima%' THEN 'Sem vitima'
		WHEN TipoDeOcorrencia LIKE '%sem vítima%' THEN 'Sem vitima'
        WHEN TipoDeOcorrencia LIKE '%danos materiais%' THEN 'Sem vitima'

        ELSE 'Com vitima'
    END;
GO



-- teste 
SELECT 
    TipoDeOcorrencia,
    TipoDeOcorrenciaPadrao,
    COUNT(*) AS Qtde
FROM fato_acidentes_BR116_SP
GROUP BY 
    TipoDeOcorrencia,
    TipoDeOcorrenciaPadrao
ORDER BY 
    TipoDeOcorrencia DESC;
GO


-- Teste 2
select * from fato_acidentes_BR116_SP
where TipoDeOcorrencia ='Acidente sem vítima'
and TipoDeOcorrenciaPadrao = 'Com vitima'
go

select * from fato_acidentes_BR116_SP
where TipoDeOcorrencia ='3 - Acidente com Danos Materiais'
and TipoDeOcorrenciaPadrao = 'Com vitima'
go

select * from fato_acidentes_BR116_SP
where TipoDeOcorrencia ='3 - Acidente com Danos Materiais'
and TipoDeOcorrenciaPadrao = 'Sem vitima'
go
  


/* ============================================================
   SESSÃO 22 — VALIDAÇÃO CAMPO:
   -- TipoDeAcidente: descartada
   ============================================================ */

      -- Avaliando 56 categorias Acidente, esta variavel se torna contraproducente

use TCC_FIA_2
select * from fato_acidentes_BR116_SP
go

SELECT 
    TipoDeAcidente,
    LEN(TipoDeAcidente) AS QtdeCaracter,
    COUNT(*) AS Qtde
FROM fato_acidentes_BR116_SP
GROUP BY TipoDeAcidente, LEN(TipoDeAcidente)
ORDER BY LEN(TipoDeAcidente), TipoDeAcidente DESC;
GO


/* ============================================================
   SESSÃO 23 — VALIDAÇÃO CAMPO (ref VEICULOS):
   -- Utilizado: Automovel, Bicicleta, Caminhao, Moto, Onibus, Utilitario
   -- Dispensado: Tracao_animal, Transp__Cargas_Especiaisdispensavel, Trator__maquinas (5 casos são 1 / irrelevante): porque ou é zero ou NULL 
      ,[Tracao_animal] /*desprezado porque ou é nulo ou 0*/
      ,[Transp__Cargas_Especiais] /*desprezado porque ou é nulo ou 0*/
      ,[Trator__maquinas] /*desprezado porque ou é nulo ou 0*/
   ============================================================ */
     
--Avaliando
select top 100 * from fato_acidentes_BR116_SP
go

SELECT 
    Utilitario,
    LEN(Utilitario) AS QtdeCaracter,
    COUNT(*) AS Qtde
FROM fato_acidentes_BR116_SP
GROUP BY Utilitario, LEN(Utilitario)
ORDER BY COUNT(*) DESC;
GO

-- 1) Criar as novas colunas binárias
ALTER TABLE fato_acidentes_BR116_SP ADD
    Automovel_bin   VARCHAR(1) NULL,
    Bicicleta_bin   VARCHAR(1) NULL,
    Caminhao_bin    VARCHAR(1) NULL,
    Moto_bin        VARCHAR(1) NULL,
    Onibus_bin      VARCHAR(1) NULL,
    Utilitario_bin  VARCHAR(1) NULL,
	Outros_bin VARCHAR(1) NULL;
GO

-- 2) Popular as colunas com a lógica definida
UPDATE fato_acidentes_BR116_SP
SET
    Automovel_bin =
        CASE 
            WHEN LTRIM(RTRIM(Automovel)) = '' THEN ''
            WHEN TRY_CONVERT(INT, Automovel) >= 1 THEN '1'
            ELSE '0'
        END,

    Bicicleta_bin =
        CASE 
            WHEN LTRIM(RTRIM(Bicicleta)) = '' THEN ''
            WHEN TRY_CONVERT(INT, Bicicleta) >= 1 THEN '1'
            ELSE '0'
        END,

    Caminhao_bin =
        CASE 
            WHEN LTRIM(RTRIM(Caminhao)) = '' THEN ''
            WHEN TRY_CONVERT(INT, Caminhao) >= 1 THEN '1'
            ELSE '0'
        END,

    Moto_bin =
        CASE 
            WHEN LTRIM(RTRIM(Moto)) = '' THEN ''
            WHEN TRY_CONVERT(INT, Moto) >= 1 THEN '1'
            ELSE '0'
        END,

    Onibus_bin =
        CASE 
            WHEN LTRIM(RTRIM(Onibus)) = '' THEN ''
            WHEN TRY_CONVERT(INT, Onibus) >= 1 THEN '1'
            ELSE '0'
        END,

    Utilitario_bin =
        CASE 
            WHEN LTRIM(RTRIM(Utilitario)) = '' THEN ''
            WHEN TRY_CONVERT(INT, Utilitario) >= 1 THEN '1'
            ELSE '0'
        END,

	Outros_bin =
        CASE 
            WHEN LTRIM(RTRIM(Outros)) = '' THEN ''
            WHEN TRY_CONVERT(INT, Outros) >= 1 THEN '1'
            ELSE '0'
        END;

GO


/* ============================================================
   SESSÃO 24 — VALIDAÇÃO CAMPO (ref PESSOAS):
   -- Adicionar _bin: Ilesos, Levemente_feridos, Moderadamente_feridos, Gravemente_feridos, Mortos
   -- Dispensado: *
   ============================================================ */
   
--Avaliando
select top 100 * from fato_acidentes_BR116_SP
go

SELECT 
    Gravemente_feridos,
    LEN(Gravemente_feridos) AS QtdeCaracter,
    COUNT(*) AS Qtde
FROM fato_acidentes_BR116_SP
GROUP BY Gravemente_feridos, LEN(Gravemente_feridos)
ORDER BY COUNT(*) DESC;
GO

-- 1) Criar as novas colunas binárias
ALTER TABLE fato_acidentes_BR116_SP ADD
    Ilesos_bin                VARCHAR(1) NULL,
    Levemente_feridos_bin     VARCHAR(1) NULL,
    Moderadamente_feridos_bin VARCHAR(1) NULL,
    Gravemente_feridos_bin    VARCHAR(1) NULL,
    Mortos_bin                VARCHAR(1) NULL;
GO

-- 2) Popular as colunas com a lógica definida
UPDATE fato_acidentes_BR116_SP
SET
    Ilesos_bin =
        CASE 
            WHEN LTRIM(RTRIM(Ilesos)) = '' THEN ''
            WHEN TRY_CONVERT(INT, Ilesos) >= 1 THEN '1'
            ELSE '0'
        END,

    Levemente_feridos_bin =
        CASE 
            WHEN LTRIM(RTRIM(Levemente_feridos)) = '' THEN ''
            WHEN TRY_CONVERT(INT, Levemente_feridos) >= 1 THEN '1'
            ELSE '0'
        END,

    Moderadamente_feridos_bin =
        CASE 
            WHEN LTRIM(RTRIM(Moderadamente_feridos)) = '' THEN ''
            WHEN TRY_CONVERT(INT, Moderadamente_feridos) >= 1 THEN '1'
            ELSE '0'
        END,

    Gravemente_feridos_bin =
        CASE 
            WHEN LTRIM(RTRIM(Gravemente_feridos)) = '' THEN ''
            WHEN TRY_CONVERT(INT, Gravemente_feridos) >= 1 THEN '1'
            ELSE '0'
        END,

    Mortos_bin =
        CASE 
            WHEN LTRIM(RTRIM(Mortos)) = '' THEN ''
            WHEN TRY_CONVERT(INT, Mortos) >= 1 THEN '1'
            ELSE '0'
        END;
GO


--Avaliando
select top 100 * from fato_acidentes_BR116_SP
go

/* ============================================================
   SESSÃO 25 — CRIANDO a TARGET Gravemente_feridos_Mortos
   -- TARGET Gravemente_feridos_Mortos
   ============================================================ */
   
-- Avalia
select top 20 * from fato_acidentes_BR116_SP

 -- Adicionando campo
ALTER TABLE fato_acidentes_BR116_SP
ADD Gravemente_feridos_Mortos VARCHAR(1) NULL;
GO

-- Popular a coluna TARGET com a lógica correta para VARCHAR
UPDATE fato_acidentes_BR116_SP
SET Gravemente_feridos_Mortos =
    CASE
        WHEN LTRIM(RTRIM(Gravemente_feridos)) = ''
         AND LTRIM(RTRIM(Mortos)) = '' THEN ''

        WHEN TRY_CONVERT(INT, Gravemente_feridos) >= 1
          OR TRY_CONVERT(INT, Mortos) >= 1 THEN '1'

        ELSE '0'
    END;
GO

-- Testando
SELECT 
    Gravemente_feridos_Mortos,
    LEN(Gravemente_feridos_Mortos) AS QtdeCaracter,
    COUNT(*) AS Qtde
FROM fato_acidentes_BR116_SP
GROUP BY Gravemente_feridos_Mortos, LEN(Gravemente_feridos_Mortos)
ORDER BY COUNT(*) DESC;
GO


/* ============================================================
   SESSÃO 26 — CRIANDO a TARGET Vitimas
   -- Indica que o acidente teve vitimas de qualquer gravidade
   ============================================================ */


-- CRIANDO VARIAVEL TARGET Vitimas
ALTER TABLE fato_acidentes_BR116_SP
ADD Vitimas VARCHAR(1) NULL;
GO

-- Avaliando
select top 100  * from fato_acidentes_BR116_SP
GO

exec sp_help fato_acidentes_BR116_SP
go

-- Popular a TARGET Vitimas (versão correta para VARCHAR)
UPDATE fato_acidentes_BR116_SP
SET Vitimas =
    CASE
        -- Todos vazios → mantém vazio
        WHEN LTRIM(RTRIM(Mortos)) = ''
         AND LTRIM(RTRIM(Gravemente_feridos)) = ''
         AND LTRIM(RTRIM(Moderadamente_feridos)) = ''
         AND LTRIM(RTRIM(Levemente_feridos)) = '' THEN ''

        -- Qualquer valor >= 1 → TARGET = 1
        WHEN TRY_CONVERT(INT, Mortos) >= 1
          OR TRY_CONVERT(INT, Gravemente_feridos) >= 1
          OR TRY_CONVERT(INT, Moderadamente_feridos) >= 1
          OR TRY_CONVERT(INT, Levemente_feridos) >= 1 THEN '1'

        -- Caso contrário → TARGET = 0
        ELSE '0'
    END;
GO

-- Testando
SELECT 
    Vitimas,
    LEN(Vitimas) AS QtdeCaracter,
    COUNT(*) AS Qtde
FROM fato_acidentes_BR116_SP
GROUP BY Vitimas, LEN(Vitimas)
ORDER BY COUNT(*) DESC;
GO

/* ============================================================
   SESSÃO 27 — CRIANDO a variável Periodo
   -- classifica em: madrugada (00:00–05:59), manhã (06:00–11:59), vespertino (12:00–17:59) e noturno (18:00–23:59). Valores nulos continuaram como nulos
   ============================================================ */

-- Avaliando
select * from fato_acidentes_BR116_SP
GO

exec sp_help fato_acidentes_BR116_SP
go

-- Criar a coluna Periodo
ALTER TABLE fato_acidentes_BR116_SP
ADD Periodo VARCHAR(20) NULL;
GO

-- Testes
SELECT HorarioPadrao
FROM fato_acidentes_BR116_SP
WHERE TRY_CONVERT(TIME, HorarioPadrao) IS NULL
      AND HorarioPadrao IS NOT NULL;

-- Testes
SELECT HorarioPadrao
FROM fato_acidentes_BR116_SP
WHERE HorarioPadrao IS NOT NULL
  AND TRY_CONVERT(TIME, HorarioPadrao) IS NULL;

-- POPULAR a coluna Periodo
UPDATE fato_acidentes_BR116_SP
SET Periodo =
    CASE 
        WHEN HorarioPadrao IS NULL THEN NULL
        WHEN HorarioPadrao >= CAST('00:00:00' AS TIME) 
         AND HorarioPadrao <  CAST('06:00:00' AS TIME) THEN 'madrugada'

        WHEN HorarioPadrao >= CAST('06:00:00' AS TIME) 
         AND HorarioPadrao <  CAST('12:00:00' AS TIME) THEN 'manha'

        WHEN HorarioPadrao >= CAST('12:00:00' AS TIME) 
         AND HorarioPadrao <  CAST('18:00:00' AS TIME) THEN 'vespertino'

        WHEN HorarioPadrao >= CAST('18:00:00' AS TIME) THEN 'noturno'

        ELSE NULL
    END;

	
-- Teste rápido
SELECT Periodo, COUNT(*) 
FROM fato_acidentes_BR116_SP
GROUP BY Periodo
ORDER BY COUNT(*) DESC;
go

Select * from fato_acidentes_BR116_SP
where HorarioPadrao like '23%'
GO

/* ============================================================
   SESSÃO 28 — CRIANDO da tabela base para o estudo inicial do modelo
   -- 
   ============================================================ */

   SELECT 
      Concessionaria
    , Num_Ocorrencia
    , DataRef
    , Periodo
    , Trecho		-- Melhor representa # Os campos Concessionaria e TrechoRegiao2, possuem colinearidade perfeita.(redundantes)
    , Pista
    , KmDecimal
    , SentidoPadrao

    -- Variáveis Veículos
    , Automovel
    , Bicicleta
    , Caminhao
    , Moto
    , Onibus
    , Outros
    , Utilitario

    -- Variáveis Pessoas
    , Ilesos
    , Levemente_feridos
    , Moderadamente_feridos
    , Gravemente_feridos
    , Mortos

    -- Variáveis binárias
    , Automovel_bin
    , Bicicleta_bin
    , Caminhao_bin
    , Moto_bin
    , Onibus_bin
    , Outros_bin
    , Utilitario_bin
    , Ilesos_bin
    , Levemente_feridos_bin
    , Moderadamente_feridos_bin
    , Gravemente_feridos_bin
    , Mortos_bin

    -- Targets possíveis
    , TipoDeOcorrenciaPadrao
    , Vitimas
    , Gravemente_feridos_Mortos

INTO dbo.base_acidentes_BR116_SP
FROM dbo.fato_acidentes_BR116_SP;


/* ============================================================
   SESSÃO 28.1 — DEDUPLICANDO fato_acidentes_BR116_SP
   -- Ignorando Num_Ocorrencia (ID não confiável) e SentidoPadrao  (campo artificial 50/50)
   ============================================================ */


WITH CTE AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY 
                   Concessionaria,
                   DataRef,
                   Periodo,
                   Trecho,
                   Pista,
                   KmDecimal,

                   Automovel,
                   Bicicleta,
                   Caminhao,
                   Moto,
                   Onibus,
                   Outros,
                   Utilitario,

                   Ilesos,
                   Levemente_feridos,
                   Moderadamente_feridos,
                   Gravemente_feridos,
                   Mortos,

                   Automovel_bin,
                   Bicicleta_bin,
                   Caminhao_bin,
                   Moto_bin,
                   Onibus_bin,
                   Outros_bin,
                   Utilitario_bin,
                   Ilesos_bin,
                   Levemente_feridos_bin,
                   Moderadamente_feridos_bin,
                   Gravemente_feridos_bin,
                   Mortos_bin,

                   TipoDeOcorrenciaPadrao,
                   Vitimas,
                   Gravemente_feridos_Mortos
               ORDER BY (SELECT NULL)
           ) AS rn
    FROM dbo.base_acidentes_BR116_SP
)
DELETE FROM CTE WHERE rn > 1;

-- 67.127 linhas
SELECT COUNT(*) AS TotalLinhas
FROM dbo.base_acidentes_BR116_SP;


/* ============================================================
   PROMPT — PADRÃO + PRINCIPAIS EVOLUÇÕES (com números incluídos)
   ============================================================

Este projeto consiste na higienização completa e estruturada da base de acidentes no SQL Server, com foco na preparação dos dados para aplicação de modelos preditivos.
Todas as etapas seguem um padrão rigoroso: colunas originais são preservadas e apenas limpas; padronizações e transformações são feitas exclusivamente em colunas derivadas.

Sessões 1–4:
Criação do BD TCC_FIA_2, importação do TXT e conferência da carga.
A tabela demonstrativo_acidentes foi carregada com 1.326.780 linhas.

Sessões 5–9:
Criação da tabela fato_acidentes (1.326.780 linhas).
Validação de duplicidades:
- Total de linhas: 1.326.780
- Linhas únicas por No_DaOcorrencia: 5.759
- Exemplo: No_DaOcorrencia = '65' → 3.833 registros

Sessão 10:
Limpeza profunda de No_DaOcorrencia (espaços, TAB, NBSP, CR, LF).

Sessões 11 e 11.1:
Criação das colunas derivadas Num_Ocorrencia e Pista.
Limpeza estrutural de Num_Ocorrencia.

Sessão 12:
Remoção de duplicidades reais via ROW_NUMBER.
- Linhas duplicadas reais: 615.931
- Linhas remanescentes: 710.849

Sessão 12.1:
Validação pós-deduplicação.
Exemplo: Num_Ocorrencia = '6501' → 1.944 registros.

Sessão 13:
Validação de Data (todos os registros com 8 caracteres, padrão dd/mm/aa).

Sessão 14:
Criação da coluna DataRef (DATE).
Faixa de datas:
- Menor: 01/01/2010
- Maior: 01/07/2023

Sessão 15:
Limpeza e padronização do campo Horario.
Criação de HorarioAMPM e HorarioPadrao (TIME).
Tratamento de formatos irregulares como “9:59”, “00:32”, “5:19”, “10:00 AM”, “1:19 PM”, “23:59h”.

Sessão 16:
Seleção exclusiva da BR‑116/SP.
Criação da tabela fato_acidentes_BR116_SP com 67.342 registros.

Sessão 17:
Limpeza e padronização do campo Km.
Criação da coluna KmDecimal (DECIMAL).
Todos os 67.342 registros padronizados.

Sessão 18:
Criação da coluna TrechoRegiao com 4 categorias principais.

Sessão 19:
Redução de granularidade → criação da coluna TrechoRegiao2 com:
- CAPITAL
- FORA DA CAPITAL

Sessão 20:
Padronização do campo Sentido → criação da coluna SentidoPadrao (NORTE / SUL).

Sessão 21:
Criação da coluna TipoDeOcorrenciaPadrao consolidando:
- Com vítima
- Sem vítima

Sessão 22:
Avaliação do campo TipoDeAcidente (56 categorias).
Mantido apenas higienizado.

Sessão 23:
Criação das colunas binárias para veículos:
Automovel_bin, Bicicleta_bin, Caminhao_bin, Moto_bin, Onibus_bin, Utilitario_bin.
Campos raros descartados: Tracao_animal, Transp__Cargas_Especiais, Trator__maquinas.

Sessão 24:
Criação das colunas binárias para pessoas:
Ilesos_bin, Levemente_feridos_bin, Moderadamente_feridos_bin, Gravemente_feridos_bin, Mortos_bin.

Sessão 25:
Criação da TARGET Gravemente_feridos_Mortos.
Regras:
- vazio → vazio
- ≥1 em Gravemente_feridos ou Mortos → '1'
- demais → '0'

Sessão 26:
Criação da TARGET Vitimas.
Regras:
- vazio → vazio
- ≥1 em qualquer campo de vítimas → '1'
- todos zero → '0'

Sessão 27:
Criação da variável Periodo com base em HorarioPadrao (TIME):
- madrugada (00:00–05:59)
- manhã (06:00–11:59)
- vespertino (12:00–17:59)
- noturno (18:00–23:59)
Valores nulos permanecem nulos.

Sessão 28:
Criação da tabela base para o estudo inicial do modelo

SESSÃO 28.1: DEDUPLICANDO fato_acidentes_BR116_SP. Ignorando Num_Ocorrencia (ID não confiável) e SentidoPadrao  (campo artificial 50/50)

---------------------------------------------------------------
Resumo conceitual para usar no CASE:

“Preencher campos numéricos faltantes com zero pode distorcer o modelo, pois zero representa um valor real e não ausência de informação.
Além disso, o próprio fato de um campo estar vazio pode carregar um padrão relevante — por exemplo, acidentes mais graves tendem a ter dados mais completos.
Portanto, manter NULL preserva a integridade estatística e melhora o desempenho dos modelos preditivos.”
Agora consta: dataset limpo, padronizado e com features prontas

============================================================ */

-- PENDENTE ATUALIZAR O RESUMO ABAIXO: ANALISE EXPLORATORIA
/*
Column_name
Concessionaria: 19 CATEGORIAS e SEM NULOS
No_DaOcorrencia: SEM NULOS
TipoDeOcorrencia: SEM NULOS
Km: DELETE Km IN ('') - 3 registros NULOS anos 11/12/13 sem mortes ou vitimas graves - Agora a tabela acidentes4 possui 672.790 registros
Trecho: sem NULOS
Sentido: São 2582 registros com IN ('','N','N/A') - sendo 3 registros ('') dos anos 11/12/13 sem mortes ou vitimas graves então alteramos todos para missing
TipoDeAcidente: 1.540 NULL (VAZIO); 13 'ERROR:#N/A' total 1.553 missing categorizada
Automovel: 157.912 NULOS e 41.046 ZERO Automovel: 198.958 NULOS convertidos para ZEROS
Bicicleta:  tem 138234 ZERO e 527365 NULO - TOTALIZARÁ 665.599
Caminhao:  tem 490.739 0, não possui NULL
Moto: tem  115860 ZERO e  453490 NULO - total de 569.350 (zero)
Onibus: tem  135164 ZERO e  515339 NULO -- transformamos nulos em zeros - total de 650.503 ZEROS
Outros: tem  133029 ZERO e  484972 NULO -- serão 618.001 zeros
Tracao_animal: tem  122208 ZERO e  549369 NULO - serão consolidados em 671.574 ZEROS
Transp__Cargas_Especiais: tem  46731 ZERO e  624191 NULO -> 670.922
Trator__maquinas: tem  105761 ZERO e  566812 NULO -> total de zeros serão 672.573
Utilitario: tem  98297 ZERO e  527676 NULO - serão 625973 zeros
Ilesos: tem  92768 ZERO e  3708 NULO serão 96476     ******************
Levemente_feridos: tem  104447 ZERO e  396173 NULO -> total será 500.620 ZEROS ****
Moderadamente_feridos: tem  126497 ZERO e  491873 NULO -> no total serão 618.370 zeros
Gravemente_feridos: tem  137760 ZERO e  519072 NULO serão no total 656.832 ZEROS
Mortos: tem  138554 ZERO e  520802 NULO, serão no total 659.356 ZEROS ++++++++++++++++++
DataRef
HorarioConsolidado

GO

MODELO NO R
-- 1. Carregar bibliotecas no R para EDA e modelagem.
-- 2. Importar a base de dados e converter para data.frame.
-- 2.1 Conectar o R ao SQL Server local para ler a tabela fato_acidentes_BR116_SP do banco TCC_FIA_2.
--     A base será importada via conexão ODBC (dbConnect), e não por arquivo CSV/Excel.
-- 3. Explorar estrutura da base (summary, skim, str).
-- 4. Fazer AED univariada das variáveis.
-- 5. Avaliar distribuição das targets (Grave_Mortos e Vitimas).
-- 6. Categorizar variáveis numéricas (quartis e optimal binning).
-- 7. Criar variáveis derivadas (ex.: Onibus_Caminhao_Bin).
-- 8. Converter variáveis categóricas para factor.
-- 9. Calcular Information Value (IV) e remover variáveis fracas.
-- 10. Selecionar variáveis finais para modelagem.
-- 11. Dividir a base em treino e teste (80/20).
-- 12. Treinar modelo de regressão logística.
-- 13. Avaliar multicolinearidade com VIF.
-- 14. Gerar probabilidades preditas no treino e teste.
-- 15. Calcular KS e AUC (ROC) para medir discriminação.
-- 16. Definir ponto de corte com cutpointr.
-- 17. Criar matriz de confusão e métricas (ACC, SENS, SPEC).
-- 18. Treinar árvore CHAID com variáveis categorizadas.
-- 19. Avaliar árvore (probabilidades, nós, matriz de confusão).
-- 20. Comparar desempenho entre regressão logística e CHAID.


   ============================================================ */

 

   AVALAIR, muito provavelmente nao afetou a base porque separamos somente sao paul e em sao paulo nao teve Km=0 mas melhor ver se estamos padronizado para evoluir nos modelos.
   --  Substituir vazio por 0
UPDATE fato_acidentes_BR116_SP
SET Km = '0'
WHERE Km = '' OR Km IS NULL;
go



