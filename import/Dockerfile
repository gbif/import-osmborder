FROM openmaptiles/postgis:2.9
ENV IMPORT_DIR=/import

RUN apt-get update && apt-get install -y --no-install-recommends \
      wget \
      ca-certificates \
      xz-utils \
      bc

RUN wget --progress=dot:mega -O pgfutter https://github.com/lukasmartinelli/pgfutter/releases/download/v1.1/pgfutter_linux_amd64 \
 && chmod +x pgfutter \
 && mv pgfutter /usr/local/bin/ \
 && mkdir -p $IMPORT_DIR \
 && wget --progress=dot:giga -O $IMPORT_DIR/osmborder_lines_3857.csv.xz http://download.gbif.org/2017/07/osmborder/osmborder_lines_3857.csv.xz \
 && wget --progress=dot:giga -O $IMPORT_DIR/osmborder_lines_4326.csv.xz http://download.gbif.org/2017/07/osmborder/osmborder_lines_4326.csv.xz \
 && apt-get purge -y --auto-remove \
      wget \
      ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app/
COPY . /usr/src/app/
CMD ["./import_osmborder_lines.sh"]
