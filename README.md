# 🚧 Predição de Acidentes na BR‑116 — Pipeline Automatizado com R + Supabase + GitHub Actions

Este repositório contém o pipeline completo para preparação, limpeza e envio automático da base de acidentes da BR‑116 para o Supabase.  
O objetivo é permitir que qualquer pessoa possa:

- baixar os dados brutos
- treinar modelos
- acompanhar atualizações automáticas
- consultar a base limpa diretamente no Supabase

---

## 📦 Estrutura do Projeto

- `raw/` — arquivos originais da ANTT (CSV/TXT/PDF)
- `scripts/` — scripts SQL para higienização da base e R para limpeza, transformação
- `outputs/` — dados tratados e prontos para modelagem
- `.github/workflows/` — automações do GitHub Actions
- `README.md` — documentação do projeto

---

## 📥 Downloads dos Dados Brutos (ANTT)

Abaixo estão os links para visualização e download dos arquivos originais disponibilizados pela ANTT.  
Esses arquivos são usados como entrada no pipeline automatizado.

> **Fonte oficial:** Agência Nacional de Transportes Terrestres (ANTT)

### 🔗 Arquivos RAW

| Arquivo | Descrição | Link |
|--------|-----------|------|
| demonstrativo_acidentes.txt | Arquivo demonstrativo de acidentes da ANTT | <a href="https://drive.google.com/file/d/1c3ABHCpNPmUiXE8j3jxtPaJ7132TvgWc/view?usp=sharing" target="_blank">Abrir no Google Drive</a> |
| demonstrativo_acidentes_dicionario_dados.pdf | Dicionário de dados oficial da ANTT | <a href="https://drive.google.com/file/d/1XaF6uW-VMaFlt6fWDeLLc6ftUGX0Xot5/view?usp=sharing" target="_blank">Abrir PDF</a> |

---

## 🔄 Pipeline Automatizado

O pipeline executa automaticamente:

1. Download dos arquivos brutos  
2. Leitura e limpeza dos dados  
3. Padronização das colunas  
4. Upload para o Supabase  
5. Execução automática a cada 4 horas via GitHub Actions  

---

## 🗄️ Acesso ao Banco (Supabase)

A base tratada pode ser consultada diretamente no Supabase:

- **URL do projeto:** https://kzybyjxqctmxphbdcibw.supabase.co  
- **Tabela:** `acidentes_br116`  

---

## 🧠 Modelagem

Os dados tratados podem ser usados para:

- modelos de classificação (gravidade)
- modelos de regressão (probabilidade de acidente)
- análises espaciais
- dashboards e monitoramento

---

## 👨‍💻 Autor

**Paulo Dias** — Consultor Data Driven & MLOps  

- 🌐 Portfólio: <a href="https://paulopconsult-bit.github.io/" target="_blank">https://paulopconsult-bit.github.io/</a>  
- 💼 LinkedIn: <a href="https://www.linkedin.com/in/paulo-data-driven/" target="_blank">https://www.linkedin.com/in/paulo-data-driven/</a>  
- 💬 WhatsApp: <a href="https://wa.me/5513991245656" target="_blank">Iniciar conversa</a>  

---