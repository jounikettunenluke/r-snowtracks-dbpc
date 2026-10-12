# ============================================================
# Lumijälki-indeksin laskenta Sulka-tietokannasta
# ============================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(rstudioapi)


# ------------------------------------------------------------
# 1. Muodostetaan tietokantayhteys turvallisesti
# ------------------------------------------------------------

# Käyttäjätunnus ja salasana kysytään yhteysfunktion sisällä.
# Salasanaa ei tallenneta erilliseen globaaliin muuttujaan.

connect_sulka <- function() {
  
  user <- readline("Käyttäjätunnus: ")
  
  con <- dbConnect(
    RPostgres::Postgres(),
    host = "lukedb2prod.ns.luke.fi",
    port = 5432,
    dbname = "rktl",
    user = user,
    password = rstudioapi::askForPassword(
      "Tietokannan salasana"
    )
  )
  
  return(con)
}

con <- connect_sulka()


# ------------------------------------------------------------
# 2. Valitaan tarkasteltava laji
# ------------------------------------------------------------

valittu_laji <- "ahma"


# ------------------------------------------------------------
# 3. Haetaan aineisto tietokannasta
# ------------------------------------------------------------

# Lajisuodatus tehdään jo tietokannassa, jolloin R:ään
# haetaan vain tarkasteltavan lajin aineisto.

sql <- "
SELECT *
FROM sulka.export_lumijaljet
WHERE laji = $1
"

lumijaljet_raw <- dbGetQuery(
  con,
  sql,
  params = list(valittu_laji)
)

# Tarkastellaan haettua aineistoa.
head(lumijaljet_raw)


# ------------------------------------------------------------
# 4. Muodostetaan analyysiaineisto
# ------------------------------------------------------------

# Alkuperäinen lumijaljet_raw säilytetään muuttumattomana.
# Laskennalliset muuttujat lisätään uuteen lumijaljet-data frameen.

lumijaljet <- lumijaljet_raw %>%
  mutate(
    
    # wltTrackIndex()-funktio käyttää vuosimuuttujan nimenä year.
    year = as.integer(vuosi),
    
    # Muutetaan lumisateen ajankohta aikamuotoon.
    lumisateen_aika_dt = as.POSIXct(
      lumisateen_aika,
      tz = "Europe/Helsinki"
    ),
    
    # Jälkien kertymisen alku on viimeisin jäljet nollaava tapahtuma:
    # esikierron päättyminen tai lumisade.
    kertymisen_alku = case_when(
      !is.na(esikierron_loppuaika) ~
        pmax(
          esikierron_loppuaika,
          lumisateen_aika_dt,
          na.rm = TRUE
        ),
      TRUE ~ lumisateen_aika_dt
    ),
    
    # Lasketaan jälkien kertymisaika vuorokausina.
    snow_days = as.numeric(
      difftime(
        laskennan_alkuaika,
        kertymisen_alku,
        units = "days"
      )
    ),
    
    # Tarkistetaan indeksin laskennassa tarvittavat lähtötiedot.
    validointi = case_when(
      is.na(n_tracks) ~
        "Virhe: n_tracks puuttuu",
      
      n_tracks < 0 ~
        "Virhe: n_tracks < 0",
      
      n_tracks != round(n_tracks) ~
        "Virhe: n_tracks ei ole kokonaisluku",
      
      is.na(covered_distance) ~
        "Virhe: covered_distance puuttuu",
      
      covered_distance <= 0 ~
        "Virhe: covered_distance <= 0",
      
      is.na(laskennan_alkuaika) ~
        "Virhe: laskennan_alkuaika puuttuu",
      
      is.na(kertymisen_alku) ~
        "Virhe: kertymisen alkuaika puuttuu",
      
      is.na(snow_days) ~
        "Virhe: snow_days puuttuu",
      
      !is.finite(snow_days) ~
        "Virhe: snow_days ei ole kelvollinen",
      
      snow_days <= 0 ~
        "Virhe: snow_days <= 0",
      
      TRUE ~ "OK"
    ),
    
    # Lasketaan lumijälki-indeksi:
    #
    # n_tracks / snow_days / (covered_distance / 10 000)
    #
    # covered_distance on metreinä.
    # Indeksin yksikkö on jälkiä / vrk / 10 km.
    #
    # Indeksi lasketaan vain riveille, joiden lähtötiedot
    # läpäisevät yllä olevan validoinnin.
    lumijalki_indeksi = if_else(
      validointi == "OK",
      n_tracks / snow_days / (covered_distance / 10000),
      NA_real_
    )
  )

# Tarkastellaan muodostettua analyysiaineistoa.
head(lumijaljet)


# ------------------------------------------------------------
# 5. Tarkastellaan mahdollisia ongelmia
# ------------------------------------------------------------
# Listataan rivit, jotka eivät läpäisseet lähtötietojen validointia.
lumijaljet %>%
  filter(validointi != "OK") %>%
  select(
    knum,
    vuosi,
    laji,
    n_tracks,
    covered_distance,
    lumisateen_aika,
    esikierron_loppuaika,
    laskennan_alkuaika,
    snow_days,
    validointi
  )
# Yhteenveto validoinnin tuloksista


lumijaljet %>%
  count(validointi, sort = TRUE)




# ------------------------------------------------------------
# 6. Suljetaan tietokantayhteys
# ------------------------------------------------------------


dbDisconnect(con)

