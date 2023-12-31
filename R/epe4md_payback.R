#' Roda um fluxo de caixa para cada caso e retorna métricas financeiras.
#'
#' @param casos_payback data.frame. Base gerada pela função
#' [epe4md::epe4md_casos_payback]
#' @param premissas_reg data.frame. Input de premissas regulatórias para serem
#' consideradas nos cálculos.
#' @param ano_base numeric. Ano base da projeção. Define o ano em que a função
#' irá buscar a base de dados. Último ano completo realizado.
#' @param sequencial logic. Parâmetro que define se a projeção deve ser
#' realizada de forma sequencial ou paralela. Para executar a projeção de forma
#' sequencial defina o parâmetro como TRUE. Default igual a FALSE.
#' @param filtro_de_uf string. Parâmetro que define uma unidade federativa (UF) a
#' ser filtrada. Caso uma UF não seja indicada ou seja informado um valor inválido,
#' o resultado será apresentado sem filtros.
#' @param filtro_de_segmento string. Parâmetro que define um segmento a ser
#' filtrado. Pode se escolher entre "comercial_at", "comercial_at_remoto",
#' "comercial_bt", "residencial" e "residencial_remoto".  Caso não seja
#' informado um valor ou seja informado um valor inválido o resultado será
#' apresentado sem filtro.
#' @param filtro_de_custo_unitario_max numeric. Parâmetro que define o valor
#' máximo do custo unitário para ser utilizado no cálculo do payback. Default
#' igual a NULL.
#' @param altera_sistemas_existentes logic. TRUE se alterações regulatórias
#' afetam investimentos realizados em anos anteriores à revisão da regulação.
#' Default igual a FALSE.
#' @param ano_decisao_alteracao numeric. Ano em que são definidas novas regras e
#' se tornam de conhecimento público. Esse parâmetro só tem efeito caso o
#' anterior seja igual a TRUE. Default igual a 2021.
#' @param inflacao mumeric. Taxa anual de inflacao considerada no reajuste das
#' tarifas e para calcular o retorno real de projetos. Default igual a 0.0375.
#' @param taxa_desconto_nominal numeric. Taxa de desconto nominal considerada
#' nos cálculos de payback descontado. Default igual a 0.13.
#' @param custo_reforco_rede numeric. Custo em R$/kW aplicado a projetos de
#' geracao remota em Alta Tensão. Representa um custo pago pelo empreendedor
#' para reforços na rede. Default igual a 200.
#' @param ano_troca_inversor numeric. Ano, a partir do ano de instalação, em que
#' é realizada a troca do inversor fotovoltaico. Default igual a 11.
#' @param pagamento_disponibilidade numeric. Percentual de meses em que o
#' consumidor residencial paga custo de disponbilidade em função da
#' variabilidade da geração FV. Default igual a 0.3. Tem efeito somente até o
#' ano de 2022.
#' @param disponibilidade_kwh_mes numeric. Consumo de disponbilidade do
#' consumidor em kWh/mês. Default igual a 100, equivalente a um consumidor
#' trifásico. Tem efeito somente até o ano de 2022.
#' @param desconto_capex_local numeric. Percentual de desconto a ser aplicado no
#' CAPEX de sistemas de geração local(ex: 0.1) para simulação de incentivos.
#' Default igual a 0.
#' @param anos_desconto vector. Anos em que há a incidência do desconto no
#' CAPEX. Default igual a 0.
#' @param dir_dados_premissas Diretório onde se encontram as premissas. Se esse
#' parâmetro não for passado, a função usa os dados default que são instalados
#' com o pacote. É importante que os nomes dos arquivos sejam os mesmos da
#' pasta default.
#'
#' @return data.frame. Métricas financeiras para cada caso.
#' @export
#'
#'@import tidyr
#'@rawNamespace import(purrr, except=c(discard))
#'@import readxl
#'@import dplyr
#'@import future
#'@import tibble
#'
#'@encoding UTF-8
#'
#' @examples
#'
#' casos_payback <- tibble::tibble(
#'   segmento = "comercial_at",
#'   fonte_resumo = "Fotovoltaica",
#'   fator_autoconsumo = 0.8,
#'   oem_anual = 0.01,
#'   nome_4md = c("OUTRA", "RGE", "RORAIMA", "SULGIPE", "UHENPAL"),
#'   fc = c(0.1633388, 0.1513311, 0.1505592, 0.1649651, 0.1481121),
#'   vida_util = 25,
#'   degradacao = 0.005,
#'   pot_sistemas = 70,
#'   geracao_1_kwh = c(100159.36, 92796.22, 92322.91, 101156.62, 90822.36),
#'   ano = 2021,
#'   custo_unitario = 3.81,
#'   custo_inversor = 0.5715,
#'   capex_inicial = 266700,
#'   capex_inversor = 57808.98
#' )
#'
#' premissas_regulatorias <- tibble::tibble(
#'   ano = 2021,
#'   alternativa = 0,
#'   p_transicao = 1.00,
#'   binomia = FALSE,
#'   demanda_g = FALSE
#' )
#'
#' payback <- epe4md_payback(
#'   casos_payback = casos_payback,
#'   premissas_reg = premissas_regulatorias,
#'   ano_base = 2021,
#'   sequencial = TRUE,
#'   filtro_de_uf = "RR,
#'   filtro_de_segmento = "comercial_at",
#'   filtro_de_custo_unitario_max = 6,
#'   altera_sistemas_existentes = TRUE,
#'   ano_decisao_alteracao = 2023,
#'   inflacao = 0.0375,
#'   taxa_desconto_nominal = 0.13,
#'   custo_reforco_rede = 200,
#'   ano_troca_inversor = 11,
#'   pagamento_disponibilidade = 0.3,
#'   disponibilidade_kwh_mes = 100,
#'   desconto_capex_local = 0,
#'   anos_desconto = 0,
#'   dir_dados_premissas = NA_character_
#' )

utils::globalVariables(c("tarifa_demanda_c", "tarifa_demanda_g", "binomia", "demanda_g",
                         "p_transicao", "alternativa", "ano_simulacao", "tarifa_autoc_bin_tusd",
                         "tarifa_autoc_tusd", "energia_ano", "energia_autoc", "capex",
                         "desconto_capex", "ano_real", "taxa_inflacao", "tarifa_autoc_te",
                         "impostos_cheio", "energia_inj", "tarifa_inj_te", "tarifa_inj_tusd",
                         "impostos_tusd", "pag_inj_te", "pag_inj_tusd", "tarifa_demanda",
                         "consumo_disponibilidade", "receita_autoc", "receita_inj_completa",
                         "pag_compensacao", "demanda_contratada", "oem", "troca_inversor",
                         "capex_obra", "custo_disponibilidade", "saldo_anual", "taxa_desconto",
                         "saldo_anual_desc", "saldo_acumulado", ".temp_maior_negativo",
                         ".temp_menor_positivo", ".temp_payback_inteiro", ".temp_payback_frac",
                         "saldo_acumulado_desc", "vida_util", "fator_autoconsumo",
                         "geracao_1_kwh", "degradacao", "capex_inicial", "capex_inversor",
                         "oem_anual", "pot_sistemas"))

epe4md_payback <- function(
    casos_payback,
    premissas_reg,
    ano_base,
    sequencial,
    filtro_de_uf,
    filtro_de_segmento,
    filtro_de_custo_unitario_max,
    altera_sistemas_existentes = TRUE,
    ano_decisao_alteracao = 2023,
    inflacao = 0.0375,
    taxa_desconto_nominal = 0.13,
    custo_reforco_rede = 200,
    ano_troca_inversor = 11,
    pagamento_disponibilidade = 0.3,
    disponibilidade_kwh_mes = 100,
    desconto_capex_local = 0,
    anos_desconto = 0,
    dir_dados_premissas = NA_character_
) {


  dir_dados_premissas <- if_else(
    is.na(dir_dados_premissas),
    system.file(stringr::str_glue("dados_premissas/{ano_base}"),
                package = "epe4md"),
    dir_dados_premissas
  )


  fator_construcao <-
    read_xlsx(stringr::str_glue("{dir_dados_premissas}/tempo_construcao.xlsx"),
                                sheet = "fator")

  tarifas <-
    read_xlsx(stringr::str_glue("{dir_dados_premissas}/tarifas_4md.xlsx"))

  tarifas_comercial_at <- tarifas %>%
    filter(subgrupo == "A4") %>%
    mutate(tarifa_demanda_g = 0,
           tarifa_demanda_c = 0,
           segmento = "comercial_at")

  tarifas_demanda_a <- tarifas %>%
    filter(subgrupo == "A4") %>%
    select(nome_4md, ano, tarifa_demanda_c, tarifa_demanda_g) %>%
    unique()

  tarifas_comercial_at_remoto <- tarifas %>%
    filter(subgrupo == "B3") %>%
    mutate(segmento = "comercial_at_remoto") %>%
    select(-tarifa_demanda_c, - tarifa_demanda_g) %>%
    left_join(tarifas_demanda_a, by = c("ano", "nome_4md"),
              multiple = "all")

  tarifas_residencial <- tarifas %>%
    filter(subgrupo == "B1") %>%
    mutate(segmento = "residencial")

  tarifas_residencial_remoto <- tarifas %>%
    filter(subgrupo == "B1") %>%
    mutate(segmento = "residencial_remoto")

  tarifas_comercial_bt <- tarifas %>%
    filter(subgrupo == "B3") %>%
    mutate(segmento = "comercial_bt")

  tarifas <- bind_rows(tarifas_comercial_at, tarifas_comercial_at_remoto,
                       tarifas_residencial,
                       tarifas_residencial_remoto, tarifas_comercial_bt)


# premissas regulatorias

  anos <- tibble(ano = seq(2013, 2050, 1))

  premissas_regulatorias <- left_join(anos, premissas_reg, by = "ano",
                                      multiple = "all") %>%
    mutate(across(
      .cols = c(binomia, demanda_g),
      .fns = ~as.logical(.x))) %>%
    fill(2:5) %>%
    mutate(p_transicao = ifelse(is.na(p_transicao), 1, p_transicao),
           alternativa = ifelse(is.na(alternativa), 0, alternativa),
           across(
             .cols = c(binomia, demanda_g),
             .fns = ~ifelse(is.na(.x), FALSE, .x)
           )
  )

  premissas_regulatorias <- premissas_regulatorias %>%
    mutate(alternativa = ifelse(binomia == TRUE & alternativa %in% c(0, 1),
                                2,
                                alternativa))

  # Aplicando filtro de UF
  tabela_regiao <-
    readxl::read_xlsx(stringr::str_glue("{dir_dados_premissas}/tabela_dist_subs.xlsx"))

  casos_payback <- casos_payback %>%
    left_join(tabela_regiao, by = c("nome_4md"))

  lista_uf <- casos_payback$uf %>% unique()

  if(filtro_de_uf %in% lista_uf){
    casos_payback <- casos_payback %>%
      filter(uf == filtro_de_uf)
  }
  else if (filtro_de_uf != "N"){
    message("\nUF incorreta! Resultado apresentado sem filtro!")
  }

  # Aplicando filtro de segmento
  lista_segmentos <- casos_payback$segmento %>% unique()

  if(filtro_de_segmento %in% lista_segmentos){
    casos_payback <- casos_payback %>%
      filter(segmento == filtro_de_segmento)
  }
  else if (filtro_de_segmento != "N"){
    message("\nSegmento incorreto! Resultado apresentado sem filtro!")
  }

  # Aplicando filtro de custo unitário máximo
  if(!(is.null(filtro_de_custo_unitario_max))){
    casos_payback <- casos_payback %>%
      filter(custo_unitario <= filtro_de_custo_unitario_max)
  }

  fluxo_de_caixa <- function(nome_4md, ano, segmento, vida_util,
                             fator_autoconsumo, geracao_1_kwh, degradacao,
                             capex_inicial, capex_inversor, oem_anual,
                             pot_sistemas) {

    fluxo_caixa <- data.frame("ano_simulacao" = 1:vida_util,
                              "segmento" = segmento,
                              "nome_4md" = nome_4md,
                              "ano" = ano)

    fluxo_caixa <- fluxo_caixa %>%
      left_join(fator_construcao, by = "segmento",
                multiple = "all") %>%
      mutate(fator_construcao = ifelse(ano_simulacao == 1, fator_construcao, 1))


    if (altera_sistemas_existentes == TRUE && ano >= ano_decisao_alteracao) {
      fluxo_caixa <- fluxo_caixa %>%
        mutate(ano = row_number() + ano - 1,
               ano = ifelse(ano > 2050, 2050, ano))
    }

    fluxo_caixa <- left_join(fluxo_caixa, premissas_regulatorias, by = "ano",
                             multiple = "all")

    fluxo_caixa <- left_join(fluxo_caixa, tarifas,
                             by = c("ano", "nome_4md",
                                    "segmento", "alternativa"),
                             multiple = "all")

    fluxo_caixa <- fluxo_caixa %>%
      mutate(tarifa_autoc_tusd = ifelse(binomia == TRUE,
                                        tarifa_autoc_bin_tusd,
                                        tarifa_autoc_tusd),
             tarifa_demanda = ifelse(demanda_g == TRUE,
                                     tarifa_demanda_g,
                                     tarifa_demanda_c),
             custo_obra = ifelse(segmento == "comercial_at_remoto" &
                                   row_number() == 1,
                                 - custo_reforco_rede * pot_sistemas, 0),
             consumo_disponibilidade = ifelse(segmento == "comercial_at" |
                                                binomia == TRUE,
                                              0,
                                              disponibilidade_kwh_mes)) %>%
      select(-tarifa_demanda_c, -tarifa_demanda_g, -tarifa_autoc_bin_tusd)


    fluxo_caixa <- fluxo_caixa %>%
      mutate(energia_ano = geracao_1_kwh * fator_construcao *
               (1 + degradacao)^(1 - ano_simulacao),
             energia_autoc = energia_ano * fator_autoconsumo,
             energia_inj = energia_ano - energia_autoc,
             capex = 0,
             troca_inversor = 0,
             capex_obra = 0,
             taxa_inflacao = (1 + inflacao)^(ano_simulacao - 1)
      )

    fluxo_caixa[1, "capex"] <- -capex_inicial
    fluxo_caixa[ano_troca_inversor, "troca_inversor"] <- -capex_inversor

    #aplicar desconto no capex
    fluxo_caixa <- fluxo_caixa %>%
      mutate(desconto_capex = desconto_capex_local,
             capex = ifelse(segmento %in% c("residencial",
                                            "comercial_bt", "comercial_at") &
                              ano %in% anos_desconto,
                            capex * (1 - desconto_capex),
                            capex))

    # ano auxiliar para possibilitar alteracoes com base no ano
    fluxo_caixa <- fluxo_caixa %>%
      mutate(ano_real = row_number() + first(ano) - 1,
             ano_real = ifelse(ano_real > 2050, 2050, ano_real))



    fluxo_caixa <- fluxo_caixa %>%
      mutate(receita_autoc = (taxa_inflacao * energia_autoc *
                                (tarifa_autoc_tusd + tarifa_autoc_te)) /
               (1 - impostos_cheio),
             receita_inj_completa = (taxa_inflacao * energia_inj *
                                       tarifa_inj_te / (1 - impostos_cheio)) +
               (taxa_inflacao * energia_inj * tarifa_inj_tusd /
                  (1 - impostos_tusd)),
             pag_compensacao = ((taxa_inflacao * energia_inj * pag_inj_te /
                                   (1 - impostos_cheio)) +
                                  (taxa_inflacao * energia_inj * pag_inj_tusd /
                                     (1 - impostos_tusd))) * -p_transicao,
             demanda_contratada = -taxa_inflacao * pot_sistemas *
               tarifa_demanda * 12 / (1 - impostos_cheio),
             capex_obra = 0,
             custo_disponibilidade = ifelse(ano_real <= 2022, #novo marco legal
                                            -pagamento_disponibilidade * 12 *
                                              consumo_disponibilidade *
                                              fator_construcao *
               taxa_inflacao * (tarifa_autoc_tusd + tarifa_autoc_te) /
               (1 - impostos_cheio),
               0)

      )


    fluxo_caixa <- fluxo_caixa %>%
      mutate(oem = -oem_anual * capex_inicial * fator_construcao,
             saldo_anual = capex + receita_autoc + receita_inj_completa +
               pag_compensacao + demanda_contratada + oem +
               troca_inversor + capex_obra + custo_disponibilidade,
             saldo_acumulado = cumsum(saldo_anual),
             taxa_desconto = (1 + taxa_desconto_nominal)^(ano_simulacao - 1),
             saldo_anual_desc = saldo_anual / taxa_desconto,
             saldo_acumulado_desc = cumsum(saldo_anual_desc))

    metricas <- fluxo_caixa %>%
      summarise(
        .temp_payback_inteiro = sum(saldo_acumulado < 0),
        .temp_menor_positivo = suppressWarnings(min(if_else(saldo_acumulado > 0,
                                                            saldo_acumulado,
                                                            NA_real_),
                                                    na.rm = TRUE)),
        .temp_maior_negativo = max(if_else(saldo_acumulado < 0,
                                           saldo_acumulado,
                                           NA_real_), na.rm = TRUE),
        .temp_payback_frac = -.temp_maior_negativo /
          (.temp_menor_positivo - .temp_maior_negativo),
        payback = .temp_payback_inteiro + .temp_payback_frac,
        .temp_payback_inteiro = sum(saldo_acumulado_desc < 0),
        .temp_menor_positivo = suppressWarnings(min(if_else(
          saldo_acumulado_desc > 0,
          saldo_acumulado_desc,
          NA_real_), na.rm = TRUE)),
        .temp_maior_negativo = max(if_else(saldo_acumulado_desc < 0,
                                           saldo_acumulado_desc,
                                           NA_real_), na.rm = TRUE),
        .temp_payback_frac = -.temp_maior_negativo /
          (.temp_menor_positivo - .temp_maior_negativo),
        payback_desc = .temp_payback_inteiro + .temp_payback_frac
      ) %>%
      select(
        -starts_with(".temp_")
      )


    metricas <- metricas %>%
      mutate(tir_nominal = jrvFinance::irr(fluxo_caixa$saldo_anual),
             tir_nominal = ifelse(is.na(tir_nominal) & payback == 25,
                                  -0.2,
                                  tir_nominal),
             tir_real = (1 + tir_nominal) / (1 + inflacao) - 1)

  }

  if(sequencial == TRUE){
    future::plan(future::sequential())

    resultado_payback <- casos_payback %>%
      mutate(saida = purrr::pmap(.l = list(nome_4md, ano, segmento,
                                                  vida_util, fator_autoconsumo,
                                                  geracao_1_kwh, degradacao,
                                                  capex_inicial, capex_inversor,
                                                  oem_anual, pot_sistemas),
                                 .f = fluxo_de_caixa)) %>%
      unnest(saida)
  }
  else{
    # Definindo a estratégia de paralelismo
    future::plan(future::multisession())

    # Executando a função em paralelo
    resultado_payback <- casos_payback %>%
      mutate(saida = furrr::future_pmap(.l = list(nome_4md, ano, segmento,
                                                  vida_util, fator_autoconsumo,
                                                  geracao_1_kwh, degradacao,
                                                  capex_inicial, capex_inversor,
                                                  oem_anual, pot_sistemas),
                                        .f = fluxo_de_caixa,
                                        .progress = TRUE)) %>%
      unnest(saida)

    # Encerrando o cluster paralelo
    future::plan(future::sequential)
  }

  resultado_payback

}
