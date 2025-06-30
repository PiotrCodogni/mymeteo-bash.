#!/bin/bash

# Piotr Codogni

if [[ "$1" == "--help" || "$1" == "--h" ]]; then
	echo "Aby skrypt zadzialal poprawnie nalezy uzyc konstrukcji \"--city miasto\" gdzie zmienna  miasto jest dowolna miejsowoacia w Polsce"
	exit 0
fi

Dane_o_stacjach="https://danepubliczne.imgw.pl/api/data/synop"
podkatalog="$HOME/.cache/projekt_pogoda"
stacje_lat_lon="$podkatalog/stacje_lat_lon.json"

mkdir -p "$podkatalog"

if [ ! -f "$podkatalog/nazwa_stacji.txt" ]; then
    curl -s "$Dane_o_stacjach" | jq -r ".[].stacja" > "$podkatalog/nazwa_stacji.txt"
fi
mapfile -t nazwa_stacji < "$podkatalog/nazwa_stacji.txt"

if [[ ! -f "$stacje_lat_lon" || ! -s "$stacje_lat_lon" ]]; then
    echo "{}" > "$stacje_lat_lon"

	for nazwa in "${nazwa_stacji[@]}"; do
		nazwa_zakodowana=$(echo "$nazwa" | jq -s -R -r @uri)
		zapytanie=$(curl -s "https://nominatim.openstreetmap.org/search?q="$nazwa_zakodowana"&format=json&limit=1")
        lat=$(echo "$zapytanie" | jq -r ".[0].lat")
        lon=$(echo "$zapytanie" | jq -r ".[0].lon")

		lat_i_lon=$(jq -n --arg lat "$lat" --arg lon "$lon" '{lat: $lat, lon: $lon}')
        jq --arg nazwa "$nazwa" --argjson lat_i_lon "$lat_i_lon" '.[$nazwa] = $lat_i_lon' "$stacje_lat_lon" > "$stacje_lat_lon.tmp"
        mv "$stacje_lat_lon.tmp" "$stacje_lat_lon"

        sleep 1
	done
fi

if [ "$1" == "--city" ]; then
	CITY="$2"
fi

city_zakodowane=$(echo "$CITY" | jq -s -R -r @uri)
sleep 1
zapytanie_city=$(curl -s "https://nominatim.openstreetmap.org/search?q="$city_zakodowane"&format=json&limit=1")
lat_city=$(echo "$zapytanie_city" | jq -r ".[0].lat")
lon_city=$(echo "$zapytanie_city" | jq -r ".[0].lon")
najblizsze_miasto=""
odleglosc_miasta=""

for miasto in $(jq -r "keys[]" "$stacje_lat_lon" | sed "s/ /%20/g"); do #kodowanie spacji aby for dobrze iterowal po nazwach miast ze spacjami
    # Przywracamy spacje w nazwach miast
    miasto=$(echo "$miasto" | sed "s/%20/ /g")
 
    # Pobieramy dane dla danego miasta
    lat_miasto=$(jq -r --arg miasto "$miasto" '.[$miasto].lat' "$stacje_lat_lon")
    lon_miasto=$(jq -r --arg miasto "$miasto" '.[$miasto].lon' "$stacje_lat_lon")	

	#wzor euklidesa
	delta_lat=$(echo ""$lat_city" - "$lat_miasto"" | bc -l)
	delta_lon=$(echo ""$lon_city" - "$lon_miasto"" | bc -l)

	srednia_lat=$(echo "("$lat_city" + "$lat_miasto") / 2" | bc -l)
	srednia_lat_w_radianach=$(echo ""$srednia_lat" * (4 * a(1)) / 180" | bc -l)
	cos_lat=$(echo "c("$srednia_lat_w_radianach")" | bc -l)

	km_lat=$(echo ""$delta_lat" * 111" | bc -l)
	km_lon=$(echo ""$delta_lon" * 111 * "$cos_lat"" | bc -l)

	odleglosc=$(echo "sqrt("$km_lat"^2 + "$km_lon"^2)" | bc -l)

	if [[ -z "$odleglosc_miasta" ]]; then
		odleglosc_miasta="$odleglosc"
		najblizsze_miasto="$miasto" 
	else
		if [[ $(echo ""$odleglosc" < "$odleglosc_miasta"" | bc -l) -eq 1 ]]; then
			odleglosc_miasta="$odleglosc"
			najblizsze_miasto="$miasto"
		fi
	fi
done

dane_stacji=$(curl -s "$Dane_o_stacjach" | jq --arg najblizsza_stacja "$najblizsze_miasto" '.[] | select(.stacja == $najblizsza_stacja)')

nazwa_stacji=$(echo "$dane_stacji" | jq -r '.stacja')
temperatura=$(echo "$dane_stacji" | jq -r '.temperatura')
predkosc_wiatru=$(echo "$dane_stacji" | jq -r '.predkosc_wiatru')
kierunek_wiatru=$(echo "$dane_stacji" | jq -r '.kierunek_wiatru')
wilgotnosc=$(echo "$dane_stacji" | jq -r '.wilgotnosc_wzgledna')
suma_opadu=$(echo "$dane_stacji" | jq -r '.suma_opadu')
cisnienie=$(echo "$dane_stacji" | jq -r '.cisnienie')

echo "Miasto: "$nazwa_stacji""
echo "Data: "$(date '+%Y-%m-%d %H:%M')""
echo "Temperatura: "$temperatura" °C"
echo "Predkosc wiatru: "$predkosc_wiatru" m/s"
echo "Kierunek wiatru: "$kierunek_wiatru" °"
echo "Wilgotnosc wzgledna: "$wilgotnosc" %"
echo "Suma opadu: "$suma_opadu" mm"
echo "Cisnienie: "$cisnienie" hPa"
