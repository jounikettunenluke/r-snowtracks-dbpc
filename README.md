# Lumijälki-indeksin laskenta Sulka-tietokannasta

R-koodi hakee valitun lajin lumijälkiaineiston Sulka-tietokannasta ja laskee sille lumijälki-indeksin.

## Toiminta

Koodi:

1. muodostaa tietokantayhteyden turvallisesti
2. hakee `sulka.export_lumijaljet`-näkymästä valitun lajin aineiston
3. säilyttää alkuperäisen aineiston `lumijaljet_raw`-data framessa
4. laskee jälkien kertymisajan (`snow_days`)
5. validoi laskennan lähtötiedot
6. laskee lumijälki-indeksin.

## Tarvittavat R-paketit

```r
library(DBI)
library(RPostgres)
library(dplyr)
library(rstudioapi)
```

## Lajin valinta

Tarkasteltava laji määritellään koodissa:

```r
valittu_laji <- "ahma"
```

Lajisuodatus tehdään jo tietokantakyselyssä, joten R:ään haetaan vain valitun lajin aineisto.

## Lumijälki-indeksi

Indeksi lasketaan kaavalla:

```text
n_tracks / snow_days / (covered_distance / 10000)
```

missä:

- `n_tracks` = havaittujen jälkien määrä
- `snow_days` = jälkien kertymisaika vuorokausina
- `covered_distance` = laskettu matka metreinä.

Indeksin yksikkö on **jälkiä / vrk / 10 km**.

Kertymisen alku määritetään esikierron päättymisen ja lumisateen perusteella. Indeksi lasketaan vain riveille, joiden lähtötiedot läpäisevät validoinnin. Virheelliset rivit säilytetään aineistossa ja niiden indeksiksi tulee `NA`.

## Tietoturva

Käyttäjätunnus ja salasana kysytään yhteyden muodostamisen yhteydessä. Salasanaa ei kirjoiteta lähdekoodiin eikä tallenneta erilliseen globaaliin R-muuttujaan.

Tietokantayhteys suljetaan työn lopuksi:

```r
dbDisconnect(con)
```
