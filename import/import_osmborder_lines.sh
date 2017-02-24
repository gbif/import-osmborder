#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

function import_csv() {
    local csv_file="$1"
    local table_name="$2"
    echo "Import CSV file $csv_file"
    pgfutter \
        --schema "public" \
        --host "$POSTGRES_HOST" \
        --port "$POSTGRES_PORT" \
        --dbname "$POSTGRES_DB" \
        --username "$POSTGRES_USER" \
        --pass "$POSTGRES_PASSWORD" \
        --table "$table_name" \
    csv \
        --fields "osm_id,admin_level,dividing_line,disputed,maritime,geometry" \
        --delimiter $'\t' \
    "$csv_file"
}

function exec_psql() {
    PGPASSWORD=$POSTGRES_PASSWORD psql --host="$POSTGRES_HOST" --port="$POSTGRES_PORT"--dbname="$POSTGRES_DB" --username="$POSTGRES_USER"
}

function drop_table() {
    local table=$1
    local drop_command="DROP TABLE IF EXISTS $table CASCADE;"
    echo "$drop_command" | exec_psql
}

function generalize_border() {
    local target_table_name="$1"
    local source_table_name="$2"
    local tolerance="$3"
    local max_admin_level="$4"
    echo "Generalize $target_table_name with tolerance $tolerance from $source_table_name"
    echo "CREATE TABLE $target_table_name AS SELECT ST_Simplify(geometry, $tolerance) AS geometry, osm_id, admin_level, dividing_line, disputed, maritime FROM $source_table_name WHERE admin_level <= $max_admin_level;" | exec_psql
    echo "CREATE INDEX ON $target_table_name USING gist (geometry);" | exec_psql
    echo "ANALYZE $target_table_name;" | exec_psql
}

function create_import_table() {
    local target_table_name="$1"
    echo "CREATE TABLE $target_table_name (osm_id bigint, admin_level int, dividing_line bool, disputed bool, maritime bool, geometry Geometry(LineString, $PROJECTION));" | exec_psql
    echo "CREATE INDEX ON $target_table_name USING gist (geometry);" | exec_psql
}

# Convert metres to degrees
function convert_units() {
	if [[ "$PROJECTION" == 3857 ]]; then
		echo "$1"
	else
		# 1° latitude ~= 111km. 1° longitude varies between 111km at the equator, and 79km at 45°, and 0km at 90°.  Use 79km.
		echo "$1*1.0/78847" | bc -l
		# Convert square metres to square degrees
		#echo "$1/510065621724000.0*41253.96" | bc -l
	fi
}

function import_borders() {
    local csv_file="$1"
    local table_name="osm_border_linestring"
    drop_table "$table_name"
    echo "Create import table"
    create_import_table "$table_name"
    import_csv "$csv_file" "$table_name"

    local gen1_table_name="osm_border_linestring_gen1"
    drop_table "$gen1_table_name"
    generalize_border "$gen1_table_name" "$table_name" $(convert_units 10) 10

    local gen2_table_name="osm_border_linestring_gen2"
    drop_table "$gen2_table_name"
    generalize_border "$gen2_table_name" "$table_name" $(convert_units 20) 10

    local gen3_table_name="osm_border_linestring_gen3"
    drop_table "$gen3_table_name"
    generalize_border "$gen3_table_name" "$table_name" $(convert_units 40) 8

    local gen4_table_name="osm_border_linestring_gen4"
    drop_table "$gen4_table_name"
    generalize_border "$gen4_table_name" "$table_name" $(convert_units 80) 6

    local gen5_table_name="osm_border_linestring_gen5"
    drop_table "$gen5_table_name"
    generalize_border "$gen5_table_name" "$table_name" $(convert_units 160) 6

    local gen6_table_name="osm_border_linestring_gen6"
    drop_table "$gen6_table_name"
    generalize_border "$gen6_table_name" "$table_name" $(convert_units 300) 4

    local gen7_table_name="osm_border_linestring_gen7"
    drop_table "$gen7_table_name"
    generalize_border "$gen7_table_name" "$table_name" $(convert_units 600) 4

    local gen8_table_name="osm_border_linestring_gen8"
    drop_table "$gen8_table_name"
    generalize_border "$gen8_table_name" "$table_name" $(convert_units 1200) 4

    local gen9_table_name="osm_border_linestring_gen9"
    drop_table "$gen9_table_name"
    generalize_border "$gen9_table_name" "$table_name" $(convert_units 2400) 4

    local gen10_table_name="osm_border_linestring_gen10"
    drop_table "$gen10_table_name"
    generalize_border "$gen10_table_name" "$table_name" $(convert_units 4800) 2
}

function uncompress_borders() {
    local csv_file="$1"
	if [[ ! -f "$csv_file" ]]; then
		unxz "$csv_file.xz"
	fi
}

uncompress_borders "$IMPORT_DIR/osmborder_lines_$PROJECTION.csv"
import_borders "$IMPORT_DIR/osmborder_lines_$PROJECTION.csv"
